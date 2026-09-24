import 'package:flutter/material.dart';
import 'package:folo/app/router/back.dart';
import 'package:folo/app/theme/app_spacing.dart';
import 'package:folo/core/layout/breakpoints.dart';

/// The shape every auth screen shares: no navigation, one column capped at 400
/// and centred, flat on the canvas.
///
/// This is the only part of the product whose layout does not restructure
/// across size classes — a form has one column at every width. Only the
/// vertical rhythm steps up on a larger screen.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({required this.children, this.back, super.key});

  static const double _columnWidth = 400;

  final List<Widget> children;

  /// Where the back control goes, or null for no app bar. The destination is
  /// named because a screen can also be reached by URL or deep link, with
  /// nothing on the stack to pop — see `backOr`.
  final String? back;

  @override
  Widget build(BuildContext context) {
    final rhythm = context.screenSize == ScreenSize.mobile
        ? AppSpacing.lg
        : AppSpacing.xl;

    return Scaffold(
      appBar: back == null
          ? null
          : AppBar(
              leading: BackButton(onPressed: () => backOr(context, back!)),
            ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            // lg, not the md screens use elsewhere: the column is capped at 400
            // and centred, so this only ever binds on mobile, where the extra
            // inset keeps the stretched buttons off the edges.
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.xl,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _columnWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: rhythm,
                children: children,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
