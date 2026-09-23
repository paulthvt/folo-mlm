import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folo/app/theme/app_theme.dart';
import 'package:folo/features/auth/data/auth_repository.dart';
import 'package:folo/features/auth/domain/auth_failure.dart';
import 'package:folo/features/auth/presentation/check_inbox_page.dart';

import '../fake_auth_repository.dart';

Widget _host(
  FakeAuthRepository fake, {
  String reason = 'confirm',
  String email = 'pauline@example.com',
}) => ProviderScope(
  overrides: [authRepositoryProvider.overrideWithValue(fake)],
  child: MaterialApp(
    theme: AppTheme.light,
    home: CheckInboxPage(reason: reason, email: email),
  ),
);

void main() {
  testWidgets('confirmation copy names the address', (tester) async {
    await tester.pumpWidget(_host(FakeAuthRepository()));

    expect(find.text('Check your inbox'), findsOneWidget);
    expect(find.textContaining('pauline@example.com'), findsOneWidget);
    expect(find.text('Resend email'), findsOneWidget);
  });

  testWidgets('reset copy never confirms that the account exists', (
    tester,
  ) async {
    await tester.pumpWidget(_host(FakeAuthRepository(), reason: 'reset'));

    expect(
      find.text('If an account exists for that address, we sent a link.'),
      findsOneWidget,
    );
  });

  testWidgets('resend on a confirmation asks for the signup email again', (
    tester,
  ) async {
    final fake = FakeAuthRepository();
    await tester.pumpWidget(_host(fake));

    await tester.tap(find.text('Resend email'));
    await tester.pumpAndSettle();

    expect(fake.calls, ['resendConfirmation(pauline@example.com)']);
    expect(find.text('Sent. It can take a minute to arrive.'), findsOneWidget);
  });

  testWidgets('resend on a reset asks for another reset link', (tester) async {
    final fake = FakeAuthRepository();
    await tester.pumpWidget(_host(fake, reason: 'reset'));

    await tester.tap(find.text('Resend email'));
    await tester.pumpAndSettle();

    expect(fake.calls, ['sendPasswordReset(pauline@example.com)']);
  });

  testWidgets('an unknown reason falls back to the confirmation copy', (
    tester,
  ) async {
    await tester.pumpWidget(_host(FakeAuthRepository(), reason: 'nonsense'));

    expect(find.text('Check your inbox'), findsOneWidget);
  });

  testWidgets('a missing address still renders and can still resend', (
    tester,
  ) async {
    final fake = FakeAuthRepository();
    await tester.pumpWidget(_host(fake, email: ''));

    expect(find.text('Check your inbox'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Resend email'), findsNothing);
  });

  testWidgets('resend spam surfaces the rate limit, not a generic error', (
    tester,
  ) async {
    final fake = FakeAuthRepository()..failWith = AuthFailure.rateLimited;
    await tester.pumpWidget(_host(fake));

    await tester.tap(find.text('Resend email'));
    await tester.pumpAndSettle();

    expect(
      find.text('Too many attempts. Try again in a few minutes.'),
      findsOneWidget,
    );
    expect(find.textContaining('went wrong'), findsNothing);
  });
}
