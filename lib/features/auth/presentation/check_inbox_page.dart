import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:folo/app/router/back.dart';
import 'package:folo/app/router/routes.dart';
import 'package:folo/app/theme/app_spacing.dart';
import 'package:folo/features/auth/data/auth_repository.dart';
import 'package:folo/features/auth/domain/auth_failure.dart';
import 'package:folo/features/auth/presentation/auth_failure_copy.dart';
import 'package:folo/features/auth/presentation/widgets/auth_scaffold.dart';
import 'package:folo/features/auth/presentation/widgets/form_error.dart';
import 'package:folo/features/auth/presentation/widgets/submit_button.dart';
import 'package:folo/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// One screen for both "confirm your email" and "we sent a reset link".
///
/// [reason] and [email] arrive as query parameters rather than a router
/// `extra`, so reloading the page on web still has its content.
class CheckInboxPage extends ConsumerStatefulWidget {
  const CheckInboxPage({required this.reason, required this.email, super.key});

  static const String confirmReason = 'confirm';
  static const String resetReason = 'reset';

  final String reason;
  final String email;

  @override
  ConsumerState<CheckInboxPage> createState() => _CheckInboxPageState();
}

class _CheckInboxPageState extends ConsumerState<CheckInboxPage> {
  bool _busy = false;
  bool _sent = false;
  AuthFailure? _failure;

  bool get _isReset => widget.reason == CheckInboxPage.resetReason;

  Future<void> _resend() async {
    // Two taps in the same frame reach here before `_busy` disables the button;
    // a second email would be sent, which can self-trip the rate limit.
    if (_busy) return;
    final repository = ref.read(authRepositoryProvider);
    setState(() {
      _busy = true;
      _failure = null;
      _sent = false;
    });
    try {
      if (_isReset) {
        await repository.sendPasswordReset(widget.email);
      } else {
        await repository.resendConfirmation(widget.email);
      }
      if (!mounted) return;
      setState(() => _sent = true);
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
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final hasEmail = widget.email.isNotEmpty;

    return AuthScaffold(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.sm,
          children: [
            Text(
              _isReset ? l10n.authCheckEmailTitle : l10n.authCheckInboxTitle,
              style: text.titleLarge,
            ),
            Text(
              _isReset
                  // Says nothing about whether the address is registered.
                  ? l10n.authResetLinkSentBody
                  : hasEmail
                  ? l10n.authCheckInboxBodyWithEmail(widget.email)
                  : l10n.authCheckInboxBody,
              style: text.bodyMedium,
            ),
          ],
        ),
        if (_failure != null) FormError(authFailureCopy(l10n, _failure!)),
        if (_sent)
          Text(
            l10n.authResendSent,
            style: text.bodySmall?.copyWith(color: scheme.primary),
          ),
        if (hasEmail)
          SubmitButton(
            label: l10n.authResendEmailAction,
            busy: _busy,
            onPressed: _resend,
          ),
        Center(
          child: TextButton(
            onPressed: () => backOr(context, Routes.login),
            child: Text(l10n.authBackToSignIn),
          ),
        ),
      ],
    );
  }
}
