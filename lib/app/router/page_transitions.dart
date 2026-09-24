import 'package:flutter/material.dart';
import 'package:folo/app/theme/app_theme.dart';
import 'package:go_router/go_router.dart';

/// The page transition every route uses (`docs/design/design-system.md` §7).
///
/// [sharedAxis] adds an 8px horizontal shift to the fade, for a move along one
/// flow — the auth screens. Everything else fades through, which is what a
/// change of context looks like. Under reduce motion both collapse to a 120ms
/// opacity change with no movement at all.
CustomTransitionPage<void> foloPage(
  BuildContext context,
  GoRouterState state,
  Widget child, {
  bool sharedAxis = false,
}) {
  final shift = sharedAxis && !context.reduceMotion ? _shift : 0.0;

  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: context.motion(AppMotion.slow),
    // Leaving is quicker than arriving: the user already knows where they are
    // going back to.
    reverseTransitionDuration: context.motion(AppMotion.medium),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: AppMotion.standard,
        reverseCurve: AppMotion.accelerate,
      );
      final faded = FadeTransition(opacity: curved, child: child);
      if (shift == 0) return faded;

      return AnimatedBuilder(
        animation: curved,
        // The shift is pixels, not a fraction of the page: an 8px hint reads the
        // same on a phone and on a desktop pane.
        builder: (context, child) => Transform.translate(
          offset: Offset(shift * (1 - curved.value), 0),
          child: child,
        ),
        child: faded,
      );
    },
  );
}

const double _shift = 8;
