import 'package:flutter/material.dart';
import '../models/entities.dart';
import '../services/app_scope.dart';
import '../services/app_store.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class CheckoutScreen extends StatefulWidget {
  final String restaurantId;
  final Map<String, int> initialCart;
  final String? orderId;
  final int? revision;
  final String? initialAddress;
  final GeoPoint? initialDeliveryPoint;
  const CheckoutScreen({
    super.key,
    required this.restaurantId,
    required this.initialCart,
    this.orderId,
    this.revision,
    this.initialAddress,
    this.initialDeliveryPoint,
  });
  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  late final Map<String, int> cart;
  final address = TextEditingController();
  bool initialized = false, saving = false;
  DeliveryQuote? quote;
  String? quoteError;
  bool quoteCalculating = false;

  // Simulated delivery coordinates (in production, from address geocoding or map pin)
  GeoPoint? _deliveryPoint;

  @override
  void initState() {
    super.initState();
    cart = Map.of(widget.initialCart);
    _deliveryPoint = widget.initialDeliveryPoint;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!initialized) {
      address.text = widget.initialAddress ?? AppScope.of(context).current?.address ?? '';
      initialized = true;
      _calculateQuote();
    }
  }

  @override
  void dispose() {
    address.dispose();
    super.dispose();
  }

  void _calculateQuote() {
    final store = AppScope.of(context);
    final r = store.restaurant(widget.restaurantId);
    if (r.location == null || cart.isEmpty) {
      setState(() {
        quote = null;
        quoteError = null;
      });
      return;
    }

    if (_deliveryPoint == null) {
      _deliveryPoint = GeoPoint(
        r.location!.lat - 0.03,
        r.location!.lng - 0.04,
      );
    }

    setState(() {
      quoteCalculating = true;
      quoteError = null;
    });

    try {
      final q = store.calculateDeliveryQuote(widget.restaurantId, _deliveryPoint!);
      setState(() {
        quote = q;
        quoteCalculating = false;
      });
    } catch (e) {
      setState(() {
        quote = null;
        quoteError = e is StateError ? e.message.toString() : 'Unable to calculate delivery.';
        quoteCalculating = false;
      });
    }
  }

  /// Revalidate prices from the backend before placing the order.
  /// Returns true if validation passes.
  bool _revalidatePrices() {
    final store = AppScope.of(context);
    try {
      // This call re-fetches current prices and availability from the store.
      // If any item is unavailable or the restaurant is inactive, it throws.
      store.revalidateCart(widget.restaurantId, Map.of(cart));
      return true;
    } catch (e) {
      if (mounted) {
        showFeedback(context, e is StateError ? e.message.toString() : 'Unable to validate cart.', isError: true);
      }
      return false;
    }
  }

  void _placeOrder() {
    if (saving) return; // Prevent double-tap

    // Validate address
    if (address.text.trim().isEmpty) {
      showFeedback(context, 'Please enter a delivery address.', isError: true);
      return;
    }

    // Validate cart
    if (cart.isEmpty) {
      showFeedback(context, 'Your cart is empty.', isError: true);
      return;
    }

    // Check quote error
    if (quoteError != null) {
      showFeedback(context, quoteError!, isError: true);
      return;
    }

    setState(() => saving = true);

    // Revalidate prices from backend
    if (!_revalidatePrices()) {
      setState(() => saving = false);
      return;
    }

    // Generate idempotency key from current timestamp + customer ID
    final store = AppScope.of(context);
    final idempotencyKey = '${store.current!.id}_${DateTime.now().millisecondsSinceEpoch}';

    try {
      final order = store.placeOrder(
        restaurantId: widget.restaurantId,
        quantities: Map.of(cart),
        address: address.text,
        deliveryPoint: _deliveryPoint,
        idempotencyKey: idempotencyKey,
      );

      if (mounted) {
        // Navigate to confirmation screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute<void>(builder: (_) => OrderConfirmationScreen(orderId: order.id)),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => saving = false);
        showFeedback(context, e is StateError ? e.message.toString() : 'Unable to place order.', isError: true);
      }
    }
  }

  void _saveDraft() {
    if (saving) return;
    setState(() => saving = true);
    try {
      AppScope.of(context).saveOrder(
        id: widget.orderId,
        revision: widget.revision,
        restaurantId: widget.restaurantId,
        quantities: Map.of(cart),
        address: address.text,
        deliveryPoint: null,
        draft: true,
      );
      if (mounted) {
        showFeedback(context, 'Draft saved');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => saving = false);
        showFeedback(context, e is StateError ? e.message.toString() : 'Unable to save draft.', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final r = s.restaurant(widget.restaurantId);
    final subtotal = cart.entries.fold<int>(0, (sum, e) => sum + s.food(e.key).priceCents * e.value);
    final deliveryFee = quote?.deliveryFeeCents ?? 0;
    final total = subtotal + deliveryFee;
    final commission = s.calculateCommission(subtotal);
    final existing = widget.orderId == null ? null : s.order(widget.orderId!);
    final allFoods = s.foods.where((f) => f.restaurantId == widget.restaurantId && f.available && !f.removed).toList();

    return Scaffold(
      appBar: AppBar(title: Text(existing == null ? 'Checkout' : 'Edit ${existing.id}')),
      body: PageBody(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          // Restaurant header
          BrandedCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                FoodImage(url: r.imageUrl, width: 56, height: 56, radius: FoodieitTheme.radiusSm, fallbackIcon: Icons.storefront),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(r.name, style: Theme.of(context).textTheme.titleMedium),
                  Text(r.cuisine, style: Theme.of(context).textTheme.bodySmall),
                ])),
              ],
            ),
          ),
          const SizedBox(height: 16),

          SectionHeader('Your items'),
          if (cart.isEmpty)
            const EmptyState('Your cart is empty. Go back to add food.', icon: Icons.shopping_cart_outlined),

          for (final entry in cart.entries.toList()) ...[
            _CartLineItem(
              name: s.food(entry.key).name,
              priceCents: s.food(entry.key).priceCents,
              quantity: entry.value,
              imageUrl: s.food(entry.key).imageUrl,
              unavailable: !s.food(entry.key).available || s.food(entry.key).removed,
              saving: saving,
              onQty: (qty) => setState(() {
                if (qty <= 0) {
                  cart.remove(entry.key);
                } else {
                  cart[entry.key] = qty;
                }
                _calculateQuote();
              }),
            ),
            const SizedBox(height: 8),
          ],

          // Add more items
          if (allFoods.any((f) => !cart.containsKey(f.id))) ...[
            const SizedBox(height: 4),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: FoodieitTheme.divider),
                borderRadius: BorderRadius.circular(FoodieitTheme.radiusSm),
              ),
              child: ExpansionTile(
                title: const Text('Add more items'),
                tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final f in allFoods.where((f) => !cart.containsKey(f.id)))
                    ListTile(
                      dense: true,
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(FoodieitTheme.radiusXs),
                        child: FoodImage(url: f.imageUrl, width: 40, height: 40, radius: FoodieitTheme.radiusXs),
                      ),
                      title: Text(f.name),
                      trailing: Text(money(f.priceCents), style: const TextStyle(fontWeight: FontWeight.w700, color: FoodieitTheme.primary)),
                      onTap: saving ? null : () => setState(() {
                        cart[f.id] = 1;
                        _calculateQuote();
                      }),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Delivery address
          SectionHeader('Delivery address'),
          Material(
            color: Colors.transparent,
            child: TextField(
              controller: address,
              maxLines: 3,
              maxLength: 500,
              decoration: const InputDecoration(labelText: 'Where should we deliver?'),
              onChanged: (_) => _calculateQuote(),
            ),
          ),
          const SizedBox(height: 8),

          // Simulated map pin note
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: FoodieitTheme.infoBg,
              borderRadius: BorderRadius.circular(FoodieitTheme.radiusXs),
            ),
            child: Row(
              children: [
                Icon(Icons.location_on, size: 16, color: FoodieitTheme.info),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  quote != null
                      ? 'Delivery pin: ${_deliveryPoint!.lat.toStringAsFixed(4)}, ${_deliveryPoint!.lng.toStringAsFixed(4)}'
                      : 'Delivery pin will be set from your address.',
                  style: TextStyle(fontSize: 11, color: FoodieitTheme.info, fontWeight: FontWeight.w600),
                )),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Distance & delivery fee breakdown
          if (quoteCalculating)
            const LoadingState('Calculating delivery fee...')
          else if (quoteError != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: FoodieitTheme.dangerBg,
                borderRadius: BorderRadius.circular(FoodieitTheme.radiusSm),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, size: 20, color: FoodieitTheme.danger),
                  const SizedBox(width: 8),
                  Expanded(child: Text(quoteError!, style: TextStyle(fontSize: 13, color: FoodieitTheme.danger, fontWeight: FontWeight.w600))),
                ],
              ),
            )
          else if (quote != null && cart.isNotEmpty) ...[
            BrandedCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Delivery & Pricing', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Distance', style: Theme.of(context).textTheme.bodyMedium),
                      Text('${quote!.distanceKm.toStringAsFixed(1)} km', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Base fee', style: Theme.of(context).textTheme.bodySmall),
                      Text(money(quote!.pricingConfig.baseFeeCents), style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Distance charge (${money(quote!.pricingConfig.perKmRateCents)}/km)', style: Theme.of(context).textTheme.bodySmall),
                      Text(money((quote!.distanceKm * quote!.pricingConfig.perKmRateCents).round()), style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Price breakdown
          BrandedCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _PriceRow(label: 'Food subtotal', value: money(subtotal)),
                const SizedBox(height: 8),
                _PriceRow(label: 'Delivery fee', value: quote != null ? money(deliveryFee) : 'Calculating...'),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total', style: Theme.of(context).textTheme.titleLarge),
                    Text(money(total), style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: FoodieitTheme.primary)),
                  ],
                ),
                const SizedBox(height: 4),
                Text('MYR - Simulated payment (no real charges)', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 8),
                // Commission breakdown (admin only info)
                if (s.current!.role == Role.admin) ...[
                  const Divider(),
                  _PriceRow(label: 'Commission (10% of food)', value: money(commission)),
                  _PriceRow(label: 'Restaurant net', value: money(subtotal - commission)),
                  _PriceRow(label: 'Rider payout', value: quote != null ? money(quote!.riderPayoutCents) : '-'),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Confirm pricing note
          if (quote != null && cart.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: FoodieitTheme.warningBg,
                borderRadius: BorderRadius.circular(FoodieitTheme.radiusXs),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lock, size: 14, color: FoodieitTheme.warning),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    'The confirmed distance, pricing, and amounts are saved with your order and will not change after acceptance.',
                    style: TextStyle(fontSize: 11, color: FoodieitTheme.warning, fontWeight: FontWeight.w600),
                  )),
                ],
              ),
            ),
          const SizedBox(height: 24),

          // Place order button (with idempotency protection)
          FilledButton(
            onPressed: saving || cart.isEmpty || quoteError != null ? null : _placeOrder,
            child: saving
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                        SizedBox(width: 12),
                        Text('Placing order...'),
                      ],
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Text(existing == null || existing.status == OrderStatus.draft ? 'Place order - ${money(total)}' : 'Save changes'),
                  ),
          ),
          if (existing == null || existing.status == OrderStatus.draft) ...[
            const SizedBox(height: 10),
            OutlinedButton(onPressed: saving || cart.isEmpty ? null : _saveDraft, child: const Text('Save as draft')),
          ],
        ],
      ),
    );
  }
}

/// Order confirmation screen shown after successful checkout.
class OrderConfirmationScreen extends StatelessWidget {
  final String orderId;
  const OrderConfirmationScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final o = s.order(orderId);
    final r = s.restaurant(o.restaurantId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Confirmed'),
        automaticallyImplyLeading: false,
      ),
      body: PageBody(
        children: [
          const SizedBox(height: 24),
          // Success icon
          Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: FoodieitTheme.successBg,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_circle, size: 64, color: FoodieitTheme.success),
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text('Order placed!', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text('Order #${o.id}', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: FoodieitTheme.textSecondary)),
          ),
          const SizedBox(height: 24),

          // Order details card
          BrandedCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    FoodImage(url: r.imageUrl, width: 48, height: 48, radius: FoodieitTheme.radiusSm, fallbackIcon: Icons.storefront),
                    const SizedBox(width: 12),
                    Expanded(child: Text(r.name, style: Theme.of(context).textTheme.titleMedium)),
                    StatusBadge(o.status, compact: true),
                  ],
                ),
                const Divider(height: 24),
                // Items
                for (final line in o.lines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${line.quantity} x ${line.name}'),
                        Text(money(line.total), style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                const Divider(height: 24),
                // Price breakdown
                if (o.financials != null) ...[
                  _PriceRow(label: 'Food subtotal', value: money(o.financials!.foodSubtotalCents)),
                  const SizedBox(height: 6),
                  _PriceRow(label: 'Delivery fee', value: money(o.financials!.deliveryFeeCents)),
                  const SizedBox(height: 6),
                  if (o.financials!.distanceKm > 0)
                    _PriceRow(label: 'Distance', value: '${o.financials!.distanceKm.toStringAsFixed(1)} km'),
                ] else ...[
                  _PriceRow(label: 'Food subtotal', value: money(o.foodSubtotalCents)),
                ],
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total paid', style: Theme.of(context).textTheme.titleMedium),
                    Text(money(o.totalCents), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: FoodieitTheme.primary)),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Simulated payment - no real charges', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Delivery info
          BrandedCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Delivery address', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(o.address),
                const SizedBox(height: 8),
                InfoRow(icon: Icons.delivery_dining, label: 'Estimated time', value: '25-35 min'),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Actions
          FilledButton(
            onPressed: () {
              // Navigate to orders tab
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text('View my orders'),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text('Back to home'),
          ),
        ],
      ),
    );
  }
}

class _CartLineItem extends StatelessWidget {
  final String name;
  final int priceCents;
  final int quantity;
  final String? imageUrl;
  final bool unavailable;
  final bool saving;
  final ValueChanged<int> onQty;
  const _CartLineItem({
    required this.name,
    required this.priceCents,
    required this.quantity,
    this.imageUrl,
    required this.unavailable,
    required this.saving,
    required this.onQty,
  });

  @override
  Widget build(BuildContext context) => BrandedCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(FoodieitTheme.radiusSm),
              child: FoodImage(url: imageUrl, width: 56, height: 56, radius: FoodieitTheme.radiusSm),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                  Text('${money(priceCents)} each', style: Theme.of(context).textTheme.bodySmall),
                  if (unavailable)
                    Text('Unavailable - remove this item', style: TextStyle(fontSize: 12, color: FoodieitTheme.danger, fontWeight: FontWeight.w600)),
                  Text(money(priceCents * quantity), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: FoodieitTheme.primary)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            QuantityStepper(quantity: quantity, onChanged: saving ? (_) {} : onQty, min: 0, compact: true),
          ],
        ),
      );
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
