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

/// Registration. The first name goes into the auth user's metadata; there is no
/// profiles table yet, and nothing in the app queries another person's name.
class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _form = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _busy = false;
  AuthFailure? _failure;

  @override
  void dispose() {
    _firstName.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;

    final email = normalizeEmail(_email.text);
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .signUp(
            email: email,
            password: _password.text,
            firstName: _firstName.text.trim(),
          );
      if (!mounted) return;
      // Email confirmation is on, so there is no session yet — the next step is
      // the user's inbox.
      context.go(Routes.checkInboxLocation(reason: 'confirm', email: email));
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
        Text('Create your account', style: text.headlineSmall),
        if (_failure != null) FormError(authFailureCopy(_failure!)),
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppSpacing.md,
            children: [
              TextFormField(
                controller: _firstName,
                enabled: !_busy,
                validator: validateFirstName,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.givenName],
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'First name'),
              ),
              TextFormField(
                controller: _email,
                enabled: !_busy,
                validator: validateEmail,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              PasswordField(
                controller: _password,
                label: 'Password',
                helper: 'At least 8 characters',
                enabled: !_busy,
                validator: validatePassword,
                onSubmitted: (_) => _busy ? null : _submit(),
              ),
              SubmitButton(
                label: 'Create account',
                busy: _busy,
                onPressed: _submit,
              ),
            ],
          ),
        ),
        Text(
          'By creating an account you agree to the terms and the privacy '
          'policy.',
          style: text.bodySmall,
        ),
        // Wrap, not Row: "Already have an account?" plus the button is wider
        // than the 400-wide column at larger text scales.
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('Already have an account?', style: text.bodySmall),
            TextButton(
              onPressed: () => context.go(Routes.login),
              child: const Text('Sign in'),
            ),
          ],
        ),
      ],
    );
  }
}
