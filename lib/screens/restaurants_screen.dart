import 'package:flutter/material.dart';
import '../models/entities.dart';
import '../services/app_scope.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'menu_screen.dart';

class RestaurantsScreen extends StatefulWidget {
  const RestaurantsScreen({super.key});
  @override
  State<RestaurantsScreen> createState() => _RestaurantsScreenState();
}

class _RestaurantsScreenState extends State<RestaurantsScreen> {
  String search = '';

  void edit(Restaurant? r) {
    final s = AppScope.of(context);
    editForm(
      context,
      title: r == null ? 'Add restaurant' : 'Edit restaurant',
      fields: [
        FieldSpec('name', 'Restaurant name', value: r?.name ?? ''),
        FieldSpec('cuisine', 'Cuisine', value: r?.cuisine ?? ''),
        FieldSpec('address', 'Address', value: r?.address ?? '', maxLines: 2),
        FieldSpec('hours', 'Hours (HH:mm-HH:mm)', value: r?.hours ?? '09:00-22:00'),
        FieldSpec('lat', 'Latitude (e.g. 3.2150)', value: r?.location?.lat.toStringAsFixed(4) ?? '', optional: true, keyboard: const TextInputType.numberWithOptions(decimal: true)),
        FieldSpec('lng', 'Longitude (e.g. 101.7300)', value: r?.location?.lng.toStringAsFixed(4) ?? '', optional: true, keyboard: const TextInputType.numberWithOptions(decimal: true)),
        FieldSpec('range', 'Service range km (blank=default)', value: r?.serviceRangeKm?.toStringAsFixed(1) ?? '', optional: true, keyboard: const TextInputType.numberWithOptions(decimal: true)),
      ],
      save: (d) => s.saveRestaurant(
        id: r?.id,
        name: d['name']!,
        cuisine: d['cuisine']!,
        address: d['address']!,
        hours: d['hours']!,
        lat: double.tryParse(d['lat'] ?? ''),
        lng: double.tryParse(d['lng'] ?? ''),
        serviceRangeKm: double.tryParse(d['range'] ?? ''),
      ),
      saveLabel: r == null ? 'Add restaurant' : 'Save changes',
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final admin = s.current!.role == Role.admin;
    final rows = s.restaurants
        .where((r) => (admin || r.active) && '${r.name} ${r.cuisine}'.toLowerCase().contains(search.toLowerCase()))
        .toList();

    return PageBody(children: [
      if (!admin) ...[
        const PromoBanner(
          title: 'Fresh picks. Big flavour.',
          subtitle: 'What are you craving today?',
          icon: Icons.restaurant_menu,
        ),
        const SizedBox(height: 18),
      ],
      SearchField(hint: 'Search restaurants or cuisines', onChanged: (v) => setState(() => search = v)),
      const SizedBox(height: 16),

      if (admin)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Align(alignment: Alignment.centerLeft, child: FilledButton.icon(onPressed: () => edit(null), icon: const Icon(Icons.add), label: const Text('Add restaurant'))),
        ),

      if (rows.isEmpty) const EmptyState('No restaurants found.', icon: Icons.storefront_outlined),

      for (final r in rows) ...[
        BrandedCard(
          onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => MenuScreen(restaurantId: r.id))),
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FoodImage(url: r.imageUrl, height: 130, width: double.infinity, radius: FoodieitTheme.radiusMd, fallbackIcon: Icons.storefront),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(r.name, style: Theme.of(context).textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis)),
                        if (admin)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: r.active ? FoodieitTheme.successBg : FoodieitTheme.dangerBg,
                              borderRadius: BorderRadius.circular(FoodieitTheme.radiusXs),
                            ),
                            child: Text(r.active ? 'Active' : 'Inactive', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: r.active ? FoodieitTheme.success : FoodieitTheme.danger)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(r.cuisine, style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.star, size: 14, color: FoodieitTheme.warning),
                        const SizedBox(width: 3),
                        Text(s.average(r.id)?.toStringAsFixed(1) ?? 'New', style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(width: 10),
                        Icon(Icons.access_time, size: 12, color: FoodieitTheme.textHint),
                        const SizedBox(width: 3),
                        Text(r.hours, style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(width: 10),
                        Icon(Icons.delivery_dining, size: 12, color: FoodieitTheme.textHint),
                        const SizedBox(width: 3),
                        Text('${(r.serviceRangeKm ?? s.deliveryPricing.maxServiceRangeKm).toStringAsFixed(0)} km', style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(r.address, style: Theme.of(context).textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (admin) ...[
                      const SizedBox(height: 10),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        OutlinedButton(onPressed: () => edit(r), child: const Text('Edit details')),
                        TextButton(
                          onPressed: () async {
                            if (await confirmAction(context, '${r.active ? 'Deactivate' : 'Reactivate'} ${r.name}?') && context.mounted) {
                              perform(context, () => s.setRestaurantActive(r.id, !r.active));
                            }
                          },
                          child: Text(r.active ? 'Deactivate' : 'Reactivate', style: TextStyle(color: r.active ? FoodieitTheme.danger : FoodieitTheme.success)),
                        ),
                        if (!r.commissionAccepted)
                          TextButton(
                            onPressed: () => perform(context, () => s.acceptCommissionTerms(r.id)),
                            child: Text('Accept 10% commission', style: TextStyle(color: FoodieitTheme.info)),
                          ),
                      ]),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
    ]);
  }
}
