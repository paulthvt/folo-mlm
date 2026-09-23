import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:folo/features/auth/data/auth_failure_mapping.dart';
import 'package:folo/features/auth/domain/auth_failure.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('wrong password maps to invalidCredentials', () {
    const error = AuthApiException(
      'Invalid login credentials',
      code: 'invalid_credentials',
      statusCode: '400',
    );
    expect(authFailureFrom(error), AuthFailure.invalidCredentials);
  });

  test('unconfirmed email maps to emailNotConfirmed', () {
    const error = AuthApiException(
      'Email not confirmed',
      code: 'email_not_confirmed',
      statusCode: '400',
    );
    expect(authFailureFrom(error), AuthFailure.emailNotConfirmed);
  });

  test('email send limit maps to rateLimited', () {
    const error = AuthApiException(
      'rate limit',
      code: 'over_email_send_rate_limit',
      statusCode: '429',
    );
    expect(authFailureFrom(error), AuthFailure.rateLimited);
  });

  test('any 429 maps to rateLimited even without a known code', () {
    const error = AuthApiException('slow down', statusCode: '429');
    expect(authFailureFrom(error), AuthFailure.rateLimited);
  });

  test('a retryable fetch failure maps to network', () {
    expect(
      authFailureFrom(AuthRetryableFetchException(message: 'offline')),
      AuthFailure.network,
    );
  });

  test('a socket failure maps to network', () {
    expect(
      authFailureFrom(const SocketException('no route to host')),
      AuthFailure.network,
    );
  });

  test('anything unrecognised maps to unknown', () {
    expect(authFailureFrom(StateError('boom')), AuthFailure.unknown);
  });

  test('an AuthFailure passes through unchanged', () {
    expect(authFailureFrom(AuthFailure.network), AuthFailure.network);
  });
}
