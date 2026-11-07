import 'package:flutter/material.dart';
import '../models/entities.dart';
import '../services/app_scope.dart';
import '../services/app_store.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'checkout_screen.dart';
import 'customer_home_screen.dart';

/// Dedicated cart screen showing all items, quantities, and checkout button.
/// Uses shared cart state from AppStore — not a local copy.
class CartScreen extends StatefulWidget {
  const CartScreen({super.key});
  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final cart = s.cart;

    // Not signed in or not a customer
    if (cart == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Cart')),
        body: const EmptyState('Please sign in to view your cart.'),
      );
    }

    final items = cart.items;
    final subtotal = cart.foodSubtotalCents;
    Restaurant? restaurant;
    try {
      restaurant = cart.restaurantId != null ? s.restaurant(cart.restaurantId!) : null;
    } catch (_) {
      // Restaurant was deleted — show cart with warning
      restaurant = null;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Cart'),
        actions: [
          if (items.isNotEmpty)
            TextButton(
              onPressed: () async {
                if (await confirmAction(context, 'Clear all items from your cart?')) {
                  perform(context, () => s.clearCart());
                }
              },
              child: Text('Clear', style: TextStyle(color: FoodieitTheme.danger)),
            ),
        ],
      ),
      body: items.isEmpty
          ? EmptyState(
              'Your cart is empty',
              icon: Icons.shopping_cart_outlined,
              actionLabel: 'Browse restaurants',
              onAction: () => Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute<void>(builder: (_) => const CustomerHomeScreen()),
                (route) => false,
              ),
            )
          : PageBody(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                // Restaurant header
                if (restaurant != null)
                  BrandedCard(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        FoodImage(url: restaurant.imageUrl, width: 56, height: 56, radius: FoodieitTheme.radiusSm, fallbackIcon: Icons.storefront),
                        const SizedBox(width: 12),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(restaurant.name, style: Theme.of(context).textTheme.titleMedium),
                            Text(restaurant.cuisine, style: Theme.of(context).textTheme.bodySmall),
                          ],
                        )),
                        if (!restaurant.active)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: FoodieitTheme.dangerBg, borderRadius: BorderRadius.circular(FoodieitTheme.radiusXs)),
                            child: Text('Inactive', style: TextStyle(color: FoodieitTheme.danger, fontSize: 11, fontWeight: FontWeight.w700)),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),

                SectionHeader('Items (${cart.itemCount})'),
                for (final item in items) ...[
                  _CartLineCard(
                    item: item,
                    saving: s.cartOperationInProgress,
                    onQty: (qty) => perform(context, () => s.setCartQuantity(item.foodId, qty)),
                    onRemove: () => perform(context, () => s.removeFromCart(item.foodId)),
                  ),
                  const SizedBox(height: 10),
                ],

                // Price summary
                const SizedBox(height: 8),
                BrandedCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _PriceRow(label: 'Food subtotal', value: money(subtotal)),
                      const SizedBox(height: 8),
                      _PriceRow(label: 'Delivery fee', value: 'Calculated at checkout'),
                      const Divider(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Estimated total', style: Theme.of(context).textTheme.titleMedium),
                          Text('${money(subtotal)} + delivery', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: FoodieitTheme.primary)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Info notice
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: FoodieitTheme.infoBg,
                    borderRadius: BorderRadius.circular(FoodieitTheme.radiusXs),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, size: 16, color: FoodieitTheme.info),
                      const SizedBox(width: 8),
                      Expanded(child: Text(
                        'Final price including delivery fee will be shown at checkout. '
                        'Prices are confirmed from the restaurant before you place your order.',
                        style: TextStyle(fontSize: 11, color: FoodieitTheme.info, fontWeight: FontWeight.w600),
                      )),
                    ],
                  ),
                ),
              ],
            ),
      // Checkout button
      bottomNavigationBar: items.isNotEmpty
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton(
                  onPressed: (restaurant == null || !restaurant.active)
                      ? null
                      : () => _goToCheckout(s, restaurant!.id),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Checkout - ${money(subtotal)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward),
                      ],
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  void _goToCheckout(AppStore s, String restaurantId) {
    final cart = s.cart!;
    Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(builder: (_) => CheckoutScreen(
        restaurantId: restaurantId,
        initialCart: cart.toQuantities(),
        initialAddress: s.defaultAddress(s.current!.id)?.addressLine ?? s.current!.address,
      )),
    ).then((placed) {
      if (placed == true && mounted) {
        // Order placed — pop back to orders
        Navigator.pop(context, true);
      }
    });
  }
}

class _CartLineCard extends StatelessWidget {
  final CartItem item;
  final bool saving;
  final ValueChanged<int> onQty;
  final VoidCallback onRemove;
  const _CartLineCard({
    required this.item,
    required this.saving,
    required this.onQty,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    // Check if food is still available
    FoodItem? food;
    try {
      food = s.food(item.foodId);
    } catch (_) {
      food = null;
    }
    final unavailable = food == null || food.removed || !food.available;

    return BrandedCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(FoodieitTheme.radiusSm),
            child: FoodImage(url: food?.imageUrl, width: 64, height: 64, radius: FoodieitTheme.radiusSm),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.foodName, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                Text('${money(item.unitPriceCents)} each', style: Theme.of(context).textTheme.bodySmall),
                if (unavailable)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text('Unavailable - remove this item', style: TextStyle(fontSize: 12, color: FoodieitTheme.danger, fontWeight: FontWeight.w600)),
                  ),
                Text(money(item.lineTotal), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: FoodieitTheme.primary)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            children: [
              QuantityStepper(quantity: item.quantity, onChanged: saving ? (_) {} : onQty, min: 0, compact: true),
              if (item.quantity > 0)
                TextButton(
                  onPressed: saving ? null : onRemove,
                  child: Text('Remove', style: TextStyle(fontSize: 11, color: FoodieitTheme.danger)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String label;
  final String value;
  const _PriceRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        ],
      );
}
