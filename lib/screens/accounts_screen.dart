import 'package:flutter/material.dart';
import '../models/entities.dart';
import '../services/app_scope.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});
  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  String search = '';
  String filter = 'all';

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final allCustomers = s.users.where((u) => u.role == Role.customer).toList();
    final filtered = allCustomers.where((u) {
      if (filter == 'active' && !u.active) return false;
      if (filter == 'inactive' && u.active) return false;
      if (search.isNotEmpty && !'${u.name} ${u.email}'.toLowerCase().contains(search.toLowerCase())) return false;
      return true;
    }).toList();

    return PageBody(
      children: [
        SectionHeader('Customers & accounts',
            subtitle: '${allCustomers.length} customers - ${allCustomers.where((c) => c.active).length} active'),
        const SizedBox(height: 12),
        SearchField(hint: 'Search customers by name or email', onChanged: (v) => setState(() => search = v)),
        const SizedBox(height: 10),
        // Filter chips
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final f in const [('all', 'All'), ('active', 'Active'), ('inactive', 'Inactive')])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(f.$2),
                    selected: filter == f.$1,
                    onSelected: (_) => setState(() => filter = f.$1),
                    selectedColor: FoodieitTheme.primary,
                    labelStyle: TextStyle(color: filter == f.$1 ? Colors.white : FoodieitTheme.textSecondary, fontWeight: FontWeight.w600),
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(FoodieitTheme.radiusXs)),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        if (filtered.isEmpty) const EmptyState('No customers found.', icon: Icons.person_search_outlined),

        for (final u in filtered) ...[
          BrandedCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: FoodieitTheme.primaryLight,
                      child: Text(u.name.isNotEmpty ? u.name[0].toUpperCase() : '?',
                          style: const TextStyle(color: FoodieitTheme.primary, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(u.name, style: Theme.of(context).textTheme.titleMedium)),
                    StatusBadge(
                      u.active ? OrderStatus.delivered : OrderStatus.cancelled,
                      compact: true,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                InfoRow(icon: Icons.email_outlined, label: 'Email', value: u.email),
                InfoRow(icon: Icons.phone_outlined, label: 'Phone', value: u.phone),
                InfoRow(icon: Icons.location_on_outlined, label: 'Address', value: u.address.isEmpty ? 'Not set' : u.address),
                InfoRow(icon: Icons.receipt_long, label: 'Orders', value: '${s.orders.where((o) => o.customerId == u.id).length}'),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () async {
                    if (await confirmAction(context, '${u.active ? 'Deactivate' : 'Reactivate'} ${u.name}?') && context.mounted) {
                      perform(context, () => s.adminSetActive(u.id, !u.active));
                    }
                  },
                  child: Text(u.active ? 'Deactivate account' : 'Reactivate account',
                      style: TextStyle(color: u.active ? FoodieitTheme.danger : FoodieitTheme.success)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}
