import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/app/theme/app_typography.dart';
import 'package:material_ui/material_ui.dart';

/// The four sizes the product uses (`docs/design/components.md` #4): inline in a
/// sentence, dense list or stack, list row, contact header.
enum AvatarSize {
  inline(24),
  dense(32),
  row(40),
  header(56);

  const AvatarSize(this.diameter);

  final double diameter;

  TextStyle get _style => switch (this) {
    AvatarSize.inline => AppTypography.overline,
    AvatarSize.dense => AppTypography.caption,
    AvatarSize.row => AppTypography.label,
    AvatarSize.header => AppTypography.title,
  };
}

/// A person. Circular at every size, initials never a generic glyph
/// (design principle #2).
class LoomiaAvatar extends StatelessWidget {
  const LoomiaAvatar({
    required this.name,
    this.size = AvatarSize.row,
    super.key,
  });

  final String name;
  final AvatarSize size;

  /// First letters of the first and last word — "Marie Dupont" → "MD".
  static String initialsOf(String name) {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    if (words.isEmpty) return '?';
    final letters = words.length == 1
        ? words.first.substring(0, 1)
        : '${words.first[0]}${words.last[0]}';
    return letters.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: name,
      child: Container(
        width: size.diameter,
        height: size.diameter,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          shape: BoxShape.circle,
        ),
        child: Text(
          initialsOf(name),
          style: size._style.copyWith(
            color: scheme.onPrimaryContainer,
            letterSpacing: size.diameter * 0.02,
          ),
        ),
      ),
    );
  }
}

/// A group of people as one object — team contexts only, never a row about one
/// person (#5).
class LoomiaAvatarGroup extends StatelessWidget {
  const LoomiaAvatarGroup({required this.names, this.max = 3, super.key});

  final List<String> names;
  final int max;

  @override
  Widget build(BuildContext context) {
    final colors = LoomiaColors.of(context);
    final shown = names.take(max).toList();
    final overflow = names.length - shown.length;
    const overlap = 10.0;
    const ring = 2.0;
    final ringed = AvatarSize.dense.diameter + 2 * ring;

    return Semantics(
      label: '${names.length} people',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (index, name) in shown.indexed)
            // Container rejects a negative margin; a narrower Align lets the
            // avatar spill left, under nothing, over the one before it.
            Align(
              alignment: Alignment.centerRight,
              widthFactor: index == 0 ? 1 : (ringed - overlap) / ringed,
              child: Container(
                padding: const EdgeInsets.all(ring),
                decoration: BoxDecoration(
                  color: colors.surfaceDefault,
                  shape: BoxShape.circle,
                ),
                child: ExcludeSemantics(
                  child: LoomiaAvatar(name: name, size: AvatarSize.dense),
                ),
              ),
            ),
          if (overflow > 0)
            Container(
              margin: const EdgeInsets.only(left: AppSpacing.xs),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: colors.surfaceSunken,
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
              child: Text(
                '+$overflow',
                style: AppTypography.caption.copyWith(color: colors.textMuted),
              ),
            ),
        ],
      ),
    );
  }
}
