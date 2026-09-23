import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:folo/app/router/routes.dart';
import 'package:folo/app/theme/app_spacing.dart';
import 'package:folo/features/auth/data/auth_repository.dart';
import 'package:folo/features/auth/domain/auth_failure.dart';
import 'package:folo/features/auth/domain/auth_validation.dart';
import 'package:folo/features/auth/presentation/auth_failure_copy.dart';
import 'package:folo/features/auth/presentation/widgets/auth_scaffold.dart';
import 'package:folo/features/auth/presentation/widgets/form_error.dart';
import 'package:folo/features/auth/presentation/widgets/password_field.dart';
import 'package:folo/features/auth/presentation/widgets/submit_button.dart';
import 'package:go_router/go_router.dart';

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

    return AuthScaffold(
      children: [
        Text('Choose a new password', style: text.headlineSmall),
        if (_failure != null) FormError(authFailureCopy(_failure!)),
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppSpacing.md,
            children: [
              PasswordField(
                controller: _password,
                label: 'New password',
                helper: 'At least 8 characters',
                enabled: !_busy,
                validator: validatePassword,
              ),
              PasswordField(
                controller: _confirmation,
                label: 'Confirm password',
                enabled: !_busy,
                validator: (value) =>
                    validatePasswordConfirmation(value, _password.text),
                onSubmitted: (_) => _busy ? null : _submit(),
              ),
              SubmitButton(
                label: 'Save and sign in',
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
            child: const Text('Back to sign in'),
          ),
        ),
      ],
    );
  }
}
