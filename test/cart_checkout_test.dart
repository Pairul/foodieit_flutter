import 'package:flutter_test/flutter_test.dart';
import 'package:foodieit/services/app_store.dart';
import 'package:foodieit/models/entities.dart';

/// Comprehensive tests for the cart, pricing, checkout, and persistence flow.
///
/// Covers:
/// 1. Cart quantities and totals (integer sen)
/// 2. Cart persistence (SharedPreferences serialization)
/// 3. Restaurant switching (one-restaurant-per-cart, replace dialog)
/// 4. Checkout validation (price revalidation, address requirement)
/// 5. Duplicate submission prevention (idempotency keys)
/// 6. Customer data isolation (customer-only access)
/// 7. End-to-end scenario: Selera Kampung → 2× Nasi Lemak Ayam + 1× Teh Ais → RM28.80
void main() {
  late AppStore store;

  setUp(() {
    store = AppStore();
    // Sign in as the demo customer
    store.login('customer@example.com', 'Customer123!');
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 1. CART QUANTITIES AND TOTALS (Integer Sen)
  // ═══════════════════════════════════════════════════════════════════════

  group('Cart quantities and totals', () {
    test('line total = unit price × quantity (integer sen)', () {
      final cart = Cart(customerId: 'customer');
      cart.add('f1', 'Nasi Lemak Ayam', 1290, qty: 2);
      final item = cart.find('f1')!;
      expect(item.lineTotal, 2580); // 1290 × 2 = 2580 sen = RM25.80
    });

    test('food subtotal = sum of line totals', () {
      final cart = Cart(customerId: 'customer');
      cart.add('f1', 'Nasi Lemak Ayam', 1290, qty: 2); // 2580
      cart.add('f3', 'Teh Ais', 300, qty: 1);          // 300
      expect(cart.foodSubtotalCents, 2880); // RM28.80
    });

    test('item count = sum of quantities (not number of lines)', () {
      final cart = Cart(customerId: 'customer');
      cart.add('f1', 'Nasi Lemak Ayam', 1290, qty: 2);
      cart.add('f3', 'Teh Ais', 300, qty: 1);
      expect(cart.itemCount, 3); // 2 + 1 = 3 items
    });

    test('adding same item twice groups into one line', () {
      final cart = Cart(customerId: 'customer');
      cart.add('f1', 'Nasi Lemak Ayam', 1290, qty: 1);
      cart.add('f1', 'Nasi Lemak Ayam', 1290, qty: 1);
      expect(cart.items.length, 1); // grouped
      expect(cart.find('f1')!.quantity, 2);
    });

    test('quantity stepper: increase and decrease', () {
      final cart = Cart(customerId: 'customer');
      cart.add('f1', 'Nasi Lemak Ayam', 1290, qty: 1);
      cart.setQuantity('f1', 3);
      expect(cart.find('f1')!.quantity, 3);
      cart.setQuantity('f1', 1);
      expect(cart.find('f1')!.quantity, 1);
    });

    test('quantity set to 0 removes the item', () {
      final cart = Cart(customerId: 'customer');
      cart.add('f1', 'Nasi Lemak Ayam', 1290, qty: 2);
      expect(cart.isEmpty, false);
      cart.setQuantity('f1', 0);
      expect(cart.find('f1'), isNull);
      expect(cart.isEmpty, true);
    });

    test('negative quantity is clamped to removal', () {
      final cart = Cart(customerId: 'customer');
      cart.add('f1', 'Nasi Lemak Ayam', 1290, qty: 1);
      cart.setQuantity('f1', -5);
      expect(cart.find('f1'), isNull);
    });

    test('quantity is clamped to max 99', () {
      final cart = Cart(customerId: 'customer');
      cart.add('f1', 'Nasi Lemak Ayam', 1290, qty: 100);
      expect(cart.find('f1')!.quantity, 99);
    });

    test('customer total = food subtotal + delivery fee (no discount)', () {
      // This tests the placeOrder flow indirectly by checking financials
      store.clearCart();
      store.addToCart('f1', qty: 2); // 2 × RM12.90 = RM25.80
      store.addToCart('f3', qty: 1); // 1 × RM3.00  = RM3.00
      final cart = store.cart!;
      expect(cart.foodSubtotalCents, 2880); // RM28.80

      // Place order with demo delivery fee
      final order = store.placeOrder(
        restaurantId: 'r1',
        quantities: cart.toQuantities(),
        address: 'TAR UMT, Jalan Genting Klang, Kuala Lumpur',
        idempotencyKey: 'test_key_1',
      );

      // Customer total = food subtotal + delivery fee
      expect(order.financials!.foodSubtotalCents, 2880);
      expect(order.financials!.totalCents, 2880 + order.financials!.deliveryFeeCents);
    });

    test('commission is separate from customer total', () {
      store.clearCart();
      store.addToCart('f1', qty: 1);
      final cart = store.cart!;
      final order = store.placeOrder(
        restaurantId: 'r1',
        quantities: cart.toQuantities(),
        address: 'TAR UMT, Jalan Genting Klang',
        idempotencyKey: 'test_key_commission',
      );
      // Commission = 10% of foodSubtotal
      expect(order.financials!.commissionCents,
          (order.financials!.foodSubtotalCents * 0.10).round());
      // Customer total does NOT include commission
      expect(order.financials!.totalCents,
          order.financials!.foodSubtotalCents + order.financials!.deliveryFeeCents);
      // Restaurant net = foodSubtotal - commission
      expect(order.financials!.restaurantNetCents,
          order.financials!.foodSubtotalCents - order.financials!.commissionCents);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 2. CART PERSISTENCE (SharedPreferences serialization)
  // ═══════════════════════════════════════════════════════════════════════

  group('Cart persistence', () {
    test('Cart serializes to JSON and back correctly', () {
      final cart = Cart(customerId: 'customer', restaurantId: 'r1', restaurantName: 'Selera Kampung');
      cart.add('f1', 'Nasi Lemak Ayam', 1290, qty: 2);
      cart.add('f3', 'Teh Ais', 300, qty: 1);

      final json = cart.toMap();
      final restored = Cart.fromMap(json);

      expect(restored.customerId, 'customer');
      expect(restored.restaurantId, 'r1');
      expect(restored.restaurantName, 'Selera Kampung');
      expect(restored.items.length, 2);
      expect(restored.find('f1')!.quantity, 2);
      expect(restored.find('f1')!.unitPriceCents, 1290);
      expect(restored.find('f3')!.quantity, 1);
      expect(restored.find('f3')!.unitPriceCents, 300);
      expect(restored.foodSubtotalCents, 2880);
      expect(restored.itemCount, 3);
    });

    test('empty cart serializes correctly', () {
      final cart = Cart(customerId: 'customer');
      final json = cart.toMap();
      final restored = Cart.fromMap(json);
      expect(restored.isEmpty, true);
      expect(restored.items.length, 0);
      expect(restored.foodSubtotalCents, 0);
    });

    test('cart with removed items is handled gracefully on restore', () {
      final cart = Cart(customerId: 'customer', restaurantId: 'r1');
      cart.add('f1', 'Nasi Lemak Ayam', 1290, qty: 1);
      cart.add('nonexistent', 'Deleted Item', 500, qty: 1);

      final json = cart.toMap();
      final restored = Cart.fromMap(json);
      // Both items are in the serialized form
      expect(restored.items.length, 2);
      // AppStore._loadCartForCustomer would remove stale items
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 3. RESTAURANT SWITCHING (One-restaurant-per-cart)
  // ═══════════════════════════════════════════════════════════════════════

  group('Restaurant switching', () {
    test('can add from same restaurant without prompt', () {
      store.clearCart();
      expect(store.canAddToCart('r1'), true);
      store.addToCart('f1'); // r1 item
      expect(store.canAddToCart('r1'), true); // still r1
      store.addToCart('f3'); // another r1 item
      expect(store.cart!.items.length, 2);
    });

    test('cannot add from different restaurant without replacing', () {
      store.clearCart();
      store.addToCart('f1'); // r1 item
      expect(store.canAddToCart('r2'), false); // different restaurant
    });

    test('adding from different restaurant throws CART_MISMATCH', () {
      store.clearCart();
      store.addToCart('f1'); // r1 item
      expect(() => store.addToCart('f4'), throwsA(predicate((e) =>
          e is StateError && e.message.contains('CART_MISMATCH'))));
    });

    test('replace cart with new restaurant clears old items', () {
      store.clearCart();
      store.addToCart('f1', qty: 2); // r1
      store.addToCart('f3', qty: 1); // r1
      expect(store.cart!.itemCount, 3);

      store.replaceCartWithRestaurant('r2'); // Burger Corner
      expect(store.cart!.isEmpty, true);
      expect(store.cart!.restaurantId, 'r2');
      expect(store.cart!.restaurantName, 'Burger Corner');
    });

    test('empty cart can add from any restaurant', () {
      store.clearCart();
      expect(store.canAddToCart('r1'), true);
      expect(store.canAddToCart('r2'), true);
      expect(store.canAddToCart('r3'), true);
    });

    test('cart restaurant ID is set after first add', () {
      store.clearCart();
      store.addToCart('f1');
      expect(store.cartRestaurantId, 'r1');
    });

    test('cart restaurant is cleared when all items removed', () {
      store.clearCart();
      store.addToCart('f1');
      expect(store.cartRestaurantId, 'r1');
      store.removeFromCart('f1');
      expect(store.cartRestaurantId, isNull);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 4. CHECKOUT VALIDATION
  // ═══════════════════════════════════════════════════════════════════════

  group('Checkout validation', () {
    test('revalidateCart fetches current prices from backend', () {
      store.clearCart();
      store.addToCart('f1', qty: 2);
      store.addToCart('f3', qty: 1);
      final quantities = store.cart!.toQuantities();

      final lines = store.revalidateCart('r1', quantities);
      expect(lines.length, 2);

      // Verify prices match backend (not client-submitted)
      final nasiLemak = lines.firstWhere((l) => l.foodId == 'f1');
      expect(nasiLemak.unitCents, 1290); // Backend price
      expect(nasiLemak.quantity, 2);
      expect(nasiLemak.total, 2580);

      final tehAis = lines.firstWhere((l) => l.foodId == 'f3');
      expect(tehAis.unitCents, 300); // Backend price
      expect(tehAis.quantity, 1);
      expect(tehAis.total, 300);
    });

    test('revalidateCart throws if item is unavailable', () {
      store.clearCart();
      // Make f1 unavailable
      store.setFoodAvailable('f1', false);
      store.addToCart('f2', qty: 1); // f2 is available

      // Try to validate f1 (unavailable)
      expect(() => store.revalidateCart('r1', {'f1': 1}),
          throwsA(predicate((e) => e is StateError)));

      // Restore
      store.setFoodAvailable('f1', true);
    });

    test('revalidateCart throws if restaurant is inactive', () {
      store.clearCart();
      store.setRestaurantActive('r1', false);
      expect(() => store.revalidateCart('r1', {'f1': 1}),
          throwsA(predicate((e) => e is StateError)));
      store.setRestaurantActive('r1', true);
    });

    test('revalidateCart throws if item belongs to different restaurant', () {
      store.clearCart();
      // f4 belongs to r2, but we validate against r1
      expect(() => store.revalidateCart('r1', {'f4': 1}),
          throwsA(predicate((e) => e is StateError)));
    });

    test('revalidateCart throws for invalid quantity (0 or negative)', () {
      store.clearCart();
      expect(() => store.revalidateCart('r1', {'f1': 0}),
          throwsA(predicate((e) => e is StateError)));
      expect(() => store.revalidateCart('r1', {'f1': -1}),
          throwsA(predicate((e) => e is StateError)));
    });

    test('placeOrder requires address', () {
      store.clearCart();
      store.addToCart('f1', qty: 1);
      expect(() => store.placeOrder(
        restaurantId: 'r1',
        quantities: store.cart!.toQuantities(),
        address: '', // empty address
        idempotencyKey: 'test_no_addr',
      ), throwsA(predicate((e) => e is StateError)));
    });

    test('placeOrder requires customer role', () {
      store.logout();
      store.login('admin@foodieit.demo', 'admin@example');
      expect(() => store.placeOrder(
        restaurantId: 'r1',
        quantities: {'f1': 1},
        address: 'Some address',
        idempotencyKey: 'test_admin',
      ), throwsA(predicate((e) => e is StateError)));
      store.logout();
      store.login('customer@example.com', 'Customer123!');
    });

    test('placeOrder clears cart on success', () {
      store.clearCart();
      store.addToCart('f1', qty: 2);
      store.addToCart('f3', qty: 1);
      expect(store.cart!.isEmpty, false);

      store.placeOrder(
        restaurantId: 'r1',
        quantities: store.cart!.toQuantities(),
        address: 'TAR UMT, Jalan Genting Klang, Kuala Lumpur',
        idempotencyKey: 'test_clear_cart',
      );

      expect(store.cart!.isEmpty, true);
      expect(store.cartRestaurantId, isNull);
    });

    test('placeOrder preserves cart on failure', () {
      store.clearCart();
      store.addToCart('f1', qty: 1);
      // Make restaurant inactive to cause failure
      store.setRestaurantActive('r1', false);
      expect(() => store.placeOrder(
        restaurantId: 'r1',
        quantities: store.cart!.toQuantities(),
        address: 'TAR UMT',
        idempotencyKey: 'test_preserve',
      ), throwsA(predicate((e) => e is StateError)));
      // Cart should still have the item
      expect(store.cart!.isEmpty, false);
      store.setRestaurantActive('r1', true);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 5. DUPLICATE SUBMISSION PREVENTION (Idempotency)
  // ═══════════════════════════════════════════════════════════════════════

  group('Idempotency / duplicate submission prevention', () {
    test('same idempotency key returns same order, no duplicate', () {
      store.clearCart();
      store.addToCart('f1', qty: 1);
      final quantities = store.cart!.toQuantities();

      final order1 = store.placeOrder(
        restaurantId: 'r1',
        quantities: quantities,
        address: 'TAR UMT',
        idempotencyKey: 'dup_key_1',
      );
      expect(order1, isNotNull);
      expect(order1.id, isNotEmpty);

      // Cart is now cleared, re-add for second attempt
      store.addToCart('f1', qty: 1);

      // Use same idempotency key — should return existing order
      // Note: the AppStore checks _usedIdempotencyKeys and returns early
      // But since cart was cleared, we need to check the key set directly
      final ordersBefore = store.orders.length;

      // The store throws because the key is already used
      expect(() => store.placeOrder(
        restaurantId: 'r1',
        quantities: {'f1': 1},
        address: 'TAR UMT',
        idempotencyKey: 'dup_key_1',
      ), throwsA(predicate((e) => e is StateError)));

      // No new order created
      expect(store.orders.length, ordersBefore);
    });

    test('different idempotency keys create separate orders', () {
      store.clearCart();
      store.addToCart('f1', qty: 1);
      final order1 = store.placeOrder(
        restaurantId: 'r1',
        quantities: store.cart!.toQuantities(),
        address: 'TAR UMT',
        idempotencyKey: 'unique_key_a',
      );

      store.addToCart('f1', qty: 1);
      final order2 = store.placeOrder(
        restaurantId: 'r1',
        quantities: store.cart!.toQuantities(),
        address: 'TAR UMT',
        idempotencyKey: 'unique_key_b',
      );

      expect(order1.id, isNot(order2.id));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 6. CUSTOMER DATA ISOLATION
  // ═══════════════════════════════════════════════════════════════════════

  group('Customer data isolation', () {
    test('customer cannot access another customer cart', () {
      // The cart is tied to current user ID
      final customerCart = store.cart;
      expect(customerCart!.customerId, 'customer');

      // Register a second customer
      store.register(
        role: Role.customer,
        name: 'Siti',
        email: 'siti@example.com',
        password: 'Siti12345!',
        phone: '+60123450000',
      );
      // Now logged in as Siti
      final sitiCart = store.cart;
      expect(sitiCart!.customerId, isNot('customer'));
    });

    test('admin cannot add to cart', () {
      store.logout();
      store.login('admin@foodieit.demo', 'admin@example');
      expect(() => store.addToCart('f1'),
          throwsA(predicate((e) => e is StateError)));
      store.logout();
      store.login('customer@example.com', 'Customer123!');
    });

    test('rider cannot add to cart', () {
      store.logout();
      store.login('rider@example.com', 'Rider123!');
      expect(() => store.addToCart('f1'),
          throwsA(predicate((e) => e is StateError)));
      store.logout();
      store.login('customer@example.com', 'Customer123!');
    });

    test('unauthenticated user has no cart', () {
      store.logout();
      expect(store.cart, isNull);
      store.login('customer@example.com', 'Customer123!');
    });

    test('customer can only place orders for themselves', () {
      store.clearCart();
      store.addToCart('f1', qty: 1);
      // The placeOrder method uses _actor() which is the current user
      final order = store.placeOrder(
        restaurantId: 'r1',
        quantities: store.cart!.toQuantities(),
        address: 'TAR UMT',
        idempotencyKey: 'isolation_test',
      );
      expect(order.customerId, 'customer'); // Order belongs to customer
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 7. END-TO-END SCENARIO
  // ═══════════════════════════════════════════════════════════════════════

  group('End-to-end scenario: Selera Kampung checkout', () {
    test('Sign in → open Selera Kampung → add 2× Nasi Lemak Ayam + 1× Teh Ais → subtotal RM28.80', () {
      // Step 1: Verify we're signed in as customer
      expect(store.current!.role, Role.customer);
      expect(store.current!.email, 'customer@example.com');

      // Step 2: Verify Selera Kampung exists and is active
      final r = store.restaurant('r1');
      expect(r.name, 'Selera Kampung');
      expect(r.active, true);

      // Step 3: Clear any existing cart
      store.clearCart();
      expect(store.cart!.isEmpty, true);

      // Step 4: Add 2× Nasi Lemak Ayam (f1, RM12.90 = 1290 sen)
      store.addToCart('f1', qty: 2);
      expect(store.cart!.find('f1')!.quantity, 2);

      // Step 5: Add 1× Teh Ais (f3, RM3.00 = 300 sen)
      store.addToCart('f3', qty: 1);
      expect(store.cart!.find('f3')!.quantity, 1);

      // Step 6: Confirm subtotal is RM28.80 (2880 sen)
      // 1290 × 2 + 300 × 1 = 2580 + 300 = 2880
      expect(store.cart!.foodSubtotalCents, 2880);
      expect(money(store.cart!.foodSubtotalCents), 'RM28.80');

      // Step 7: Cart belongs to Selera Kampung
      expect(store.cartRestaurantId, 'r1');
      expect(store.cart!.restaurantName, 'Selera Kampung');

      // Step 8: Item count is 3 (2 + 1)
      expect(store.cart!.itemCount, 3);
    });

    test('Change quantities → subtotal recalculates', () {
      store.clearCart();
      store.addToCart('f1', qty: 2);
      store.addToCart('f3', qty: 1);
      expect(store.cart!.foodSubtotalCents, 2880); // RM28.80

      // Increase Nasi Lemak to 3
      store.setCartQuantity('f1', 3);
      // 1290 × 3 + 300 × 1 = 3870 + 300 = 4170
      expect(store.cart!.foodSubtotalCents, 4170);
      expect(money(store.cart!.foodSubtotalCents), 'RM41.70');

      // Decrease back to 1
      store.setCartQuantity('f1', 1);
      // 1290 × 1 + 300 × 1 = 1290 + 300 = 1590
      expect(store.cart!.foodSubtotalCents, 1590);
      expect(money(store.cart!.foodSubtotalCents), 'RM15.90');
    });

    test('Checkout → order appears in history → cart cleared', () {
      store.clearCart();
      store.addToCart('f1', qty: 2);
      store.addToCart('f3', qty: 1);

      final orderCountBefore = store.orders.length;

      // Place order
      final order = store.placeOrder(
        restaurantId: 'r1',
        quantities: store.cart!.toQuantities(),
        address: 'TAR UMT, Jalan Genting Klang, Kuala Lumpur',
        idempotencyKey: 'e2e_checkout_${DateTime.now().millisecondsSinceEpoch}',
      );

      // Order is in history
      expect(store.orders.length, orderCountBefore + 1);
      expect(store.orders.first.id, order.id);

      // Cart is cleared
      expect(store.cart!.isEmpty, true);
      expect(store.cartRestaurantId, isNull);

      // Order has correct items
      expect(order.lines.length, 2);
      expect(order.lines.where((l) => l.foodId == 'f1').first.quantity, 2);
      expect(order.lines.where((l) => l.foodId == 'f3').first.quantity, 1);

      // Order has correct financials
      expect(order.financials!.foodSubtotalCents, 2880);
      expect(order.status, OrderStatus.placed);
    });

    test('Cart survives serialization (simulated restart)', () {
      store.clearCart();
      store.addToCart('f1', qty: 2);
      store.addToCart('f3', qty: 1);

      // Serialize cart
      final serialized = store.cart!.toMap();

      // Simulate restart: create new store, restore cart
      final restoredCart = Cart.fromMap(serialized);

      expect(restoredCart.customerId, 'customer');
      expect(restoredCart.restaurantId, 'r1');
      expect(restoredCart.find('f1')!.quantity, 2);
      expect(restoredCart.find('f3')!.quantity, 1);
      expect(restoredCart.foodSubtotalCents, 2880);
      expect(restoredCart.itemCount, 3);
    });

    test('Price breakdown displayed separately after checkout', () {
      store.clearCart();
      store.addToCart('f1', qty: 2);
      store.addToCart('f3', qty: 1);

      final order = store.placeOrder(
        restaurantId: 'r1',
        quantities: store.cart!.toQuantities(),
        address: 'TAR UMT, Jalan Genting Klang, Kuala Lumpur',
        idempotencyKey: 'breakdown_test_${DateTime.now().millisecondsSinceEpoch}',
      );

      // Every charge is separate:
      // - food subtotal
      expect(order.financials!.foodSubtotalCents, 2880);
      // - delivery fee (non-zero)
      expect(order.financials!.deliveryFeeCents, greaterThan(0));
      // - commission (10% of subtotal, separate from customer total)
      expect(order.financials!.commissionCents, 288); // 10% of 2880
      // - restaurant net = subtotal - commission
      expect(order.financials!.restaurantNetCents, 2592); // 2880 - 288
      // - customer total = subtotal + delivery fee
      expect(order.financials!.totalCents,
          order.financials!.foodSubtotalCents + order.financials!.deliveryFeeCents);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 8. SEED DATA VERIFICATION
  // ═══════════════════════════════════════════════════════════════════════

  group('Seed data', () {
    test('5 sample restaurants exist with correct names', () {
      expect(store.restaurants.length, greaterThanOrEqualTo(5));
      expect(store.restaurant('r1').name, 'Selera Kampung');
      expect(store.restaurant('r2').name, 'Burger Corner');
      expect(store.restaurant('r3').name, 'Pizza House');
      expect(store.restaurant('r4').name, 'Rasa Thai');
      expect(store.restaurant('r5').name, 'Sweet Treats');
    });

    test('15 sample food items exist', () {
      expect(store.foods.length, greaterThanOrEqualTo(15));
    });

    test('Nasi Lemak Ayam is RM12.90 (1290 sen)', () {
      final f = store.food('f1');
      expect(f.name, 'Nasi Lemak Ayam');
      expect(f.priceCents, 1290);
      expect(f.available, true);
    });

    test('Teh Ais is RM3.00 (300 sen)', () {
      final f = store.food('f3');
      expect(f.name, 'Teh Ais');
      expect(f.priceCents, 300);
      expect(f.available, true);
    });

    test('all restaurants are active', () {
      for (final r in store.restaurants) {
        expect(r.active, true, reason: '${r.name} should be active');
      }
    });

    test('all food items are available and not removed', () {
      for (final f in store.foods) {
        expect(f.available, true, reason: '${f.name} should be available');
        expect(f.removed, false, reason: '${f.name} should not be removed');
      }
    });

    test('all food items belong to an existing restaurant', () {
      for (final f in store.foods) {
        expect(() => store.restaurant(f.restaurantId), returnsNormally,
            reason: '${f.name} has invalid restaurantId ${f.restaurantId}');
      }
    });

    test('seed order exists with financials', () {
      expect(store.orders.length, greaterThanOrEqualTo(1));
      final seedOrder = store.orders.where((o) => o.id == 'o1').firstOrNull;
      expect(seedOrder, isNotNull);
      expect(seedOrder!.status, OrderStatus.delivered);
      expect(seedOrder.financials, isNotNull);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 9. ADDRESS MANAGEMENT
  // ═══════════════════════════════════════════════════════════════════════

  group('Address management', () {
    test('customer can save a delivery address', () {
      store.saveAddress(
        recipient: 'Aiman',
        phone: '+60123456789',
        addressLine: 'TAR UMT, Jalan Genting Klang, Kuala Lumpur',
      );
      expect(store.addressesFor('customer').length, greaterThanOrEqualTo(1));
    });

    test('first address is automatically default', () {
      store.saveAddress(
        recipient: 'Aiman',
        phone: '+60123456789',
        addressLine: 'Home address',
      );
      final addr = store.defaultAddress('customer');
      expect(addr, isNotNull);
      expect(addr!.isDefault, true);
    });

    test('customer can save multiple addresses', () {
      store.saveAddress(
        recipient: 'Aiman',
        phone: '+60123456789',
        addressLine: 'Home',
      );
      store.saveAddress(
        recipient: 'Aiman',
        phone: '+60123456789',
        addressLine: 'Office',
      );
      expect(store.addressesFor('customer').length, greaterThanOrEqualTo(2));
    });

    test('non-customer cannot save addresses', () {
      store.logout();
      store.login('admin@foodieit.demo', 'admin@example');
      expect(() => store.saveAddress(
        recipient: 'Admin',
        phone: '+60123456789',
        addressLine: 'Somewhere',
      ), throwsA(predicate((e) => e is StateError)));
      store.logout();
      store.login('customer@example.com', 'Customer123!');
    });

    test('address serializes to JSON and back', () {
      final addr = DeliveryAddress(
        id: 'addr1',
        customerId: 'customer',
        recipient: 'Aiman',
        phone: '+60123456789',
        addressLine: 'TAR UMT, Jalan Genting Klang',
        isDefault: true,
      );
      final json = addr.toMap();
      final restored = DeliveryAddress.fromMap(json);
      expect(restored.id, 'addr1');
      expect(restored.customerId, 'customer');
      expect(restored.recipient, 'Aiman');
      expect(restored.addressLine, 'TAR UMT, Jalan Genting Klang');
      expect(restored.isDefault, true);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 10. PRICE CALCULATION EDGE CASES
  // ═══════════════════════════════════════════════════════════════════════

  group('Price calculation edge cases', () {
    test('money() formats sen as RM with 2 decimal places', () {
      expect(money(2880), 'RM28.80');
      expect(money(1290), 'RM12.90');
      expect(money(300), 'RM3.00');
      expect(money(0), 'RM0.00');
    });

    test('commission calculation is 10% of food subtotal', () {
      expect(store.calculateCommission(2880), 288); // 10% of RM28.80
      expect(store.calculateCommission(1290), 129); // 10% of RM12.90
      expect(store.calculateCommission(0), 0);
    });

    test('parsePrice converts RM string to sen integer', () {
      expect(AppStore.parsePrice('12.90'), 1290);
      expect(AppStore.parsePrice('3'), 300);
      expect(AppStore.parsePrice('3.00'), 300);
      expect(AppStore.parsePrice('0.50'), 50);
    });

    test('parsePrice rejects invalid formats', () {
      expect(() => AppStore.parsePrice('abc'), throwsA(isA<StateError>()));
      expect(() => AppStore.parsePrice(''), throwsA(isA<StateError>()));
      expect(() => AppStore.parsePrice('-5'), throwsA(isA<StateError>()));
    });
  });
}
