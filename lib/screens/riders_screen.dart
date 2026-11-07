import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'orders_screen.dart';
import 'admin_features_screen.dart';

/// Legacy riders screen — now redirects to the admin rider review screen
/// for the directory tab, while keeping the deliveries tab.
class RidersScreen extends StatelessWidget {
  const RidersScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            tabs: const [Tab(text: 'Deliveries'), Tab(text: 'Rider directory')],
            labelColor: FoodieitTheme.primary,
            unselectedLabelColor: FoodieitTheme.textSecondary,
            indicatorColor: FoodieitTheme.primary,
          ),
          Expanded(
            child: TabBarView(
              children: [
                const OrdersScreen(),
                // Use the new admin rider review screen which includes
                // approval status, document review, and audit log
                const AdminRiderReviewScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
