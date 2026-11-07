import 'package:flutter/material.dart';
import '../models/entities.dart';
import '../services/app_scope.dart';
import '../theme/app_theme.dart';
import 'orders_screen.dart';
import 'profile_screen.dart';
import 'customer_home_screen.dart';
import 'customer_search_screen.dart';
import 'admin/admin_dashboard.dart';
import 'tracking_screen.dart';
import 'admin_features_screen.dart';
import 'cart_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int selected = 0;

  @override
  Widget build(BuildContext context) {
    final u = AppScope.of(context).current!;

    if (u.role == Role.admin) {
      return AdminDashboard(key: ValueKey('admin_${u.id}'));
    }

    // Rider navigation
    if (u.role == Role.rider) {
      return _RiderShell(
        selected: selected,
        onChanged: (i) => setState(() => selected = i),
      );
    }

    // Customer navigation
    final cart = AppScope.of(context).cart;
    final cartCount = cart?.itemCount ?? 0;
    final pages = [
      const CustomerHomeScreen(),
      const CustomerSearchScreen(),
      const CartScreen(),
      const OrdersScreen(),
      const ProfileScreen(),
    ];
    final destinations = [
      const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
      const NavigationDestination(icon: Icon(Icons.search), selectedIcon: Icon(Icons.search), label: 'Search'),
      NavigationDestination(
        icon: Badge(
          isLabelVisible: cartCount > 0,
          label: Text('$cartCount'),
          child: const Icon(Icons.shopping_cart_outlined),
        ),
        selectedIcon: Badge(
          isLabelVisible: cartCount > 0,
          label: Text('$cartCount'),
          child: const Icon(Icons.shopping_cart),
        ),
        label: 'Cart',
      ),
      const NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Orders'),
      const NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
    ];

    return Scaffold(
      backgroundColor: FoodieitTheme.background,
      body: IndexedStack(index: selected, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected,
        onDestinationSelected: (i) => setState(() => selected = i),
        destinations: destinations,
      ),
    );
  }
}

class _RiderShell extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onChanged;
  const _RiderShell({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final u = store.current!;

    final pages = [
      const RiderDeliveryScreen(),
      const RiderApplicationScreen(),
      const ProfileScreen(),
    ];
    final destinations = [
      const NavigationDestination(icon: Icon(Icons.delivery_dining_outlined), selectedIcon: Icon(Icons.delivery_dining), label: 'Deliveries'),
      NavigationDestination(
        icon: const Icon(Icons.assignment_outlined),
        selectedIcon: const Icon(Icons.assignment),
        label: 'Application',
      ),
      const NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
    ];

    return Scaffold(
      backgroundColor: FoodieitTheme.background,
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.delivery_dining, color: FoodieitTheme.primary, size: 24),
            const SizedBox(width: 8),
            const Text('Foodieit', style: TextStyle(fontWeight: FontWeight.w900, color: FoodieitTheme.primary)),
          ],
        ),
        actions: [
          // Approval status badge
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: u.riderApprovalStatus == RiderApprovalStatus.approved
                      ? FoodieitTheme.successBg
                      : FoodieitTheme.warningBg,
                  borderRadius: BorderRadius.circular(FoodieitTheme.radiusXs),
                ),
                child: Text(
                  u.riderApprovalStatus.label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: u.riderApprovalStatus == RiderApprovalStatus.approved
                        ? FoodieitTheme.success
                        : FoodieitTheme.warning,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: IndexedStack(index: selected, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected,
        onDestinationSelected: onChanged,
        destinations: destinations,
      ),
    );
  }
}
