import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folo/app/router/routes.dart';
import 'package:folo/app/theme/app_theme.dart';
import 'package:folo/features/auth/data/auth_repository.dart';
import 'package:folo/features/auth/domain/auth_failure.dart';
import 'package:folo/features/auth/presentation/reset_password_page.dart';
import 'package:folo/features/auth/presentation/widgets/password_field.dart';
import 'package:go_router/go_router.dart';

import '../fake_auth_repository.dart';

GoRouter _router() => GoRouter(
  initialLocation: Routes.resetPassword,
  routes: [
    GoRoute(
      path: Routes.resetPassword,
      builder: (context, state) => const ResetPasswordPage(),
    ),
    GoRoute(
      path: Routes.dashboard,
      builder: (context, state) => const Text('Dashboard'),
    ),
  ],
);

Widget _host(GoRouter router, FakeAuthRepository fake) => ProviderScope(
  overrides: [authRepositoryProvider.overrideWithValue(fake)],
  child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
);

String _location(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.toString();

Future<void> _fill(
  WidgetTester tester, {
  required String password,
  required String confirmation,
}) async {
  final fields = find.byType(PasswordField);
  await tester.enterText(fields.at(0), password);
  await tester.enterText(fields.at(1), confirmation);
}

void main() {
  testWidgets('has no back button — a deep link has no previous screen', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_router(), FakeAuthRepository()));

    expect(find.text('Choose a new password'), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
  });

  testWidgets('a mismatch blocks the request', (tester) async {
    final fake = FakeAuthRepository();
    await tester.pumpWidget(_host(_router(), fake));

    await _fill(tester, password: 'hunter22', confirmation: 'hunter23');
    await tester.tap(find.text('Save and sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Those passwords do not match.'), findsOneWidget);
    expect(fake.calls, isEmpty);
  });

  testWidgets('a short password blocks the request', (tester) async {
    final fake = FakeAuthRepository();
    await tester.pumpWidget(_host(_router(), fake));

    await _fill(tester, password: 'hunter2', confirmation: 'hunter2');
    await tester.tap(find.text('Save and sign in'));
    await tester.pumpAndSettle();

    expect(find.text('At least 8 characters.'), findsOneWidget);
    expect(fake.calls, isEmpty);
  });

  testWidgets('saving the password lands on the dashboard', (tester) async {
    final fake = FakeAuthRepository();
    final router = _router();
    await tester.pumpWidget(_host(router, fake));

    await _fill(tester, password: 'hunter22', confirmation: 'hunter22');
    await tester.tap(find.text('Save and sign in'));
    await tester.pumpAndSettle();

    expect(fake.calls, ['updatePassword(hunter22)']);
    expect(_location(router), Routes.dashboard);
  });

  testWidgets('an expired link shows a form error and stays put', (
    tester,
  ) async {
    final fake = FakeAuthRepository()..failWith = AuthFailure.unknown;
    final router = _router();
    await tester.pumpWidget(_host(router, fake));

    await _fill(tester, password: 'hunter22', confirmation: 'hunter22');
    await tester.tap(find.text('Save and sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Something went wrong. Try again.'), findsOneWidget);
    expect(_location(router), Routes.resetPassword);
  });

  testWidgets('reusing the current password says what to change', (
    tester,
  ) async {
    final fake = FakeAuthRepository()..failWith = AuthFailure.samePassword;
    await tester.pumpWidget(_host(_router(), fake));

    await _fill(tester, password: 'hunter22', confirmation: 'hunter22');
    await tester.tap(find.text('Save and sign in'));
    await tester.pumpAndSettle();

    expect(
      find.text('That is already your password. Choose a different one.'),
      findsOneWidget,
    );
  });

  testWidgets('a rejected weak password says what to change', (tester) async {
    final fake = FakeAuthRepository()..failWith = AuthFailure.weakPassword;
    await tester.pumpWidget(_host(_router(), fake));

    await _fill(tester, password: 'password', confirmation: 'password');
    await tester.tap(find.text('Save and sign in'));
    await tester.pumpAndSettle();

    expect(
      find.text('That password is too easy to guess. Choose another one.'),
      findsOneWidget,
    );
  });

  testWidgets('the user is never trapped: leaving signs the session out', (
    tester,
  ) async {
    final fake = FakeAuthRepository();
    await tester.pumpWidget(_host(_router(), fake));

    await tester.tap(find.text('Back to sign in'));
    await tester.pumpAndSettle();

    expect(fake.calls, ['signOut()']);
  });
}
