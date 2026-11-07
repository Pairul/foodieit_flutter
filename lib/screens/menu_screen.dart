import 'package:flutter/material.dart';
import '../models/entities.dart';
import '../services/app_scope.dart';
import '../services/app_store.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'cart_screen.dart';

class MenuScreen extends StatefulWidget {
  final String restaurantId;
  const MenuScreen({super.key, required this.restaurantId});
  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  Restaurant? _restaurant;
  String? _loadError;
  bool _loading = true;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _loadRestaurant();
    }
  }

  /// Load the restaurant by ID with error handling.
  /// Called from didChangeDependencies() — never from initState().
  /// This prevents the "dependOnInheritedWidgetOfExactType called before
  /// initState completed" crash.
  void _loadRestaurant() {
    final s = AppScope.of(context);
    try {
      _restaurant = s.restaurant(widget.restaurantId);
      _loadError = null;
    } catch (e) {
      _restaurant = null;
      _loadError = 'Restaurant not found. It may have been removed.';
    }
    _loading = false;
    if (mounted) setState(() {});
  }

  void edit(FoodItem? food) {
    final s = AppScope.of(context);
    editForm(
      context,
      title: food == null ? 'Add food item' : 'Edit food item',
      fields: [
        FieldSpec('name', 'Food name', value: food?.name ?? ''),
        FieldSpec('description', 'Description', value: food?.description ?? '', optional: true, maxLines: 2),
        FieldSpec('price', 'Price (RM)', value: food == null ? '' : (food.priceCents / 100).toStringAsFixed(2), keyboard: const TextInputType.numberWithOptions(decimal: true)),
      ],
      save: (d) => s.saveFood(id: food?.id, restaurantId: widget.restaurantId, name: d['name']!, description: d['description']!, price: d['price']!),
      saveLabel: food == null ? 'Add item' : 'Save changes',
    );
  }

  @override
  Widget build(BuildContext context) {
    // Show loading indicator while data loads
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading...')),
        body: const LoadingState('Loading restaurant details...'),
      );
    }

    // Show error state if restaurant couldn't be loaded
    if (_restaurant == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Restaurant')),
        body: EmptyState(
          _loadError ?? 'Restaurant not found.',
          icon: Icons.error_outline,
          actionLabel: 'Go back',
          onAction: () => Navigator.pop(context),
        ),
      );
    }

    final s = AppScope.of(context);
    final r = _restaurant!;

    if (s.current == null) {
      return Scaffold(appBar: AppBar(title: const Text('Signed out')), body: const EmptyState('Return to sign in.'));
    }
    final admin = s.current!.role == Role.admin;
    final isCustomer = s.current!.role == Role.customer;
    final avg = s.average(r.id);
    final rows = s.foods.where((f) => f.restaurantId == r.id && !f.removed).toList();

    // Use shared cart state
    final cart = s.cart;
    final cartItems = cart?.items.where((i) =>
        rows.any((f) => f.id == i.foodId)).toList() ?? [];
    final cartCount = cartItems.fold<int>(0, (sum, i) => sum + i.quantity);
    final cartSubtotal = cartItems.fold<int>(0, (sum, i) => sum + i.lineTotal);
    final canAddFromHere = cart == null || cart.canAddFromRestaurant(r.id);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Restaurant header image
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  FoodImage(url: r.imageUrl, height: 200, width: double.infinity, radius: 0, fallbackIcon: Icons.storefront),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withValues(alpha: 0.5)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Content
          SliverToBoxAdapter(
            child: PageBody(
              padding: EdgeInsets.fromLTRB(16, 16, 16, admin || !isCustomer ? 16 : 100),
              children: [
                // Restaurant info card
                BrandedCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.name, style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 4),
                      Text(r.cuisine, style: Theme.of(context).textTheme.bodyMedium),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.star, size: 16, color: FoodieitTheme.warning),
                          const SizedBox(width: 4),
                          Text(avg?.toStringAsFixed(1) ?? 'New', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(width: 16),
                          Icon(Icons.access_time, size: 14, color: FoodieitTheme.textSecondary),
                          const SizedBox(width: 4),
                          Text(r.hours, style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                      const SizedBox(height: 8),
                      InfoRow(icon: Icons.location_on_outlined, label: 'Address', value: r.address),
                      InfoRow(icon: Icons.delivery_dining, label: 'Delivery', value: '25-35 min'),
                      if (r.serviceRangeKm != null)
                        InfoRow(icon: Icons.social_distance, label: 'Service range', value: '${r.serviceRangeKm!.toStringAsFixed(0)} km'),
                      if (!r.active)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: FoodieitTheme.dangerBg, borderRadius: BorderRadius.circular(FoodieitTheme.radiusXs)),
                            child: Row(children: [Icon(Icons.warning, size: 16, color: FoodieitTheme.danger), const SizedBox(width: 6), Text('This restaurant is inactive', style: TextStyle(color: FoodieitTheme.danger, fontWeight: FontWeight.w600))]),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Menu section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Menu', style: Theme.of(context).textTheme.titleLarge),
                    if (admin) FilledButton.icon(onPressed: () => edit(null), icon: const Icon(Icons.add, size: 18), label: const Text('Add item')),
                  ],
                ),
                const SizedBox(height: 14),

                if (rows.isEmpty) const EmptyState('The menu is empty.', icon: Icons.restaurant_menu),

                for (final f in rows) ...[
                  _MenuItemCard(
                    food: f,
                    admin: admin,
                    isCustomer: isCustomer,
                    restaurantActive: r.active,
                    quantity: cart?.find(f.id)?.quantity ?? 0,
                    canAdd: canAddFromHere,
                    onEdit: () => edit(f),
                    onToggleAvail: () => perform(context, () => s.setFoodAvailable(f.id, !f.available)),
                    onRemove: () async {
                      if (await confirmAction(context, 'Remove ${f.name} from this menu?') && context.mounted) {
                        perform(context, () => s.removeFood(f.id));
                      }
                    },
                    onAdd: () => _handleAdd(s, f, r),
                    onQty: (qty) => _handleQtyChange(s, f, r, qty),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ],
      ),
      // Persistent cart bar — opens cart screen, not checkout directly
      bottomNavigationBar: !admin && isCustomer && cart != null && cartCount > 0
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Container(
                  decoration: BoxDecoration(
                    color: FoodieitTheme.primary,
                    borderRadius: BorderRadius.circular(FoodieitTheme.radiusMd),
                    boxShadow: FoodieitTheme.shadowMd,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(FoodieitTheme.radiusMd),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(builder: (_) => const CartScreen()),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(FoodieitTheme.radiusXs),
                              ),
                              child: Text('$cartCount', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'View cart - ${money(cartSubtotal)}',
                                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                              ),
                            ),
                            const Icon(Icons.shopping_bag, color: Colors.white, size: 22),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  /// Handle adding an item to the cart. Shows replace dialog if different restaurant.
  /// Shows error snackbar if the operation fails.
  void _handleAdd(AppStore s, FoodItem f, Restaurant r) {
    final cart = s.cart;
    if (cart == null) {
      showFeedback(context, 'Please sign in as a customer to add items.', isError: true);
      return;
    }

    if (cart.canAddFromRestaurant(r.id)) {
      perform(context, () => s.addToCart(f.id));
    } else {
      // Ask whether to replace
      _showReplaceDialog(s, f, r);
    }
  }

  void _handleQtyChange(AppStore s, FoodItem f, Restaurant r, int qty) {
    final cart = s.cart;
    if (cart == null) {
      showFeedback(context, 'Please sign in as a customer to modify cart.', isError: true);
      return;
    }

    if (qty > 0 && !cart.canAddFromRestaurant(r.id)) {
      _showReplaceDialog(s, f, r);
      return;
    }
    perform(context, () => s.setCartQuantity(f.id, qty));
  }

  void _showReplaceDialog(AppStore s, FoodItem f, Restaurant r) {
    final cart = s.cart!;
    final currentRestaurant = cart.restaurantName ?? 'another restaurant';
    showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Replace cart?'),
        content: Text(
          'Your cart has items from $currentRestaurant. '
          'Adding from ${r.name} will clear your current cart. '
          'Do you want to continue?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Keep current')),
          FilledButton(
            onPressed: () {
              Navigator.pop(c);
              perform(context, () {
                s.replaceCartWithRestaurant(r.id);
                s.addToCart(f.id);
              });
            },
            child: const Text('Replace cart'),
          ),
        ],
      ),
    );
  }
}

class _MenuItemCard extends StatelessWidget {
  final FoodItem food;
  final bool admin;
  final bool isCustomer;
  final bool restaurantActive;
  final int quantity;
  final bool canAdd;
  final VoidCallback onEdit;
  final VoidCallback onToggleAvail;
  final VoidCallback onRemove;
  final VoidCallback onAdd;
  final ValueChanged<int> onQty;

  const _MenuItemCard({
    required this.food,
    required this.admin,
    required this.isCustomer,
    required this.restaurantActive,
    required this.quantity,
    required this.canAdd,
    required this.onEdit,
    required this.onToggleAvail,
    required this.onRemove,
    required this.onAdd,
    required this.onQty,
  });

  @override
  Widget build(BuildContext context) => BrandedCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Food image
            ClipRRect(
              borderRadius: BorderRadius.circular(FoodieitTheme.radiusSm),
              child: FoodImage(url: food.imageUrl, width: 90, height: 90, radius: FoodieitTheme.radiusSm),
            ),
            const SizedBox(width: 12),
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(food.name, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(food.description, style: Theme.of(context).textTheme.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Text(money(food.priceCents), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: FoodieitTheme.primary)),
                  if (!food.available)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('Currently unavailable', style: TextStyle(fontSize: 12, color: FoodieitTheme.danger, fontWeight: FontWeight.w600)),
                    ),
                  const SizedBox(height: 8),
                  // Actions
                  if (admin)
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      OutlinedButton(onPressed: onEdit, child: const Text('Edit')),
                      TextButton(onPressed: onToggleAvail, child: Text(food.available ? 'Hide' : 'Show')),
                      TextButton(onPressed: onRemove, child: Text('Remove', style: TextStyle(color: FoodieitTheme.danger))),
                    ])
                  else if (isCustomer && food.available && restaurantActive)
                    Align(
                      alignment: Alignment.centerRight,
                      child: quantity > 0
                          ? QuantityStepper(quantity: quantity, onChanged: onQty, min: 0)
                          : OutlinedButton.icon(
                              onPressed: canAdd ? onAdd : onAdd, // Still allow tap to show replace dialog
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Add'),
                            ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
}
