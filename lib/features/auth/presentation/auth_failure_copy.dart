import 'package:folo/features/auth/domain/auth_failure.dart';

/// User-facing copy for a failure. Lives in `presentation` because it is copy,
/// not logic.
///
/// [AuthFailure.invalidCredentials] deliberately does not say which field was
/// wrong and does not reveal whether the account exists.
String authFailureCopy(AuthFailure failure) => switch (failure) {
  AuthFailure.invalidCredentials => 'Email or password is incorrect.',
  AuthFailure.emailNotConfirmed =>
    'Confirm your email first. We can send the link again.',
  AuthFailure.samePassword =>
    'That is already your password. Choose a different one.',
  AuthFailure.weakPassword =>
    'That password is too easy to guess. Choose another one.',
  AuthFailure.rateLimited => 'Too many attempts. Try again in a few minutes.',
  AuthFailure.network => 'We could not reach Folo. Check your connection.',
  AuthFailure.unknown => 'Something went wrong. Try again.',
};
