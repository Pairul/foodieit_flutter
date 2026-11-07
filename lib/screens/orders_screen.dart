import 'package:flutter/material.dart';
import '../models/entities.dart';
import '../services/app_scope.dart';
import '../services/app_store.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'checkout_screen.dart';
import 'reviews_screen.dart';
import 'tracking_screen.dart';
import 'mfa_screen.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});
  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  String filter = 'all';

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final u = s.current!;

    final allRows = s.orders.where((o) {
      if (u.role == Role.admin) return true;
      if (u.role == Role.customer) return o.customerId == u.id;
      if (u.role == Role.rider) return o.riderId == u.id || [OrderStatus.placed, OrderStatus.updated].contains(o.status);
      return false;
    }).toList();

    final rows = filter == 'all'
        ? allRows
        : allRows.where((o) {
            if (filter == 'active') return o.status.active;
            if (filter == 'draft') return o.status == OrderStatus.draft;
            if (filter == 'delivered') return o.status == OrderStatus.delivered;
            if (filter == 'cancelled') return o.status == OrderStatus.cancelled;
            return true;
          }).toList();

    final title = u.role == Role.customer
        ? 'My orders'
        : u.role == Role.rider
            ? 'Available & my deliveries'
            : 'All orders & deliveries';

    final filters = u.role == Role.customer
        ? const [('all', 'All'), ('active', 'Active'), ('draft', 'Drafts'), ('delivered', 'Delivered'), ('cancelled', 'Cancelled')]
        : const [('all', 'All'), ('active', 'Active'), ('delivered', 'Delivered'), ('cancelled', 'Cancelled')];

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          // MFA quick access for all roles
          IconButton(
            onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const MfaManagementScreen())),
            icon: Icon(
              u.mfa.enrolled ? Icons.verified_user : Icons.shield_outlined,
              color: u.mfa.enrolled ? FoodieitTheme.success : FoodieitTheme.textSecondary,
              size: 22,
            ),
            tooltip: 'Security & MFA',
          ),
        ],
      ),
      body: PageBody(
        children: [
          // Status filter chips
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final f in filters)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(f.$2),
                      selected: filter == f.$1,
                      onSelected: (_) => setState(() => filter = f.$1),
                      selectedColor: FoodieitTheme.primary,
                      labelStyle: TextStyle(
                        color: filter == f.$1 ? Colors.white : FoodieitTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      side: BorderSide.none,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(FoodieitTheme.radiusXs)),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          if (rows.isEmpty)
            EmptyState(
              u.role == Role.customer
                  ? 'No orders yet. Browse restaurants to start ordering!'
                  : 'No orders found.',
              icon: Icons.receipt_long_outlined,
            ),

          for (final o in rows) ...[
            _OrderCard(order: o, store: s),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final FoodOrder order;
  final AppStore store;
  const _OrderCard({required this.order, required this.store});

  @override
  Widget build(BuildContext context) {
    final s = store;
    final u = s.current!;
    final o = order;
    return BrandedCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Expanded(child: Text('#${o.id}', style: Theme.of(context).textTheme.titleLarge)),
              StatusBadge(o.status),
            ],
          ),
          const SizedBox(height: 6),
          Text(s.restaurant(o.restaurantId).name, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
          Text(money(o.totalCents), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: FoodieitTheme.primary)),
          Text('${o.createdAt.toLocal().toString().substring(0, 16)} - revision ${o.revision}', style: Theme.of(context).textTheme.bodySmall),

          // Financials summary
          if (o.financials != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.route, size: 14, color: FoodieitTheme.textSecondary),
                const SizedBox(width: 4),
                Text('${o.financials!.distanceKm.toStringAsFixed(1)} km', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(width: 12),
                Icon(Icons.delivery_dining, size: 14, color: FoodieitTheme.textSecondary),
                const SizedBox(width: 4),
                Text('Fee: ${money(o.financials!.deliveryFeeCents)}', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ],

          // Details expansion
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Order details'),
            children: [
              for (final line in o.lines)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text('${line.quantity} x ${line.name}'),
                  trailing: Text(money(line.total)),
                ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.location_on_outlined, size: 20),
                title: Text(o.address, style: Theme.of(context).textTheme.bodySmall),
              ),
              if (u.role != Role.customer)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Customer: ${s.user(o.customerId).name}'),
                  subtitle: Text(s.user(o.customerId).phone),
                ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(o.riderId == null ? 'No rider assigned' : 'Rider: ${s.user(o.riderId!).name}'),
              ),
              // Full financial breakdown
              if (o.financials != null) ...[
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Financial Breakdown', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _FinRow('Food subtotal', money(o.financials!.foodSubtotalCents)),
                      _FinRow('Delivery fee', money(o.financials!.deliveryFeeCents)),
                      _FinRow('Total paid', money(o.financials!.totalCents)),
                      if (u.role == Role.admin || u.role == Role.rider) ...[
                        const SizedBox(height: 4),
                        _FinRow('Commission (${o.financials!.commissionRatePercent}%)', money(o.financials!.commissionCents)),
                        _FinRow('Restaurant net', money(o.financials!.restaurantNetCents)),
                        _FinRow('Rider payout', money(o.financials!.riderPayoutCents)),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),

          // Actions
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // Customer: Track order
              if (u.role == Role.customer && o.status.trackingVisible)
                FilledButton.icon(
                  onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => CustomerTrackingScreen(orderId: o.id))),
                  icon: const Icon(Icons.my_location),
                  label: const Text('Track rider'),
                ),
              if (u.role == Role.customer && o.status.editable)
                OutlinedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<bool>(builder: (_) => CheckoutScreen(
                      restaurantId: o.restaurantId,
                      initialCart: {for (final l in o.lines) l.foodId: l.quantity},
                      orderId: o.id,
                      revision: o.revision,
                      initialAddress: o.address,
                      initialDeliveryPoint: o.deliveryPoint,
                    )),
                  ),
                  child: Text(o.status == OrderStatus.draft ? 'Edit / place draft' : 'Edit order'),
                ),
              if (u.role == Role.customer && o.status == OrderStatus.draft)
                TextButton(
                  onPressed: () async {
                    if (await confirmAction(context, 'Delete this draft?') && context.mounted) {
                      perform(context, () => s.deleteDraft(o.id));
                    }
                  },
                  child: Text('Delete draft', style: TextStyle(color: FoodieitTheme.danger)),
                ),
              if ((u.role == Role.customer && [OrderStatus.placed, OrderStatus.updated].contains(o.status)) ||
                  (u.role == Role.admin && o.status.active))
                TextButton(
                  onPressed: () async {
                    if (await confirmAction(context, 'Cancel this order?') && context.mounted) {
                      perform(context, () => s.cancelOrder(o.id));
                    }
                  },
                  child: Text('Cancel order', style: TextStyle(color: FoodieitTheme.danger)),
                ),
              if (u.role == Role.admin && [OrderStatus.placed, OrderStatus.updated].contains(o.status))
                FilledButton.tonal(onPressed: () => _assignRider(context, s, o), child: const Text('Assign rider')),
              if (u.role == Role.rider && [OrderStatus.placed, OrderStatus.updated].contains(o.status))
                FilledButton(onPressed: () => perform(context, () => s.assignRider(o.id, u.id)), child: const Text('Accept delivery')),
              if ((u.role == Role.admin || (u.role == Role.rider && o.riderId == u.id)) && o.status == OrderStatus.assigned)
                FilledButton(onPressed: () => perform(context, () => s.deliveryStatus(o.id, OrderStatus.pickedUp)), child: const Text('Mark picked up')),
              if ((u.role == Role.admin || (u.role == Role.rider && o.riderId == u.id)) && o.status == OrderStatus.pickedUp)
                FilledButton(onPressed: () => perform(context, () => s.deliveryStatus(o.id, OrderStatus.delivered)), child: const Text('Mark delivered')),
              if (u.role == Role.customer && o.status == OrderStatus.delivered)
                FilledButton.tonal(onPressed: () => reviewEditor(context, o), child: Text(s.reviewFor(o.id) == null ? 'Write review' : 'Edit review')),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _assignRider(BuildContext context, AppStore s, FoodOrder o) async {
    final riders = s.users.where((u) => u.role == Role.rider && u.active && s.riderCanAcceptJobs(u.id)).toList();
    final id = await showDialog<String>(
      context: context,
      builder: (c) => SimpleDialog(
        title: const Text('Assign rider'),
        children: [
          if (riders.isEmpty)
            const Padding(padding: EdgeInsets.all(24), child: Text('No approved riders with valid documents available.')),
          for (final r in riders)
            SimpleDialogOption(onPressed: () => Navigator.pop(c, r.id), child: Text('${r.name} - ${r.phone}')),
        ],
      ),
    );
    if (id != null && context.mounted) perform(context, () => s.assignRider(o.id, id));
  }
}

class _FinRow extends StatelessWidget {
  final String label;
  final String value;
  const _FinRow(this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 2),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12)),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    ),
  );
}
