import 'package:loomia/app/theme/app_colors.dart';
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
                padding: EdgeInsets.only(right: _MarkPainter.gap * size),
                child: Transform.translate(
                  offset: Offset(0, _MarkPainter.overshoot * size),
                  child: CustomPaint(
                    size: _MarkPainter.box * size,
                    painter: _MarkPainter(LoomiaColors.of(context).brand),
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

/// Geometry in em, measured on the Figma component (100px type): a ring the
/// size of the Bold "o", and three dots growing towards the top, each 0.065em
/// clear of the ring.
class _MarkPainter extends CustomPainter {
  const _MarkPainter(this.color);

  final Color color;

  static const _outer = 0.285;
  static const _inner = 0.155;
  static const _dots = [
    (Offset(-0.35119, -0.16376), 0.0375),
    (Offset(-0.18046, -0.35418), 0.0475),
    (Offset(0.07076, -0.40131), 0.0575),
  ];

  /// Ring centre from the top-left of the box, which the dots widen and heighten.
  static const _centre = Offset(0.38869, 0.45881);
  static const box = Size(0.67369, 0.74381);

  /// Space before "omia": the "o"'s left side bearing plus the Figma kerning.
  static const gap = 0.046;
  static const overshoot = 0.016;

  @override
  void paint(Canvas canvas, Size size) {
    final em = size.height / box.height;
    final paint = Paint()..color = color;
    canvas
      ..scale(em)
      ..translate(_centre.dx, _centre.dy)
      ..drawCircle(
        Offset.zero,
        (_outer + _inner) / 2,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = _outer - _inner,
      );
    for (final (centre, radius) in _dots) {
      canvas.drawCircle(centre, radius, paint);
    }
  }

  @override
  bool shouldRepaint(_MarkPainter old) => old.color != color;
}
