import 'package:flutter/material.dart';
import 'package:folo/app/theme/app_spacing.dart';
import 'package:folo/core/layout/breakpoints.dart';

/// The shape every auth screen shares: no navigation, one column capped at 400
/// and centred, flat on the canvas.
///
/// This is the only part of the product whose layout does not restructure
/// across size classes — a form has one column at every width. Only the
/// vertical rhythm steps up on a larger screen.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({required this.children, this.showBack = true, super.key});

  static const double _columnWidth = 400;

  final List<Widget> children;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final rhythm = context.screenSize == ScreenSize.mobile
        ? AppSpacing.lg
        : AppSpacing.xl;

    return Scaffold(
      appBar: showBack ? AppBar() : null,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
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
