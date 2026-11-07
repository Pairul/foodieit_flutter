# Foodieit Backend Setup Guide

This document explains how to connect the Foodieit app to a Firebase backend for
persistent data, authentication with MFA, private document storage, GPS tracking,
distance-based pricing, and commission calculations.

## Current Status

| Feature | Simulated | Production-Ready Code |
|---------|-----------|----------------------|
| In-memory state | ✅ (active) | N/A |
| Firebase Auth + MFA | ✅ (simulated TOTP) | ✅ Code written, needs Firebase project |
| Firestore database | ✅ (in-memory) | ✅ Security rules written |
| Private document storage | ✅ (simulated path) | ✅ Storage rules written |
| GPS tracking | ✅ (simulated movement) | ✅ Architecture designed, needs Maps SDK |
| Distance pricing | ✅ (Haversine) | ✅ Cloud Functions written, needs Maps API |
| Commission | ✅ (calculated) | ✅ Cloud Functions written |
| Rider approval | ✅ (workflow) | ✅ Security rules enforce permissions |
| Audit log | ✅ (in-memory) | ✅ Cloud Functions write entries |
| Payments | ✅ (simulated) | ❌ No payment provider integrated |

## Step-by-Step Firebase Setup

### 1. Create a Firebase Project

1. Go to https://console.firebase.google.com/
2. Click "Add project" and name it `foodieit`
3. Enable Google Analytics (optional)
4. Wait for project creation

### 2. Enable Authentication

1. In Firebase Console → Authentication → Sign-in method
2. Enable **Email/Password**
3. (For MFA) Enable **Multi-factor Authentication**:
   - Go to Authentication → Settings → MFA
   - Toggle "Enable" under Multi-factor Authentication
   - Select TOTP (Time-based One-Time Password) as the second factor
   - Save

### 3. Create Firestore Database

1. Firebase Console → Firestore Database → Create database
2. Start in production mode
3. Choose a region close to your users (e.g. `asia-southeast1` for Malaysia)
4. Deploy the security rules:
   ```bash
   cd firebase
   firebase deploy --only firestore:rules
   ```

### 4. Create Storage Bucket

1. Firebase Console → Storage → Get started
2. Choose the same region as Firestore
3. Deploy storage rules:
   ```bash
   firebase deploy --only storage
   ```

### 5. Deploy Cloud Functions

```bash
cd firebase/functions
npm install
cd ..
firebase deploy --only functions
```

Required Cloud Functions:
- `calculateDeliveryFee` — Distance-based pricing (needs Google Maps API key)
- `calculateCommission` — Commission calculation
- `approveRider` — Admin-only rider approval
- `updateOrderStatus` — Order state machine enforcement

### 6. Add Flutter Firebase Dependencies

Add to `pubspec.yaml`:
```yaml
dependencies:
  firebase_core: ^3.0.0
  firebase_auth: ^5.0.0
  cloud_firestore: ^5.0.0
  firebase_storage: ^12.0.0
  google_maps_flutter: ^2.6.0
  geolocator: ^12.0.0
  permission_handler: ^11.0.0
```

### 7. Configure Firebase in Flutter

1. Install FlutterFire CLI:
   ```bash
   dart pub global activate flutterfire_cli
   ```
2. Configure:
   ```bash
   flutterfire configure --project=foodieit
   ```
3. This generates `lib/firebase_options.dart` automatically.

### 8. Google Maps API Key (for distance calculation)

1. Go to Google Cloud Console → APIs & Services → Credentials
2. Create an API key
3. Enable **Distance Matrix API** and **Maps SDK for Android**
4. Add the API key to your Cloud Functions environment:
   ```bash
   firebase functions:secrets:set GOOGLE_MAPS_API_KEY
   ```
5. Update `functions/index.js` to call the Distance Matrix API instead of Haversine.

### 9. Background Location Permissions (Android)

Add to `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
```

### 10. Location Retention Policy

Rider location records are retained for a maximum of **24 hours** after delivery
completion. In production, add a Cloud Function scheduled trigger:

```javascript
exports.cleanupLocations = functions.pubsub
  .schedule('every 24 hours')
  .onRun(async () => {
    const cutoff = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() - 24 * 60 * 60 * 1000)
    );
    // Delete all rider_locations older than cutoff
  });
```

## MFA Configuration

### Provider: Firebase Auth MFA (TOTP)

- **Factor type**: TOTP (Time-based One-Time Password)
- **Supported apps**: Google Authenticator, Authy, Microsoft Authenticator
- **Code expiry**: 30 seconds (standard TOTP)
- **Demo code expiry**: 5 minutes (simulated)
- **Attempt limit**: 5 per session
- **Lockout**: 15 minutes after max attempts
- **Resend limit**: 3 per session
- **Recovery codes**: 8 one-time-use codes generated at enrolment

### Enrolment flow:
1. User installs an authenticator app
2. User scans QR code or enters secret key manually
3. User saves recovery codes
4. User enters 6-digit code to verify

### Recovery:
- Use any unused recovery code (each can be used once)
- If all recovery codes are exhausted, contact admin to reset MFA

## Permission Enforcement

Permissions are enforced on BOTH the client and the backend:

| Action | Client check | Backend enforcement |
|--------|-------------|---------------------|
| View rider documents | ✅ | ✅ Firestore rules |
| Approve rider | ✅ | ✅ Cloud Function + Firestore rules |
| Change rider status | ✅ | ✅ Cloud Function only |
| View order tracking | ✅ | ✅ Firestore rules |
| Update order status | ✅ | ✅ Cloud Function |
| Change pricing config | ✅ | ✅ Firestore rules |
| Calculate delivery fee | ✅ | ✅ Cloud Function |

## Cart & Checkout Architecture

### Cart Persistence

The cart is stored in **two layers** for maximum resilience:

| Layer | Storage | Scope |
|-------|---------|-------|
| Client-side | `SharedPreferences` (JSON) | Survives app restarts, no network needed |
| Server-side | Firestore `carts/{customerId}` + `cart_items/{itemId}` | Syncs across devices, enforced by security rules |

In the current demo, the client-side `SharedPreferences` layer is active.
When Firebase is connected, the Firestore layer takes over and the client
layer becomes a read-through cache.

### One Restaurant Per Cart

A cart can only contain items from **one restaurant**. If the user tries to
add an item from a different restaurant, a replace dialog appears:
- **Replace**: Clears the current cart and switches to the new restaurant.
- **Cancel**: Keeps the current cart unchanged.

This is enforced both in `AppStore.addToCart()` (client) and in the Firestore
security rules (server).

### Price Calculation (Integer Sen)

All monetary values are stored as **integers in sen** (1 RM = 100 sen) to
avoid floating-point rounding errors.

```
Line total     = unitPriceCents × quantity
Food subtotal  = Σ(line totals)
Customer total = foodSubtotal + deliveryFee − discount
Commission     = round(foodSubtotal × commissionRate% / 100)  [separate]
```

The customer total **never** includes commission. Commission is calculated
separately and tracked in `OrderFinancials` for restaurant payout purposes.

### Checkout Flow (Idempotent)

1. Customer selects items → cart stored in `AppStore`
2. Customer selects delivery address
3. Checkout screen calls `store.revalidateCart()` to fetch current prices
4. `store.placeOrder()` is called with an idempotency key
5. If the same key was already used, the existing order is returned (no duplicate)
6. On success, cart is cleared and `OrderConfirmationScreen` is shown
7. Order appears in order history immediately

In production, `placeOrder` is a Cloud Function (`exports.placeOrder`) that:
- Revalidates all prices from Firestore
- Checks restaurant and item availability
- Calculates delivery fee (distance-based or demo flat RM 3.00)
- Creates the order atomically
- Clears the cart
- Writes an audit log entry

### Simulated vs Production Features

| Feature | Simulated (Demo) | Production-Ready |
|---------|-----------------|-----------------|
| Cart state | SharedPreferences | Firestore `carts` collection |
| Price revalidation | In-memory prices | Cloud Function fetches from Firestore |
| Order creation | `AppStore.placeOrder()` | Cloud Function `placeOrder` |
| Payment | Simulated (no charge) | ❌ No payment provider |
| Delivery fee | RM 3.00 flat demo fee | Distance-based via Maps API |
| Idempotency | In-memory key set | Firestore query on `idempotencyKey` field |

### Firestore Collections

| Collection | Purpose | Security |
|------------|---------|----------|
| `users` | User profiles & roles | Owner or admin |
| `restaurants` | Restaurant listings | Public read, admin write |
| `food_items` | Menu items | Public read, admin write |
| `carts` | Customer cart (one per customer) | Customer-only, owns cart |
| `cart_items` | Cart line items (sub-collection) | Customer-only, validates food availability |
| `addresses` | Delivery addresses | Customer-only, owns address |
| `orders` | Placed orders | Customer reads own, rider reads assigned, admin all |
| `order_items` | (Embedded in order doc as `items` array) | N/A |
| `reviews` | Restaurant reviews | Public read, customer creates own |
| `rider_documents` | Rider verification docs | Rider or admin only |
| `rider_applications` | Rider approval workflow | Rider or admin |
| `audit_log` | Audit trail | Admin only |
| `config` | Pricing & commission config | Signed-in read, admin write |

### Required Firestore Indexes

```bash
# Composite index for idempotency check
gcloud firestore indexes composite create \
  --collection-group=orders \
  --field-config field-path=idempotencyKey,order=ascending \
  --field-config field-path=customerId,order=ascending

# Customer orders query (orders by customerId, ordered by placedAt desc)
gcloud firestore indexes composite create \
  --collection-group=orders \
  --field-config field-path=customerId,order=ascending \
  --field-config field-path=placedAt,order=descending

# Cart items by restaurantId
gcloud firestore indexes composite create \
  --collection-group=cart_items \
  --field-config field-path=customerId,order=ascending \
  --field-config field-path=restaurantId,order=ascending

# Addresses by customerId
gcloud firestore indexes composite create \
  --collection-group=addresses \
  --field-config field-path=customerId,order=ascending \
  --field-config field-path=isDefault,order=ascending
```

### Seed Data

Call the `seedSampleData` Cloud Function once to populate:
- 5 sample restaurants (Selera Kampung, Burger Corner, Pizza House, Rasa Thai, Sweet Treats)
- 15 food items at RM prices (Nasi Lemak Ayam RM12.90, Teh Ais RM3.00, etc.)
- All items have descriptions, categories, image URLs, and availability flags

In demo mode (no Firebase), the same data is seeded in-memory by `AppStore._seed()`.

## File Locations

- `firebase/firebase.json` — Firebase CLI configuration
- `firebase/firestore.rules` — Firestore security rules
- `firebase/storage.rules` — Storage security rules
- `firebase/functions/index.js` — Cloud Functions
- `firebase/functions/package.json` — Functions dependencies

## Demo Credentials (unchanged)

- **Admin**: `admin 123` / `admin@example`
- **Customer**: `customer@example.com` / `Customer123!`
- **Rider**: `rider@example.com` / `Rider123!`

These credentials are for demo only. MFA is NOT enrolled by default for any
demo account. Enrol MFA from Profile → Security to test the MFA flow.
