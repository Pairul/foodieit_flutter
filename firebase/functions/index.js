// Foodieit Cloud Functions — backend permission enforcement & calculations
//
// These Cloud Functions run with admin SDK privileges and enforce:
// - Distance-based delivery pricing (not calculable on client alone)
// - Commission calculations (never trust client for financial values)
// - Rider approval status changes (riders cannot approve themselves)
// - Order status transitions (only valid state machine transitions)
// - Audit log entries

const functions = require('firebase-functions/v2');
const admin = require('firebase-admin');
admin.initializeApp();

const db = admin.firestore();

// ── Calculate delivery fee ────────────────────────────────────────────
// Called by the client before placing an order.
// Returns the confirmed distance, fee, and pricing snapshot.
exports.calculateDeliveryFee = functions.https.onCall(async (request) => {
  const { restaurantId, deliveryLat, deliveryLng } = request.data;
  const uid = request.auth.uid;
  if (!uid) throw new functions.https.HttpsError('unauthenticated', 'Sign in required.');

  // Fetch config and restaurant from Firestore
  const configDoc = await db.collection('config').doc('deliveryPricing').get();
  const config = configDoc.data() || {
    baseFeeCents: 200,
    perKmRateCents: 50,
    minFeeCents: 200,
    maxServiceRangeKm: 15,
    roundingUnitCents: 10,
    riderPayoutBaseCents: 100,
    riderPayoutPerKmCents: 40,
    riderPayoutPercentage: 0.75,
  };

  const restDoc = await db.collection('restaurants').doc(restaurantId).get();
  const restaurant = restDoc.data();
  if (!restaurant) throw new functions.https.HttpsError('not-found', 'Restaurant not found.');
  if (!restaurant.active) throw new functions.https.HttpsError('failed-precondition', 'Restaurant is inactive.');
  if (!restaurant.location) throw new functions.https.HttpsError('failed-precondition', 'Restaurant location not set.');

  // Calculate road distance using Google Maps Distance Matrix API
  // In production, call:
  //   https://maps.googleapis.com/maps/api/distancematrix/json?origins=...&destinations=...&key=API_KEY
  // For now, use Haversine with road factor as fallback
  const distance = haversineDistance(
    restaurant.location.lat, restaurant.location.lng,
    deliveryLat, deliveryLng
  ) * 1.35; // road factor

  const maxRange = restaurant.serviceRangeKm || config.maxServiceRangeKm;
  if (distance > maxRange) {
    throw new functions.https.HttpsError('failed-precondition',
      `Delivery address is ${distance.toFixed(1)} km away — outside the ${maxRange.toFixed(0)} km service range.`);
  }

  const fee = calculateFee(distance, config);
  const riderPayout = calculateRiderPayout(distance, fee, config);

  return {
    restaurantPoint: restaurant.location,
    deliveryPoint: { lat: deliveryLat, lng: deliveryLng },
    distanceKm: distance,
    deliveryFeeCents: fee,
    riderPayoutCents: riderPayout,
    maxServiceRangeKm: maxRange,
    pricingSnapshot: config,
  };
});

// ── Calculate commission ──────────────────────────────────────────────
exports.calculateCommission = functions.https.onCall(async (request) => {
  const { foodSubtotalCents, discountCents = 0 } = request.data;
  const configDoc = await db.collection('config').doc('commission').get();
  const config = configDoc.data() || { commissionRatePercent: 10, discountsReduceBase: true };

  const base = config.discountsReduceBase
    ? Math.max(0, foodSubtotalCents - discountCents)
    : foodSubtotalCents;
  const commission = Math.round(base * config.commissionRatePercent / 100);

  return {
    commissionCents: commission,
    restaurantNetCents: foodSubtotalCents - commission,
    commissionRatePercent: config.commissionRatePercent,
  };
});

// ── Approve rider (admin only) ────────────────────────────────────────
// This function is the ONLY way to change rider approval status.
// Riders cannot call this on themselves.
exports.approveRider = functions.https.onCall(async (request) => {
  const { riderId } = request.data;
  const uid = request.auth.uid;
  if (!uid) throw new functions.https.HttpsError('unauthenticated', 'Sign in required.');

  // Verify caller is admin
  const callerDoc = await db.collection('users').doc(uid).get();
  if (callerDoc.data().role !== 'admin') {
    throw new functions.https.HttpsError('permission-denied', 'Administrator access required.');
  }
  if (riderId === uid) {
    throw new functions.https.HttpsError('permission-denied', 'You cannot approve yourself.');
  }

  // Verify rider has all required documents and none are expired
  const docsSnap = await db.collection('rider_documents')
    .where('riderId', '==', riderId).get();
  const requiredTypes = ['license', 'vehicleRegistration', 'insurance'];
  for (const type of requiredTypes) {
    const typeDocs = docsSnap.docs.filter(d => d.data().type === type);
    if (typeDocs.length === 0) {
      throw new functions.https.HttpsError('failed-precondition', `Missing document: ${type}`);
    }
    const expired = typeDocs.some(d => {
      const expiry = d.data().expiryDate;
      return expiry && expiry.toDate() < new Date();
    });
    if (expired) {
      throw new functions.https.HttpsError('failed-precondition', `${type} has expired.`);
    }
  }

  // Update rider status
  await db.collection('users').doc(riderId).update({
    riderApprovalStatus: 'approved',
    rejectionReason: admin.firestore.FieldValue.delete(),
  });

  // Write audit log entry
  await db.collection('audit_log').add({
    riderId,
    actorId: uid,
    actorRole: 'admin',
    action: 'rider_approved',
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { success: true };
});

// ── Place order (trusted checkout) ────────────────────────────────────
// This is the ONLY way orders should be created in production.
// It revalidates prices, checks availability, calculates financials server-side,
// and uses an idempotency key to prevent duplicate orders.
exports.placeOrder = functions.https.onCall(async (request) => {
  const {
    restaurantId,
    quantities,      // { foodId: qty, ... }
    addressId,
    idempotencyKey,
    deliveryLat,
    deliveryLng,
  } = request.data;
  const uid = request.auth.uid;
  if (!uid) throw new functions.https.HttpsError('unauthenticated', 'Sign in required.');

  // ── Idempotency check: return existing order if this key was already used ──
  if (idempotencyKey) {
    const existingSnap = await db.collection('orders')
      .where('idempotencyKey', '==', idempotencyKey)
      .where('customerId', '==', uid)
      .limit(1)
      .get();
    if (!existingSnap.empty) {
      return { orderId: existingSnap.docs[0].id, duplicate: true };
    }
  }

  // ── Validate customer ──
  const callerDoc = await db.collection('users').doc(uid).get();
  const caller = callerDoc.data();
  if (!caller || caller.role !== 'customer') {
    throw new functions.https.HttpsError('permission-denied', 'Customer access required.');
  }

  // ── Validate delivery address ──
  const addrDoc = await db.collection('addresses').doc(addressId).get();
  const address = addrDoc.data();
  if (!address || address.customerId !== uid) {
    throw new functions.https.HttpsError('permission-denied', 'Invalid delivery address.');
  }

  // ── Validate restaurant ──
  const restDoc = await db.collection('restaurants').doc(restaurantId).get();
  const restaurant = restDoc.data();
  if (!restaurant) throw new functions.https.HttpsError('not-found', 'Restaurant not found.');
  if (!restaurant.active) throw new functions.https.HttpsError('failed-precondition', 'Restaurant is inactive.');

  // ── Revalidate all items and fetch current prices from backend ──
  const foodItemIds = Object.keys(quantities);
  const foodDocs = await Promise.all(
    foodItemIds.map(id => db.collection('food_items').doc(id).get())
  );

  let foodSubtotalCents = 0;
  const orderItems = [];

  for (let i = 0; i < foodItemIds.length; i++) {
    const foodDoc = foodDocs[i];
    const foodId = foodItemIds[i];
    const qty = quantities[foodId];

    if (!foodDoc.exists) {
      throw new functions.https.HttpsError('not-found', `Food item ${foodId} not found.`);
    }
    const food = foodDoc.data();
    if (!food.available) {
      throw new functions.https.HttpsError('failed-precondition', `${food.name} is no longer available.`);
    }
    if (food.restaurantId !== restaurantId) {
      throw new functions.https.HttpsError('failed-precondition', `${food.name} does not belong to this restaurant.`);
    }
    if (qty <= 0) {
      throw new functions.https.HttpsError('invalid-argument', `Invalid quantity for ${food.name}.`);
    }

    const lineTotalCents = food.priceCents * qty;
    foodSubtotalCents += lineTotalCents;

    orderItems.push({
      foodId,
      foodName: food.name,
      unitPriceCents: food.priceCents,   // server-fetched, never client-trusted
      quantity: qty,
      lineTotalCents,
    });
  }

  if (orderItems.length === 0) {
    throw new functions.https.HttpsError('invalid-argument', 'Cart is empty.');
  }

  // ── Calculate delivery fee (distance-based or demo) ──
  let deliveryFeeCents = 0;
  let distanceKm = 0;
  if (restaurant.location && deliveryLat && deliveryLng) {
    const configDoc = await db.collection('config').doc('deliveryPricing').get();
    const config = configDoc.data() || {
      baseFeeCents: 200, perKmRateCents: 50, minFeeCents: 200,
      maxServiceRangeKm: 15, roundingUnitCents: 10,
    };
    distanceKm = haversineDistance(
      restaurant.location.lat, restaurant.location.lng,
      deliveryLat, deliveryLng
    ) * 1.35;
    const maxRange = restaurant.serviceRangeKm || config.maxServiceRangeKm;
    if (distanceKm > maxRange) {
      throw new functions.https.HttpsError('failed-precondition',
        `Delivery address is ${distanceKm.toFixed(1)} km away — outside the ${maxRange.toFixed(0)} km service range.`);
    }
    deliveryFeeCents = calculateFee(distanceKm, config);
  } else {
    // Demo fee when location is not available
    deliveryFeeCents = 300; // RM 3.00 demo flat fee
  }

  // ── Calculate commission (separate from customer total) ──
  const commissionConfigDoc = await db.collection('config').doc('commission').get();
  const commissionConfig = commissionConfigDoc.data() || { commissionRatePercent: 10 };
  const commissionCents = Math.round(foodSubtotalCents * commissionConfig.commissionRatePercent / 100);

  // ── Calculate customer total ──
  const discountCents = 0; // no discounts in demo
  const customerTotalCents = foodSubtotalCents + deliveryFeeCents - discountCents;

  // ── Create order atomically ──
  const orderRef = db.collection('orders').doc();
  await orderRef.set({
    id: orderRef.id,
    customerId: uid,
    customerName: caller.name,
    restaurantId,
    restaurantName: restaurant.name,
    status: 'placed',
    revision: 1,
    items: orderItems,
    address: {
      recipient: address.recipient,
      phone: address.phone,
      addressLine: address.addressLine,
      notes: address.notes || '',
    },
    deliveryPoint: address.coordinates || null,
    financials: {
      foodSubtotalCents,
      deliveryFeeCents,
      discountCents,
      customerTotalCents,
      commissionCents,
      commissionRatePercent: commissionConfig.commissionRatePercent,
      restaurantNetCents: foodSubtotalCents - commissionCents,
    },
    distanceKm,
    idempotencyKey: idempotencyKey || null,
    placedAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // ── Clear cart after successful order ──
  const cartRef = db.collection('carts').doc(uid);
  const cartItemsSnap = await cartRef.collection('cart_items').get();
  const batch = db.batch();
  cartItemsSnap.docs.forEach(doc => batch.delete(doc.ref));
  batch.update(cartRef, { restaurantId: null, restaurantName: null, revision: admin.firestore.FieldValue.increment(1), updatedAt: admin.firestore.FieldValue.serverTimestamp() });
  await batch.commit();

  // ── Audit log ──
  await db.collection('audit_log').add({
    orderId: orderRef.id,
    actorId: uid,
    actorRole: 'customer',
    action: 'order_placed',
    details: { totalCents: customerTotalCents, itemCount: orderItems.length },
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { orderId: orderRef.id, duplicate: false };
});

// ── Seed sample data ──────────────────────────────────────────────────
// Call once to populate restaurants, food items, and demo order.
// Usage: call from client with admin credentials.
exports.seedSampleData = functions.https.onCall(async (request) => {
  const uid = request.auth.uid;
  if (!uid) throw new functions.https.HttpsError('unauthenticated', 'Sign in required.');
  const callerDoc = await db.collection('users').doc(uid).get();
  if (callerDoc.data().role !== 'admin') {
    throw new functions.https.HttpsError('permission-denied', 'Administrator access required.');
  }

  // Check if already seeded
  const existing = await db.collection('restaurants').doc('r1').get();
  if (existing.exists) {
    return { success: true, message: 'Data already seeded.' };
  }

  const batch = db.batch();

  // 5 sample restaurants
  const restaurants = [
    { id: 'r1', name: 'Selera Kampung', cuisine: 'Malaysian', rating: 4.6, active: true,
      openHours: '08:00-22:00', deliveryFeeCents: 300, serviceRangeKm: 15,
      imageUrl: 'https://images.unsplash.com/photo-1565557623264-ba0f5b2cf84e?w=800',
      location: { lat: 3.2154, lng: 101.7267 },
      address: 'Jalan Genting Klang, Kuala Lumpur' },
    { id: 'r2', name: 'Burger Corner', cuisine: 'Western', rating: 4.4, active: true,
      openHours: '10:00-23:00', deliveryFeeCents: 300, serviceRangeKm: 15,
      imageUrl: 'https://images.unsplash.com/photo-1571091718767-18b5b1457add?w=800',
      location: { lat: 3.1663, lng: 101.6240 },
      address: 'Jalan Tuanku Abdul Rahman, Kuala Lumpur' },
    { id: 'r3', name: 'Pizza House', cuisine: 'Italian', rating: 4.5, active: true,
      openHours: '11:00-23:30', deliveryFeeCents: 300, serviceRangeKm: 15,
      imageUrl: 'https://images.unsplash.com/photo-1513104890138-7c7496593de1?w=800',
      location: { lat: 3.1190, lng: 101.6740 },
      address: 'Jalan Bukit Bintang, Kuala Lumpur' },
    { id: 'r4', name: 'Rasa Thai', cuisine: 'Thai', rating: 4.6, active: true,
      openHours: '11:00-22:00', deliveryFeeCents: 300, serviceRangeKm: 15,
      imageUrl: 'https://images.unsplash.com/photo-1559329007-40df8a9345d7?w=800',
      location: { lat: 3.1040, lng: 101.6800 },
      address: 'Jalan Ampang, Kuala Lumpur' },
    { id: 'r5', name: 'Sweet Treats', cuisine: 'Dessert', rating: 4.7, active: true,
      openHours: '10:00-22:00', deliveryFeeCents: 300, serviceRangeKm: 15,
      imageUrl: 'https://images.unsplash.com/photo-1551024601-bec78aea704b?w=800',
      location: { lat: 3.1270, lng: 101.6870 },
      address: 'Jalan Bangsar, Kuala Lumpur' },
  ];
  restaurants.forEach(r => {
    const ref = db.collection('restaurants').doc(r.id);
    batch.set(ref, r);
  });

  // 15 sample food items (prices in sen: RM = sen / 100)
  const foods = [
    { id: 'f1', name: 'Nasi Lemak Ayam', restaurantId: 'r1', priceCents: 1290, categoryId: 'Main', available: true,
      imageUrl: 'https://images.unsplash.com/photo-1645469138201-6b81b9c25f33?w=800',
      description: 'Coconut rice with fried chicken, sambal, peanuts, and egg.' },
    { id: 'f2', name: 'Mee Goreng Mamak', restaurantId: 'r1', priceCents: 1100, categoryId: 'Main', available: true,
      imageUrl: 'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?w=800',
      description: 'Spicy stir-fried noodles with vegetables and egg.' },
    { id: 'f3', name: 'Roti Canai', restaurantId: 'r1', priceCents: 300, categoryId: 'Snack', available: true,
      imageUrl: 'https://images.unsplash.com/photo-1631292784644-0f4f5f5b5b5b?w=800',
      description: 'Flaky flatbread served with curry dipping sauce.' },
    { id: 'f4', name: 'Teh Ais', restaurantId: 'r1', priceCents: 300, categoryId: 'Beverage', available: true,
      imageUrl: 'https://images.unsplash.com/photo-1576092768241-dec231879fc3?w=800',
      description: 'Iced milk tea, classic Malaysian favourite.' },
    { id: 'f5', name: 'Beef Burger', restaurantId: 'r2', priceCents: 1450, categoryId: 'Main', available: true,
      imageUrl: 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=800',
      description: 'Juicy beef patty with cheese, lettuce, and tomato.' },
    { id: 'f6', name: 'Chicken Burger', restaurantId: 'r2', priceCents: 1250, categoryId: 'Main', available: true,
      imageUrl: 'https://images.unsplash.com/photo-1606755962773-d324e0a13086?w=800',
      description: 'Crispy chicken fillet burger with mayo and slaw.' },
    { id: 'f7', name: 'Fries', restaurantId: 'r2', priceCents: 600, categoryId: 'Snack', available: true,
      imageUrl: 'https://images.unsplash.com/photo-1573080496219-bb080dd4f877?w=800',
      description: 'Golden fried potato wedges with salt.' },
    { id: 'f8', name: 'Cola', restaurantId: 'r2', priceCents: 350, categoryId: 'Beverage', available: true,
      imageUrl: 'https://images.unsplash.com/photo-1554866585-cd94860890b7?w=800',
      description: 'Chilled cola, 330ml.' },
    { id: 'f9', name: 'Margherita Pizza', restaurantId: 'r3', priceCents: 1890, categoryId: 'Main', available: true,
      imageUrl: 'https://images.unsplash.com/photo-1604068549290-dea0e4a305ca?w=800',
      description: 'Classic pizza with mozzarella, basil, and tomato sauce.' },
    { id: 'f10', name: 'Pepperoni Pizza', restaurantId: 'r3', priceCents: 2190, categoryId: 'Main', available: true,
      imageUrl: 'https://images.unsplash.com/photo-1513104890138-7c7496593de1?w=800',
      description: 'Pizza topped with pepperoni slices and cheese.' },
    { id: 'f11', name: 'Garlic Bread', restaurantId: 'r3', priceCents: 700, categoryId: 'Snack', available: true,
      imageUrl: 'https://images.unsplash.com/photo-1573140247632-f8fd74997d5c?w=800',
      description: 'Toasted bread with garlic butter and herbs.' },
    { id: 'f12', name: 'Tom Yum Goong', restaurantId: 'r4', priceCents: 1690, categoryId: 'Main', available: true,
      imageUrl: 'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?w=800',
      description: 'Spicy and sour prawn soup with lemongrass.' },
    { id: 'f13', name: 'Pad Thai', restaurantId: 'r4', priceCents: 1490, categoryId: 'Main', available: true,
      imageUrl: 'https://images.unsplash.com/photo-1559314809-0d155014e29e?w=800',
      description: 'Stir-fried rice noodles with shrimp, egg, and peanuts.' },
    { id: 'f14', name: 'Thai Milk Tea', restaurantId: 'r4', priceCents: 500, categoryId: 'Beverage', available: true,
      imageUrl: 'https://images.unsplash.com/photo-1576092768241-dec231879fc3?w=800',
      description: 'Sweet and creamy Thai iced tea.' },
    { id: 'f15', name: 'Mango Sticky Rice', restaurantId: 'r5', priceCents: 990, categoryId: 'Dessert', available: true,
      imageUrl: 'https://images.unsplash.com/photo-1604068549290-dea0e4a305ca?w=800',
      description: 'Sweet sticky rice with fresh mango and coconut cream.' },
  ];
  foods.forEach(f => {
    const ref = db.collection('food_items').doc(f.id);
    batch.set(ref, f);
  });

  await batch.commit();
  return { success: true, message: 'Seeded 5 restaurants and 15 food items.' };
});

// ── Order status transition (enforced on backend) ─────────────────────
exports.updateOrderStatus = functions.https.onCall(async (request) => {
  const { orderId, newStatus } = request.data;
  const uid = request.auth.uid;
  if (!uid) throw new functions.https.HttpsError('unauthenticated', 'Sign in required.');

  const orderDoc = await db.collection('orders').doc(orderId).get();
  const order = orderDoc.data();
  if (!order) throw new functions.https.HttpsError('not-found', 'Order not found.');

  const callerDoc = await db.collection('users').doc(uid).get();
  const caller = callerDoc.data();

  // Validate permissions
  const isAdmin = caller.role === 'admin';
  const isAssignedRider = order.riderId === uid && caller.role === 'rider';
  const isOrderCustomer = order.customerId === uid && caller.role === 'customer';

  // Only admin or assigned rider can change delivery status
  if (!isAdmin && !isAssignedRider) {
    throw new functions.https.HttpsError('permission-denied', 'Not authorized.');
  }

  // Validate state machine transition
  const current = order.status;
  const validTransitions = {
    'placed': ['updated', 'cancelled', 'assigned'],
    'updated': ['cancelled', 'assigned'],
    'assigned': ['pickedUp', 'cancelled'],
    'pickedUp': ['delivered', 'cancelled'],
    'delivered': [],
    'cancelled': [],
    'draft': ['placed'],
  };

  if (!validTransitions[current] || !validTransitions[current].includes(newStatus)) {
    throw new functions.https.HttpsError('failed-precondition', `Invalid transition: ${current} -> ${newStatus}`);
  }

  await db.collection('orders').doc(orderId).update({
    status: newStatus,
    revision: admin.firestore.FieldValue.increment(1),
  });

  // Clear rider location records when delivered or cancelled
  if (newStatus === 'delivered' || newStatus === 'cancelled') {
    if (order.riderId) {
      const locSnap = await db.collection('orders').doc(orderId)
        .collection('rider_locations').get();
      const batch = db.batch();
      locSnap.docs.forEach(doc => batch.delete(doc.ref));
      await batch.commit();
    }
  }

  // Write audit log
  await db.collection('audit_log').add({
    orderId,
    actorId: uid,
    actorRole: caller.role,
    action: 'status_changed',
    details: { from: current, to: newStatus },
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { success: true };
});

// ── Helper functions ──────────────────────────────────────────────────
function haversineDistance(lat1, lng1, lat2, lng2) {
  const R = 6371; // km
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLng = (lng2 - lng1) * Math.PI / 180;
  const a = Math.sin(dLat/2) * Math.sin(dLat/2) +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
    Math.sin(dLng/2) * Math.sin(dLng/2);
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
}

function calculateFee(distance, config) {
  const raw = config.baseFeeCents + Math.round(distance * config.perKmRateCents);
  const clamped = Math.max(config.minFeeCents, raw);
  return roundTo(clamped, config.roundingUnitCents);
}

function calculateRiderPayout(distance, fee, config) {
  const flat = config.riderPayoutBaseCents + Math.round(distance * config.riderPayoutPerKmCents);
  const percentage = Math.round(fee * config.riderPayoutPercentage);
  return roundTo(Math.max(flat, percentage), config.roundingUnitCents);
}

function roundTo(value, unit) {
  return unit <= 0 ? value : Math.round(value / unit) * unit;
}
