import 'package:flutter/services.dart';
import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/core/ui/loomia_mark.dart';
import 'package:material_ui/material_ui.dart';

/// The cold-start splash, over the app while it builds underneath: the ring
/// the native launch screen already shows, the three dots growing in smallest
/// first, then a fade into the app.
///
/// The one staggered entrance in the product (design-system.md §7.4): a brand
/// moment, not UI. No overshoot; with reduce motion the dots are already there
/// and only the fade plays.
class LaunchSplash extends StatefulWidget {
  const LaunchSplash({required this.child, super.key});

  final Widget child;

  /// Outer diameter of the ring, in logical pixels. The native launch screens
  /// draw the same ring at the same size (android `drawable/launch_ring.xml`,
  /// iOS `LaunchImage`, web `index.html`), so the hand-off is invisible.
  static const ring = 96.0;

  static const _stagger = Duration(milliseconds: 120);

  @override
  State<LaunchSplash> createState() => _LaunchSplashState();
}

class _LaunchSplashState extends State<LaunchSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<Animation<double>> _dots;
  late final Animation<double> _fade;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller.duration != null) return;

    final reduce = context.reduceMotion;
    final grow = reduce ? Duration.zero : AppMotion.medium;
    final stagger = reduce ? Duration.zero : LaunchSplash._stagger;
    final fade = context.motion(AppMotion.quick);
    final total = stagger * 2 + grow + fade;
    double at(Duration d) => d.inMicroseconds / total.inMicroseconds;

    _dots = [
      for (var i = 0; i < 3; i++)
        reduce
            ? kAlwaysCompleteAnimation
            : CurvedAnimation(
                parent: _controller,
                curve: Interval(
                  at(stagger * i),
                  at(stagger * i + grow),
                  curve: AppMotion.decelerate,
                ),
              ),
    ];
    _fade = ReverseAnimation(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(at(total - fade), 1, curve: AppMotion.accelerate),
      ),
    );
    _controller
      ..duration = total
      ..forward().whenComplete(() {
        if (mounted) setState(() => _done = true);
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_done) return widget.child;

    const em = LaunchSplash.ring / (LoomiaMarkPainter.outer * 2);
    // Centres the ring, not the box the dots widen.
    final shift =
        (LoomiaMarkPainter.box.center(Offset.zero) - LoomiaMarkPainter.centre) *
        em;

    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: AnnotatedRegion(
              value: SystemUiOverlayStyle.light,
              child: FadeTransition(
                opacity: _fade,
                child: ColoredBox(
                  color: LoomiaColors.of(context).brand,
                  child: Center(
                    child: Transform.translate(
                      offset: shift,
                      child: AnimatedBuilder(
                        animation: _controller,
                        builder: (context, _) => CustomPaint(
                          size: LoomiaMarkPainter.box * em,
                          painter: LoomiaMarkPainter(
                            Theme.of(context).colorScheme.onPrimary,
                            dots: [for (final dot in _dots) dot.value],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
