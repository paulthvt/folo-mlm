import 'dart:async';
import 'dart:io';

import 'package:folo/features/auth/domain/auth_failure.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Translates anything thrown by `supabase_flutter` into an [AuthFailure].
///
/// Matches on `code` first — the messages are server copy and change without
/// notice.
AuthFailure authFailureFrom(Object error) {
  if (error is AuthFailure) return error;
  if (error is AuthRetryableFetchException) return AuthFailure.network;
  if (error is AuthException) {
    if (error.statusCode == '429') return AuthFailure.rateLimited;
    switch (error.code) {
      case 'invalid_credentials':
      case 'invalid_grant':
        return AuthFailure.invalidCredentials;
      case 'email_not_confirmed':
        return AuthFailure.emailNotConfirmed;
      case 'same_password':
        return AuthFailure.samePassword;
      case 'weak_password':
        return AuthFailure.weakPassword;
      case 'over_email_send_rate_limit':
      case 'over_request_rate_limit':
        return AuthFailure.rateLimited;
      case 'user_already_exists':
      case 'email_exists':
        // Deliberately not surfaced as its own failure: telling the user the
        // address is taken is an account-enumeration oracle.
        return AuthFailure.unknown;
    }
    return AuthFailure.unknown;
  }
  if (error is SocketException || error is TimeoutException) {
    return AuthFailure.network;
  }
  return AuthFailure.unknown;
}
