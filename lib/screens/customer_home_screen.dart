import 'package:flutter/material.dart';
import '../models/entities.dart';
import '../services/app_scope.dart';
import '../services/app_store.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'menu_screen.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});
  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  String search = '';
  String selectedCategory = 'all';

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final u = s.current!;

    // Filter restaurants by category. If a specific category is selected,
    // show restaurants that EITHER have that categoryId OR have menu items
    // in that category. This ensures e.g. "Drinks" shows restaurants that
    // serve drinks even if the restaurant's own categoryId is different.
    final filteredRestaurants = s.restaurants.where((r) {
      if (!r.active) return false;
      if (selectedCategory != 'all') {
        final restaurantMatches = r.categoryId == selectedCategory;
        final hasFoodInCategory = s.foods.any((f) =>
            f.restaurantId == r.id && !f.removed && f.available &&
            f.categoryId == selectedCategory);
        if (!restaurantMatches && !hasFoodInCategory) return false;
      }
      if (search.isNotEmpty &&
          !'${r.name} ${r.cuisine}'.toLowerCase().contains(search.toLowerCase())) return false;
      return true;
    }).toList();

    final popularFoods = s.foods
        .where((f) => !f.removed && f.available && f.restaurantId.isNotEmpty)
        .toList();

    return Scaffold(
      backgroundColor: FoodieitTheme.background,
      body: PageBody(
        children: [
        // ── Delivery address bar ──
        BrandedCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          onTap: () => _showAddressPicker(context, s, u),
          child: Row(
            children: [
              const Icon(Icons.location_on, color: FoodieitTheme.primary, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Deliver to', style: Theme.of(context).textTheme.bodySmall),
                    Text(
                      u.address.isEmpty ? 'Set your address' : u.address,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.keyboard_arrow_down, color: FoodieitTheme.textSecondary),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Search ──
        SearchField(
          hint: 'Search for restaurants or dishes',
          onChanged: (v) => setState(() => search = v),
        ),
        const SizedBox(height: 20),

        // ── Promo banners ──
        SizedBox(
          height: 170,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              const PromoBanner(
                title: 'Free delivery',
                subtitle: 'On your first 3 orders this week',
                icon: Icons.delivery_dining,
              ),
              const SizedBox(width: 12),
              PromoBanner(
                title: '20% OFF',
                subtitle: 'Malaysian favourites at Selera Kampung',
                color: FoodieitTheme.info,
                icon: Icons.local_fire_department,
              ),
              const SizedBox(width: 12),
              const PromoBanner(
                title: 'Healthy picks',
                subtitle: 'Fresh bowls from RM13.90',
                icon: Icons.eco,
                color: FoodieitTheme.success,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // ── Categories ──
        SectionHeader('Categories'),
        SizedBox(
          height: 92,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final cat in categories)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: GestureDetector(
                    onTap: () => setState(() => selectedCategory = cat.id),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: selectedCategory == cat.id
                                ? FoodieitTheme.primary
                                : FoodieitTheme.primaryLight,
                            borderRadius: BorderRadius.circular(FoodieitTheme.radiusMd),
                          ),
                          child: Icon(cat.icon,
                              size: 24,
                              color: selectedCategory == cat.id
                                  ? Colors.white
                                  : FoodieitTheme.primary),
                        ),
                        const SizedBox(height: 6),
                        Text(cat.label,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: selectedCategory == cat.id
                                    ? FoodieitTheme.primary
                                    : FoodieitTheme.textSecondary)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // ── Popular restaurants ──
        SectionHeader('Popular near you', subtitle: '${filteredRestaurants.length} restaurants'),
        if (filteredRestaurants.isEmpty)
          const EmptyState('No restaurants match your search.', icon: Icons.search_off),
        for (final r in filteredRestaurants) ...[
          _RestaurantCard(restaurant: r, store: s),
          const SizedBox(height: 14),
        ],

        // ── Recommended items ──
        if (popularFoods.isNotEmpty) ...[
          const SizedBox(height: 8),
          SectionHeader('Recommended for you', subtitle: 'Popular dishes'),
          SizedBox(
            height: 220,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final f in popularFoods.take(8))
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _FoodMiniCard(food: f, store: s),
                  ),
              ],
            ),
          ),
        ],
      ],
      ),
    );
  }

  void _showAddressPicker(BuildContext context, AppStore s, AppUser u) {
    editForm(
      context,
      title: 'Delivery address',
      fields: [FieldSpec('address', 'Street address', value: u.address, maxLines: 3)],
      save: (d) => s.editProfile(u.name, u.phone, d['address']!),
      saveLabel: 'Save address',
    );
  }
}

class _RestaurantCard extends StatelessWidget {
  final Restaurant restaurant;
  final AppStore store;
  const _RestaurantCard({required this.restaurant, required this.store});

  @override
  Widget build(BuildContext context) {
    final avg = store.average(restaurant.id);
    return BrandedCard(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => MenuScreen(restaurantId: restaurant.id)),
      ),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Restaurant image
          FoodImage(
            url: restaurant.imageUrl,
            height: 140,
            width: double.infinity,
            radius: FoodieitTheme.radiusMd,
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(restaurant.name,
                          style: Theme.of(context).textTheme.titleMedium,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: FoodieitTheme.successBg,
                        borderRadius: BorderRadius.circular(FoodieitTheme.radiusXs),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star, size: 14, color: FoodieitTheme.warning),
                          const SizedBox(width: 3),
                          Text(avg?.toStringAsFixed(1) ?? 'New',
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w700, color: FoodieitTheme.success)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(restaurant.cuisine, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 14, color: FoodieitTheme.textHint),
                    const SizedBox(width: 4),
                    Text(restaurant.hours, style: Theme.of(context).textTheme.bodySmall),
                    const Spacer(),
                    Icon(Icons.delivery_dining, size: 14, color: FoodieitTheme.textHint),
                    const SizedBox(width: 4),
                    Text('Free', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FoodMiniCard extends StatelessWidget {
  final FoodItem food;
  final AppStore store;
  const _FoodMiniCard({required this.food, required this.store});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 150,
        child: BrandedCard(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => MenuScreen(restaurantId: food.restaurantId)),
          ),
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FoodImage(url: food.imageUrl, height: 110, width: 150, radius: 0),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(food.name,
                        style: Theme.of(context).textTheme.titleSmall,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(store.restaurant(food.restaurantId).name,
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(money(food.priceCents),
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w800, color: FoodieitTheme.primary)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}
