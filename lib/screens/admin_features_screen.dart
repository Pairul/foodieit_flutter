import 'package:flutter/material.dart';
import '../models/entities.dart';
import '../services/app_scope.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// Rider application form with document uploads and approval status.
class RiderApplicationScreen extends StatefulWidget {
  const RiderApplicationScreen({super.key});
  @override
  State<RiderApplicationScreen> createState() => _RiderApplicationScreenState();
}

class _RiderApplicationScreenState extends State<RiderApplicationScreen> {
  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final rider = store.current!;

    if (rider.role != Role.rider) {
      return Scaffold(
        appBar: AppBar(title: const Text('Rider Application')),
        body: const EmptyState('Rider access only.', icon: Icons.lock),
      );
    }

    final docs = store.documentsFor(rider.id);
    final expiredDocs = store.expiredOrExpiringDocuments(rider.id);

    return Scaffold(
      appBar: AppBar(title: const Text('My Application')),
      body: PageBody(
        children: [
          // Approval status banner
          BrandedCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _statusColor(rider.riderApprovalStatus).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(FoodieitTheme.radiusSm),
                      ),
                      child: Icon(
                        _statusIcon(rider.riderApprovalStatus),
                        size: 28,
                        color: _statusColor(rider.riderApprovalStatus),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Application Status', style: Theme.of(context).textTheme.bodySmall),
                          Text(rider.riderApprovalStatus.label,
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                                  color: _statusColor(rider.riderApprovalStatus))),
                        ],
                      ),
                    ),
                  ],
                ),
                if (rider.rejectionReason != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: FoodieitTheme.dangerBg,
                      borderRadius: BorderRadius.circular(FoodieitTheme.radiusSm),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.error_outline, size: 16, color: FoodieitTheme.danger),
                        const SizedBox(width: 8),
                        Expanded(child: Text(
                          rider.riderApprovalStatus == RiderApprovalStatus.rejected
                              ? 'Rejected: ${rider.rejectionReason}'
                              : 'Suspended: ${rider.rejectionReason}',
                          style: TextStyle(fontSize: 12, color: FoodieitTheme.danger, fontWeight: FontWeight.w600),
                        )),
                      ],
                    ),
                  ),
                ],
                if (rider.riderApprovalStatus == RiderApprovalStatus.rejected) ...[
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () {
                      store.resubmitRiderApplication();
                      showFeedback(context, 'Application resubmitted');
                    },
                    child: const Text('Resubmit application'),
                  ),
                ],
                if (rider.riderApprovalStatus == RiderApprovalStatus.pending)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text('Your application is under review. You can update your documents below.',
                        style: Theme.of(context).textTheme.bodySmall),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Vehicle info
          SectionHeader('Vehicle Information'),
          BrandedCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (rider.vehicleInfo != null) ...[
                  InfoRow(icon: Icons.motorcycle, label: 'Registration', value: rider.vehicleInfo!.registrationNumber),
                  InfoRow(icon: Icons.directions_bike, label: 'Make', value: rider.vehicleInfo!.make),
                  InfoRow(icon: Icons.model_training, label: 'Model', value: rider.vehicleInfo!.model),
                  InfoRow(icon: Icons.palette, label: 'Color', value: rider.vehicleInfo!.color),
                ] else
                  Text('No vehicle information provided.', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _editVehicleInfo(context, rider),
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit vehicle info'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Documents
          SectionHeader('Documents', subtitle: 'Required: licence, registration, insurance'),
          if (expiredDocs.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: FoodieitTheme.dangerBg,
                borderRadius: BorderRadius.circular(FoodieitTheme.radiusSm),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, size: 16, color: FoodieitTheme.danger),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    '${expiredDocs.length} document(s) expired or expiring. Update them to continue accepting jobs.',
                    style: TextStyle(fontSize: 12, color: FoodieitTheme.danger, fontWeight: FontWeight.w600),
                  )),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Document list by type
          for (final type in DocumentType.values) ...[
            _DocumentSection(
              type: type,
              documents: docs.where((d) => d.type == type).toList(),
              riderId: rider.id,
            ),
            const SizedBox(height: 12),
          ],

          // Privacy notice
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: FoodieitTheme.infoBg,
              borderRadius: BorderRadius.circular(FoodieitTheme.radiusSm),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.privacy_tip, size: 16, color: FoodieitTheme.info),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  'Your documents are stored privately. Only you and authorised administrators can access them. '
                  'Customers never see verification documents.',
                  style: TextStyle(fontSize: 11, color: FoodieitTheme.info, fontWeight: FontWeight.w600),
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(RiderApprovalStatus s) => switch (s) {
    RiderApprovalStatus.pending => FoodieitTheme.warning,
    RiderApprovalStatus.approved => FoodieitTheme.success,
    RiderApprovalStatus.rejected => FoodieitTheme.danger,
    RiderApprovalStatus.suspended => FoodieitTheme.danger,
  };

  IconData _statusIcon(RiderApprovalStatus s) => switch (s) {
    RiderApprovalStatus.pending => Icons.hourglass_top,
    RiderApprovalStatus.approved => Icons.verified,
    RiderApprovalStatus.rejected => Icons.cancel,
    RiderApprovalStatus.suspended => Icons.block,
  };

  void _editVehicleInfo(BuildContext context, AppUser rider) {
    editForm(
      context,
      title: 'Edit vehicle info',
      fields: [
        FieldSpec('regNumber', 'Registration number', value: rider.vehicleInfo?.registrationNumber ?? ''),
        FieldSpec('make', 'Make', value: rider.vehicleInfo?.make ?? ''),
        FieldSpec('model', 'Model', value: rider.vehicleInfo?.model ?? ''),
        FieldSpec('color', 'Color', value: rider.vehicleInfo?.color ?? ''),
      ],
      save: (d) {
        rider.vehicleInfo = VehicleInfo(
          registrationNumber: d['regNumber']!,
          make: d['make']!,
          model: d['model']!,
          color: d['color']!,
        );
      },
    );
  }
}

class _DocumentSection extends StatelessWidget {
  final DocumentType type;
  final List<RiderDocument> documents;
  final String riderId;
  const _DocumentSection({required this.type, required this.documents, required this.riderId});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final hasDoc = documents.isNotEmpty;
    final hasExpired = documents.any((d) => d.isExpired);

    return BrandedCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(type.icon, size: 20, color: FoodieitTheme.primary),
              const SizedBox(width: 8),
              Expanded(child: Text(type.label, style: Theme.of(context).textTheme.titleMedium)),
              if (hasDoc && !hasExpired)
                Icon(Icons.check_circle, size: 18, color: FoodieitTheme.success)
              else if (hasExpired)
                Icon(Icons.error, size: 18, color: FoodieitTheme.danger)
              else
                Icon(Icons.upload_file, size: 18, color: FoodieitTheme.textHint),
            ],
          ),
          if (hasDoc) ...[
            const SizedBox(height: 8),
            for (final doc in documents) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(Icons.description, size: 16, color: FoodieitTheme.textSecondary),
                    const SizedBox(width: 8),
                    Expanded(child: Text(doc.fileName, style: Theme.of(context).textTheme.bodySmall)),
                    if (doc.expiryDate != null) ...[
                      Text(
                        doc.isExpired ? 'Expired ${doc.expiryDate!.toLocal().toString().substring(0, 10)}'
                            : 'Expires ${doc.expiryDate!.toLocal().toString().substring(0, 10)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: doc.isExpired ? FoodieitTheme.danger :
                                 doc.isExpiringSoon ? FoodieitTheme.warning : FoodieitTheme.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () {
                        final url = store.getDocumentAccessUrl(doc.id);
                        if (url != null) {
                          showFeedback(context, 'Generating temporary access link...');
                        }
                      },
                      child: const Text('View'),
                    ),
                    TextButton(
                      onPressed: () async {
                        if (await confirmAction(context, 'Remove ${doc.fileName}?') && context.mounted) {
                          perform(context, () => store.removeDocument(doc.id));
                        }
                      },
                      child: Text('Remove', style: TextStyle(color: FoodieitTheme.danger)),
                    ),
                  ],
                ),
              ),
            ],
          ],
          const SizedBox(height: 8),
          // Upload button
          OutlinedButton.icon(
            onPressed: () => _uploadDocument(context, type),
            icon: const Icon(Icons.upload, size: 18),
            label: Text(hasDoc ? 'Replace ${type.label}' : 'Upload ${type.label}'),
          ),
        ],
      ),
    );
  }

  void _uploadDocument(BuildContext context, DocumentType type) {
    final store = AppScope.of(context);
    // Simulated upload — in production this opens a file picker, uploads to Firebase Storage
    final needsExpiry = type == DocumentType.license || type == DocumentType.insurance;
    editForm(
      context,
      title: 'Upload ${type.label}',
      fields: [
        FieldSpec('fileName', 'File name (e.g. license.pdf)'),
        if (needsExpiry)
          FieldSpec('expiry', 'Expiry date (YYYY-MM-DD)', optional: true),
      ],
      save: (d) {
        final fileName = d['fileName']!;
        DateTime? expiry;
        if (needsExpiry && d['expiry'] != null && d['expiry']!.isNotEmpty) {
          expiry = DateTime.tryParse(d['expiry']!);
        }
        // In production: upload to Firebase Storage path: riders/{riderId}/{type}/{fileName}
        store.uploadDocument(
          riderId: riderId,
          type: type,
          fileName: fileName,
          storagePath: 'riders/$riderId/${type.name}/$fileName',
          expiryDate: expiry,
        );
      },
      saveLabel: 'Upload',
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════
// ADMIN RIDER REVIEW SCREEN
// ═════════════════════════════════════════════════════════════════════════

/// Admin screen for reviewing rider applications and managing approval status.
class AdminRiderReviewScreen extends StatefulWidget {
  const AdminRiderReviewScreen({super.key});
  @override
  State<AdminRiderReviewScreen> createState() => _AdminRiderReviewScreenState();
}

class _AdminRiderReviewScreenState extends State<AdminRiderReviewScreen> {
  String filter = 'all';

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final riders = store.users.where((u) => u.role == Role.rider).toList();
    final filtered = filter == 'all'
        ? riders
        : riders.where((r) => r.riderApprovalStatus.name == filter).toList();

    return PageBody(
      children: [
        SectionHeader('Rider Applications',
            subtitle: '${riders.length} riders - ${riders.where((r) => r.riderApprovalStatus == RiderApprovalStatus.pending).length} pending'),
        const SizedBox(height: 12),

        // Filter chips
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final f in const [
                ('all', 'All'),
                ('pending', 'Pending'),
                ('approved', 'Approved'),
                ('rejected', 'Rejected'),
                ('suspended', 'Suspended'),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(f.$2),
                    selected: filter == f.$1,
                    onSelected: (_) => setState(() => filter = f.$1),
                    selectedColor: FoodieitTheme.primary,
                    labelStyle: TextStyle(color: filter == f.$1 ? Colors.white : FoodieitTheme.textSecondary,
                        fontWeight: FontWeight.w600),
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(FoodieitTheme.radiusXs)),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        if (filtered.isEmpty)
          const EmptyState('No riders in this category.', icon: Icons.delivery_dining_outlined),

        for (final r in filtered) ...[
          _RiderReviewCard(riderId: r.id),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _RiderReviewCard extends StatelessWidget {
  final String riderId;
  const _RiderReviewCard({required this.riderId});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final rider = store.user(riderId);
    final docs = store.documentsFor(riderId);
    final auditLog = store.auditLog.where((a) => a.riderId == riderId).toList();

    return BrandedCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: FoodieitTheme.primaryLight,
                child: Text(rider.name.isNotEmpty ? rider.name[0].toUpperCase() : '?',
                    style: const TextStyle(color: FoodieitTheme.primary, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(rider.name, style: Theme.of(context).textTheme.titleMedium),
                    Text(rider.email, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusBg(rider.riderApprovalStatus),
                  borderRadius: BorderRadius.circular(FoodieitTheme.radiusXs),
                ),
                child: Text(rider.riderApprovalStatus.label,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _statusFg(rider.riderApprovalStatus))),
              ),
            ],
          ),
          const SizedBox(height: 10),
          InfoRow(icon: Icons.phone, label: 'Phone', value: rider.phone),
          if (rider.vehicleInfo != null) ...[
            InfoRow(icon: Icons.motorcycle, label: 'Vehicle', value: '${rider.vehicleInfo!.make} ${rider.vehicleInfo!.model}'),
            InfoRow(icon: Icons.numbers, label: 'Reg. No.', value: rider.vehicleInfo!.registrationNumber),
          ],

          // Document status
          const SizedBox(height: 10),
          Text('Documents (${docs.length})', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          for (final type in [DocumentType.license, DocumentType.vehicleRegistration, DocumentType.insurance, DocumentType.profilePhoto])
            _DocumentStatusRow(type: type, docs: docs),

          // View documents
          if (docs.isNotEmpty) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => _showDocuments(context, docs),
              child: const Text('View uploaded documents'),
            ),
          ],

          // Audit log
          if (auditLog.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('Audit History', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            for (final entry in auditLog.take(3))
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  '${entry.timestamp.toLocal().toString().substring(0, 16)} - ${entry.action}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],

          // Actions
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (rider.riderApprovalStatus == RiderApprovalStatus.pending)
                FilledButton.icon(
                  onPressed: () => _approve(context, riderId),
                  icon: const Icon(Icons.check),
                  label: const Text('Approve'),
                ),
              if (rider.riderApprovalStatus == RiderApprovalStatus.pending)
                OutlinedButton.icon(
                  onPressed: () => _reject(context, riderId),
                  icon: Icon(Icons.close, color: FoodieitTheme.danger),
                  label: Text('Reject', style: TextStyle(color: FoodieitTheme.danger)),
                ),
              if (rider.riderApprovalStatus == RiderApprovalStatus.rejected)
                OutlinedButton.icon(
                  onPressed: () => _showResubmitInfo(context),
                  icon: const Icon(Icons.info),
                  label: const Text('Awaiting resubmission'),
                ),
              if (rider.riderApprovalStatus == RiderApprovalStatus.approved)
                OutlinedButton.icon(
                  onPressed: () => _suspend(context, riderId),
                  icon: Icon(Icons.block, color: FoodieitTheme.danger),
                  label: Text('Suspend', style: TextStyle(color: FoodieitTheme.danger)),
                ),
              if (rider.riderApprovalStatus == RiderApprovalStatus.suspended)
                FilledButton.icon(
                  onPressed: () {
                    perform(context, () => store.reinstateRider(riderId));
                  },
                  icon: const Icon(Icons.restore),
                  label: const Text('Reinstate'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Color _statusBg(RiderApprovalStatus s) => switch (s) {
    RiderApprovalStatus.pending => FoodieitTheme.warningBg,
    RiderApprovalStatus.approved => FoodieitTheme.successBg,
    RiderApprovalStatus.rejected => FoodieitTheme.dangerBg,
    RiderApprovalStatus.suspended => FoodieitTheme.dangerBg,
  };

  Color _statusFg(RiderApprovalStatus s) => switch (s) {
    RiderApprovalStatus.pending => FoodieitTheme.warning,
    RiderApprovalStatus.approved => FoodieitTheme.success,
    RiderApprovalStatus.rejected => FoodieitTheme.danger,
    RiderApprovalStatus.suspended => FoodieitTheme.danger,
  };

  void _approve(BuildContext context, String riderId) {
    final store = AppScope.of(context);
    try {
      store.approveRider(riderId);
      showFeedback(context, 'Rider approved');
    } catch (e) {
      showFeedback(context, e is StateError ? e.message.toString() : 'Unable to approve.', isError: true);
    }
  }

  void _reject(BuildContext context, String riderId) {
    editForm(
      context,
      title: 'Reject rider application',
      fields: [FieldSpec('reason', 'Reason for rejection')],
      save: (d) {
        AppScope.of(context).rejectRider(riderId, d['reason']!);
      },
      saveLabel: 'Reject',
    );
  }

  void _suspend(BuildContext context, String riderId) {
    editForm(
      context,
      title: 'Suspend rider',
      fields: [FieldSpec('reason', 'Reason for suspension')],
      save: (d) {
        AppScope.of(context).suspendRider(riderId, d['reason']!);
      },
      saveLabel: 'Suspend',
    );
  }

  void _showDocuments(BuildContext context, List<RiderDocument> docs) {
    final store = AppScope.of(context);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rider Documents'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final doc in docs)
                  ListTile(
                    leading: Icon(doc.type.icon, color: FoodieitTheme.primary),
                    title: Text(doc.fileName),
                    subtitle: Text('${doc.type.label} - uploaded ${doc.uploadedAt.toLocal().toString().substring(0, 10)}'),
                    trailing: doc.isExpired
                        ? Text('Expired', style: TextStyle(color: FoodieitTheme.danger, fontSize: 11, fontWeight: FontWeight.w600))
                        : Icon(Icons.check_circle, color: FoodieitTheme.success, size: 18),
                    onTap: () {
                      store.getDocumentAccessUrl(doc.id);
                      showFeedback(context, 'Generating private access link...');
                    },
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  void _showResubmitInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rejected rider'),
        content: const Text('This rider has been rejected. They can correct their information and resubmit their application from their rider app.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════
// ADMIN DELIVERY PRICING SETTINGS
// ═════════════════════════════════════════════════════════════════════════

class AdminPricingScreen extends StatefulWidget {
  const AdminPricingScreen({super.key});
  @override
  State<AdminPricingScreen> createState() => _AdminPricingScreenState();
}

class _AdminPricingScreenState extends State<AdminPricingScreen> {
  late TextEditingController baseFee;
  late TextEditingController perKm;
  late TextEditingController minFee;
  late TextEditingController maxRange;
  late TextEditingController rounding;
  late TextEditingController riderBase;
  late TextEditingController riderPerKm;
  late TextEditingController riderPct;
  late TextEditingController commissionRate;

  @override
  void initState() {
    super.initState();
    final store = AppScope.of(context);
    final p = store.deliveryPricing;
    final c = store.commissionConfig;
    baseFee = TextEditingController(text: (p.baseFeeCents / 100).toStringAsFixed(2));
    perKm = TextEditingController(text: (p.perKmRateCents / 100).toStringAsFixed(2));
    minFee = TextEditingController(text: (p.minFeeCents / 100).toStringAsFixed(2));
    maxRange = TextEditingController(text: p.maxServiceRangeKm.toStringAsFixed(1));
    rounding = TextEditingController(text: (p.roundingUnitCents / 100).toStringAsFixed(2));
    riderBase = TextEditingController(text: (p.riderPayoutBaseCents / 100).toStringAsFixed(2));
    riderPerKm = TextEditingController(text: (p.riderPayoutPerKmCents / 100).toStringAsFixed(2));
    riderPct = TextEditingController(text: (p.riderPayoutPercentage * 100).toStringAsFixed(0));
    commissionRate = TextEditingController(text: c.commissionRatePercent.toStringAsFixed(1));
  }

  @override
  void dispose() {
    baseFee.dispose(); perKm.dispose(); minFee.dispose(); maxRange.dispose();
    rounding.dispose(); riderBase.dispose(); riderPerKm.dispose(); riderPct.dispose();
    commissionRate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageBody(
      children: [
        SectionHeader('Delivery Pricing', subtitle: 'Configure distance-based delivery fees'),
        const SizedBox(height: 12),
        BrandedCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Customer Delivery Fee', style: Theme.of(context).textTheme.titleMedium),
              Text('fee = max(min, base + per_km x distance)', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: TextField(controller: baseFee, decoration: const InputDecoration(labelText: 'Base fee (RM)'), keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: perKm, decoration: const InputDecoration(labelText: 'Rate per km (RM)'), keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: TextField(controller: minFee, decoration: const InputDecoration(labelText: 'Min fee (RM)'), keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: maxRange, decoration: const InputDecoration(labelText: 'Max range (km)'), keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                ],
              ),
              const SizedBox(height: 12),
              TextField(controller: rounding, decoration: const InputDecoration(labelText: 'Rounding unit (RM, e.g. 0.10)'), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
            ],
          ),
        ),
        const SizedBox(height: 16),

        BrandedCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Rider Payout', style: Theme.of(context).textTheme.titleMedium),
              Text('payout = max(base + per_km x distance, fee x percentage)', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: TextField(controller: riderBase, decoration: const InputDecoration(labelText: 'Base payout (RM)'), keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: riderPerKm, decoration: const InputDecoration(labelText: 'Per km (RM)'), keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                ],
              ),
              const SizedBox(height: 12),
              TextField(controller: riderPct, decoration: const InputDecoration(labelText: 'Percentage of delivery fee (%)'), keyboardType: TextInputType.number),
            ],
          ),
        ),
        const SizedBox(height: 16),

        BrandedCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Restaurant Commission', style: Theme.of(context).textTheme.titleMedium),
              Text('Charged on food subtotal only (excludes delivery fee and taxes)', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 16),
              TextField(controller: commissionRate, decoration: const InputDecoration(labelText: 'Commission rate (%)'), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
            ],
          ),
        ),
        const SizedBox(height: 20),

        FilledButton(
          onPressed: () => _save(context),
          child: const Text('Save settings'),
        ),
      ],
    );
  }

  void _save(BuildContext context) {
    final store = AppScope.of(context);
    try {
      final p = DeliveryPricingConfig(
        baseFeeCents: (double.parse(baseFee.text) * 100).round(),
        perKmRateCents: (double.parse(perKm.text) * 100).round(),
        minFeeCents: (double.parse(minFee.text) * 100).round(),
        maxServiceRangeKm: double.parse(maxRange.text),
        roundingUnitCents: (double.parse(rounding.text) * 100).round(),
        riderPayoutBaseCents: (double.parse(riderBase.text) * 100).round(),
        riderPayoutPerKmCents: (double.parse(riderPerKm.text) * 100).round(),
        riderPayoutPercentage: double.parse(riderPct.text) / 100,
      );
      final c = CommissionConfig(
        commissionRatePercent: double.parse(commissionRate.text),
        discountsReduceBase: true,
      );
      store.updateDeliveryPricing(p);
      store.updateCommissionConfig(c);
      showFeedback(context, 'Pricing settings saved');
    } catch (e) {
      showFeedback(context, 'Invalid values. Please check your input.', isError: true);
    }
  }
}

// ═════════════════════════════════════════════════════════════════════════
// ADMIN COMMISSION REPORTS
// ═════════════════════════════════════════════════════════════════════════

class AdminCommissionScreen extends StatelessWidget {
  const AdminCommissionScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final summary = store.commissionSummary;

    return PageBody(
      children: [
        SectionHeader('Commission Reports', subtitle: 'Platform earnings from completed orders'),
        const SizedBox(height: 12),

        // Summary cards
        LayoutBuilder(builder: (context, constraints) {
          final crossCount = constraints.maxWidth > 700 ? 3 : 2;
          final spacing = 12.0;
          final cardWidth = (constraints.maxWidth - spacing * (crossCount - 1)) / crossCount;
          final stats = [
            ('Completed orders', '${summary.completedOrderCount}', Icons.check_circle, FoodieitTheme.success),
            ('Food subtotal', money(summary.totalFoodSubtotalCents), Icons.restaurant, FoodieitTheme.primary),
            ('Commission earned', money(summary.totalCommissionCents), Icons.percent, FoodieitTheme.success),
            ('Delivery fees', money(summary.totalDeliveryFeesCents), Icons.delivery_dining, FoodieitTheme.info),
            ('Rider payouts', money(summary.totalRiderPayoutsCents), Icons.payments, FoodieitTheme.warning),
            ('Platform net', money(summary.platformNetCents), Icons.account_balance, FoodieitTheme.success),
          ];
          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              for (final stat in stats)
                SizedBox(width: cardWidth, child: StatCard(label: stat.$1, value: stat.$2, icon: stat.$3, color: stat.$4)),
            ],
          );
        }),
        const SizedBox(height: 24),

        // Per-restaurant settlements
        SectionHeader('Restaurant Settlements', subtitle: 'Per-vendor commission breakdown'),
        for (final r in store.restaurants) ...[
          _SettlementCard(restaurantId: r.id),
          const SizedBox(height: 10),
        ],

        const SizedBox(height: 16),
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
              Expanded(child: Text(
                'Commission is recognized only for delivered orders. Cancelled orders do not generate commission. '
                'Payments are simulated until a payment provider is integrated.',
                style: TextStyle(fontSize: 12, color: FoodieitTheme.warning, fontWeight: FontWeight.w600),
              )),
            ],
          ),
        ),
      ],
    );
  }
}

class _DocumentStatusRow extends StatelessWidget {
  final DocumentType type;
  final List<RiderDocument> docs;
  const _DocumentStatusRow({required this.type, required this.docs});

  @override
  Widget build(BuildContext context) {
    final typeDocs = docs.where((d) => d.type == type).toList();
    final hasDoc = typeDocs.isNotEmpty;
    final hasExpired = typeDocs.any((d) => d.isExpired);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(type.icon, size: 16, color: FoodieitTheme.textSecondary),
          const SizedBox(width: 8),
          Expanded(child: Text(type.label, style: Theme.of(context).textTheme.bodySmall)),
          if (hasDoc && !hasExpired)
            Icon(Icons.check_circle, size: 16, color: FoodieitTheme.success)
          else if (hasExpired)
            Icon(Icons.error, size: 16, color: FoodieitTheme.danger)
          else
            Text('Missing', style: TextStyle(fontSize: 11, color: FoodieitTheme.warning, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _SettlementCard extends StatelessWidget {
  final String restaurantId;
  const _SettlementCard({required this.restaurantId});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final r = store.restaurant(restaurantId);
    final settlement = store.restaurantSettlement(restaurantId);

    return BrandedCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(r.name, style: Theme.of(context).textTheme.titleMedium)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: r.commissionAccepted ? FoodieitTheme.successBg : FoodieitTheme.warningBg,
                  borderRadius: BorderRadius.circular(FoodieitTheme.radiusXs),
                ),
                child: Text(
                  r.commissionAccepted ? '${settlement.commissionRatePercent.toStringAsFixed(0)}% accepted' : 'Not accepted',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                      color: r.commissionAccepted ? FoodieitTheme.success : FoodieitTheme.warning),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          InfoRow(icon: Icons.receipt_long, label: 'Completed orders', value: '${settlement.completedOrders}'),
          InfoRow(icon: Icons.restaurant, label: 'Food subtotal', value: money(settlement.foodSubtotalCents)),
          InfoRow(icon: Icons.percent, label: 'Commission (${settlement.commissionRatePercent.toStringAsFixed(0)}%)', value: money(settlement.commissionCents)),
          InfoRow(icon: Icons.account_balance_wallet, label: 'Net earnings', value: money(settlement.netEarningsCents)),
          if (!r.commissionAccepted) ...[
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: () {
                perform(context, () => store.acceptCommissionTerms(r.id));
              },
              child: const Text('Accept commission terms'),
            ),
          ],
        ],
      ),
    );
  }
}
