import 'package:flutter/material.dart';
import '../models/entities.dart';
import '../services/app_scope.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'menu_screen.dart';

class CustomerSearchScreen extends StatefulWidget {
  const CustomerSearchScreen({super.key});
  @override
  State<CustomerSearchScreen> createState() => _CustomerSearchScreenState();
}

class _CustomerSearchScreenState extends State<CustomerSearchScreen> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final q = query.toLowerCase();

    final restaurants = s.restaurants.where((r) =>
        r.active && (q.isEmpty || '${r.name} ${r.cuisine}'.toLowerCase().contains(q))).toList();

    final foods = s.foods.where((f) =>
        !f.removed && f.available &&
        s.restaurant(f.restaurantId).active &&
        (q.isEmpty || '${f.name} ${f.description}'.toLowerCase().contains(q))).toList();

    return Scaffold(
      backgroundColor: FoodieitTheme.background,
      body: PageBody(
        children: [
          SearchField(hint: 'Search restaurants or dishes', onChanged: (v) => setState(() => query = v)),
        const SizedBox(height: 20),

        if (query.isEmpty) ...[
          SectionHeader('Popular searches'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
            'Nasi Lemak', 'Burger', 'Mee Goreng', 'Pizza', 'Tom Yum',
            'Waffle', 'Cheesecake', 'Thai Tea',
            ].map((t) => ActionChip(
              label: Text(t),
              onPressed: () => setState(() => query = t),
            )).toList(),
          ),
          const SizedBox(height: 20),
        ],

        if (restaurants.isNotEmpty) ...[
          SectionHeader('Restaurants (${restaurants.length})'),
          for (final r in restaurants) ...[
              BrandedCard(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute<void>(builder: (_) => MenuScreen(restaurantId: r.id))),
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    FoodImage(url: r.imageUrl, width: 64, height: 64, radius: FoodieitTheme.radiusSm),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.name, style: Theme.of(context).textTheme.titleMedium),
                          Text(r.cuisine, style: Theme.of(context).textTheme.bodySmall),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.star, size: 14, color: FoodieitTheme.warning),
                              const SizedBox(width: 2),
                              Text(s.average(r.id)?.toStringAsFixed(1) ?? 'New',
                                  style: Theme.of(context).textTheme.bodySmall),
                              const SizedBox(width: 8),
                              Icon(Icons.access_time, size: 12, color: FoodieitTheme.textHint),
                              const SizedBox(width: 2),
                              Text(r.hours, style: Theme.of(context).textTheme.bodySmall),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
        ],

        if (foods.isNotEmpty) ...[
          const SizedBox(height: 8),
          SectionHeader('Dishes (${foods.length})'),
          for (final f in foods) ...[
            BrandedCard(
              onTap: () => Navigator.push(context,
                  MaterialPageRoute<void>(builder: (_) => MenuScreen(restaurantId: f.restaurantId))),
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  FoodImage(url: f.imageUrl, width: 64, height: 64, radius: FoodieitTheme.radiusSm),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(f.name, style: Theme.of(context).textTheme.titleMedium),
                        Text(f.description, style: Theme.of(context).textTheme.bodySmall,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text(s.restaurant(f.restaurantId).name, style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                  Text(money(f.priceCents),
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800, color: FoodieitTheme.primary)),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],

        if (query.isNotEmpty && restaurants.isEmpty && foods.isEmpty)
          const EmptyState('No results found. Try a different search.', icon: Icons.search_off),
      ],
      ),
    );
  }
}
