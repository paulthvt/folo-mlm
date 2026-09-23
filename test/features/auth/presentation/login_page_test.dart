import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folo/app/theme/app_theme.dart';
import 'package:folo/features/auth/data/auth_repository.dart';
import 'package:folo/features/auth/domain/auth_failure.dart';
import 'package:folo/features/auth/presentation/login_page.dart';

import '../fake_auth_repository.dart';

Widget _host(
  FakeAuthRepository fake, {
  GlobalKey<NavigatorState>? navigator,
  double textScale = 1,
}) => ProviderScope(
  overrides: [authRepositoryProvider.overrideWithValue(fake)],
  child: MaterialApp(
    theme: AppTheme.light,
    navigatorKey: navigator,
    builder: (context, child) => MediaQuery.withClampedTextScaling(
      minScaleFactor: textScale,
      maxScaleFactor: textScale,
      child: child!,
    ),
    home: const LoginPage(),
  ),
);

Future<void> _fill(
  WidgetTester tester, {
  required String email,
  required String password,
}) async {
  await tester.enterText(find.byType(TextFormField).first, email);
  await tester.enterText(find.byType(TextFormField).last, password);
}

void main() {
  testWidgets('renders the sign-in form', (tester) async {
    await tester.pumpWidget(_host(FakeAuthRepository()));

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
  });

  testWidgets('will not call the repository with an invalid email', (
    tester,
  ) async {
    final fake = FakeAuthRepository();
    await tester.pumpWidget(_host(fake));

    await _fill(tester, email: 'pauline', password: 'hunter22');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('That address does not look right.'), findsOneWidget);
    expect(fake.calls, isEmpty);
  });

  testWidgets('a rejected sign-in shows the neutral form error', (
    tester,
  ) async {
    final fake = FakeAuthRepository()
      ..failWith = AuthFailure.invalidCredentials;
    await tester.pumpWidget(_host(fake));

    await _fill(tester, email: 'pauline@example.com', password: 'wrongpass');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Email or password is incorrect.'), findsOneWidget);
    expect(find.textContaining('password'), findsWidgets);
    // Nothing on screen may say whether the account exists.
    expect(find.textContaining('No account'), findsNothing);
  });

  testWidgets('normalizes the email before signing in', (tester) async {
    final fake = FakeAuthRepository();
    await tester.pumpWidget(_host(fake));

    await _fill(tester, email: '  Pauline@Example.COM ', password: 'hunter22');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(fake.calls, ['signIn(pauline@example.com, hunter22)']);
  });

  testWidgets('a request that outlives the screen does not throw', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    final fake = FakeAuthRepository()..gate = Completer<void>();
    await tester.pumpWidget(_host(fake, navigator: navigator));

    await _fill(tester, email: 'pauline@example.com', password: 'hunter22');
    await tester.tap(find.text('Sign in'));
    await tester.pump();

    navigator.currentState!.pop();
    await tester.pumpAndSettle();

    fake.gate!.complete();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('two taps in the same frame send one request', (tester) async {
    final fake = FakeAuthRepository()..gate = Completer<void>();
    await tester.pumpWidget(_host(fake));

    await _fill(tester, email: 'pauline@example.com', password: 'hunter22');
    await tester.tap(find.text('Sign in'));
    await tester.tap(find.text('Sign in'));
    await tester.pump();

    fake.gate!.complete();
    await tester.pumpAndSettle();

    expect(fake.calls, ['signIn(pauline@example.com, hunter22)']);
  });

  testWidgets('the footer fits the column at large text sizes', (tester) async {
    await tester.pumpWidget(_host(FakeAuthRepository(), textScale: 2));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
