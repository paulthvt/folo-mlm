import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:folo/app/router/routes.dart';
import 'package:folo/app/theme/app_spacing.dart';
import 'package:folo/features/auth/data/auth_repository.dart';
import 'package:folo/features/auth/domain/auth_failure.dart';
import 'package:folo/features/auth/domain/auth_validation.dart';
import 'package:folo/features/auth/presentation/auth_failure_copy.dart';
import 'package:folo/features/auth/presentation/auth_validation_copy.dart';
import 'package:folo/features/auth/presentation/check_inbox_page.dart';
import 'package:folo/features/auth/presentation/widgets/auth_scaffold.dart';
import 'package:folo/features/auth/presentation/widgets/form_error.dart';
import 'package:folo/features/auth/presentation/widgets/password_field.dart';
import 'package:folo/features/auth/presentation/widgets/submit_button.dart';
import 'package:folo/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// Email + password sign-in.
///
/// The form-level error never says which field was wrong and never reveals
/// whether the account exists.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _busy = false;
  AuthFailure? _failure;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // Two taps in the same frame reach here before `busy` disables the button.
    if (_busy) return;
    if (!_form.currentState!.validate()) return;

    final email = normalizeEmail(_email.text);
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .signIn(email: email, password: _password.text);
    } on AuthFailure catch (failure) {
      // The request can outlive the screen: the user may go back while it is in
      // flight.
      if (!mounted) return;
      if (failure == AuthFailure.emailNotConfirmed) {
        // Telling them the link can be re-sent is only useful next to the
        // button that re-sends it.
        setState(() => _busy = false);
        unawaited(
          context.push(
            Routes.checkInboxLocation(
              reason: CheckInboxPage.confirmReason,
              email: email,
            ),
          ),
        );
        return;
      }
      setState(() => _failure = failure);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);

    return AuthScaffold(
      back: Routes.welcome,
      children: [
        Text(l10n.authLoginTitle, style: text.headlineSmall),
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
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: l10n.authEmailLabel),
              ),
              PasswordField(
                controller: _password,
                label: l10n.authPasswordLabel,
                enabled: !_busy,
                validator: (value) => passwordFieldError(l10n, value),
                onSubmitted: (_) => _busy ? null : _submit(),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => context.push(Routes.forgotPassword),
                  child: Text(l10n.authForgotPasswordAction),
                ),
              ),
              SubmitButton(
                label: l10n.authSignInAction,
                busy: _busy,
                onPressed: _submit,
              ),
            ],
          ),
        ),
        // Wrap, not Row: the label plus the button is wider than the 400-wide
        // column at larger text scales.
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(l10n.authNewHere, style: text.bodySmall),
            TextButton(
              onPressed: () => context.push(Routes.register),
              child: Text(l10n.authCreateAccountAction),
            ),
          ],
        ),
      ],
    );
  }
}
