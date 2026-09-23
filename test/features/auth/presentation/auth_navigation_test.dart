import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folo/app/app.dart';
import 'package:folo/features/auth/data/auth_repository.dart';
import 'package:folo/features/auth/domain/auth_failure.dart';

import '../fake_auth_repository.dart';

/// Navigation between auth screens goes through the real router: every
/// transition uses `context.go`, so nothing can be popped and the back control
/// has to be explicit.
Widget _app(FakeAuthRepository fake) => ProviderScope(
  overrides: [authRepositoryProvider.overrideWithValue(fake)],
  child: const FoloApp(),
);

Future<void> _openLogin(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.tap(find.text('Continue with email'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the back control on sign-in returns to welcome', (tester) async {
    await tester.pumpWidget(_app(FakeAuthRepository()));
    await _openLogin(tester);
    expect(find.text('Welcome back'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.text('Continue with email'), findsOneWidget);
  });

  testWidgets('an unconfirmed email lands on check your inbox, which can '
      'resend the link', (tester) async {
    final fake = FakeAuthRepository()..failWith = AuthFailure.emailNotConfirmed;
    await tester.pumpWidget(_app(fake));
    await _openLogin(tester);

    await tester.enterText(
      find.byType(TextFormField).first,
      'pauline@example.com',
    );
    await tester.enterText(find.byType(TextFormField).last, 'hunter22');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Check your inbox'), findsOneWidget);
    expect(find.text('Resend email'), findsOneWidget);
  });
}
