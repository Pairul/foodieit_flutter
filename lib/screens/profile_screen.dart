import 'package:flutter/material.dart';
import '../models/entities.dart';
import '../services/app_scope.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'mfa_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final u = store.current!;
    final orderCount = store.orders.where((o) => o.customerId == u.id).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: PageBody(
        children: [
          // Profile header card
          BrandedCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: FoodieitTheme.primary,
                  child: Text(u.name.isNotEmpty ? u.name[0].toUpperCase() : '?',
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white)),
                ),
                const SizedBox(height: 14),
                Text(u.name, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: u.role == Role.admin ? FoodieitTheme.infoBg : FoodieitTheme.primaryLight,
                    borderRadius: BorderRadius.circular(FoodieitTheme.radiusXs),
                  ),
                  child: Text(u.role.name.toUpperCase(),
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: u.role == Role.admin ? FoodieitTheme.info : FoodieitTheme.primary)),
                ),
                const SizedBox(height: 8),
                Text(u.email, style: Theme.of(context).textTheme.bodySmall),
                // Rider approval badge
                if (u.role == Role.rider) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: u.riderApprovalStatus == RiderApprovalStatus.approved
                          ? FoodieitTheme.successBg
                          : u.riderApprovalStatus == RiderApprovalStatus.pending
                              ? FoodieitTheme.warningBg
                              : FoodieitTheme.dangerBg,
                      borderRadius: BorderRadius.circular(FoodieitTheme.radiusXs),
                    ),
                    child: Text(u.riderApprovalStatus.label.toUpperCase(),
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: u.riderApprovalStatus == RiderApprovalStatus.approved
                                ? FoodieitTheme.success
                                : u.riderApprovalStatus == RiderApprovalStatus.pending
                                    ? FoodieitTheme.warning
                                    : FoodieitTheme.danger)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Quick stats
          if (u.role == Role.customer)
            Row(
              children: [
                Expanded(child: StatCard(label: 'Orders', value: '$orderCount', icon: Icons.receipt_long)),
                const SizedBox(width: 12),
                Expanded(child: StatCard(label: 'Reviews', value: '${store.reviews.where((r) => r.customerId == u.id).length}', icon: Icons.star, color: FoodieitTheme.warning)),
              ],
            ),
          if (u.role == Role.rider)
            Row(
              children: [
                Expanded(child: StatCard(label: 'Deliveries', value: '${store.ordersForRider(u.id).where((o) => o.status == OrderStatus.delivered).length}', icon: Icons.delivery_dining)),
                const SizedBox(width: 12),
                Expanded(child: StatCard(label: 'Earnings', value: money(store.ordersForRider(u.id).where((o) => o.status == OrderStatus.delivered).fold<int>(0, (s, o) => s + (o.financials?.riderPayoutCents ?? 0))), icon: Icons.payments, color: FoodieitTheme.success)),
              ],
            ),
          if (u.role == Role.customer || u.role == Role.rider) const SizedBox(height: 16),

          // Personal details
          SectionHeader('Personal details'),
          BrandedCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                InfoRow(icon: Icons.phone_outlined, label: 'Phone', value: u.phone),
                InfoRow(icon: Icons.location_on_outlined, label: 'Address', value: u.address.isEmpty ? 'Not set' : u.address),
                InfoRow(icon: Icons.email_outlined, label: 'Email', value: u.email),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => editForm(
              context,
              title: 'Edit profile & address',
              fields: [
                FieldSpec('name', 'Name', value: u.name),
                FieldSpec('phone', 'Phone', value: u.phone, keyboard: TextInputType.phone),
                FieldSpec('address', 'Address', value: u.address, optional: true, maxLines: 2),
              ],
              save: (d) => store.editProfile(d['name']!, d['phone']!, d['address']!),
            ),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit profile'),
          ),
          const SizedBox(height: 24),

          // Security & MFA section
          SectionHeader('Security'),
          BrandedCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(u.mfa.enrolled ? Icons.verified_user : Icons.shield_outlined,
                        size: 20,
                        color: u.mfa.enrolled ? FoodieitTheme.success : FoodieitTheme.warning),
                    const SizedBox(width: 8),
                    Expanded(child: Text(u.mfa.enrolled ? 'MFA enabled' : 'MFA not enabled',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
                  ],
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const MfaManagementScreen())),
                  icon: const Icon(Icons.security),
                  label: const Text('Manage MFA'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Account section
          SectionHeader('Account'),
          BrandedCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Demo data is held in memory. Switching accounts keeps changes until the app restarts.',
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: store.logout,
                  icon: const Icon(Icons.logout),
                  label: const Text('Sign out'),
                ),
                if (u.role != Role.admin) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () async {
                      final confirmed = await confirmAction(context, 'Deactivate your account? This cannot be undone.');
                      if (!confirmed || !context.mounted) return;
                      editForm(
                        context,
                        title: 'Deactivate your account',
                        fields: const [FieldSpec('password', 'Confirm password', secret: true)],
                        save: (d) => store.deactivateSelf(d['password']!),
                        saveLabel: 'Deactivate',
                      );
                    },
                    icon: Icon(Icons.person_off_outlined, color: FoodieitTheme.danger),
                    label: Text('Deactivate account', style: TextStyle(color: FoodieitTheme.danger)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
