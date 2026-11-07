# Foodieit — Flutter six-module food delivery app

University project: **Grab Food Mobile Application**, branded **Foodieit**. Team: Aiman (Accounts & Orders), Mikhail (Restaurants & Menus), Roshan (Riders & Reviews).

This is a complete **local simulator/demo implementation** using Flutter Material 3, Dart, ChangeNotifier and an InheritedNotifier scope. All six modules share one in-memory repository. There is no Firebase account, PHP server, REST API, payment gateway or persistent database to configure. It is independent of the earlier PHP project.

**Important:** credentials and authorization are demo logic on the client. This is not secure production authentication. Data survives logout/login within the same running app but resets on hot restart, process termination or relaunch. Separate devices/emulators do not share data. See `docs/BACKEND_MIGRATION.md` before adding real users.

## Demo logins

| Role | Login identifier | Password |
|---|---|---|
| Admin | `admin 123` | `admin@example` |
| Customer | `customer@example.com` | `Customer123!` |
| Rider | `rider@example.com` | `Rider123!` |

The admin username contains a single space. You can also sign in as the admin using the seeded internal email `admin@foodieit.demo`. There is no admin registration button. Customer/rider registration is available on the login screen. Admins can create additional riders without changing their admin session.

## Setup — Android emulator (Windows/macOS/Linux)

1. Install the current stable Flutter SDK and add `flutter/bin` to PATH. Install Android Studio with the Android SDK and create/start an Android emulator using Device Manager. Install the Flutter and Dart VS Code extensions if using VS Code.
2. Extract this ZIP and open the `foodieit_flutter` folder in VS Code. Open a terminal **in that folder**, where `pubspec.yaml` is located.
3. Check the setup:

```bash
flutter doctor
flutter doctor --android-licenses
```

Resolve Android toolchain issues reported by `flutter doctor`. This source bundle includes `lib/`, tests and configuration; generate the platform-specific Android/iOS/web runner files using the Flutter SDK installed on your computer:

```bash
flutter create --project-name foodieit --org com.foodieit.university --platforms=android,ios,web .
flutter pub get
```

Use the command as shown, without `--overwrite`; keep the supplied `lib/`, `pubspec.yaml`, and tests. Standard `flutter create` fills missing platform files. Commit generated platform folders to your team's Git repository once setup succeeds.

4. Start your emulator, then run:

```bash
flutter devices
flutter run
```

If there are multiple devices, copy a device ID from `flutter devices`:

```bash
flutter run -d YOUR_DEVICE_ID
```

You can also choose the emulator from VS Code's device selector and press F5. Hot reload keeps most live state; hot restart resets the demo.

## iOS simulator / web

- iOS builds require macOS, Xcode and an iOS simulator. After `flutter doctor` passes and a simulator is running, use `flutter devices` and `flutter run -d YOUR_SIMULATOR_ID`.
- A convenient desktop demo is `flutter run -d chrome` when Chrome is installed. If available on your OS, another browser may appear in `flutter devices`.
- No runtime network requests, native permissions or API keys are needed for the mock demo. SDK/package/platform setup may require an internet connection.

## Folder structure

```text
lib/
  main.dart                     App, theme and authentication gate
  models/entities.dart          Users, restaurants, foods, orders, reviews
  services/
    app_store.dart              Seed data, CRUD, role and workflow rules
    app_scope.dart              Shared ChangeNotifier subscription
  widgets/common.dart           Forms, confirmations, badges, page layouts
  screens/
    auth_screen.dart            Admin/customer/rider login and registration
    home_shell.dart             Role-specific bottom navigation
    accounts_screen.dart        Admin customer monitoring
    profile_screen.dart         Profile/address, logout, soft deactivation
    restaurants_screen.dart     Restaurant discovery and admin CRUD
    menu_screen.dart            Menu CRUD, availability, cart selection
    checkout_screen.dart        Dynamic cart, drafts, placing and editing
    orders_screen.dart          History, retrieval, cancellation, deliveries
    riders_screen.dart          Rider registration/directory/deactivation
    reviews_screen.dart         Submit/edit/delete reviews and ratings
 test/
  app_store_test.dart            Business-rule scenarios
  widget_test.dart               Login/customer-monitoring widget test
 tool/check_structure.py         Optional source integrity checks only
 docs/
  DEMO_WALKTHROUGH.md
  MODULE_MAP.md
  BACKEND_MIGRATION.md
  VALIDATION.md
```

## How state and navigation work

`FoodieitApp` owns one `AppStore`. `AppScope` exposes the store above `MaterialApp`, so pushed menu/checkout routes and all bottom tabs use the same data. Widgets rebuild on `notifyListeners()`. Business mutations live in `services/`, not in form widgets. Native Material routes provide normal back navigation, while `NavigationBar` and `IndexedStack` preserve tab state.

Admin tabs: Accounts / Stores / Delivery / Reviews / Profile. Customer tabs: Discover / Orders / Reviews / Profile. Rider tabs: Deliveries / Profile. The admin Delivery tab includes both orders and a rider directory.

## Rules to know

- One restaurant per order; 1–50 distinct foods and quantities 1–99. Prices use integer MYR cents. Maximum order total RM100,000. Current catalogue prices are checked when placing/saving.
- Drafts can be edited, placed or deleted. Placed/Updated orders can be edited or cancelled before rider assignment. Editing a placed order marks it Updated. Editing checks a revision number to reject a stale checkout screen.
- A rider accepts an unassigned order, or an admin assigns an active rider. Delivery follows Assigned → Picked up → Delivered. Only the assigned rider or admin may advance it. Admin may cancel an active delivery; a customer cannot cancel after assignment.
- Deactivation is a soft delete. Active customer orders or assigned rider jobs block deactivation until completed/cancelled. Admins can reactivate customer/rider accounts. Seed admin cannot deactivate itself.
- Restaurant deactivation prevents new checkout but preserves existing order fulfilment/history. Food removal is also soft deletion. Historical order lines retain their original item names/prices.
- Operating hours are editable `HH:mm-HH:mm` display data, including overnight ranges. This demo does not automatically enforce opening times.
- Only the customer who owns a Delivered order can submit/edit its review. One review per order; ratings are 1–5. Owners can delete their review; restaurant summaries recalculate immediately. Admins can view summaries/feedback.
- Emails cannot be edited in this version. No password-reset flow, real payments, delivery fees, push notifications or live GPS maps are included.

## Verification commands

Run after generating platform files and fetching Flutter dependencies:

```bash
dart format lib test
flutter analyze
flutter test
flutter run
```

Tests cover requested admin credentials, registration restrictions, profile persistence, admin restaurant/menu/rider management, price validation, checkout/edit/revision behavior, ownership, draft deletion, inactive catalogue, delivery transitions, account deactivation and review CRUD/averages. The widget test exercises admin login and customer monitoring.

**These Flutter tests and compilation were not run in the generation environment because Flutter/Dart were unavailable.** The included Python integrity check passed; it only checks delimiters and local imports, not Dart types, compilation or UI layout. See `docs/VALIDATION.md`. Run analysis/tests locally before submission.

Start your presentation with the step-by-step flow in `docs/DEMO_WALKTHROUGH.md`.

## Official setup/state references

- https://docs.flutter.dev/reference/flutter-cli
- https://docs.flutter.dev/reference/create-new-app
- https://docs.flutter.dev/learn/pathway/tutorial/change-notifier
- https://api.flutter.dev/flutter/widgets/InheritedNotifier-class.html
- https://firebase.google.com/docs/flutter/setup
