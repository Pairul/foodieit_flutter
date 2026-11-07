import 'package:flutter/material.dart';
import '../../models/entities.dart';
import '../../services/app_scope.dart';
import '../../services/app_store.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../accounts_screen.dart';
import '../orders_screen.dart';
import '../restaurants_screen.dart';
import '../reviews_screen.dart';
import '../profile_screen.dart';
import '../mfa_screen.dart';
import '../admin_features_screen.dart';

/// Professional admin dashboard with responsive layout.
///
/// - Mobile: compact navigation drawer
/// - Larger screens: sidebar + responsive content area
/// - Dashboard header, search, page titles, consistent primary actions
/// - Summary cards from actual app state
/// - Recent orders, status groupings, shortcuts
class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});
  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int selected = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  static const _destinations = [
    _NavItem(icon: Icons.dashboard_outlined, selectedIcon: Icons.dashboard, label: 'Dashboard'),
    _NavItem(icon: Icons.people_outline, selectedIcon: Icons.people, label: 'Customers'),
    _NavItem(icon: Icons.receipt_long_outlined, selectedIcon: Icons.receipt_long, label: 'Orders'),
    _NavItem(icon: Icons.storefront_outlined, selectedIcon: Icons.storefront, label: 'Restaurants'),
    _NavItem(icon: Icons.restaurant_menu_outlined, selectedIcon: Icons.restaurant_menu, label: 'Menus'),
    _NavItem(icon: Icons.delivery_dining_outlined, selectedIcon: Icons.delivery_dining, label: 'Riders'),
    _NavItem(icon: Icons.star_outline, selectedIcon: Icons.star, label: 'Reviews'),
    _NavItem(icon: Icons.tune_outlined, selectedIcon: Icons.tune, label: 'Pricing'),
    _NavItem(icon: Icons.percent_outlined, selectedIcon: Icons.percent, label: 'Commission'),
    _NavItem(icon: Icons.security_outlined, selectedIcon: Icons.security, label: 'Security'),
    _NavItem(icon: Icons.person_outline, selectedIcon: Icons.person, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final u = s.current!;
    final isWide = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.restaurant_menu, color: FoodieitTheme.primary, size: 24),
            const SizedBox(width: 8),
            const Text('Foodieit', style: TextStyle(fontWeight: FontWeight.w900, color: FoodieitTheme.primary)),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: FoodieitTheme.primaryLight,
                borderRadius: BorderRadius.circular(FoodieitTheme.radiusXs),
              ),
              child: const Text('ADMIN', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: FoodieitTheme.primary)),
            ),
          ],
        ),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.search)),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: FoodieitTheme.primary,
              child: Text(u.name[0], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
            ),
          ),
        ],
      ),
      drawer: isWide ? null : _Drawer(
        destinations: _destinations,
        selectedIndex: selected,
        onSelect: (i) {
          setState(() => selected = i);
          Navigator.pop(context);
        },
        userName: u.name,
      ),
      body: Row(
        children: [
          if (isWide) _Sidebar(destinations: _destinations, selectedIndex: selected, onSelect: (i) => setState(() => selected = i)),
          Expanded(child: _buildPage(context, s, u, isWide)),
        ],
      ),
    );
  }

  Widget _buildPage(BuildContext context, AppStore s, AppUser u, bool isWide) {
    switch (selected) {
      case 0:
        return _DashboardPage(store: s, isWide: isWide, onNavigate: (i) => setState(() => selected = i));
      case 1:
        return const AccountsScreen();
      case 2:
        return const OrdersScreen();
      case 3:
        return const RestaurantsScreen();
      case 4:
        return const _MenuManagementPage();
      case 5:
        return const AdminRiderReviewScreen();
      case 6:
        return const ReviewsScreen();
      case 7:
        return const AdminPricingScreen();
      case 8:
        return const AdminCommissionScreen();
      case 9:
        return const MfaManagementScreen();
      case 10:
        return const ProfileScreen();
      default:
        return const SizedBox.shrink();
    }
  }
}

class _NavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  const _NavItem({required this.icon, required this.selectedIcon, required this.label});
}

class _Sidebar extends StatelessWidget {
  final List<_NavItem> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  const _Sidebar({required this.destinations, required this.selectedIndex, required this.onSelect});

  @override
  Widget build(BuildContext context) => Container(
        width: 240,
        color: FoodieitTheme.surface,
        child: Column(
          children: [
            const SizedBox(height: 12),
            for (int i = 0; i < destinations.length; i++)
              _NavTile(
                item: destinations[i],
                selected: i == selectedIndex,
                onTap: () => onSelect(i),
              ),
            const Spacer(),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('DEMO v2.0', style: TextStyle(fontSize: 10, color: FoodieitTheme.textHint, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
}

class _Drawer extends StatelessWidget {
  final List<_NavItem> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final String userName;
  const _Drawer({required this.destinations, required this.selectedIndex, required this.onSelect, required this.userName});

  @override
  Widget build(BuildContext context) => Drawer(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              color: FoodieitTheme.primary,
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.restaurant_menu, color: Colors.white, size: 32),
                    const SizedBox(height: 8),
                    const Text('Foodieit', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white)),
                    const SizedBox(height: 4),
                    Text(userName, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  for (int i = 0; i < destinations.length; i++)
                    _NavTile(
                      item: destinations[i],
                      selected: i == selectedIndex,
                      onTap: () => onSelect(i),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _NavTile extends StatelessWidget {
  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;
  const _NavTile({required this.item, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
        color: selected ? FoodieitTheme.primaryLight : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Icon(selected ? item.selectedIcon : item.icon,
                    size: 22, color: selected ? FoodieitTheme.primary : FoodieitTheme.textSecondary),
                const SizedBox(width: 12),
                Text(item.label,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected ? FoodieitTheme.primary : FoodieitTheme.textPrimary)),
              ],
            ),
          ),
        ),
      );
}

// ═════════════════════════════════════════════════════════════════════════
// DASHBOARD PAGE
// ═════════════════════════════════════════════════════════════════════════

class _DashboardPage extends StatelessWidget {
  final AppStore store;
  final bool isWide;
  final ValueChanged<int> onNavigate;
  const _DashboardPage({required this.store, required this.isWide, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final customers = store.users.where((u) => u.role == Role.customer).length;
    final activeRestaurants = store.restaurants.where((r) => r.active).length;
    final approvedRiders = store.users.where((u) => u.role == Role.rider && u.riderApprovalStatus == RiderApprovalStatus.approved).length;
    final pendingRiders = store.users.where((u) => u.role == Role.rider && u.riderApprovalStatus == RiderApprovalStatus.pending).length;
    final activeOrders = store.orders.where((o) => o.status.active).length;
    final deliveredValue = store.orders
        .where((o) => o.status == OrderStatus.delivered)
        .fold<int>(0, (sum, o) => sum + o.totalCents);
    final commissionTotal = store.commissionSummary;

    final recentOrders = store.orders.take(6).toList();
    final statusGroups = [
      ('Active', store.orders.where((o) => o.status.active).toList(), FoodieitTheme.warning),
      ('Delivered', store.orders.where((o) => o.status == OrderStatus.delivered).toList(), FoodieitTheme.success),
      ('Cancelled', store.orders.where((o) => o.status == OrderStatus.cancelled).toList(), FoodieitTheme.danger),
    ];

    return PageBody(
      maxWidth: isWide ? 1200 : 900,
      children: [
        Text('Dashboard', style: Theme.of(context).textTheme.displaySmall),
        Text('Overview of Foodieit operations', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 20),

        // Summary stat cards
        LayoutBuilder(builder: (context, constraints) {
          final crossCount = constraints.maxWidth > 700 ? 3 : 2;
          final spacing = 12.0;
          final cardWidth = (constraints.maxWidth - spacing * (crossCount - 1)) / crossCount;
          final stats = [
            ('Customers', '$customers', Icons.people, FoodieitTheme.info, 'Total registered'),
            ('Active restaurants', '$activeRestaurants', Icons.storefront, FoodieitTheme.primary, 'Accepting orders'),
            ('Approved riders', '$approvedRiders', Icons.delivery_dining, FoodieitTheme.success, '$pendingRiders pending'),
            ('Active orders', '$activeOrders', Icons.receipt_long, FoodieitTheme.warning, 'In progress'),
            ('Delivered value', money(deliveredValue), Icons.payments, FoodieitTheme.success, 'Total delivered'),
            ('Commission earned', money(commissionTotal.totalCommissionCents), Icons.percent, FoodieitTheme.success, '${commissionTotal.commissionRatePercent.toStringAsFixed(0)}% rate'),
          ];
          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              for (final stat in stats)
                SizedBox(
                  width: cardWidth,
                  child: StatCard(
                    label: stat.$1,
                    value: stat.$2,
                    icon: stat.$3,
                    color: stat.$4,
                    subtitle: stat.$5,
                    onTap: () => onNavigate(_destinationFor(stat.$1)),
                  ),
                ),
            ],
          );
        }),
        const SizedBox(height: 24),

        // Shortcuts row
        SectionHeader('Quick actions'),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            ActionChip(label: const Text('View all orders'), onPressed: () => onNavigate(2)),
            ActionChip(label: const Text('Add restaurant'), onPressed: () => onNavigate(3)),
            ActionChip(label: const Text('Manage menus'), onPressed: () => onNavigate(4)),
            ActionChip(label: const Text('Review riders'), onPressed: () => onNavigate(5)),
            ActionChip(label: const Text('Pricing settings'), onPressed: () => onNavigate(7)),
            ActionChip(label: const Text('Commission reports'), onPressed: () => onNavigate(8)),
          ],
        ),
        const SizedBox(height: 24),

        // Two-column: recent orders + status groups
        if (isWide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: _RecentOrders(recentOrders: recentOrders, store: store)),
              const SizedBox(width: 16),
              Expanded(flex: 2, child: _StatusGroups(groups: statusGroups)),
            ],
          )
        else ...[
          _RecentOrders(recentOrders: recentOrders, store: store),
          const SizedBox(height: 16),
          _StatusGroups(groups: statusGroups),
        ],

        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: FoodieitTheme.warningBg,
            borderRadius: BorderRadius.circular(FoodieitTheme.radiusSm),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: FoodieitTheme.warning),
              const SizedBox(width: 8),
              Expanded(child: Text('All figures shown are from the in-memory demo store and reset on restart. '
                  'GPS tracking, MFA, document verification, and payments are simulated.',
                  style: TextStyle(fontSize: 12, color: FoodieitTheme.warning, fontWeight: FontWeight.w600))),
            ],
          ),
        ),
      ],
    );
  }

  int _destinationFor(String label) => switch (label) {
    'Customers' => 1,
    'Active restaurants' => 3,
    'Approved riders' => 5,
    'Active orders' => 2,
    'Delivered value' => 2,
    'Commission earned' => 8,
    _ => 0,
  };
}

class _RecentOrders extends StatelessWidget {
  final List<FoodOrder> recentOrders;
  final AppStore store;
  const _RecentOrders({required this.recentOrders, required this.store});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader('Recent orders', subtitle: 'Latest ${recentOrders.length} orders'),
          for (final o in recentOrders) ...[
            BrandedCard(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('#${o.id}', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                        Text(store.restaurant(o.restaurantId).name, style: Theme.of(context).textTheme.bodySmall),
                        Text('${store.user(o.customerId).name} - ${o.createdAt.toLocal().toString().substring(0, 16)}',
                            style: Theme.of(context).textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(money(o.totalCents), style: const TextStyle(fontWeight: FontWeight.w800, color: FoodieitTheme.primary)),
                      const SizedBox(height: 4),
                      StatusBadge(o.status, compact: true),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (recentOrders.isEmpty) const EmptyState('No orders yet.', icon: Icons.receipt_long_outlined),
        ],
      );
}

class _StatusGroups extends StatelessWidget {
  final List<(String, List<FoodOrder>, Color)> groups;
  const _StatusGroups({required this.groups});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader('Orders by status'),
          for (final g in groups) ...[
            BrandedCard(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 32,
                    decoration: BoxDecoration(color: g.$3, borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(g.$1, style: Theme.of(context).textTheme.titleMedium),
                        Text('${g.$2.length} orders', style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                  Text('${g.$2.length}', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: g.$3)),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      );
}

// ═════════════════════════════════════════════════════════════════════════
// MENU MANAGEMENT PAGE (admin)
// ═════════════════════════════════════════════════════════════════════════

class _MenuManagementPage extends StatefulWidget {
  const _MenuManagementPage();
  @override
  State<_MenuManagementPage> createState() => _MenuManagementPageState();
}

class _MenuManagementPageState extends State<_MenuManagementPage> {
  String? selectedRestaurantId;
  String search = '';

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final restaurants = s.restaurants.toList();
    final rid = selectedRestaurantId ?? (restaurants.isNotEmpty ? restaurants.first.id : '');
    final foods = s.foods.where((f) =>
        f.restaurantId == rid &&
        !f.removed &&
        (search.isEmpty || f.name.toLowerCase().contains(search.toLowerCase()))).toList();

    void edit(FoodItem? food) {
      editForm(
        context,
        title: food == null ? 'Add food item' : 'Edit food item',
        fields: [
          FieldSpec('name', 'Food name', value: food?.name ?? ''),
          FieldSpec('description', 'Description', value: food?.description ?? '', optional: true, maxLines: 2),
          FieldSpec('price', 'Price (RM)', value: food == null ? '' : (food.priceCents / 100).toStringAsFixed(2), keyboard: const TextInputType.numberWithOptions(decimal: true)),
        ],
        save: (d) => s.saveFood(id: food?.id, restaurantId: rid, name: d['name']!, description: d['description']!, price: d['price']!),
        saveLabel: food == null ? 'Add item' : 'Save changes',
      );
    }

    return PageBody(
      children: [
        SectionHeader('Menu management', subtitle: 'Add, edit prices and availability, remove items'),
        const SizedBox(height: 12),

        Text('Select restaurant', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final r in restaurants)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(r.name),
                    selected: rid == r.id,
                    onSelected: (_) => setState(() => selectedRestaurantId = r.id),
                    selectedColor: FoodieitTheme.primary,
                    labelStyle: TextStyle(color: rid == r.id ? Colors.white : FoodieitTheme.textSecondary, fontWeight: FontWeight.w600),
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(FoodieitTheme.radiusXs)),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        SearchField(hint: 'Search food items', onChanged: (v) => setState(() => search = v)),
        const SizedBox(height: 12),

        FilledButton.icon(onPressed: () => edit(null), icon: const Icon(Icons.add), label: const Text('Add food item')),
        const SizedBox(height: 16),

        if (foods.isEmpty)
          const EmptyState('No food items. Add your first item.', icon: Icons.restaurant_menu),

        for (final f in foods) ...[
          BrandedCard(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(FoodieitTheme.radiusSm),
                  child: FoodImage(url: f.imageUrl, width: 64, height: 64, radius: FoodieitTheme.radiusSm),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(f.name, style: Theme.of(context).textTheme.titleMedium),
                      Text(f.description, style: Theme.of(context).textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(money(f.priceCents), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: FoodieitTheme.primary)),
                      if (!f.available)
                        Text('Unavailable', style: TextStyle(fontSize: 12, color: FoodieitTheme.danger, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Wrap(direction: Axis.vertical, spacing: 4, children: [
                  OutlinedButton(onPressed: () => edit(f), child: const Text('Edit')),
                  TextButton(onPressed: () => perform(context, () => s.setFoodAvailable(f.id, !f.available)), child: Text(f.available ? 'Hide' : 'Show')),
                  TextButton(
                    onPressed: () async {
                      if (await confirmAction(context, 'Remove ${f.name} from this menu?') && context.mounted) {
                        perform(context, () => s.removeFood(f.id));
                      }
                    },
                    child: Text('Remove', style: TextStyle(color: FoodieitTheme.danger)),
                  ),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}
