import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:folo/app/router/routes.dart';
import 'package:folo/app/theme/app_spacing.dart';
import 'package:folo/features/auth/data/auth_repository.dart';
import 'package:folo/features/auth/domain/auth_failure.dart';
import 'package:folo/features/auth/presentation/auth_failure_copy.dart';
import 'package:folo/features/auth/presentation/widgets/auth_scaffold.dart';
import 'package:folo/features/auth/presentation/widgets/form_error.dart';
import 'package:go_router/go_router.dart';

/// The signed-out root: the promise, and the three ways in.
///
/// The social buttons live here and nowhere else — a user who signed up with
/// Google is never shown a competing email form beside their real path.
class WelcomePage extends ConsumerStatefulWidget {
  const WelcomePage({super.key});

  @override
  ConsumerState<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends ConsumerState<WelcomePage> {
  bool _busy = false;
  AuthFailure? _failure;

  Future<void> _continueWith(Future<void> Function() start) async {
    // Two taps in the same frame reach here before `_busy` disables the button.
    if (_busy) return;
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      await start();
    } on AuthFailure catch (failure) {
      if (!mounted) return;
      setState(() => _failure = failure);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return AuthScaffold(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.ms,
          children: [
            // ponytail: the wordmark is set type until there is a real logo —
            // that is its own issue.
            Text('Folo', style: text.displaySmall),
            Text('Know what to do next.', style: text.titleLarge),
            Text(
              'Organize your relationships, know what to do next.',
              style: text.bodyMedium,
            ),
          ],
        ),
        if (_failure != null) FormError(authFailureCopy(_failure!)),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.ms,
          children: [
            // Google and Apple each mandate their own sign-in mark; until those
            // assets are added the buttons are label-only.
            OutlinedButton(
              onPressed: _busy
                  ? null
                  : () => _continueWith(
                      ref.read(authRepositoryProvider).signInWithGoogle,
                    ),
              child: const Text('Continue with Google'),
            ),
            OutlinedButton(
              onPressed: _busy
                  ? null
                  : () => _continueWith(
                      ref.read(authRepositoryProvider).signInWithApple,
                    ),
              child: const Text('Continue with Apple'),
            ),
            FilledButton(
              onPressed: _busy ? null : () => context.go(Routes.login),
              child: const Text('Continue with email'),
            ),
          ],
        ),
        // Wrap, not Row: the label plus the button is wider than the 400-wide
        // column at larger text scales.
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('New here?', style: text.bodySmall),
            TextButton(
              onPressed: () => context.go(Routes.register),
              child: const Text('Create an account'),
            ),
          ],
        ),
      ],
    );
  }
}
