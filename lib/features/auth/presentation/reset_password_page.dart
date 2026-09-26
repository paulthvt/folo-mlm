import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:folo/app/router/routes.dart';
import 'package:folo/app/theme/app_spacing.dart';
import 'package:folo/features/auth/data/auth_repository.dart';
import 'package:folo/features/auth/domain/auth_failure.dart';
import 'package:folo/features/auth/domain/auth_validation.dart';
import 'package:folo/features/auth/presentation/auth_failure_copy.dart';
import 'package:folo/features/auth/presentation/auth_validation_copy.dart';
import 'package:folo/features/auth/presentation/widgets/auth_scaffold.dart';
import 'package:folo/features/auth/presentation/widgets/form_error.dart';
import 'package:folo/features/auth/presentation/widgets/password_field.dart';
import 'package:folo/features/auth/presentation/widgets/submit_button.dart';
import 'package:folo/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// Reached by the recovery deep link, which has already created a session — so
/// there is no back button and nowhere to go back to.
class ResetPasswordPage extends ConsumerStatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  ConsumerState<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends ConsumerState<ResetPasswordPage> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();

  bool _busy = false;
  AuthFailure? _failure;

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // Two taps in the same frame reach here before `_busy` disables the button.
    if (_busy) return;
    if (!_form.currentState!.validate()) return;

    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      await ref.read(authRepositoryProvider).updatePassword(_password.text);
      if (!mounted) return;
      context.go(Routes.today);
    } on AuthFailure catch (failure) {
      if (!mounted) return;
      setState(() => _failure = failure);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _leave() async {
    try {
      await ref.read(authRepositoryProvider).signOut();
    } on AuthFailure catch (failure) {
      // Still signed in and still recovering, so the guard keeps them here —
      // which is the safe outcome. Say why nothing happened.
      if (!mounted) return;
      setState(() => _failure = failure);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);

    return AuthScaffold(
      children: [
        Text(l10n.authNewPasswordTitle, style: text.headlineSmall),
        if (_failure != null) FormError(authFailureCopy(l10n, _failure!)),
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppSpacing.md,
            children: [
              PasswordField(
                controller: _password,
                label: l10n.authNewPasswordLabel,
                helper: l10n.authPasswordHelperMinimum(minPasswordLength),
                enabled: !_busy,
                validator: (value) => passwordFieldError(l10n, value),
              ),
              PasswordField(
                controller: _confirmation,
                label: l10n.authConfirmPasswordLabel,
                enabled: !_busy,
                validator: (value) =>
                    passwordConfirmationFieldError(l10n, value, _password.text),
                onSubmitted: (_) => _busy ? null : _submit(),
              ),
              SubmitButton(
                label: l10n.authSaveAndSignInAction,
                busy: _busy,
                onPressed: _submit,
              ),
            ],
          ),
        ),
        // The recovery link created a session and the guard pins the user to
        // this screen, so leaving has to end that session. The router sends
        // them on as soon as it does.
        Center(
          child: TextButton(
            onPressed: _busy ? null : _leave,
            child: Text(l10n.authBackToSignIn),
          ),
        ),
      ],
    );
  }
}
