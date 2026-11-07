import 'dart:math' as math;
import 'package:flutter/material.dart';

enum Role { customer, admin, rider }
enum OrderStatus { draft, placed, updated, assigned, pickedUp, delivered, cancelled }
extension StatusText on OrderStatus {
  String get label => switch (this) {
    OrderStatus.draft => 'Draft', OrderStatus.placed => 'Placed',
    OrderStatus.updated => 'Updated', OrderStatus.assigned => 'Rider assigned',
    OrderStatus.pickedUp => 'Picked up', OrderStatus.delivered => 'Delivered',
    OrderStatus.cancelled => 'Cancelled',
  };
  bool get editable => [OrderStatus.draft, OrderStatus.placed, OrderStatus.updated].contains(this);
  bool get active => ![OrderStatus.draft, OrderStatus.delivered, OrderStatus.cancelled].contains(this);
  /// Customer-visible GPS tracking is only shown while the rider has picked up the order.
  bool get trackingVisible => this == OrderStatus.pickedUp;
}
String money(int cents) => 'RM${(cents / 100).toStringAsFixed(2)}';

/// Food category for the home screen category chips.
class FoodCategory {
  final String id;
  final String label;
  final IconData icon;
  const FoodCategory(this.id, this.label, this.icon);
}

const categories = <FoodCategory>[
  FoodCategory('all', 'All', Icons.restaurant),
  FoodCategory('malaysian', 'Malaysian', Icons.rice_bowl),
  FoodCategory('healthy', 'Healthy', Icons.eco),
  FoodCategory('noodles', 'Noodles', Icons.ramen_dining),
  FoodCategory('drinks', 'Drinks', Icons.local_drink),
  FoodCategory('breakfast', 'Breakfast', Icons.breakfast_dining),
];

// ═════════════════════════════════════════════════════════════════════════
// GEO / LOCATION
// ═════════════════════════════════════════════════════════════════════════

/// Simple geographic coordinate with Haversine distance calculation.
class GeoPoint {
  final double lat;
  final double lng;
  const GeoPoint(this.lat, this.lng);

  /// Haversine distance in kilometres between two points (straight-line).
  double distanceKmTo(GeoPoint other) {
    const r = 6371.0; // Earth radius km
    final dLat = _toRad(other.lat - lat);
    final dLng = _toRad(other.lng - lng);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(lat)) * math.cos(_toRad(other.lat)) *
            math.sin(dLng / 2) * math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  /// Estimated road-route distance multiplier over straight-line distance.
  /// Typical road network factor is ~1.3-1.4 in urban areas.
  static double roadFactor = 1.35;

  /// Estimated road distance in km (straight-line × road factor).
  /// In production this is replaced by Google Maps Distance Matrix API.
  double roadDistanceKmTo(GeoPoint other) =>
      distanceKmTo(other) * roadFactor;

  double _toRad(double deg) => deg * (math.pi / 180.0);

  @override
  String toString() => 'GeoPoint(${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)})';
}

/// A single rider location update record with timestamp.
class LocationRecord {
  final GeoPoint point;
  final DateTime timestamp;
  final bool simulated;
  const LocationRecord({required this.point, required this.timestamp, this.simulated = false});

  /// Whether this location is stale (older than [staleAfter] seconds).
  bool isStale({Duration staleAfter = const Duration(seconds: 60)}) =>
      DateTime.now().difference(timestamp) > staleAfter;
}

// ═════════════════════════════════════════════════════════════════════════
// RIDER APPROVAL & DOCUMENTS
// ═════════════════════════════════════════════════════════════════════════

enum RiderApprovalStatus { pending, approved, rejected, suspended }
extension RiderApprovalLabel on RiderApprovalStatus {
  String get label => switch (this) {
    RiderApprovalStatus.pending => 'Pending Approval',
    RiderApprovalStatus.approved => 'Approved',
    RiderApprovalStatus.rejected => 'Rejected',
    RiderApprovalStatus.suspended => 'Suspended',
  };
  bool get canAcceptJobs => this == RiderApprovalStatus.approved;
}

/// Type of document required for rider verification.
enum DocumentType { license, vehicleRegistration, insurance, profilePhoto }
extension DocTypeLabel on DocumentType {
  String get label => switch (this) {
    DocumentType.license => 'Driving Licence',
    DocumentType.vehicleRegistration => 'Motorcycle Registration',
    DocumentType.insurance => 'Insurance Document',
    DocumentType.profilePhoto => 'Profile Photo',
  };
  IconData get icon => switch (this) {
    DocumentType.license => Icons.badge_outlined,
    DocumentType.vehicleRegistration => Icons.motorcycle,
    DocumentType.insurance => Icons.shield_outlined,
    DocumentType.profilePhoto => Icons.person_outline,
  };
}

/// A document uploaded by a rider for admin verification.
class RiderDocument {
  final String id;
  final String riderId;
  final DocumentType type;
  final String fileName;
  final String storagePath; // Private storage path (Firebase Storage in production)
  final DateTime uploadedAt;
  final DateTime? expiryDate;
  final bool verified;

  RiderDocument({
    required this.id,
    required this.riderId,
    required this.type,
    required this.fileName,
    required this.storagePath,
    required this.uploadedAt,
    this.expiryDate,
    this.verified = false,
  });

  bool get isExpired =>
      expiryDate != null && DateTime.now().isAfter(expiryDate!);

  bool get isExpiringSoon =>
      expiryDate != null &&
      DateTime.now().difference(expiryDate!).inDays > -30 &&
      !isExpired;
}

/// Vehicle details for rider registration.
class VehicleInfo {
  String registrationNumber;
  String make;
  String model;
  String color;
  VehicleInfo({
    required this.registrationNumber,
    required this.make,
    required this.model,
    required this.color,
  });
}

/// Audit log entry recording rider application changes and admin decisions.
class AuditLogEntry {
  final String id;
  final String riderId;
  final String actorId;
  final String actorRole;
  final String action;
  final String? reason;
  final DateTime timestamp;
  final Map<String, dynamic> details;

  AuditLogEntry({
    required this.id,
    required this.riderId,
    required this.actorId,
    required this.actorRole,
    required this.action,
    this.reason,
    required this.timestamp,
    this.details = const {},
  });
}

// ═════════════════════════════════════════════════════════════════════════
// DELIVERY PRICING
// ═════════════════════════════════════════════════════════════════════════

/// Configurable delivery pricing rules. All amounts in integer sen.
class DeliveryPricingConfig {
  int baseFeeCents;       // Base delivery fee
  int perKmRateCents;     // Rate per billable kilometre
  int minFeeCents;        // Minimum delivery fee
  double maxServiceRangeKm; // Maximum service radius from restaurant
  int roundingUnitCents;  // Rounding granularity (e.g. 10 = round to RM0.10)
  int riderPayoutBaseCents;   // Rider payout base
  int riderPayoutPerKmCents;  // Rider payout per km
  double riderPayoutPercentage; // Rider payout as % of delivery fee (0-1)

  DeliveryPricingConfig({
    this.baseFeeCents = 200,     // RM 2.00 base
    this.perKmRateCents = 50,    // RM 0.50 per km
    this.minFeeCents = 200,      // RM 2.00 minimum
    this.maxServiceRangeKm = 15.0,
    this.roundingUnitCents = 10, // Round to nearest RM0.10
    this.riderPayoutBaseCents = 100, // RM 1.00 base payout
    this.riderPayoutPerKmCents = 40, // RM 0.40 per km
    this.riderPayoutPercentage = 0.75, // 75% of delivery fee
  });

  /// Calculate the delivery fee for a given road distance.
  /// fee = max(minFee, base + perKm × distance), rounded to roundingUnit.
  int calculateFee(double roadDistanceKm) {
    final raw = baseFeeCents + (roadDistanceKm * perKmRateCents).round();
    final clamped = raw < minFeeCents ? minFeeCents : raw;
    return _roundTo(clamped, roundingUnitCents);
  }

  /// Calculate rider payout for a given road distance and delivery fee.
  /// payout = max(base + perKm × distance, fee × percentage)
  int calculateRiderPayout(double roadDistanceKm, int deliveryFeeCents) {
    final flatPayout = riderPayoutBaseCents +
        (roadDistanceKm * riderPayoutPerKmCents).round();
    final percentagePayout = (deliveryFeeCents * riderPayoutPercentage).round();
    final payout = flatPayout > percentagePayout ? flatPayout : percentagePayout;
    return _roundTo(payout, roundingUnitCents);
  }

  int _roundTo(int value, int unit) =>
      unit <= 0 ? value : ((value + unit ~/ 2) ~/ unit) * unit;

  Map<String, dynamic> toMap() => {
    'baseFeeCents': baseFeeCents,
    'perKmRateCents': perKmRateCents,
    'minFeeCents': minFeeCents,
    'maxServiceRangeKm': maxServiceRangeKm,
    'roundingUnitCents': roundingUnitCents,
    'riderPayoutBaseCents': riderPayoutBaseCents,
    'riderPayoutPerKmCents': riderPayoutPerKmCents,
    'riderPayoutPercentage': riderPayoutPercentage,
  };
}

/// Financial details saved with each order — immutable after confirmation.
class OrderFinancials {
  final GeoPoint restaurantPoint;
  final GeoPoint deliveryPoint;
  final double distanceKm;       // Confirmed road distance
  final int deliveryFeeCents;    // Customer delivery fee
  final int riderPayoutCents;    // Rider earnings
  final int foodSubtotalCents;   // Sum of food line items
  final int commissionRatePercent; // e.g. 10
  final int commissionCents;     // Platform commission
  final int restaurantNetCents;  // Restaurant net food earnings
  final int totalCents;          // Customer pays: subtotal + delivery fee
  final DeliveryPricingConfig pricingSnapshot; // Rules at time of order

  const OrderFinancials({
    required this.restaurantPoint,
    required this.deliveryPoint,
    required this.distanceKm,
    required this.deliveryFeeCents,
    required this.riderPayoutCents,
    required this.foodSubtotalCents,
    required this.commissionRatePercent,
    required this.commissionCents,
    required this.restaurantNetCents,
    required this.totalCents,
    required this.pricingSnapshot,
  });

  Map<String, dynamic> toMap() => {
    'restaurantPoint': {'lat': restaurantPoint.lat, 'lng': restaurantPoint.lng},
    'deliveryPoint': {'lat': deliveryPoint.lat, 'lng': deliveryPoint.lng},
    'distanceKm': distanceKm,
    'deliveryFeeCents': deliveryFeeCents,
    'riderPayoutCents': riderPayoutCents,
    'foodSubtotalCents': foodSubtotalCents,
    'commissionRatePercent': commissionRatePercent,
    'commissionCents': commissionCents,
    'restaurantNetCents': restaurantNetCents,
    'totalCents': totalCents,
    'pricingSnapshot': pricingSnapshot.toMap(),
  };
}

// ═════════════════════════════════════════════════════════════════════════
// COMMISSION CONFIG
// ═════════════════════════════════════════════════════════════════════════

/// Restaurant commission configuration.
class CommissionConfig {
  double commissionRatePercent; // 10.0 = 10%
  bool discountsReduceBase;     // If true, discounts reduce the commissionable base

  CommissionConfig({
    this.commissionRatePercent = 10.0,
    this.discountsReduceBase = true,
  });

  /// Calculate commission on food subtotal.
  int calculateCommission(int foodSubtotalCents, {int discountCents = 0}) {
    final base = discountsReduceBase
        ? (foodSubtotalCents - discountCents).clamp(0, foodSubtotalCents)
        : foodSubtotalCents;
    return (base * commissionRatePercent / 100).round();
  }

  int calculateRestaurantNet(int foodSubtotalCents, int commissionCents) =>
      foodSubtotalCents - commissionCents;
}

// ═════════════════════════════════════════════════════════════════════════
// MFA
// ═════════════════════════════════════════════════════════════════════════

/// MFA enrolment state for a user.
class MfaEnrolment {
  bool enrolled;
  String? secret;        // TOTP shared secret (stored encrypted on backend)
  List<String> recoveryCodes; // One-time use recovery codes
  DateTime? enrolledAt;
  DateTime? lastVerifiedAt;
  String factorType;     // 'totp', 'sms', 'email'

  MfaEnrolment({
    this.enrolled = false,
    this.secret,
    this.recoveryCodes = const [],
    this.enrolledAt,
    this.lastVerifiedAt,
    this.factorType = 'totp',
  });

  /// Whether the user needs to re-verify MFA (recent auth required for sensitive ops).
  bool requiresRecentAuth({Duration maxAge = const Duration(minutes: 15)}) {
    if (!enrolled || lastVerifiedAt == null) return true;
    return DateTime.now().difference(lastVerifiedAt!) > maxAge;
  }
}

// ═════════════════════════════════════════════════════════════════════════
// CORE ENTITIES
// ═════════════════════════════════════════════════════════════════════════

class AppUser {
  final String id;
  final Role role;
  String name, email, phone, address;
  bool active;

  // Rider approval fields
  RiderApprovalStatus riderApprovalStatus;
  VehicleInfo? vehicleInfo;
  String? profilePhotoUrl;
  String? rejectionReason;

  // MFA
  MfaEnrolment mfa;

  AppUser({
    required this.id,
    required this.role,
    required this.name,
    required this.email,
    required this.phone,
    this.address = '',
    this.active = true,
    this.riderApprovalStatus = RiderApprovalStatus.pending,
    this.vehicleInfo,
    this.profilePhotoUrl,
    this.rejectionReason,
    MfaEnrolment? mfa,
  }) : mfa = mfa ?? MfaEnrolment();
}
class Restaurant {
  final String id;
  String name, cuisine, address, hours;
  bool active;
  String? imageUrl;
  String? categoryId;

  // Location for distance calculation
  GeoPoint? location;

  // Service range override (null = use global config)
  double? serviceRangeKm;

  // Commission acceptance
  bool commissionAccepted;
  DateTime? commissionAcceptedAt;

  Restaurant({
    required this.id,
    required this.name,
    required this.cuisine,
    required this.address,
    required this.hours,
    this.active = true,
    this.imageUrl,
    this.categoryId,
    this.location,
    this.serviceRangeKm,
    this.commissionAccepted = false,
    this.commissionAcceptedAt,
  });
}
class FoodItem {
  final String id, restaurantId;
  String name, description;
  int priceCents;
  bool available, removed;
  String? imageUrl;
  String? categoryId;
  FoodItem({required this.id, required this.restaurantId, required this.name,
    required this.description, required this.priceCents, this.available = true, this.removed = false, this.imageUrl, this.categoryId});
}
class OrderLine {
  final String foodId, name;
  final int quantity, unitCents;
  const OrderLine(this.foodId, this.name, this.quantity, this.unitCents);
  int get total => quantity * unitCents;
}
class FoodOrder {
  final String id, customerId, restaurantId;
  final DateTime createdAt;
  List<OrderLine> lines;
  String address;
  String? riderId;
  OrderStatus status;
  int revision;

  // Delivery address coordinates
  GeoPoint? deliveryPoint;

  // Financial snapshot (saved at order confirmation)
  OrderFinancials? financials;

  FoodOrder({required this.id, required this.customerId, required this.restaurantId,
    required this.lines, required this.address, required this.status,
    required this.createdAt, this.riderId, this.revision = 1,
    this.deliveryPoint, this.financials});

  int get totalCents => financials?.totalCents ??
      lines.fold(0, (sum, line) => sum + line.total);

  int get foodSubtotalCents =>
      lines.fold(0, (sum, line) => sum + line.total);
}
class FoodReview {
  final String id, orderId, customerId, restaurantId;
  int rating;
  String comment;
  FoodReview({required this.id, required this.orderId, required this.customerId,
    required this.restaurantId, required this.rating, required this.comment});
}

// ═════════════════════════════════════════════════════════════════════════
// CART — shared application state for the customer's shopping cart
// ═════════════════════════════════════════════════════════════════════════

/// A single line in the cart. Groups identical items (same foodId) into one line.
/// In production with selected options, the option signature would be part of the key.
class CartItem {
  final String foodId;
  final String foodName;
  final int unitPriceCents;
  int quantity;

  CartItem({
    required this.foodId,
    required this.foodName,
    required this.unitPriceCents,
    required this.quantity,
  });

  int get lineTotal => unitPriceCents * quantity;

  Map<String, dynamic> toMap() => {
    'foodId': foodId,
    'foodName': foodName,
    'unitPriceCents': unitPriceCents,
    'quantity': quantity,
  };

  factory CartItem.fromMap(Map<String, dynamic> m) => CartItem(
    foodId: m['foodId'] as String,
    foodName: m['foodName'] as String,
    unitPriceCents: m['unitPriceCents'] as int,
    quantity: m['quantity'] as int,
  );
}

/// The customer's cart. Enforces one-restaurant-per-cart.
class Cart {
  final String customerId;
  String? restaurantId;
  String? restaurantName;
  final List<CartItem> items = [];
  int revision;
  DateTime updatedAt;

  Cart({required this.customerId, this.restaurantId, this.restaurantName, this.revision = 1})
      : updatedAt = DateTime.now();

  bool get isEmpty => items.isEmpty;
  int get itemCount => items.fold(0, (s, i) => s + i.quantity);
  int get foodSubtotalCents => items.fold(0, (s, i) => s + i.lineTotal);

  CartItem? find(String foodId) =>
      items.where((i) => i.foodId == foodId).firstOrNull;

  /// Add or increment a food item. Returns true if added, false if restaurant mismatch.
  /// Caller must check [canAddFromRestaurant] before calling this.
  void add(String foodId, String foodName, int unitPriceCents, {int qty = 1}) {
    final existing = find(foodId);
    if (existing != null) {
      existing.quantity = (existing.quantity + qty).clamp(1, 99);
    } else {
      items.add(CartItem(foodId: foodId, foodName: foodName, unitPriceCents: unitPriceCents, quantity: qty.clamp(1, 99)));
    }
    revision++;
    updatedAt = DateTime.now();
  }

  /// Set the exact quantity for an item. Removes if qty <= 0.
  void setQuantity(String foodId, int qty) {
    if (qty <= 0) {
      items.removeWhere((i) => i.foodId == foodId);
    } else {
      final existing = find(foodId);
      if (existing != null) {
        existing.quantity = qty.clamp(1, 99);
      }
    }
    revision++;
    updatedAt = DateTime.now();
  }

  /// Remove an item entirely.
  void remove(String foodId) {
    items.removeWhere((i) => i.foodId == foodId);
    revision++;
    updatedAt = DateTime.now();
  }

  /// Clear all items but keep the restaurant association.
  void clearItems() {
    items.clear();
    revision++;
    updatedAt = DateTime.now();
  }

  /// Clear everything including restaurant.
  void clear() {
    items.clear();
    restaurantId = null;
    restaurantName = null;
    revision++;
    updatedAt = DateTime.now();
  }

  /// Check if items can be added from the given restaurant.
  /// Returns true if cart is empty or restaurant matches.
  bool canAddFromRestaurant(String restaurantId) =>
      this.restaurantId == null || this.restaurantId == restaurantId;

  /// Convert cart to a quantities map for order creation.
  Map<String, int> toQuantities() =>
      {for (final i in items) i.foodId: i.quantity};

  Map<String, dynamic> toMap() => {
    'customerId': customerId,
    'restaurantId': restaurantId,
    'restaurantName': restaurantName,
    'revision': revision,
    'updatedAt': updatedAt.toIso8601String(),
    'items': [for (final i in items) i.toMap()],
  };

  factory Cart.fromMap(Map<String, dynamic> m) {
    final c = Cart(
      customerId: m['customerId'] as String,
      restaurantId: m['restaurantId'] as String?,
      restaurantName: m['restaurantName'] as String?,
      revision: m['revision'] as int? ?? 1,
    );
    c.updatedAt = m['updatedAt'] != null
        ? DateTime.tryParse(m['updatedAt'] as String) ?? DateTime.now()
        : DateTime.now();
    for (final item in (m['items'] as List?) ?? []) {
      c.items.add(CartItem.fromMap(item as Map<String, dynamic>));
    }
    return c;
  }
}

/// A saved delivery address for a customer.
class DeliveryAddress {
  final String id;
  final String customerId;
  String recipient;
  String phone;
  String addressLine;
  String? notes;
  GeoPoint? coordinates;
  bool isDefault;

  DeliveryAddress({
    required this.id,
    required this.customerId,
    required this.recipient,
    required this.phone,
    required this.addressLine,
    this.notes,
    this.coordinates,
    this.isDefault = false,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'customerId': customerId,
    'recipient': recipient,
    'phone': phone,
    'addressLine': addressLine,
    'notes': notes,
    'coordinates': coordinates != null
        ? {'lat': coordinates!.lat, 'lng': coordinates!.lng}
        : null,
    'isDefault': isDefault,
  };

  factory DeliveryAddress.fromMap(Map<String, dynamic> m) => DeliveryAddress(
    id: m['id'] as String,
    customerId: m['customerId'] as String,
    recipient: m['recipient'] as String,
    phone: m['phone'] as String,
    addressLine: m['addressLine'] as String,
    notes: m['notes'] as String?,
    coordinates: m['coordinates'] != null
        ? GeoPoint((m['coordinates'] as Map)['lat'], (m['coordinates'] as Map)['lng'])
        : null,
    isDefault: m['isDefault'] as bool? ?? false,
  );
}
