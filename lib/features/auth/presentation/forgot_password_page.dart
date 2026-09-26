import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:folo/app/router/back.dart';
import 'package:folo/app/router/routes.dart';
import 'package:folo/app/theme/app_spacing.dart';
import 'package:folo/features/auth/data/auth_repository.dart';
import 'package:folo/features/auth/domain/auth_failure.dart';
import 'package:folo/features/auth/domain/auth_validation.dart';
import 'package:folo/features/auth/presentation/auth_failure_copy.dart';
import 'package:folo/features/auth/presentation/auth_validation_copy.dart';
import 'package:folo/features/auth/presentation/widgets/auth_scaffold.dart';
import 'package:folo/features/auth/presentation/widgets/form_error.dart';
import 'package:folo/features/auth/presentation/widgets/submit_button.dart';
import 'package:folo/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// Request a password reset link.
///
/// The outcome is deliberately the same whether or not the address has an
/// account: this screen must not be usable to find out who is registered. Only
/// failures that are about *this device* — no connection, too many attempts —
/// are shown, because they say nothing about the address.
class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();

  bool _busy = false;
  AuthFailure? _failure;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // Two taps in the same frame reach here before `_busy` disables the button;
    // a second email would be sent.
    if (_busy) return;
    if (!_form.currentState!.validate()) return;

    final email = normalizeEmail(_email.text);
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      await ref.read(authRepositoryProvider).sendPasswordReset(email);
    } on AuthFailure catch (failure) {
      if (!mounted) return;
      if (failure == AuthFailure.network ||
          failure == AuthFailure.rateLimited) {
        setState(() {
          _failure = failure;
          _busy = false;
        });
        return;
      }
      // Any server-side failure is swallowed on purpose — see the class doc.
    }
    if (!mounted) return;
    setState(() => _busy = false);
    context.pushReplacement(
      Routes.checkInboxLocation(reason: 'reset', email: email),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);

    return AuthScaffold(
      back: Routes.login,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.sm,
          children: [
            Text(l10n.authForgotTitle, style: text.headlineSmall),
            Text(l10n.authForgotBody, style: text.bodyMedium),
          ],
        ),
        if (_failure != null) FormError(authFailureCopy(l10n, _failure!)),
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppSpacing.md,
            children: [
              TextFormField(
                controller: _email,
                enabled: !_busy,
                validator: (value) => emailFieldError(l10n, value),
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                onFieldSubmitted: (_) => _busy ? null : _submit(),
                decoration: InputDecoration(labelText: l10n.authEmailLabel),
              ),
              SubmitButton(
                label: l10n.authSendResetLinkAction,
                busy: _busy,
                onPressed: _submit,
              ),
            ],
          ),
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
