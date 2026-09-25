import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folo/app/router/routes.dart';
import 'package:folo/app/theme/app_theme.dart';
import 'package:folo/features/auth/data/auth_repository.dart';
import 'package:folo/features/auth/domain/auth_failure.dart';
import 'package:folo/features/auth/presentation/forgot_password_page.dart';
import 'package:folo/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

import '../fake_auth_repository.dart';

GoRouter _router() => GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => const ForgotPasswordPage()),
    GoRoute(
      path: Routes.checkInbox,
      builder: (context, state) => const SizedBox.shrink(),
    ),
  ],
);

Widget _host(GoRouter router, FakeAuthRepository fake) => ProviderScope(
  overrides: [authRepositoryProvider.overrideWithValue(fake)],
  child: MaterialApp.router(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: AppTheme.light,
    routerConfig: router,
  ),
);

String _location(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.toString();

Future<void> _request(WidgetTester tester, String email) async {
  await tester.enterText(find.byType(TextFormField), email);
  await tester.tap(find.text('Send reset link'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders the request form', (tester) async {
    await tester.pumpWidget(_host(_router(), FakeAuthRepository()));

    expect(find.text('Reset your password'), findsOneWidget);
    expect(find.text('Back to sign in'), findsOneWidget);
  });

  testWidgets('sends the reset and confirms on check-inbox', (tester) async {
    final fake = FakeAuthRepository();
    final router = _router();
    await tester.pumpWidget(_host(router, fake));

    await _request(tester, ' Pauline@Example.com ');

    expect(fake.calls, ['sendPasswordReset(pauline@example.com)']);
    expect(
      _location(router),
      Routes.checkInboxLocation(reason: 'reset', email: 'pauline@example.com'),
    );
  });

  testWidgets(
    'an unknown address is confirmed identically — no enumeration oracle',
    (tester) async {
      // The server answers the same way for an address it does not know; if it
      // ever errors, the screen must still not say so.
      final fake = FakeAuthRepository()..failWith = AuthFailure.unknown;
      final router = _router();
      await tester.pumpWidget(_host(router, fake));

      await _request(tester, 'nobody@example.com');

      expect(
        _location(router),
        Routes.checkInboxLocation(reason: 'reset', email: 'nobody@example.com'),
      );
      expect(find.textContaining('went wrong'), findsNothing);
    },
  );

  testWidgets('a connection failure is reported, not silently confirmed', (
    tester,
  ) async {
    final fake = FakeAuthRepository()..failWith = AuthFailure.network;
    final router = _router();
    await tester.pumpWidget(_host(router, fake));

    await _request(tester, 'pauline@example.com');

    expect(_location(router), '/');
    expect(
      find.text('We could not reach Folo. Check your connection.'),
      findsOneWidget,
    );
  });
}
