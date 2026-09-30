import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/core/ui/loomia_mark.dart';
import 'package:material_ui/material_ui.dart';

/// The logo: "l", the mark in place of the first "o", then "omia"
/// (Figma `07 — Loomia logo`, E5b). The letters take [style], so the wordmark
/// sizes like the text it replaces.
///
/// The mark is painted rather than shipped as an image: it is a ring and three
/// dots, and painting keeps it on the theme's `brand` token in both modes.
class LoomiaWordmark extends StatelessWidget {
  const LoomiaWordmark({required this.style, super.key});

  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final size = style.fontSize ?? DefaultTextStyle.of(context).style.fontSize!;
    final ink = style.color ?? Theme.of(context).colorScheme.onSurface;

    return Semantics(
      label: 'Loomia',
      excludeSemantics: true,
      child: Text.rich(
        TextSpan(
          style: style.copyWith(color: ink),
          children: [
            const TextSpan(text: 'l'),
            WidgetSpan(
              // Box bottom on the baseline, then down by the "o"'s own
              // overshoot so the ring sits where the letter would.
              alignment: PlaceholderAlignment.aboveBaseline,
              baseline: TextBaseline.alphabetic,
              child: Padding(
                padding: EdgeInsets.only(right: LoomiaMarkPainter.gap * size),
                child: Transform.translate(
                  offset: Offset(0, LoomiaMarkPainter.overshoot * size),
                  child: CustomPaint(
                    size: LoomiaMarkPainter.box * size,
                    painter: LoomiaMarkPainter(LoomiaColors.of(context).brand),
                  ),
                ),
              ),
            ),
            const TextSpan(text: 'omia'),
          ],
        ),
      ),
    );
  }
}
