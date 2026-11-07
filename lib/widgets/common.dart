import 'package:flutter/material.dart';
import '../models/entities.dart';
import '../theme/app_theme.dart';

/// ── Helper: run a store action and show errors as a snackbar ─────────────
void perform(BuildContext context, VoidCallback action) {
  try {
    action();
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is StateError ? e.message.toString() : 'Unable to complete this action.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

/// ── Confirmation dialog ─────────────────────────────────────────────────
Future<bool> confirmAction(BuildContext context, String message) async =>
    await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Please confirm'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Keep')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Confirm')),
        ],
      ),
    ) ??
    false;

/// ── Feedback snackbar ───────────────────────────────────────────────────
void showFeedback(BuildContext context, String message, {bool isError = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      backgroundColor: isError ? FoodieitTheme.danger : FoodieitTheme.success,
    ),
  );
}

// ═════════════════════════════════════════════════════════════════════════
// FORM EDITOR DIALOG
// ═════════════════════════════════════════════════════════════════════════

class FieldSpec {
  final String key, label, value;
  final bool secret, optional;
  final TextInputType keyboard;
  final int maxLines;
  const FieldSpec(
    this.key,
    this.label, {
    this.value = '',
    this.secret = false,
    this.optional = false,
    this.keyboard = TextInputType.text,
    this.maxLines = 1,
  });
}

Future<void> editForm(
  BuildContext context, {
  required String title,
  required List<FieldSpec> fields,
  required void Function(Map<String, String>) save,
  String saveLabel = 'Save',
}) =>
    showDialog<void>(
      context: context,
      builder: (_) => _EditorDialog(title: title, fields: fields, save: save, saveLabel: saveLabel),
    );

class _EditorDialog extends StatefulWidget {
  final String title;
  final List<FieldSpec> fields;
  final void Function(Map<String, String>) save;
  final String saveLabel;
  const _EditorDialog({
    required this.title,
    required this.fields,
    required this.save,
    required this.saveLabel,
  });
  @override
  State<_EditorDialog> createState() => _EditorDialogState();
}

class _EditorDialogState extends State<_EditorDialog> {
  final form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> controllers;
  late final Map<String, bool> obscureMap;
  String? error;

  @override
  void initState() {
    super.initState();
    controllers = {
      for (final f in widget.fields) f.key: TextEditingController(text: f.value),
    };
    obscureMap = {for (final f in widget.fields) f.key: f.secret};
  }

  @override
  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.title),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final f in widget.fields)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: TextFormField(
                        controller: controllers[f.key],
                        obscureText: obscureMap[f.key] ?? false,
                        keyboardType: f.keyboard,
                        maxLength: f.secret ? 72 : 500,
                        maxLines: (obscureMap[f.key] ?? false) ? 1 : f.maxLines,
                        decoration: InputDecoration(
                          labelText: f.label,
                          counterText: '',
                          suffixIcon: f.secret
                              ? IconButton(
                                  icon: Icon(obscureMap[f.key]!
                                      ? Icons.visibility_off
                                      : Icons.visibility),
                                  onPressed: () =>
                                      setState(() => obscureMap[f.key] = !obscureMap[f.key]!),
                                )
                              : null,
                        ),
                        validator: (v) =>
                            !f.optional && (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                    ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(error!, style: TextStyle(color: FoodieitTheme.danger, fontSize: 13)),
                    ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (!form.currentState!.validate()) return;
              try {
                widget.save({for (final f in widget.fields) f.key: controllers[f.key]!.text});
                Navigator.pop(context);
              } catch (e) {
                setState(() => error =
                    e is StateError ? e.message.toString() : 'Please check your details.');
              }
            },
            child: Text(widget.saveLabel),
          ),
        ],
      );
}

// ═════════════════════════════════════════════════════════════════════════
// PAGE BODY — constrained scrollable content
// ═════════════════════════════════════════════════════════════════════════

class PageBody extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsets padding;
  final double maxWidth;
  const PageBody({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.all(16),
    this.maxWidth = 900,
  });

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: ListView(
            padding: padding,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: children,
          ),
        ),
      );
}

// ═════════════════════════════════════════════════════════════════════════
// EMPTY STATE
// ═════════════════════════════════════════════════════════════════════════

class EmptyState extends StatelessWidget {
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  const EmptyState(this.message, {super.key, this.icon = Icons.inbox_outlined, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: FoodieitTheme.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 40, color: FoodieitTheme.primary),
              ),
              const SizedBox(height: 16),
              Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 16),
                OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
              ],
            ],
          ),
        ),
      );
}

// ═════════════════════════════════════════════════════════════════════════
// LOADING STATE
// ═════════════════════════════════════════════════════════════════════════

class LoadingState extends StatelessWidget {
  final String message;
  const LoadingState(this.message, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: FoodieitTheme.primary, strokeWidth: 3),
              const SizedBox(height: 16),
              Text(message, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      );
}

// ═════════════════════════════════════════════════════════════════════════
// STATUS BADGE
// ═════════════════════════════════════════════════════════════════════════

class StatusBadge extends StatelessWidget {
  final OrderStatus status;
  final bool compact;
  const StatusBadge(this.status, {super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final label = status.label;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 12, vertical: compact ? 3 : 5),
      decoration: BoxDecoration(
        color: FoodieitTheme.statusBg(label),
        borderRadius: BorderRadius.circular(FoodieitTheme.radiusXs),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: compact ? 10 : 12,
          fontWeight: FontWeight.w700,
          color: FoodieitTheme.statusFg(label),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════
// FOOD IMAGE — network image with loading placeholder + error fallback
// ═════════════════════════════════════════════════════════════════════════

class FoodImage extends StatelessWidget {
  final String? url;
  final double? width;
  final double? height;
  final double radius;
  final BoxFit fit;
  final IconData fallbackIcon;
  const FoodImage({
    super.key,
    this.url,
    this.width,
    this.height,
    this.radius = FoodieitTheme.radiusMd,
    this.fit = BoxFit.cover,
    this.fallbackIcon = Icons.restaurant,
  });

  @override
  Widget build(BuildContext context) {
    // Use deterministic Unsplash food photos based on a seed when no URL is provided.
    final src = url?.isNotEmpty == true
        ? url!
        : 'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=400&q=80';
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.network(
        src,
        width: width,
        height: height,
        fit: fit,
        headers: const {'Accept': 'image/*'},
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            width: width,
            height: height,
            color: FoodieitTheme.primaryLight.withValues(alpha: 0.3),
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                value: progress.cumulativeBytesLoaded / (progress.expectedTotalBytes ?? 1),
                color: FoodieitTheme.primary,
              ),
            ),
          );
        },
        errorBuilder: (context, error, stack) => Container(
          width: width,
          height: height,
          color: FoodieitTheme.primaryLight.withValues(alpha: 0.4),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(fallbackIcon, size: 32, color: FoodieitTheme.primary.withValues(alpha: 0.6)),
                const SizedBox(height: 4),
                Icon(Icons.broken_image_outlined, size: 18, color: FoodieitTheme.textHint),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════
// BRANDED CARD
// ═════════════════════════════════════════════════════════════════════════

class BrandedCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final List<BoxShadow>? shadow;
  final Color? color;
  final Border? border;
  const BrandedCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.shadow,
    this.color,
    this.border,
  });

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: color ?? FoodieitTheme.cardBg,
          borderRadius: BorderRadius.circular(FoodieitTheme.radiusMd),
          boxShadow: shadow ?? FoodieitTheme.shadowSm,
          border: border,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(FoodieitTheme.radiusMd),
            child: Padding(padding: padding, child: child),
          ),
        ),
      );
}

// ═════════════════════════════════════════════════════════════════════════
// SECTION HEADER
// ═════════════════════════════════════════════════════════════════════════

class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  const SectionHeader(this.title, {super.key, this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleLarge),
                  if (subtitle != null)
                    Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      );
}

// ═════════════════════════════════════════════════════════════════════════
// SEARCH FIELD
// ═════════════════════════════════════════════════════════════════════════

class SearchField extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;
  const SearchField({super.key, required this.hint, required this.onChanged, this.controller});

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: const Icon(Icons.search, color: FoodieitTheme.textHint),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(FoodieitTheme.radiusSm),
              borderSide: const BorderSide(color: FoodieitTheme.divider),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(FoodieitTheme.radiusSm),
              borderSide: const BorderSide(color: FoodieitTheme.divider),
            ),
          ),
        ),
      );
}

// ═════════════════════════════════════════════════════════════════════════
// RATING STARS
// ═════════════════════════════════════════════════════════════════════════

class RatingStars extends StatelessWidget {
  final double rating;
  final int max;
  final double size;
  const RatingStars({super.key, required this.rating, this.max = 5, this.size = 16});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(max, (i) {
        final filled = i < rating.round();
        return Icon(
          filled ? Icons.star : Icons.star_border,
          size: size,
          color: FoodieitTheme.warning,
        );
      }),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════
// QUANTITY STEPPER
// ═════════════════════════════════════════════════════════════════════════

class QuantityStepper extends StatelessWidget {
  final int quantity;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final bool compact;
  const QuantityStepper({
    super.key,
    required this.quantity,
    required this.onChanged,
    this.min = 0,
    this.max = 99,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final btnSize = compact ? 32.0 : 40.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _stepBtn(Icons.remove, quantity <= min, () => onChanged(quantity - 1), btnSize),
        Container(
          constraints: BoxConstraints(minWidth: compact ? 28 : 36),
          alignment: Alignment.center,
          child: Text(
            '$quantity',
            style: TextStyle(
              fontSize: compact ? 14 : 16,
              fontWeight: FontWeight.w700,
              color: FoodieitTheme.textPrimary,
            ),
          ),
        ),
        _stepBtn(Icons.add, quantity >= max, () => onChanged(quantity + 1), btnSize),
      ],
    );
  }

  Widget _stepBtn(IconData icon, bool disabled, VoidCallback onTap, double size) => Material(
        color: disabled
            ? FoodieitTheme.divider
            : FoodieitTheme.primaryLight,
        borderRadius: BorderRadius.circular(FoodieitTheme.radiusXs),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: disabled ? null : onTap,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, size: compact ? 16 : 20, color: disabled ? FoodieitTheme.textHint : FoodieitTheme.primary),
          ),
        ),
      );
}

// ═════════════════════════════════════════════════════════════════════════
// SUMMARY STAT CARD (admin dashboard)
// ═════════════════════════════════════════════════════════════════════════

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;
  final String? subtitle;
  final VoidCallback? onTap;
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => BrandedCard(
        onTap: onTap,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (color ?? FoodieitTheme.primary).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(FoodieitTheme.radiusXs),
                  ),
                  child: Icon(icon, size: 20, color: color ?? FoodieitTheme.primary),
                ),
                const Spacer(),
                Text(value, style: Theme.of(context).textTheme.headlineSmall),
              ],
            ),
            const SizedBox(height: 10),
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
            if (subtitle != null)
              Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      );
}

// ═════════════════════════════════════════════════════════════════════════
// INFO ROW
// ═════════════════════════════════════════════════════════════════════════

class InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const InfoRow({super.key, required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(icon, size: 18, color: FoodieitTheme.textSecondary),
            const SizedBox(width: 10),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const Spacer(),
            Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

// ═════════════════════════════════════════════════════════════════════════
// PROMO BANNER
// ═════════════════════════════════════════════════════════════════════════

class PromoBanner extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color? color;
  final IconData icon;
  const PromoBanner({
    super.key,
    required this.title,
    required this.subtitle,
    this.color,
    this.icon = Icons.local_offer,
  });

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [(color ?? FoodieitTheme.primary), (color ?? FoodieitTheme.primaryDark)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(FoodieitTheme.radiusLg),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(fontSize: 13, color: Colors.white70)),
                ],
              ),
            ),
            Icon(icon, size: 48, color: Colors.white.withValues(alpha: 0.5)),
          ],
        ),
      );
}
