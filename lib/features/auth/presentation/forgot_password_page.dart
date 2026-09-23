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
import 'package:folo/features/auth/presentation/widgets/submit_button.dart';
import 'package:go_router/go_router.dart';

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
    context.go(Routes.checkInboxLocation(reason: 'reset', email: email));
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return AuthScaffold(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.sm,
          children: [
            Text('Reset your password', style: text.headlineSmall),
            Text(
              'Enter the address you signed up with and we will send a link.',
              style: text.bodyMedium,
            ),
          ],
        ),
        if (_failure != null) FormError(authFailureCopy(_failure!)),
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppSpacing.md,
            children: [
              TextFormField(
                controller: _email,
                enabled: !_busy,
                validator: validateEmail,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                onFieldSubmitted: (_) => _busy ? null : _submit(),
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              SubmitButton(
                label: 'Send reset link',
                busy: _busy,
                onPressed: _submit,
              ),
            ],
          ),
        ),
        Center(
          child: TextButton(
            onPressed: () => context.go(Routes.login),
            child: const Text('Back to sign in'),
          ),
        ),
      ],
    );
  }
}
