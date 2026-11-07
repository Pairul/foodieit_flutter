import 'dart:async';
import 'package:flutter/material.dart';
import '../models/entities.dart';
import '../services/app_scope.dart';
import '../services/app_store.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// Customer order tracking screen showing rider position on a stylised map.
///
/// Uses a custom-painted map (not Google Maps SDK) to avoid requiring API keys
/// for the demo. In production, replace _TrackingMapView with GoogleMap widget.
class CustomerTrackingScreen extends StatefulWidget {
  final String orderId;
  const CustomerTrackingScreen({super.key, required this.orderId});
  @override
  State<CustomerTrackingScreen> createState() => _CustomerTrackingScreenState();
}

class _CustomerTrackingScreenState extends State<CustomerTrackingScreen> {
  Timer? _refreshTimer;
  Timer? _simTimer;

  @override
  void initState() {
    super.initState();
    // Refresh every 3 seconds to pick up new location updates
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _simTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final order = store.order(widget.orderId);

    // Permission check: only the order owner can track
    final user = store.current!;
    if (order.customerId != user.id) {
      return Scaffold(
        appBar: AppBar(title: const Text('Tracking')),
        body: const EmptyState('You can only track your own orders.', icon: Icons.lock),
      );
    }

    // Stop tracking if order is delivered or cancelled
    if (!order.status.trackingVisible) {
      return Scaffold(
        appBar: AppBar(title: const Text('Tracking')),
        body: PageBody(children: [
          BrandedCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Icon(order.status == OrderStatus.delivered
                    ? Icons.check_circle
                    : Icons.cancel,
                    size: 48,
                    color: order.status == OrderStatus.delivered
                        ? FoodieitTheme.success
                        : FoodieitTheme.danger),
                const SizedBox(height: 12),
                Text(order.status == OrderStatus.delivered
                    ? 'Order delivered'
                    : 'Order cancelled',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text('Live tracking is no longer available for this order.',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ]),
      );
    }

    final restaurant = store.restaurant(order.restaurantId);
    final location = store.getRiderLocationForOrder(widget.orderId);
    final route = store.getRiderRouteForOrder(widget.orderId);
    final isStale = location?.isStale() ?? false;

    // Calculate ETA
    String etaText;
    if (location == null) {
      etaText = 'Waiting for rider location...';
    } else if (isStale) {
      etaText = 'Location update delayed';
    } else {
      final remaining = location.point.distanceKmTo(
          order.deliveryPoint ?? restaurant.location ?? const GeoPoint(0, 0));
      final etaMin = (remaining / 0.3).round(); // ~18 km/h average
      etaText = 'ETA ~${etaMin} min (${remaining.toStringAsFixed(1)} km)';
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Track your order'),
        actions: [
          if (location != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isStale ? FoodieitTheme.dangerBg : FoodieitTheme.successBg,
                    borderRadius: BorderRadius.circular(FoodieitTheme.radiusXs),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(isStale ? Icons.warning : Icons.gps_fixed,
                          size: 14,
                          color: isStale ? FoodieitTheme.danger : FoodieitTheme.success),
                      const SizedBox(width: 4),
                      Text(isStale ? 'STALE' : 'LIVE',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
                              color: isStale ? FoodieitTheme.danger : FoodieitTheme.success)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Map view
          Expanded(
            flex: 3,
            child: _TrackingMapView(
              restaurantPoint: restaurant.location ?? const GeoPoint(3.2150, 101.7300),
              deliveryPoint: order.deliveryPoint ?? const GeoPoint(3.1700, 101.6700),
              riderPoint: location?.point,
              route: route.map((r) => r.point).toList(),
              isStale: isStale,
            ),
          ),
          // Info panel
          Expanded(
            flex: 2,
            child: PageBody(
              padding: const EdgeInsets.all(16),
              children: [
                // ETA card
                BrandedCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isStale ? FoodieitTheme.dangerBg : FoodieitTheme.primaryLight,
                          borderRadius: BorderRadius.circular(FoodieitTheme.radiusSm),
                        ),
                        child: Icon(
                          isStale ? Icons.warning_amber : Icons.delivery_dining,
                          size: 28,
                          color: isStale ? FoodieitTheme.danger : FoodieitTheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(etaText, style: Theme.of(context).textTheme.titleMedium),
                            if (location != null)
                              Text('Last updated: ${location.timestamp.toLocal().toString().substring(11, 19)}',
                                  style: Theme.of(context).textTheme.bodySmall),
                            if (location?.simulated == true)
                              Text('SIMULATED TRACKING MODE',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: FoodieitTheme.warning)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Order info
                BrandedCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Order #${order.id}', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      InfoRow(icon: Icons.storefront, label: 'From', value: restaurant.name),
                      InfoRow(icon: Icons.location_on_outlined, label: 'To', value: order.address),
                      if (order.riderId != null) ...[
                        InfoRow(icon: Icons.delivery_dining, label: 'Rider', value: store.user(order.riderId!).name),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          StatusBadge(order.status),
                          const Spacer(),
                          Text(money(order.totalCents), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: FoodieitTheme.primary)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Stale warning
                if (isStale)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: FoodieitTheme.warningBg,
                      borderRadius: BorderRadius.circular(FoodieitTheme.radiusSm),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning, size: 16, color: FoodieitTheme.warning),
                        const SizedBox(width: 8),
                        Expanded(child: Text(
                          'The rider\'s location has not updated recently. This may be due to poor connectivity or GPS being disabled. The last known position is shown.',
                          style: TextStyle(fontSize: 12, color: FoodieitTheme.warning, fontWeight: FontWeight.w600),
                        )),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Stylised map view with custom painting.
/// Shows restaurant, delivery point, rider position, and route trail.
/// In production, replace with GoogleMap from google_maps_flutter package.
class _TrackingMapView extends StatelessWidget {
  final GeoPoint restaurantPoint;
  final GeoPoint deliveryPoint;
  final GeoPoint? riderPoint;
  final List<GeoPoint> route;
  final bool isStale;

  const _TrackingMapView({
    required this.restaurantPoint,
    required this.deliveryPoint,
    this.riderPoint,
    required this.route,
    required this.isStale,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE8EAED), // map background
      child: CustomPaint(
        size: Size.infinite,
        painter: _MapPainter(
          restaurantPoint: restaurantPoint,
          deliveryPoint: deliveryPoint,
          riderPoint: riderPoint,
          route: route,
          isStale: isStale,
        ),
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  final GeoPoint restaurantPoint;
  final GeoPoint deliveryPoint;
  final GeoPoint? riderPoint;
  final List<GeoPoint> route;
  final bool isStale;

  _MapPainter({
    required this.restaurantPoint,
    required this.deliveryPoint,
    this.riderPoint,
    required this.route,
    required this.isStale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Calculate bounds from all points
    final allPoints = [restaurantPoint, deliveryPoint, ...route, if (riderPoint != null) riderPoint!];
    final minLat = allPoints.map((p) => p.lat).reduce((a, b) => a < b ? a : b);
    final maxLat = allPoints.map((p) => p.lat).reduce((a, b) => a > b ? a : b);
    final minLng = allPoints.map((p) => p.lng).reduce((a, b) => a < b ? a : b);
    final maxLng = allPoints.map((p) => p.lng).reduce((a, b) => a > b ? a : b);

    // Add padding to bounds
    final latPad = (maxLat - minLat) * 0.2 + 0.001;
    final lngPad = (maxLng - minLng) * 0.2 + 0.001;
    final bMinLat = minLat - latPad, bMaxLat = maxLat + latPad;
    final bMinLng = minLng - lngPad, bMaxLng = maxLng + lngPad;

    // Project lat/lng to canvas coordinates
    Offset project(GeoPoint p) {
      final x = (p.lng - bMinLng) / (bMaxLng - bMinLng) * size.width;
      final y = size.height - (p.lat - bMinLat) / (bMaxLat - bMinLat) * size.height;
      return Offset(x, y);
    }

    // Draw grid lines (streets)
    final gridPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2;
    for (int i = 0; i <= 8; i++) {
      final x = size.width * i / 8;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
      final y = size.height * i / 8;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Draw route trail
    if (route.isNotEmpty) {
      final routePaint = Paint()
        ..color = FoodieitTheme.primary.withValues(alpha: 0.4)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;
      for (int i = 0; i < route.length - 1; i++) {
        canvas.drawLine(project(route[i]), project(route[i + 1]), routePaint);
      }
    }

    // Draw line from restaurant to delivery (direct)
    final linePaint = Paint()
      ..color = FoodieitTheme.divider
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(project(restaurantPoint), project(deliveryPoint), linePaint);

    // Draw restaurant marker (blue)
    _drawMarker(canvas, project(restaurantPoint), Colors.blue, Icons.storefront);

    // Draw delivery marker (green)
    _drawMarker(canvas, project(deliveryPoint), FoodieitTheme.success, Icons.home);

    // Draw rider marker (orange)
    if (riderPoint != null) {
      final riderColor = isStale ? FoodieitTheme.textSecondary : FoodieitTheme.primary;
      _drawRiderMarker(canvas, project(riderPoint!), riderColor, isStale);
    }
  }

  void _drawMarker(Canvas canvas, Offset pos, Color color, IconData icon) {
    // Circle
    canvas.drawCircle(pos, 14, Paint()..color = color);
    canvas.drawCircle(pos, 14, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 3);
  }

  void _drawRiderMarker(Canvas canvas, Offset pos, Color color, bool stale) {
    // Larger circle for rider
    canvas.drawCircle(pos, 18, Paint()..color = color);
    canvas.drawCircle(pos, 18, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 3);
    // Pulse ring if not stale
    if (!stale) {
      canvas.drawCircle(pos, 28, Paint()..color = color.withValues(alpha: 0.2)..style = PaintingStyle.stroke..strokeWidth = 2);
    }
  }

  @override
  bool shouldRepaint(covariant _MapPainter old) => true;
}

// ═════════════════════════════════════════════════════════════════════════
// RIDER ACTIVE DELIVERY SCREEN
// ═════════════════════════════════════════════════════════════════════════

/// Rider active delivery screen with tracking controls and earnings.
class RiderDeliveryScreen extends StatefulWidget {
  const RiderDeliveryScreen({super.key});
  @override
  State<RiderDeliveryScreen> createState() => _RiderDeliveryScreenState();
}

class _RiderDeliveryScreenState extends State<RiderDeliveryScreen> {
  Timer? _simTimer;

  @override
  void dispose() {
    _simTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final rider = store.current!;

    if (rider.role != Role.rider) {
      return Scaffold(
        appBar: AppBar(title: const Text('Deliveries')),
        body: const EmptyState('Rider access only.', icon: Icons.lock),
      );
    }

    // Check approval status
    if (rider.riderApprovalStatus != RiderApprovalStatus.approved) {
      return Scaffold(
        appBar: AppBar(title: const Text('Deliveries')),
        body: PageBody(children: [
          BrandedCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Icon(Icons.pending_actions, size: 48, color: FoodieitTheme.warning),
                const SizedBox(height: 12),
                Text('Approval Required', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text('Your rider application status: ${rider.riderApprovalStatus.label}',
                    style: Theme.of(context).textTheme.bodyMedium),
                if (rider.rejectionReason != null) ...[
                  const SizedBox(height: 8),
                  Text('Reason: ${rider.rejectionReason}',
                      style: TextStyle(color: FoodieitTheme.danger, fontWeight: FontWeight.w600)),
                ],
                const SizedBox(height: 16),
                if (rider.riderApprovalStatus == RiderApprovalStatus.rejected)
                  FilledButton(
                    onPressed: () => store.resubmitRiderApplication(),
                    child: const Text('Resubmit application'),
                  ),
              ],
            ),
          ),
        ]),
      );
    }

    // Check expired documents
    final expiredDocs = store.expiredOrExpiringDocuments(rider.id);
    if (expiredDocs.isNotEmpty) {
      // Show warning but still allow current delivery if in progress
      final hasActive = store.ordersForRider(rider.id).any((o) =>
          o.status == OrderStatus.assigned || o.status == OrderStatus.pickedUp);
      if (!hasActive) {
        return Scaffold(
          appBar: AppBar(title: const Text('Deliveries')),
          body: PageBody(children: [
            BrandedCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(Icons.warning, size: 48, color: FoodieitTheme.danger),
                  const SizedBox(height: 12),
                  Text('Document Action Required', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text('Some of your documents have expired or are expiring soon. '
                      'You cannot accept new delivery jobs until they are updated.',
                      style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  for (final d in expiredDocs)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Icon(d.isExpired ? Icons.error : Icons.warning, size: 16,
                              color: d.isExpired ? FoodieitTheme.danger : FoodieitTheme.warning),
                          const SizedBox(width: 8),
                          Expanded(child: Text('${d.type.label} ${d.isExpired ? '(expired)' : '(expiring soon)'}',
                              style: Theme.of(context).textTheme.bodySmall)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ]),
        );
      }
    }

    // Get rider's active and available orders
    final activeOrders = store.orders.where((o) =>
        o.riderId == rider.id && (o.status == OrderStatus.assigned || o.status == OrderStatus.pickedUp)).toList();
    final availableOrders = store.orders.where((o) =>
        [OrderStatus.placed, OrderStatus.updated].contains(o.status) && o.riderId == null).toList();
    final completedDeliveries = store.ordersForRider(rider.id)
        .where((o) => o.status == OrderStatus.delivered).toList();
    final totalEarnings = completedDeliveries.fold<int>(0, (s, o) =>
        s + (o.financials?.riderPayoutCents ?? 0));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Deliveries'),
        actions: [
          // Simulated tracking toggle
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: GestureDetector(
                onTap: () => store.toggleSimulatedTracking(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: store.simulatedTrackingEnabled ? FoodieitTheme.warningBg : FoodieitTheme.divider,
                    borderRadius: BorderRadius.circular(FoodieitTheme.radiusXs),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.science_outlined, size: 14,
                          color: store.simulatedTrackingEnabled ? FoodieitTheme.warning : FoodieitTheme.textHint),
                      const SizedBox(width: 4),
                      Text('SIM', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
                          color: store.simulatedTrackingEnabled ? FoodieitTheme.warning : FoodieitTheme.textHint)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: PageBody(
        children: [
          // Earnings summary
          BrandedCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: FoodieitTheme.successBg,
                    borderRadius: BorderRadius.circular(FoodieitTheme.radiusSm),
                  ),
                  child: const Icon(Icons.payments, size: 24, color: FoodieitTheme.success),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Total earnings', style: Theme.of(context).textTheme.bodySmall),
                      Text(money(totalEarnings), style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: FoodieitTheme.success)),
                      Text('${completedDeliveries.length} completed deliveries', style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Active delivery
          if (activeOrders.isNotEmpty) ...[
            SectionHeader('Active delivery'),
            for (final o in activeOrders) ...[
              _ActiveDeliveryCard(
                order: o,
                store: store,
                onSimulate: () {
                  if (o.status == OrderStatus.pickedUp) {
                    store.generateSimulatedLocation(o.id);
                    setState(() {});
                  }
                },
                onStatusChange: () => setState(() {}),
              ),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 16),
          ],

          // Available orders
          SectionHeader('Available deliveries', subtitle: '${availableOrders.length} orders waiting'),
          if (availableOrders.isEmpty)
            const EmptyState('No deliveries available right now.', icon: Icons.inbox_outlined),
          for (final o in availableOrders) ...[
            _AvailableOrderCard(order: o, store: store),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _ActiveDeliveryCard extends StatelessWidget {
  final FoodOrder order;
  final AppStore store;
  final VoidCallback onSimulate;
  final VoidCallback onStatusChange;

  const _ActiveDeliveryCard({
    required this.order,
    required this.store,
    required this.onSimulate,
    required this.onStatusChange,
  });

  @override
  Widget build(BuildContext context) {
    final restaurant = store.restaurant(order.restaurantId);
    final customer = store.user(order.customerId);
    final payout = order.financials?.riderPayoutCents ?? 0;

    return BrandedCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('#${order.id}', style: Theme.of(context).textTheme.titleLarge)),
              StatusBadge(order.status),
            ],
          ),
          const SizedBox(height: 12),
          InfoRow(icon: Icons.storefront, label: 'Pickup', value: restaurant.name),
          InfoRow(icon: Icons.location_on_outlined, label: 'Drop-off', value: order.address),
          InfoRow(icon: Icons.person, label: 'Customer', value: customer.name),
          InfoRow(icon: Icons.payments, label: 'Your earnings', value: money(payout)),
          if (order.financials != null)
            InfoRow(icon: Icons.route, label: 'Distance', value: '${order.financials!.distanceKm.toStringAsFixed(1)} km'),
          const SizedBox(height: 16),

          // Actions based on status
          if (order.status == OrderStatus.assigned)
            FilledButton.icon(
              onPressed: () {
                perform(context, () => store.deliveryStatus(order.id, OrderStatus.pickedUp));
                onStatusChange();
              },
              icon: const Icon(Icons.shopping_bag),
              label: const Text('Mark picked up'),
            ),
          if (order.status == OrderStatus.pickedUp) ...[
            // Tracking controls
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: FoodieitTheme.infoBg,
                borderRadius: BorderRadius.circular(FoodieitTheme.radiusSm),
              ),
              child: Row(
                children: [
                  Icon(Icons.gps_fixed, size: 16, color: FoodieitTheme.info),
                  const SizedBox(width: 8),
                  Expanded(child: Text('GPS tracking is active. Customer can see your location.',
                      style: TextStyle(fontSize: 12, color: FoodieitTheme.info, fontWeight: FontWeight.w600))),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (store.simulatedTrackingEnabled)
              OutlinedButton.icon(
                onPressed: onSimulate,
                icon: const Icon(Icons.my_location),
                label: const Text('Send simulated location'),
              ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () {
                perform(context, () => store.deliveryStatus(order.id, OrderStatus.delivered));
                onStatusChange();
              },
              icon: const Icon(Icons.check_circle),
              label: const Text('Mark delivered'),
            ),
          ],
        ],
      ),
    );
  }
}

class _AvailableOrderCard extends StatelessWidget {
  final FoodOrder order;
  final AppStore store;
  const _AvailableOrderCard({required this.order, required this.store});

  @override
  Widget build(BuildContext context) {
    final restaurant = store.restaurant(order.restaurantId);
    final rider = store.current!;
    final payout = order.financials?.riderPayoutCents ?? 0;
    final distance = order.financials?.distanceKm ?? 0.0;

    // Check if rider can accept
    final canAccept = store.riderCanAcceptJobs(rider.id);

    return BrandedCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('#${order.id}', style: Theme.of(context).textTheme.titleMedium)),
              Text(money(order.totalCents), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: FoodieitTheme.primary)),
            ],
          ),
          const SizedBox(height: 8),
          InfoRow(icon: Icons.storefront, label: 'Restaurant', value: restaurant.name),
          InfoRow(icon: Icons.location_on_outlined, label: 'Deliver to', value: order.address),
          if (distance > 0) InfoRow(icon: Icons.route, label: 'Distance', value: '${distance.toStringAsFixed(1)} km'),
          if (payout > 0)
            InfoRow(icon: Icons.payments, label: 'Earnings', value: money(payout)),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: canAccept
                ? () => perform(context, () => store.assignRider(order.id, rider.id))
                : null,
            child: Text(canAccept ? 'Accept delivery' : 'Cannot accept (check approval/documents)'),
          ),
        ],
      ),
    );
  }
}
