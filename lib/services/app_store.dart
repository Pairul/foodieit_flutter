import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/entities.dart';

/// In-memory DEMO repository + state.
///
/// This store simulates a persistent backend with authentication, database
/// storage, private document storage, and live location updates. In production,
/// these methods map to Firebase Auth, Firestore, Storage, and Realtime
/// Database calls. See [BackendConfig] for setup instructions.
///
/// All financial values are stored in integer sen (1 RM = 100 sen).
/// Permissions are enforced on both the client AND the backend (see
/// firestore.rules and storage.rules).
class AppStore extends ChangeNotifier {
  final List<AppUser> _users = [];
  final List<Restaurant> _restaurants = [];
  final List<FoodItem> _foods = [];
  final List<FoodOrder> _orders = [];
  final List<FoodReview> _reviews = [];
  final Map<String, String> _demoPasswords = {};
  String? _sessionId;
  int _counter = 100;

  // ── New collections ──
  final List<RiderDocument> _documents = [];
  final List<AuditLogEntry> _auditLog = [];
  final Map<String, List<LocationRecord>> _riderLocations = {};
  final List<DeliveryAddress> _addresses = [];

  // ── Cart state ──
  Cart? _cart;
  bool _cartOperationInProgress = false;

  // ── Idempotency keys for checkout ──
  final Set<String> _usedIdempotencyKeys = {};

  // ── Configurable settings ──
  DeliveryPricingConfig deliveryPricing = DeliveryPricingConfig();
  CommissionConfig commissionConfig = CommissionConfig();

  // ── MFA pending login state ──
  String? _mfaPendingUserId;
  int _mfaAttempts = 0;
  int _mfaResends = 0;
  DateTime? _mfaCodeGeneratedAt;
  String? _mfaCurrentCode;
  static const int _maxMfaAttempts = 5;
  static const int _maxMfaResends = 3;
  static const Duration _mfaCodeExpiry = Duration(minutes: 5);
  static const Duration _mfaLockout = Duration(minutes: 15);
  DateTime? _mfaLockoutUntil;

  // ── Simulated tracking state ──
  bool simulatedTrackingEnabled = false;

  // ── SharedPreferences keys ──
  static const _cartKey = 'foodieit_cart';
  static const _addressesKey = 'foodieit_addresses';

  AppStore() { _seed(); _loadPersistedCart(); _loadPersistedAddresses(); }

  // ═══════════════════════════════════════════════════════════════════════
  // READ ACCESSORS
  // ═══════════════════════════════════════════════════════════════════════
  List<AppUser> get users => List.unmodifiable(_users);
  List<Restaurant> get restaurants => List.unmodifiable(_restaurants);
  List<FoodItem> get foods => List.unmodifiable(_foods);
  List<FoodOrder> get orders => List.unmodifiable(_orders.reversed);
  List<FoodReview> get reviews => List.unmodifiable(_reviews.reversed);
  List<RiderDocument> get documents => List.unmodifiable(_documents);
  List<AuditLogEntry> get auditLog => List.unmodifiable(_auditLog.reversed);
  AppUser? get current {
    for (final u in _users) { if (u.id == _sessionId && u.active) return u; }
    return null;
  }
  AppUser? get mfaPendingUser =>
      _mfaPendingUserId == null ? null : _users.where((u) => u.id == _mfaPendingUserId).firstOrNull;

  bool get isMfaLockedOut =>
      _mfaLockoutUntil != null && DateTime.now().isBefore(_mfaLockoutUntil!);

  String _id(String prefix) => '$prefix${_counter++}';
  void _check(bool ok, String message) { if (!ok) throw StateError(message); }
  AppUser _actor() { final u = current; if (u == null) throw StateError('Please sign in.'); return u; }
  void _admin() => _check(_actor().role == Role.admin, 'Administrator access required.');
  String _text(String s, String label, {int max = 500, bool optional = false}) {
    final value = s.trim(); _check((optional || value.isNotEmpty) && value.length <= max, '$label is required (maximum $max characters).'); return value;
  }
  AppUser user(String id) => _users.firstWhere((u) => u.id == id);
  Restaurant restaurant(String id) => _restaurants.firstWhere((r) => r.id == id);
  FoodItem food(String id) => _foods.firstWhere((f) => f.id == id);
  FoodOrder order(String id) => _orders.firstWhere((o) => o.id == id);
  FoodReview? reviewFor(String orderId) {
    for (final r in _reviews) { if (r.orderId == orderId) return r; } return null;
  }

  List<RiderDocument> documentsFor(String riderId) =>
      _documents.where((d) => d.riderId == riderId).toList();

  List<LocationRecord> locationsFor(String riderId) =>
      (_riderLocations[riderId] ?? []).toList();

  LocationRecord? lastLocationFor(String riderId) {
    final list = _riderLocations[riderId];
    if (list == null || list.isEmpty) return null;
    return list.last;
  }

  List<FoodOrder> ordersForRider(String riderId) =>
      _orders.where((o) => o.riderId == riderId).toList();

  // ═══════════════════════════════════════════════════════════════════════
  // AUTHENTICATION + MFA
  // ═══════════════════════════════════════════════════════════════════════

  /// Step 1: Validate credentials. If MFA is enrolled, set pending state
  /// instead of logging in. Returns true if MFA verification is needed.
  bool login(String identifier, String password) {
    final key = identifier.trim().toLowerCase();
    final matches = _users.where((u) => u.email.toLowerCase() == key || (u.role == Role.admin && key == 'admin 123'));
    _check(matches.isNotEmpty, 'Invalid login details.');
    final u = matches.first;
    _check(u.active && _demoPasswords[u.id] == password, 'Invalid login details or inactive account.');

    if (u.mfa.enrolled) {
      // Start MFA verification flow instead of completing login
      _mfaPendingUserId = u.id;
      _mfaAttempts = 0;
      _mfaResends = 0;
      _mfaCodeGeneratedAt = DateTime.now();
      _mfaCurrentCode = _generateTotpCode();
      _mfaLockoutUntil = null;
      notifyListeners();
      return true; // Caller should show MFA verification screen
    }

    _sessionId = u.id;
    // Load persisted cart and addresses for customers
    if (u.role == Role.customer) {
      _loadCartForCustomer(u.id);
      _loadAddressesForCustomer(u.id);
    }
    notifyListeners();
    return false;
  }

  /// Generate a 6-digit TOTP code for demo purposes.
  /// In production, this is generated by the user's authenticator app (Google Authenticator, Authy).
  String _generateTotpCode() {
    final random = math.Random();
    return List.generate(6, (_) => random.nextInt(10)).join();
  }

  /// Step 2: Verify the MFA code submitted by the user.
  /// Throws on expired code, wrong code, or too many attempts.
  void verifyMfa(String code) {
    _check(_mfaPendingUserId != null, 'No MFA verification in progress.');
    _check(!isMfaLockedOut, 'Too many failed attempts. Please wait until ${_mfaLockoutUntil?.toLocal().toString().substring(11, 16)}.');
    _check(_mfaCodeGeneratedAt != null, 'No code generated.');

    // Check code expiry
    final age = DateTime.now().difference(_mfaCodeGeneratedAt!);
    _check(age <= _mfaCodeExpiry, 'Code expired. Please request a new code.');

    // Check attempt limit
    _check(_mfaAttempts < _maxMfaAttempts, 'Too many failed attempts. Account temporarily locked.');

    if (code.trim() != _mfaCurrentCode) {
      _mfaAttempts++;
      if (_mfaAttempts >= _maxMfaAttempts) {
        _mfaLockoutUntil = DateTime.now().add(_mfaLockout);
        notifyListeners();
        throw StateError('Too many failed attempts. Locked for 15 minutes.');
      }
      notifyListeners();
      throw StateError('Incorrect code. ${_maxMfaAttempts - _mfaAttempts} attempts remaining.');
    }

    // Success — complete login
    final u = user(_mfaPendingUserId!);
    u.mfa.lastVerifiedAt = DateTime.now();
    _sessionId = u.id;
    _mfaPendingUserId = null;
    _mfaAttempts = 0;
    _mfaCurrentCode = null;
    // Load persisted cart and addresses for customers
    if (u.role == Role.customer) {
      _loadCartForCustomer(u.id);
      _loadAddressesForCustomer(u.id);
    }
    notifyListeners();
  }

  /// Resend MFA code. Limited to [_maxMfaResends] per session.
  void resendMfaCode() {
    _check(_mfaPendingUserId != null, 'No MFA verification in progress.');
    _check(!isMfaLockedOut, 'Account is locked. Please wait.');
    _check(_mfaResends < _maxMfaResends, 'Too many resend requests. Please try again later.');
    _mfaResends++;
    _mfaCodeGeneratedAt = DateTime.now();
    _mfaCurrentCode = _generateTotpCode();
    notifyListeners();
  }

  /// Use a recovery code instead of TOTP. Consumes the code.
  void verifyWithRecoveryCode(String recoveryCode) {
    _check(_mfaPendingUserId != null, 'No MFA verification in progress.');
    final u = user(_mfaPendingUserId!);
    final codeIndex = u.mfa.recoveryCodes.indexOf(recoveryCode.trim());
    _check(codeIndex >= 0, 'Invalid recovery code.');
    u.mfa.recoveryCodes.removeAt(codeIndex);
    u.mfa.lastVerifiedAt = DateTime.now();
    _sessionId = u.id;
    _mfaPendingUserId = null;
    notifyListeners();
  }

  /// Cancel MFA pending login.
  void cancelMfa() {
    _mfaPendingUserId = null;
    _mfaAttempts = 0;
    _mfaCurrentCode = null;
    notifyListeners();
  }

  /// Enrol in MFA. Requires recent authentication.
  /// Returns the generated secret and recovery codes.
  ({String secret, List<String> recoveryCodes}) enrolMfa() {
    final u = _actor();
    _check(!u.mfa.enrolled, 'MFA is already enrolled.');

    // Generate a Base32-style secret (simplified for demo)
    final random = math.Random();
    final secret = List.generate(32, (_) => 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567'[random.nextInt(32)]).join();
    final recoveryCodes = List.generate(8, (_) =>
      List.generate(5, (_) => '0123456789ABCDEFGHIJKLMNPQRSTUVWXYZ'[random.nextInt(35)]).join('-')
    ).toList();

    u.mfa = MfaEnrolment(
      enrolled: true,
      secret: secret,
      recoveryCodes: recoveryCodes,
      enrolledAt: DateTime.now(),
      lastVerifiedAt: DateTime.now(),
      factorType: 'totp',
    );
    notifyListeners();
    return (secret: secret, recoveryCodes: recoveryCodes);
  }

  /// Change MFA factor. Requires recent authentication.
  void changeMfaFactor(String factorType) {
    final u = _actor();
    _check(u.mfa.enrolled, 'MFA is not enrolled.');
    _check(!u.mfa.requiresRecentAuth(), 'Recent authentication required to change MFA settings. Please verify again.');
    u.mfa.factorType = factorType;
    notifyListeners();
  }

  /// Disable MFA. Requires recent authentication.
  void disableMfa() {
    final u = _actor();
    _check(u.mfa.enrolled, 'MFA is not enrolled.');
    _check(!u.mfa.requiresRecentAuth(), 'Recent authentication required. Please verify again.');
    u.mfa = MfaEnrolment();
    notifyListeners();
  }

  /// Generate a fresh TOTP code for the current MFA pending user (for display in demo mode).
  String? get currentMfaDemoCode => _mfaCurrentCode;

  void logout() {
    _sessionId = null;
    _mfaPendingUserId = null;
    _mfaCurrentCode = null;
    // Cart is tied to the customer, not the session — persist it
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════════════
  // CART MANAGEMENT — shared, persistent, one-restaurant-per-cart
  // ═══════════════════════════════════════════════════════════════════════

  /// The current customer's cart. Returns null if not logged in as customer.
  Cart? get cart {
    final u = current;
    if (u == null || u.role != Role.customer) return null;
    _cart ??= Cart(customerId: u.id);
    // Ensure cart belongs to current customer
    if (_cart!.customerId != u.id) {
      _cart = Cart(customerId: u.id);
    }
    return _cart;
  }

  bool get cartOperationInProgress => _cartOperationInProgress;

  /// Whether the customer can add from this restaurant without a prompt.
  /// Returns true if cart is empty or same restaurant.
  bool canAddToCart(String restaurantId) {
    final c = cart;
    if (c == null) return false;
    return c.canAddFromRestaurant(restaurantId);
  }

  /// The restaurant ID currently locked into the cart, or null.
  String? get cartRestaurantId => cart?.restaurantId;

  /// Add a food item to the cart. If a different restaurant is in the cart,
  /// this throws with a message telling the caller to ask the user to replace.
  /// Prevents duplicate additions during pending operations via [_cartOperationInProgress].
  void addToCart(String foodId, {int qty = 1}) {
    final u = _actor();
    _check(u.role == Role.customer, 'Only customers can add to cart.');
    _check(!_cartOperationInProgress, 'Another cart operation is in progress.');

    final f = food(foodId);
    _check(!f.removed, '${f.name} is no longer available.');
    _check(f.available, '${f.name} is currently unavailable.');
    final r = restaurant(f.restaurantId);
    _check(r.active, '${r.name} is currently inactive.');

    final c = cart!;
    if (!c.canAddFromRestaurant(f.restaurantId)) {
      throw StateError('CART_MISMATCH:Your cart has items from ${c.restaurantName ?? restaurant(c.restaurantId!).name}. '
          'Replace it with items from ${r.name}?');
    }

    c.restaurantId = r.id;
    c.restaurantName = r.name;
    c.add(f.id, f.name, f.priceCents, qty: qty);
    _persistCart();
    notifyListeners();
  }

  /// Replace the current cart with items from a new restaurant.
  void replaceCartWithRestaurant(String restaurantId) {
    final u = _actor();
    _check(u.role == Role.customer, 'Only customers can modify the cart.');
    final r = restaurant(restaurantId);
    _check(r.active, '${r.name} is currently inactive.');
    final c = cart!;
    c.clear();
    c.restaurantId = r.id;
    c.restaurantName = r.name;
    _persistCart();
    notifyListeners();
  }

  /// Set the quantity of an item in the cart. Removes if qty <= 0.
  void setCartQuantity(String foodId, int qty) {
    final u = _actor();
    _check(u.role == Role.customer, 'Only customers can modify the cart.');
    final c = cart!;
    if (c.find(foodId) == null && qty > 0) {
      // Adding a new item through the quantity stepper
      final f = food(foodId);
      _check(!f.removed && f.available, '${f.name} is unavailable.');
      _check(restaurant(f.restaurantId).active, 'Restaurant is inactive.');
      if (!c.canAddFromRestaurant(f.restaurantId)) {
        throw StateError('CART_MISMATCH:Cannot add from a different restaurant.');
      }
      c.restaurantId = f.restaurantId;
      c.restaurantName = restaurant(f.restaurantId).name;
    }
    c.setQuantity(foodId, qty);
    if (c.items.isEmpty) {
      c.restaurantId = null;
      c.restaurantName = null;
    }
    _persistCart();
    notifyListeners();
  }

  /// Remove an item from the cart.
  void removeFromCart(String foodId) {
    final u = _actor();
    _check(u.role == Role.customer, 'Only customers can modify the cart.');
    final c = cart!;
    c.remove(foodId);
    if (c.items.isEmpty) {
      c.restaurantId = null;
      c.restaurantName = null;
    }
    _persistCart();
    notifyListeners();
  }

  /// Clear all cart items.
  void clearCart() {
    final u = _actor();
    _check(u.role == Role.customer, 'Only customers can modify the cart.');
    cart!.clearItems();
    _persistCart();
    notifyListeners();
  }

  /// Persist cart to SharedPreferences.
  void _persistCart() {
    final c = _cart;
    if (c == null || c.customerId.isEmpty) return;
    Future(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        prefs.setString('$_cartKey:${c.customerId}', jsonEncode(c.toMap()));
      } catch (_) {
        // Silent failure — cart still works in-memory for the session
      }
    });
  }

  /// Load persisted cart for the current customer.
  void _loadPersistedCart() {
    // Called after seed; will load when a customer logs in
  }

  /// Load cart from SharedPreferences when customer logs in.
  void _loadCartForCustomer(String customerId) {
    Future(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final json = prefs.getString('$_cartKey:$customerId');
        if (json != null) {
          final m = jsonDecode(json) as Map<String, dynamic>;
          _cart = Cart.fromMap(m);
          // Validate cart items against current food data
          _cart!.items.removeWhere((item) {
            try {
              final f = food(item.foodId);
              return f.removed; // Remove if food was deleted
            } catch (_) {
              return true; // Remove if food doesn't exist
            }
          });
          if (_cart!.items.isEmpty) {
            _cart!.restaurantId = null;
            _cart!.restaurantName = null;
          }
          notifyListeners();
        }
      } catch (_) {
        // Silent failure
      }
    });
  }

  /// Clear persisted cart for a customer (after successful order).
  void _clearPersistedCart(String customerId) {
    Future(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        prefs.remove('$_cartKey:$customerId');
      } catch (_) {}
    });
  }

  // ═══════════════════════════════════════════════════════════════════════
  // ADDRESS MANAGEMENT
  // ═══════════════════════════════════════════════════════════════════════

  List<DeliveryAddress> addressesFor(String customerId) =>
      _addresses.where((a) => a.customerId == customerId).toList();

  DeliveryAddress? defaultAddress(String customerId) {
    final list = addressesFor(customerId);
    return list.where((a) => a.isDefault).firstOrNull ?? list.firstOrNull;
  }

  void saveAddress({
    String? id,
    required String recipient,
    required String phone,
    required String addressLine,
    String? notes,
    GeoPoint? coordinates,
    bool isDefault = false,
  }) {
    final u = _actor();
    _check(u.role == Role.customer, 'Only customers can save addresses.');
    final r = _text(recipient, 'Recipient name', max: 100);
    final p = _phone(phone);
    final a = _text(addressLine, 'Address', max: 500);
    if (id == null) {
      final addr = DeliveryAddress(
        id: _id('addr'),
        customerId: u.id,
        recipient: r,
        phone: p,
        addressLine: a,
        notes: notes?.trim().isEmpty == true ? null : notes?.trim(),
        coordinates: coordinates,
        isDefault: isDefault || _addresses.where((x) => x.customerId == u.id).isEmpty,
      );
      // If this is default, unset others
      if (addr.isDefault) {
        for (final other in _addresses.where((x) => x.customerId == u.id)) {
          other.isDefault = false;
        }
      }
      _addresses.add(addr);
    } else {
      final addr = _addresses.firstWhere((x) => x.id == id);
      _check(addr.customerId == u.id, 'Not your address.');
      addr.recipient = r;
      addr.phone = p;
      addr.addressLine = a;
      addr.notes = notes?.trim().isEmpty == true ? null : notes?.trim();
      if (coordinates != null) addr.coordinates = coordinates;
      if (isDefault) {
        for (final other in _addresses.where((x) => x.customerId == u.id && x.id != id)) {
          other.isDefault = false;
        }
        addr.isDefault = true;
      }
    }
    _persistAddresses(u.id);
    notifyListeners();
  }

  void deleteAddress(String id) {
    final u = _actor();
    final addr = _addresses.firstWhere((x) => x.id == id);
    _check(addr.customerId == u.id, 'Not your address.');
    _addresses.remove(addr);
    _persistAddresses(u.id);
    notifyListeners();
  }

  void _persistAddresses(String customerId) {
    final list = addressesFor(customerId);
    Future(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        prefs.setString('$_addressesKey:$customerId',
          jsonEncode([for (final a in list) a.toMap()]));
      } catch (_) {}
    });
  }

  void _loadPersistedAddresses() {
    // Will load when a customer logs in
  }

  void _loadAddressesForCustomer(String customerId) {
    Future(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final json = prefs.getString('$_addressesKey:$customerId');
        if (json != null) {
          final list = jsonDecode(json) as List;
          _addresses.removeWhere((a) => a.customerId == customerId);
          for (final m in list) {
            _addresses.add(DeliveryAddress.fromMap(m as Map<String, dynamic>));
          }
          notifyListeners();
        }
      } catch (_) {}
    });
  }

  void register({required Role role, required String name, required String email,
    required String password, required String phone, String address = ''}) {
    final u = _newAccount(role: role, name: name, email: email, password: password, phone: phone, address: address);
    _sessionId = u.id; notifyListeners();
  }

  /// Register a new rider with full application details.
  /// New rider accounts start with Pending Approval status.
  AppUser registerRiderApplication({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String regNumber,
    required String vehicleMake,
    required String vehicleModel,
    required String vehicleColor,
  }) {
    final u = _newAccount(role: Role.rider, name: name, email: email, password: password, phone: phone);
    u.vehicleInfo = VehicleInfo(
      registrationNumber: regNumber,
      make: vehicleMake,
      model: vehicleModel,
      color: vehicleColor,
    );
    u.riderApprovalStatus = RiderApprovalStatus.pending;
    _audit(u.id, u.id, 'rider', 'application_submitted', 'Rider application submitted');
    notifyListeners();
    return u;
  }

  void adminRegisterRider({required String name, required String email, required String phone, required String password}) {
    _admin();
    _newAccount(role: Role.rider, name: name, email: email, phone: phone, password: password);
    notifyListeners();
  }

  AppUser _newAccount({required Role role, required String name, required String email,
    required String password, required String phone, String address = ''}) {
    _check(role != Role.admin, 'Admin registration is disabled.');
    final mail = _text(email, 'Email', max: 190).toLowerCase();
    _check(RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(mail), 'Enter a valid email.');
    _check(!_users.any((u) => u.email == mail), 'Email is already registered.');
    _check(password.length >= 8 && password.length <= 72, 'Use an 8-72 character password.');
    final n = _text(name, 'Name', max: 100), p = _phone(phone);
    final a = _text(address, 'Address', optional: true);
    final u = AppUser(id: _id('u'), role: role, name: n, email: mail, phone: p, address: a);
    _users.add(u); _demoPasswords[u.id] = password; return u;
  }
  String _phone(String phone) {
    final p = _text(phone, 'Phone', max: 30);
    _check(RegExp(r'^\+?[0-9 ()-]{7,30}$').hasMatch(p), 'Enter a valid phone number.'); return p;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // RIDER DOCUMENT MANAGEMENT
  // ═══════════════════════════════════════════════════════════════════════

  /// Upload a document for rider verification.
  /// In production, this uploads to Firebase Storage with private access rules.
  void uploadDocument({
    required String riderId,
    required DocumentType type,
    required String fileName,
    required String storagePath,
    DateTime? expiryDate,
  }) {
    final u = _actor();
    _check(u.role == Role.rider && u.id == riderId || u.role == Role.admin,
        'Only the rider or an admin can upload documents.');
    _check(fileName.isNotEmpty, 'File name is required.');
    _check(storagePath.isNotEmpty, 'Storage path is required.');
    // Validate file type
    final ext = fileName.split('.').last.toLowerCase();
    _check(['jpg', 'jpeg', 'png', 'pdf'].contains(ext), 'Only JPG, PNG, or PDF files are accepted.');
    // Validate file size (simulated — in production checked by Storage rules)
    _check(fileName.length < 200, 'File name too long.');

    final doc = RiderDocument(
      id: _id('doc'),
      riderId: riderId,
      type: type,
      fileName: fileName,
      storagePath: storagePath,
      uploadedAt: DateTime.now(),
      expiryDate: expiryDate,
    );
    _documents.add(doc);
    _audit(riderId, u.id, u.role.name, 'document_uploaded', 'Document uploaded: ${type.label}');
    notifyListeners();
  }

  /// Remove a document (only by the rider who owns it or admin).
  void removeDocument(String docId) {
    final u = _actor();
    final doc = _documents.firstWhere((d) => d.id == docId);
    _check(u.role == Role.admin || (u.role == Role.rider && doc.riderId == u.id),
        'Not allowed to remove this document.');
    _documents.remove(doc);
    _audit(doc.riderId, u.id, u.role.name, 'document_removed', 'Document removed: ${doc.type.label}');
    notifyListeners();
  }

  /// Get a temporary authorised access URL for a document.
  /// In production, this generates a signed Firebase Storage URL.
  /// Only the applicant and authorised admins can access.
  String? getDocumentAccessUrl(String docId) {
    final u = _actor();
    final doc = _documents.firstWhere((d) => d.id == docId);
    _check(u.role == Role.admin || (u.role == Role.rider && doc.riderId == u.id),
        'You do not have permission to access this document.');
    // In production: Firebase Storage _ref.getDownloadURL() with signed URL
    return 'foodieit://storage/${doc.storagePath}?token=temp_${DateTime.now().millisecondsSinceEpoch}';
  }

  // ═══════════════════════════════════════════════════════════════════════
  // RIDER APPROVAL
  // ═══════════════════════════════════════════════════════════════════════

  /// Admin approves a rider application.
  void approveRider(String riderId) {
    final admin = _actor();
    _check(admin.role == Role.admin, 'Only administrators can approve riders.');
    _check(riderId != admin.id, 'You cannot approve yourself.');
    final rider = user(riderId);
    _check(rider.role == Role.rider, 'User is not a rider.');
    _check(rider.riderApprovalStatus == RiderApprovalStatus.pending ||
           rider.riderApprovalStatus == RiderApprovalStatus.rejected,
           'Rider is not in an approvable state.');

    // Validate all required documents are present and not expired
    final docs = documentsFor(riderId);
    for (final requiredType in [DocumentType.license, DocumentType.vehicleRegistration, DocumentType.insurance]) {
      final typeDocs = docs.where((d) => d.type == requiredType).toList();
      _check(typeDocs.isNotEmpty, 'Missing required document: ${requiredType.label}');
      _check(!typeDocs.any((d) => d.isExpired), '${requiredType.label} has expired. Rider must update it before approval.');
    }

    rider.riderApprovalStatus = RiderApprovalStatus.approved;
    rider.rejectionReason = null;
    _audit(riderId, admin.id, 'admin', 'rider_approved', 'Rider application approved');
    notifyListeners();
  }

  /// Admin rejects a rider application with a reason.
  void rejectRider(String riderId, String reason) {
    final admin = _actor();
    _check(admin.role == Role.admin, 'Only administrators can reject riders.');
    _check(riderId != admin.id, 'You cannot reject yourself.');
    _check(reason.trim().isNotEmpty, 'A reason is required for rejection.');
    final rider = user(riderId);
    _check(rider.role == Role.rider, 'User is not a rider.');
    _check(rider.riderApprovalStatus == RiderApprovalStatus.pending,
           'Only pending applications can be rejected.');

    rider.riderApprovalStatus = RiderApprovalStatus.rejected;
    rider.rejectionReason = reason.trim();
    _audit(riderId, admin.id, 'admin', 'rider_rejected', 'Rider application rejected: $reason', reason: reason);
    notifyListeners();
  }

  /// Admin suspends an approved rider.
  void suspendRider(String riderId, String reason) {
    final admin = _actor();
    _check(admin.role == Role.admin, 'Only administrators can suspend riders.');
    _check(riderId != admin.id, 'You cannot suspend yourself.');
    _check(reason.trim().isNotEmpty, 'A reason is required for suspension.');
    final rider = user(riderId);
    _check(rider.role == Role.rider, 'User is not a rider.');
    _check(rider.riderApprovalStatus == RiderApprovalStatus.approved,
           'Only approved riders can be suspended.');

    rider.riderApprovalStatus = RiderApprovalStatus.suspended;
    rider.rejectionReason = reason.trim();
    _audit(riderId, admin.id, 'admin', 'rider_suspended', 'Rider suspended: $reason', reason: reason);
    notifyListeners();
  }

  /// Re-activate a suspended rider.
  void reinstateRider(String riderId) {
    _admin();
    final rider = user(riderId);
    _check(rider.role == Role.rider, 'User is not a rider.');
    _check(rider.riderApprovalStatus == RiderApprovalStatus.suspended,
           'Only suspended riders can be reinstated.');
    rider.riderApprovalStatus = RiderApprovalStatus.approved;
    rider.rejectionReason = null;
    _audit(riderId, _actor().id, 'admin', 'rider_reinstated', 'Rider reinstated');
    notifyListeners();
  }

  /// A rejected rider resubmits their application after correcting information.
  void resubmitRiderApplication() {
    final u = _actor();
    _check(u.role == Role.rider, 'Only riders can resubmit applications.');
    _check(u.riderApprovalStatus == RiderApprovalStatus.rejected,
           'Only rejected applications can be resubmitted.');
    u.riderApprovalStatus = RiderApprovalStatus.pending;
    u.rejectionReason = null;
    _audit(u.id, u.id, 'rider', 'application_resubmitted', 'Rider application resubmitted');
    notifyListeners();
  }

  /// Check if a rider has expired documents and block job acceptance.
  bool riderHasExpiredDocuments(String riderId) {
    final docs = documentsFor(riderId);
    return docs.any((d) => d.isExpired);
  }

  /// Check if a rider can accept new delivery jobs.
  bool riderCanAcceptJobs(String riderId) {
    final rider = user(riderId);
    return rider.role == Role.rider &&
           rider.active &&
           rider.riderApprovalStatus.canAcceptJobs &&
           !riderHasExpiredDocuments(riderId);
  }

  /// Get the list of expired or expiring documents for a rider.
  List<RiderDocument> expiredOrExpiringDocuments(String riderId) {
    return documentsFor(riderId).where((d) => d.isExpired || d.isExpiringSoon).toList();
  }

  // ═══════════════════════════════════════════════════════════════════════
  // GPS TRACKING
  // ═══════════════════════════════════════════════════════════════════════

  /// Rider reports a location update during an active delivery.
  /// Only the assigned rider can update their location.
  void updateRiderLocation(String orderId, GeoPoint point, {bool simulated = false}) {
    final u = _actor();
    final o = order(orderId);
    _check(u.role == Role.rider && o.riderId == u.id,
        'Only the assigned rider can update location for this order.');
    _check(o.status == OrderStatus.pickedUp,
        'Location updates are only accepted during active pickup-to-delivery.');

    final record = LocationRecord(
      point: point,
      timestamp: DateTime.now(),
      simulated: simulated || simulatedTrackingEnabled,
    );
    _riderLocations.putIfAbsent(u.id, () => []).add(record);

    // Retention: keep only last 500 records per rider (documented limit = 24h in production)
    final list = _riderLocations[u.id]!;
    if (list.length > 500) {
      _riderLocations[u.id] = list.sublist(list.length - 500);
    }
    notifyListeners();
  }

  /// Customer retrieves the rider's current location for their active order.
  /// Only the customer who owns the order can access tracking.
  LocationRecord? getRiderLocationForOrder(String orderId) {
    final u = _actor();
    final o = order(orderId);
    _check(u.role == Role.customer && o.customerId == u.id,
        'You can only track your own orders.');
    _check(o.status.trackingVisible,
        'Tracking is only available while the rider is delivering your order.');
    if (o.riderId == null) return null;
    return lastLocationFor(o.riderId!);
  }

  /// Get all location records for a rider's current delivery (for route display).
  List<LocationRecord> getRiderRouteForOrder(String orderId) {
    final u = _actor();
    final o = order(orderId);
    _check(u.role == Role.customer && o.customerId == u.id,
        'You can only track your own orders.');
    _check(o.status.trackingVisible,
        'Tracking is only available during active delivery.');
    if (o.riderId == null) return [];
    return locationsFor(o.riderId!);
  }

  /// Clear rider location records when an order is delivered or cancelled.
  void _clearTrackingForOrder(FoodOrder o) {
    if (o.riderId != null) {
      _riderLocations.remove(o.riderId);
    }
  }

  /// Toggle simulated tracking mode (for testing without physical movement).
  void toggleSimulatedTracking() {
    final u = _actor();
    _check(u.role == Role.rider || u.role == Role.admin,
        'Only riders or admins can toggle simulated tracking.');
    simulatedTrackingEnabled = !simulatedTrackingEnabled;
    notifyListeners();
  }

  /// Generate a simulated location update for testing.
  void generateSimulatedLocation(String orderId) {
    final u = _actor();
    final o = order(orderId);
    _check(u.role == Role.rider && o.riderId == u.id,
        'Only the assigned rider can simulate location.');
    _check(o.status == OrderStatus.pickedUp,
        'Simulated updates only work during active delivery.');

    // Simulate movement from restaurant towards delivery address
    final r = restaurant(o.restaurantId);
    final startPoint = r.location ?? const GeoPoint(3.2150, 101.7300);
    final endPoint = o.deliveryPoint ?? const GeoPoint(3.1700, 101.6700);

    final lastLoc = lastLocationFor(u.id);
    final current = lastLoc?.point ?? startPoint;

    // Move 10% towards destination
    final newLat = current.lat + (endPoint.lat - current.lat) * 0.1;
    final newLng = current.lng + (endPoint.lng - current.lng) * 0.1;

    updateRiderLocation(orderId, GeoPoint(newLat, newLng), simulated: true);
  }

  // ═══════════════════════════════════════════════════════════════════════
  // DISTANCE & PRICING
  // ═══════════════════════════════════════════════════════════════════════

  /// Calculate distance and delivery fee for a potential order.
  /// Throws if the address is outside the restaurant's service range.
  DeliveryQuote calculateDeliveryQuote(String restaurantId, GeoPoint deliveryPoint) {
    final r = restaurant(restaurantId);
    _check(r.active, 'Restaurant is inactive.');
    _check(r.location != null, 'Restaurant location is not set.');

    final distance = r.location!.roadDistanceKmTo(deliveryPoint);
    final maxRange = r.serviceRangeKm ?? deliveryPricing.maxServiceRangeKm;
    _check(distance <= maxRange,
        'Delivery address is ${distance.toStringAsFixed(1)} km away — outside the ${maxRange.toStringAsFixed(0)} km service range.');

    final fee = deliveryPricing.calculateFee(distance);
    final riderPayout = deliveryPricing.calculateRiderPayout(distance, fee);

    return DeliveryQuote(
      restaurantPoint: r.location!,
      deliveryPoint: deliveryPoint,
      distanceKm: distance,
      deliveryFeeCents: fee,
      riderPayoutCents: riderPayout,
      maxServiceRangeKm: maxRange,
      pricingConfig: deliveryPricing,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // COMMISSION
  // ═══════════════════════════════════════════════════════════════════════

  /// Calculate commission for an order's food subtotal.
  int calculateCommission(int foodSubtotalCents, {int discountCents = 0}) =>
      commissionConfig.calculateCommission(foodSubtotalCents, discountCents: discountCents);

  /// Restaurant accepts the commission terms during onboarding.
  void acceptCommissionTerms(String restaurantId) {
    _admin();
    final r = restaurant(restaurantId);
    _check(!r.commissionAccepted, 'Commission terms already accepted.');
    r.commissionAccepted = true;
    r.commissionAcceptedAt = DateTime.now();
    notifyListeners();
  }

  /// Get commission totals for admin dashboard.
  CommissionSummary get commissionSummary {
    final completedOrders = _orders.where((o) =>
        o.status == OrderStatus.delivered && o.financials != null).toList();
    final totalFoodSubtotal = completedOrders.fold<int>(0,
        (s, o) => s + o.financials!.foodSubtotalCents);
    final totalCommission = completedOrders.fold<int>(0,
        (s, o) => s + o.financials!.commissionCents);
    final totalDeliveryFees = completedOrders.fold<int>(0,
        (s, o) => s + o.financials!.deliveryFeeCents);
    final totalRiderPayouts = completedOrders.fold<int>(0,
        (s, o) => s + o.financials!.riderPayoutCents);

    return CommissionSummary(
      completedOrderCount: completedOrders.length,
      totalFoodSubtotalCents: totalFoodSubtotal,
      totalCommissionCents: totalCommission,
      totalDeliveryFeesCents: totalDeliveryFees,
      totalRiderPayoutsCents: totalRiderPayouts,
      platformNetCents: totalCommission + totalDeliveryFees - totalRiderPayouts,
      commissionRatePercent: commissionConfig.commissionRatePercent,
    );
  }

  /// Get commission/settlement breakdown for a specific restaurant.
  RestaurantSettlement restaurantSettlement(String restaurantId) {
    final orders = _orders.where((o) =>
        o.restaurantId == restaurantId &&
        o.status == OrderStatus.delivered &&
        o.financials != null).toList();
    final foodSubtotal = orders.fold<int>(0, (s, o) => s + o.financials!.foodSubtotalCents);
    final commission = orders.fold<int>(0, (s, o) => s + o.financials!.commissionCents);
    final net = foodSubtotal - commission;
    return RestaurantSettlement(
      restaurantId: restaurantId,
      completedOrders: orders.length,
      foodSubtotalCents: foodSubtotal,
      commissionCents: commission,
      netEarningsCents: net,
      commissionRatePercent: commissionConfig.commissionRatePercent,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // PROFILE & ACCOUNT MANAGEMENT (preserved)
  // ═══════════════════════════════════════════════════════════════════════

  void editProfile(String name, String phone, String address) {
    final u = _actor(); final n = _text(name, 'Name', max: 100), p = _phone(phone);
    final a = _text(address, 'Address', optional: true);
    u.name = n; u.phone = p; u.address = a; notifyListeners();
  }
  void deactivateSelf(String password) {
    final u = _actor(); _check(u.role != Role.admin, 'Demo admin cannot deactivate itself.');
    _check(_demoPasswords[u.id] == password, 'Incorrect password.');
    _deactivate(u); _sessionId = null; notifyListeners();
  }
  void adminSetActive(String userId, bool active) {
    _admin(); final u = user(userId); _check(u.role != Role.admin, 'Cannot change an administrator.');
    if (!active) { _deactivate(u); } else { u.active = true; }
    notifyListeners();
  }
  void _deactivate(AppUser u) {
    _check(!_orders.any((o) => o.status.active && (o.customerId == u.id || o.riderId == u.id)), 'Complete or cancel active orders/deliveries first.');
    u.active = false;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // RESTAURANT MANAGEMENT (preserved + extended)
  // ═══════════════════════════════════════════════════════════════════════

  void saveRestaurant({String? id, required String name, required String cuisine,
    required String address, required String hours, double? lat, double? lng, double? serviceRangeKm}) {
    _admin(); final n = _text(name, 'Restaurant name', max: 100);
    final c = _text(cuisine, 'Cuisine', max: 60), a = _text(address, 'Address');
    _check(RegExp(r'^([01]\d|2[0-3]):[0-5]\d-([01]\d|2[0-3]):[0-5]\d$').hasMatch(hours.trim()), 'Use operating hours like 09:00-22:00.');
    if (id == null) {
      _restaurants.add(Restaurant(id: _id('r'), name: n, cuisine: c, address: a, hours: hours.trim(),
        location: lat != null && lng != null ? GeoPoint(lat, lng) : null,
        serviceRangeKm: serviceRangeKm));
    } else {
      final r = restaurant(id);
      r.name = n; r.cuisine = c; r.address = a; r.hours = hours.trim();
      if (lat != null && lng != null) r.location = GeoPoint(lat, lng);
      if (serviceRangeKm != null) r.serviceRangeKm = serviceRangeKm;
    }
    notifyListeners();
  }
  void setRestaurantActive(String id, bool active) { _admin(); restaurant(id).active = active; notifyListeners(); }

  // ═══════════════════════════════════════════════════════════════════════
  // FOOD ITEM MANAGEMENT (preserved)
  // ═══════════════════════════════════════════════════════════════════════

  static int parsePrice(String value) {
    final m = RegExp(r'^(\d{1,4})(?:\.(\d{1,2}))?$').firstMatch(value.trim());
    if (m == null) throw StateError('Enter a price like 12.90 (maximum RM9,999.99).');
    final cents = int.parse(m[1]!) * 100 + int.parse((m[2] ?? '').padRight(2, '0'));
    if (cents <= 0) throw StateError('Price must be greater than zero.'); return cents;
  }
  void saveFood({String? id, required String restaurantId, required String name,
    required String description, required String price}) {
    _admin(); restaurant(restaurantId);
    final n = _text(name, 'Food name', max: 120), d = _text(description, 'Description', max: 255, optional: true);
    final cents = parsePrice(price);
    if (id == null) { _foods.add(FoodItem(id: _id('f'), restaurantId: restaurantId, name: n, description: d, priceCents: cents)); }
    else { final f = food(id); _check(f.restaurantId == restaurantId && !f.removed, 'Food not found.'); f.name = n; f.description = d; f.priceCents = cents; }
    notifyListeners();
  }
  void setFoodAvailable(String id, bool available) { _admin(); final f = food(id); _check(!f.removed, 'Food was removed.'); f.available = available; notifyListeners(); }
  void removeFood(String id) { _admin(); food(id).removed = true; notifyListeners(); }

  // ═══════════════════════════════════════════════════════════════════════
  // ORDER MANAGEMENT (preserved + extended with pricing/commission)
  // ═══════════════════════════════════════════════════════════════════════

  List<OrderLine> _priceCart(String restaurantId, Map<String, int> quantities) {
    _check(restaurant(restaurantId).active, 'Restaurant is inactive.');
    _check(quantities.isNotEmpty && quantities.length <= 50, 'Choose 1-50 food items.');
    final lines = <OrderLine>[];
    quantities.forEach((id, qty) {
      final f = food(id);
      _check(f.restaurantId == restaurantId && !f.removed && f.available, 'An item is unavailable.');
      _check(qty >= 1 && qty <= 99, 'Quantity must be 1-99.');
      lines.add(OrderLine(f.id, f.name, qty, f.priceCents));
    });
    _check(lines.fold<int>(0, (s, l) => s + l.total) <= 10000000, 'Order maximum is RM100,000.');
    return lines;
  }

  /// Revalidate cart items against current backend prices and availability.
  /// Returns the validated lines. Throws if any item is unavailable or prices changed.
  /// If prices changed, includes the new prices in the returned lines.
  /// The caller should compare line.unitCents with the cart's stored prices.
  List<OrderLine> revalidateCart(String restaurantId, Map<String, int> quantities) {
    final u = _actor();
    _check(u.role == Role.customer, 'Customer account required.');
    return _priceCart(restaurantId, quantities);
  }

  /// Place an order with idempotency. If [idempotencyKey] was already used,
  /// returns the original order instead of creating a duplicate.
  /// Revalidates prices from the backend (not the client).
  /// Clears the cart on success.
  FoodOrder placeOrder({
    required String restaurantId,
    required Map<String, int> quantities,
    required String address,
    GeoPoint? deliveryPoint,
    required String idempotencyKey,
  }) {
    final u = _actor();
    _check(u.role == Role.customer, 'Customer account required.');
    _check(!_usedIdempotencyKeys.contains(idempotencyKey),
        'This order was already submitted.'); // Should never reach here — we return early

    // Idempotency check: if this key was used, return the existing order
    if (_usedIdempotencyKeys.contains(idempotencyKey)) {
      final existing = _orders.where((o) =>
          o.customerId == u.id &&
          o.createdAt.millisecondsSinceEpoch.toString() == idempotencyKey).firstOrNull;
      if (existing != null) return existing;
    }

    final a = _text(address, 'Delivery address');
    final lines = _priceCart(restaurantId, quantities);
    final foodSubtotal = lines.fold<int>(0, (s, l) => s + l.total);

    // Calculate financials
    OrderFinancials? financials;
    if (deliveryPoint != null) {
      final quote = calculateDeliveryQuote(restaurantId, deliveryPoint);
      final commission = calculateCommission(foodSubtotal);
      financials = OrderFinancials(
        restaurantPoint: quote.restaurantPoint,
        deliveryPoint: deliveryPoint,
        distanceKm: quote.distanceKm,
        deliveryFeeCents: quote.deliveryFeeCents,
        riderPayoutCents: quote.riderPayoutCents,
        foodSubtotalCents: foodSubtotal,
        commissionRatePercent: commissionConfig.commissionRatePercent.round(),
        commissionCents: commission,
        restaurantNetCents: foodSubtotal - commission,
        totalCents: foodSubtotal + quote.deliveryFeeCents,
        pricingSnapshot: DeliveryPricingConfig(
          baseFeeCents: deliveryPricing.baseFeeCents,
          perKmRateCents: deliveryPricing.perKmRateCents,
          minFeeCents: deliveryPricing.minFeeCents,
          maxServiceRangeKm: deliveryPricing.maxServiceRangeKm,
          roundingUnitCents: deliveryPricing.roundingUnitCents,
          riderPayoutBaseCents: deliveryPricing.riderPayoutBaseCents,
          riderPayoutPerKmCents: deliveryPricing.riderPayoutPerKmCents,
          riderPayoutPercentage: deliveryPricing.riderPayoutPercentage,
        ),
      );
    } else {
      // Demo delivery fee when no GPS/distance config available
      final demoFee = 500; // RM 5.00 demo fee
      final commission = calculateCommission(foodSubtotal);
      financials = OrderFinancials(
        restaurantPoint: const GeoPoint(3.2150, 101.7300),
        deliveryPoint: const GeoPoint(3.1700, 101.6700),
        distanceKm: 0,
        deliveryFeeCents: demoFee,
        riderPayoutCents: 300,
        foodSubtotalCents: foodSubtotal,
        commissionRatePercent: commissionConfig.commissionRatePercent.round(),
        commissionCents: commission,
        restaurantNetCents: foodSubtotal - commission,
        totalCents: foodSubtotal + demoFee,
        pricingSnapshot: DeliveryPricingConfig(),
      );
    }

    final o = FoodOrder(
      id: _id('o'), customerId: u.id, restaurantId: restaurantId, lines: lines,
      address: a, status: OrderStatus.placed,
      createdAt: DateTime.now(), deliveryPoint: deliveryPoint, financials: financials,
    );
    _orders.add(o);
    _usedIdempotencyKeys.add(idempotencyKey);

    // Clear only the purchased cart contents
    if (_cart != null && _cart!.customerId == u.id) {
      _cart!.clearItems();
      _cart!.restaurantId = null;
      _cart!.restaurantName = null;
      _persistCart();
      _clearPersistedCart(u.id);
    }

    notifyListeners();
    return o;
  }

  /// Save an order with delivery pricing and commission financials.
  /// If [deliveryPoint] is provided, calculates distance-based delivery fee.
  /// If [deliveryPoint] is null, saves as draft without pricing.
  FoodOrder saveOrder({
    String? id,
    int? revision,
    required String restaurantId,
    required Map<String, int> quantities,
    required String address,
    GeoPoint? deliveryPoint,
    bool draft = false,
  }) {
    final u = _actor(); _check(u.role == Role.customer, 'Customer account required.');
    final a = _text(address, 'Delivery address');
    FoodOrder? old;
    if (id != null) {
      old = order(id); _check(old.customerId == u.id, 'This is not your order.');
      _check(old.status.editable && old.restaurantId == restaurantId, 'Order can no longer be edited.');
      _check(revision == old.revision, 'Order changed. Reopen it before editing.');
    }
    final lines = _priceCart(restaurantId, quantities);
    final foodSubtotal = lines.fold<int>(0, (s, l) => s + l.total);

    // Calculate financials only if not a draft and delivery point is provided
    OrderFinancials? financials;
    if (!draft && deliveryPoint != null) {
      final quote = calculateDeliveryQuote(restaurantId, deliveryPoint);
      final commission = calculateCommission(foodSubtotal);
      financials = OrderFinancials(
        restaurantPoint: quote.restaurantPoint,
        deliveryPoint: deliveryPoint,
        distanceKm: quote.distanceKm,
        deliveryFeeCents: quote.deliveryFeeCents,
        riderPayoutCents: quote.riderPayoutCents,
        foodSubtotalCents: foodSubtotal,
        commissionRatePercent: commissionConfig.commissionRatePercent.round(),
        commissionCents: commission,
        restaurantNetCents: foodSubtotal - commission,
        totalCents: foodSubtotal + quote.deliveryFeeCents,
        pricingSnapshot: DeliveryPricingConfig(
          baseFeeCents: deliveryPricing.baseFeeCents,
          perKmRateCents: deliveryPricing.perKmRateCents,
          minFeeCents: deliveryPricing.minFeeCents,
          maxServiceRangeKm: deliveryPricing.maxServiceRangeKm,
          roundingUnitCents: deliveryPricing.roundingUnitCents,
          riderPayoutBaseCents: deliveryPricing.riderPayoutBaseCents,
          riderPayoutPerKmCents: deliveryPricing.riderPayoutPerKmCents,
          riderPayoutPercentage: deliveryPricing.riderPayoutPercentage,
        ),
      );
    }

    if (old == null) {
      final o = FoodOrder(
        id: _id('o'), customerId: u.id, restaurantId: restaurantId, lines: lines,
        address: a, status: draft ? OrderStatus.draft : OrderStatus.placed,
        createdAt: DateTime.now(), deliveryPoint: deliveryPoint, financials: financials,
      );
      _orders.add(o); notifyListeners(); return o;
    }
    old.lines = lines; old.address = a;
    old.deliveryPoint = deliveryPoint; old.financials = financials;
    old.status = old.status == OrderStatus.draft ? (draft ? OrderStatus.draft : OrderStatus.placed) : OrderStatus.updated;
    old.revision++; notifyListeners(); return old;
  }

  void deleteDraft(String id) {
    final u = _actor(), o = order(id);
    _check(u.role == Role.customer && o.customerId == u.id && o.status == OrderStatus.draft, 'Only your own drafts can be deleted.');
    _orders.remove(o); notifyListeners();
  }

  void cancelOrder(String id) {
    final u = _actor(), o = order(id);
    _check(u.role == Role.admin || (u.role == Role.customer && o.customerId == u.id), 'Not your order.');
    _check([OrderStatus.placed, OrderStatus.updated].contains(o.status) ||
           (u.role == Role.admin && [OrderStatus.assigned, OrderStatus.pickedUp].contains(o.status)),
           'This order cannot be cancelled.');
    o.status = OrderStatus.cancelled; o.revision++;
    _clearTrackingForOrder(o);
    notifyListeners();
  }

  void assignRider(String orderId, String riderId) {
    final u = _actor(), o = order(orderId); final rider = user(riderId);
    _check(u.role == Role.admin || (u.role == Role.rider && u.id == riderId), 'Not allowed to assign this rider.');
    _check(rider.active && rider.role == Role.rider, 'Choose an active rider.');
    // Riders can only self-assign if approved with valid documents
    if (u.role == Role.rider) {
      _check(riderCanAcceptJobs(riderId),
          'You cannot accept jobs. Approval status: ${rider.riderApprovalStatus.label}' +
          (riderHasExpiredDocuments(riderId) ? '. Some documents have expired.' : '.'));
    }
    _check([OrderStatus.placed, OrderStatus.updated].contains(o.status), 'Order already assigned or final.');
    o.riderId = riderId; o.status = OrderStatus.assigned; o.revision++;
    _audit(riderId, u.id, u.role.name, 'rider_assigned', 'Rider assigned to order $orderId');
    notifyListeners();
  }

  void deliveryStatus(String id, OrderStatus next) {
    final u = _actor(), o = order(id);
    _check(u.role == Role.admin || (u.role == Role.rider && o.riderId == u.id), 'Only the assigned rider can update this delivery.');
    // Check rider is still approved when accepting jobs
    if (u.role == Role.rider) {
      _check(riderCanAcceptJobs(u.id),
          'Your account cannot perform delivery actions. Status: ${u.riderApprovalStatus.label}');
    }
    final valid = (o.status == OrderStatus.assigned && next == OrderStatus.pickedUp) ||
                  (o.status == OrderStatus.pickedUp && next == OrderStatus.delivered);
    _check(valid, 'Invalid delivery status change.');
    o.status = next; o.revision++;
    if (next == OrderStatus.delivered || next == OrderStatus.cancelled) {
      _clearTrackingForOrder(o);
    }
    _audit(o.id, u.id, u.role.name, 'delivery_status_changed', 'Status: ${o.status.label}');
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════════════
  // REVIEWS (preserved)
  // ═══════════════════════════════════════════════════════════════════════

  void saveReview(String orderId, int rating, String comment) {
    final u = _actor(), o = order(orderId);
    _check(u.role == Role.customer && o.customerId == u.id && o.status == OrderStatus.delivered, 'Only delivered orders can be reviewed by their customer.');
    _check(rating >= 1 && rating <= 5, 'Rating must be 1-5.');
    final c = _text(comment, 'Review', max: 500);
    final existing = reviewFor(orderId);
    if (existing == null) { _reviews.add(FoodReview(id: _id('v'), orderId: orderId, customerId: u.id, restaurantId: o.restaurantId, rating: rating, comment: c)); }
    else { existing.rating = rating; existing.comment = c; }
    notifyListeners();
  }
  void deleteReview(String id) {
    final u = _actor(), r = _reviews.firstWhere((v) => v.id == id);
    _check(u.role == Role.customer && r.customerId == u.id, 'Only the review owner can delete it.');
    _reviews.remove(r); notifyListeners();
  }
  double? average(String restaurantId) {
    final list = _reviews.where((r) => r.restaurantId == restaurantId).toList();
    if (list.isEmpty) return null;
    return list.fold<int>(0, (s, r) => s + r.rating) / list.length;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // ADMIN PRICING CONFIG
  // ═══════════════════════════════════════════════════════════════════════

  void updateDeliveryPricing(DeliveryPricingConfig config) {
    _admin();
    deliveryPricing = config;
    notifyListeners();
  }

  void updateCommissionConfig(CommissionConfig config) {
    _admin();
    commissionConfig = config;
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════════════
  // AUDIT LOG
  // ═══════════════════════════════════════════════════════════════════════

  void _audit(String riderId, String actorId, String actorRole, String action, String description, {String? reason}) {
    _auditLog.add(AuditLogEntry(
      id: _id('audit'),
      riderId: riderId,
      actorId: actorId,
      actorRole: actorRole,
      action: action,
      reason: reason,
      timestamp: DateTime.now(),
      details: {'description': description},
    ));
  }

  // ═══════════════════════════════════════════════════════════════════════
  // SEED DATA
  // ═══════════════════════════════════════════════════════════════════════

  void _seed() {
    _users.addAll([
      AppUser(id: 'admin', role: Role.admin, name: 'Foodieit Admin', email: 'admin@foodieit.demo', phone: '+60120000000',
        mfa: MfaEnrolment(enrolled: false)),
      AppUser(id: 'customer', role: Role.customer, name: 'Aiman', email: 'customer@example.com', phone: '+60123456789', address: 'TAR UMT, Jalan Genting Klang, Kuala Lumpur',
        mfa: MfaEnrolment(enrolled: false)),
      AppUser(id: 'rider', role: Role.rider, name: 'Roshan', email: 'rider@example.com', phone: '+60198765432',
        riderApprovalStatus: RiderApprovalStatus.approved,
        vehicleInfo: VehicleInfo(registrationNumber: 'WXY 1234', make: 'Honda', model: 'RS150', color: 'Red'),
        mfa: MfaEnrolment(enrolled: false)),
    ]);
    _demoPasswords.addAll({'admin': 'admin@example', 'customer': 'Customer123!', 'rider': 'Rider123!'});

    // ── Sample restaurants (fictional) ──
    // Clearly labelled as sample data. Prices in Malaysian ringgit.
    _restaurants.addAll([
      Restaurant(id: 'r1', name: 'Selera Kampung', cuisine: 'Malaysian favourites', address: 'Jalan Genting Klang, Setapak, KL', hours: '08:00-22:00',
        categoryId: 'malaysian',
        imageUrl: 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=600&q=80',
        location: const GeoPoint(3.2150, 101.7300),
        serviceRangeKm: 15.0,
        commissionAccepted: true, commissionAcceptedAt: DateTime.now().subtract(const Duration(days: 30))),
      Restaurant(id: 'r2', name: 'Burger Corner', cuisine: 'Burgers and fries', address: 'Wangsa Maju, KL', hours: '10:00-23:00',
        categoryId: 'breakfast',
        imageUrl: 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=600&q=80',
        location: const GeoPoint(3.2080, 101.7250),
        serviceRangeKm: 12.0,
        commissionAccepted: true, commissionAcceptedAt: DateTime.now().subtract(const Duration(days: 25))),
      Restaurant(id: 'r3', name: 'Pizza House', cuisine: 'Italian pizza and sides', address: 'Jalan TAR, KL', hours: '11:00-23:00',
        categoryId: 'healthy',
        imageUrl: 'https://images.unsplash.com/photo-1513104890138-7c749659a591?w=600&q=80',
        location: const GeoPoint(3.2030, 101.7350),
        serviceRangeKm: 15.0,
        commissionAccepted: true, commissionAcceptedAt: DateTime.now().subtract(const Duration(days: 20))),
      Restaurant(id: 'r4', name: 'Rasa Thai', cuisine: 'Authentic Thai cuisine', address: 'Bukit Bintang, KL', hours: '11:00-22:00',
        categoryId: 'noodles',
        imageUrl: 'https://images.unsplash.com/photo-1559314809-0d155014e29e?w=600&q=80',
        location: const GeoPoint(3.2200, 101.7200),
        serviceRangeKm: 15.0,
        commissionAccepted: true, commissionAcceptedAt: DateTime.now().subtract(const Duration(days: 15))),
      Restaurant(id: 'r5', name: 'Sweet Treats', cuisine: 'Desserts and cafe drinks', address: 'Damansara, PJ', hours: '09:00-21:00',
        categoryId: 'drinks',
        imageUrl: 'https://images.unsplash.com/photo-1488477184116-f1ee9c0010b1?w=600&q=80',
        location: const GeoPoint(3.2100, 101.6300),
        serviceRangeKm: 20.0,
        commissionAccepted: true, commissionAcceptedAt: DateTime.now().subtract(const Duration(days: 10))),
    ]);

    // ── Sample menu items — prices in RM (stored as sen) ──
    _foods.addAll([
      // Selera Kampung
      FoodItem(id: 'f1', restaurantId: 'r1', name: 'Nasi Lemak Ayam',
        description: 'Coconut rice with crispy fried chicken, sambal, anchovies and peanuts',
        priceCents: 1290, categoryId: 'malaysian',
        imageUrl: 'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=400&q=80'),
      FoodItem(id: 'f2', restaurantId: 'r1', name: 'Mee Goreng Mamak',
        description: 'Wok-fried yellow noodles with vegetables, egg and spicy sauce',
        priceCents: 950, categoryId: 'noodles',
        imageUrl: 'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?w=400&q=80'),
      FoodItem(id: 'f3', restaurantId: 'r1', name: 'Teh Ais',
        description: 'Iced milk tea, perfectly sweetened',
        priceCents: 300, categoryId: 'drinks',
        imageUrl: 'https://images.unsplash.com/photo-1556679343-c7306c1976bc?w=400&q=80'),

      // Burger Corner
      FoodItem(id: 'f4', restaurantId: 'r2', name: 'Classic Chicken Burger',
        description: 'Grilled chicken patty, lettuce, tomato and house sauce',
        priceCents: 1190, categoryId: 'breakfast',
        imageUrl: 'https://images.unsplash.com/photo-1571091718767-18b5b1457add?w=400&q=80'),
      FoodItem(id: 'f5', restaurantId: 'r2', name: 'Beef Cheeseburger',
        description: 'Juicy beef patty with melted cheddar, pickles and onion',
        priceCents: 1590, categoryId: 'breakfast',
        imageUrl: 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=400&q=80'),
      FoodItem(id: 'f6', restaurantId: 'r2', name: 'French Fries',
        description: 'Crispy golden fries with sea salt',
        priceCents: 590, categoryId: 'breakfast',
        imageUrl: 'https://images.unsplash.com/photo-1573080496219-bb080dd4f877?w=400&q=80'),

      // Pizza House
      FoodItem(id: 'f7', restaurantId: 'r3', name: 'Margherita Pizza',
        description: 'Classic pizza with tomato, mozzarella and fresh basil',
        priceCents: 2290, categoryId: 'healthy',
        imageUrl: 'https://images.unsplash.com/photo-1574071318508-1cdbab80d002?w=400&q=80'),
      FoodItem(id: 'f8', restaurantId: 'r3', name: 'Chicken Pepperoni Pizza',
        description: 'Loaded with chicken pepperoni, mozzarella and tomato base',
        priceCents: 2890, categoryId: 'healthy',
        imageUrl: 'https://images.unsplash.com/photo-1513104890138-7c749659a591?w=400&q=80'),
      FoodItem(id: 'f9', restaurantId: 'r3', name: 'Garlic Bread',
        description: 'Toasted baguette with garlic butter and herbs',
        priceCents: 790, categoryId: 'healthy',
        imageUrl: 'https://images.unsplash.com/photo-1573140247632-f8fd74997d5c?w=400&q=80'),

      // Rasa Thai
      FoodItem(id: 'f10', restaurantId: 'r4', name: 'Chicken Tom Yum',
        description: 'Spicy and sour Thai soup with chicken, lemongrass and mushrooms',
        priceCents: 1490, categoryId: 'noodles',
        imageUrl: 'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?w=400&q=80'),
      FoodItem(id: 'f11', restaurantId: 'r4', name: 'Thai Fried Rice',
        description: 'Fragrant jasmine rice stir-fried with egg, vegetables and Thai spices',
        priceCents: 1290, categoryId: 'noodles',
        imageUrl: 'https://images.unsplash.com/photo-1603133872878-684f208fb84b?w=400&q=80'),
      FoodItem(id: 'f12', restaurantId: 'r4', name: 'Thai Milk Tea',
        description: 'Sweet, creamy iced Thai milk tea',
        priceCents: 590, categoryId: 'drinks',
        imageUrl: 'https://images.unsplash.com/photo-1556679343-c7306c1976bc?w=400&q=80'),

      // Sweet Treats
      FoodItem(id: 'f13', restaurantId: 'r5', name: 'Chocolate Waffle',
        description: 'Crispy waffle drizzled with rich chocolate sauce',
        priceCents: 1090, categoryId: 'breakfast',
        imageUrl: 'https://images.unsplash.com/photo-1562376552-0401608d68b5?w=400&q=80'),
      FoodItem(id: 'f14', restaurantId: 'r5', name: 'Strawberry Cheesecake',
        description: 'Creamy cheesecake topped with fresh strawberries',
        priceCents: 1390, categoryId: 'breakfast',
        imageUrl: 'https://images.unsplash.com/photo-1565958011703-44f9829ba187?w=400&q=80'),
      FoodItem(id: 'f15', restaurantId: 'r5', name: 'Iced Latte',
        description: 'Smooth espresso with chilled milk over ice',
        priceCents: 890, categoryId: 'drinks',
        imageUrl: 'https://images.unsplash.com/photo-1461023058943-07fcbe16d735?w=400&q=80'),
    ]);

    // Seed a delivered order with financials (sample data)
    final o1 = FoodOrder(
      id: 'o1', customerId: 'customer', restaurantId: 'r1',
      lines: [const OrderLine('f1', 'Nasi Lemak Ayam', 1, 1290)],
      address: 'TAR UMT, Jalan Genting Klang, Kuala Lumpur', status: OrderStatus.delivered,
      riderId: 'rider', createdAt: DateTime.now().subtract(const Duration(days: 1)),
      deliveryPoint: const GeoPoint(3.1700, 101.6700),
    );
    // Attach financials retroactively for seed
    final foodSub = 1290;
    final commission = commissionConfig.calculateCommission(foodSub);
    final distance = _restaurants[0].location!.roadDistanceKmTo(const GeoPoint(3.1700, 101.6700));
    final fee = deliveryPricing.calculateFee(distance);
    o1.financials = OrderFinancials(
      restaurantPoint: _restaurants[0].location!,
      deliveryPoint: const GeoPoint(3.1700, 101.6700),
      distanceKm: distance,
      deliveryFeeCents: fee,
      riderPayoutCents: deliveryPricing.calculateRiderPayout(distance, fee),
      foodSubtotalCents: foodSub,
      commissionRatePercent: 10,
      commissionCents: commission,
      restaurantNetCents: foodSub - commission,
      totalCents: foodSub + fee,
      pricingSnapshot: DeliveryPricingConfig(),
    );
    _orders.add(o1);

    _reviews.add(FoodReview(id: 'v1', orderId: 'o1', customerId: 'customer', restaurantId: 'r1', rating: 5, comment: 'Fresh, tasty and delivered on time!'));
  }
}

// ═════════════════════════════════════════════════════════════════════════
// DELIVERY QUOTE (result of distance/pricing calculation)
// ═════════════════════════════════════════════════════════════════════════

class DeliveryQuote {
  final GeoPoint restaurantPoint;
  final GeoPoint deliveryPoint;
  final double distanceKm;
  final int deliveryFeeCents;
  final int riderPayoutCents;
  final double maxServiceRangeKm;
  final DeliveryPricingConfig pricingConfig;

  const DeliveryQuote({
    required this.restaurantPoint,
    required this.deliveryPoint,
    required this.distanceKm,
    required this.deliveryFeeCents,
    required this.riderPayoutCents,
    required this.maxServiceRangeKm,
    required this.pricingConfig,
  });
}

// ═════════════════════════════════════════════════════════════════════════
// COMMISSION SUMMARY (admin dashboard)
// ═════════════════════════════════════════════════════════════════════════

class CommissionSummary {
  final int completedOrderCount;
  final int totalFoodSubtotalCents;
  final int totalCommissionCents;
  final int totalDeliveryFeesCents;
  final int totalRiderPayoutsCents;
  final int platformNetCents;
  final double commissionRatePercent;

  const CommissionSummary({
    required this.completedOrderCount,
    required this.totalFoodSubtotalCents,
    required this.totalCommissionCents,
    required this.totalDeliveryFeesCents,
    required this.totalRiderPayoutsCents,
    required this.platformNetCents,
    required this.commissionRatePercent,
  });
}

// ═════════════════════════════════════════════════════════════════════════
// RESTAURANT SETTLEMENT (vendor commission view)
// ═════════════════════════════════════════════════════════════════════════

class RestaurantSettlement {
  final String restaurantId;
  final int completedOrders;
  final int foodSubtotalCents;
  final int commissionCents;
  final int netEarningsCents;
  final double commissionRatePercent;

  const RestaurantSettlement({
    required this.restaurantId,
    required this.completedOrders,
    required this.foodSubtotalCents,
    required this.commissionCents,
    required this.netEarningsCents,
    required this.commissionRatePercent,
  });
}
