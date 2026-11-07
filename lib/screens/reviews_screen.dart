import 'package:flutter/material.dart';
import '../models/entities.dart';
import '../services/app_scope.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

Future<void> reviewEditor(BuildContext context, FoodOrder order) async {
  final s = AppScope.of(context);
  final existing = s.reviewFor(order.id);
  await editForm(
    context,
    title: 'Review ${s.restaurant(order.restaurantId).name}',
    fields: [
      FieldSpec('rating', 'Stars (1-5)', value: '${existing?.rating ?? 5}', keyboard: TextInputType.number),
      FieldSpec('comment', 'Your review', value: existing?.comment ?? '', maxLines: 3),
    ],
    save: (d) {
      final rating = int.tryParse(d['rating']!);
      if (rating == null) throw StateError('Choose an integer rating from 1 to 5.');
      s.saveReview(order.id, rating, d['comment']!);
    },
    saveLabel: existing == null ? 'Submit review' : 'Update review',
  );
}

class ReviewsScreen extends StatelessWidget {
  const ReviewsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final u = s.current!;

    return PageBody(
      children: [
        SectionHeader('Reviews & ratings'),
        const SizedBox(height: 12),

        // Rating summaries per restaurant
        for (final r in s.restaurants) ...[
          BrandedCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.name, style: Theme.of(context).textTheme.titleMedium),
                      Text('${s.reviews.where((v) => v.restaurantId == r.id).length} reviews',
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                RatingStars(rating: s.average(r.id) ?? 0, size: 18),
                const SizedBox(width: 6),
                Text(s.average(r.id)?.toStringAsFixed(1) ?? '-',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: FoodieitTheme.primary)),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],

        const SizedBox(height: 8),
        Text('Customer feedback', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),

        if (s.reviews.isEmpty)
          const EmptyState('No reviews yet. Complete a delivery to leave a review.', icon: Icons.star_border),

        for (final v in s.reviews) ...[
          BrandedCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(s.restaurant(v.restaurantId).name, style: Theme.of(context).textTheme.titleMedium)),
                    RatingStars(rating: v.rating.toDouble(), size: 14),
                  ],
                ),
                const SizedBox(height: 4),
                Text('${s.user(v.customerId).name}', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 8),
                Text(v.comment, style: Theme.of(context).textTheme.bodyMedium),
                if (u.role == Role.customer && u.id == v.customerId) ...[
                  const SizedBox(height: 10),
                  Wrap(children: [
                    OutlinedButton(onPressed: () => reviewEditor(context, s.order(v.orderId)), child: const Text('Edit')),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () async {
                        if (await confirmAction(context, 'Delete this review?') && context.mounted) {
                          perform(context, () => s.deleteReview(v.id));
                        }
                      },
                      child: Text('Delete', style: TextStyle(color: FoodieitTheme.danger)),
                    ),
                  ]),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}
