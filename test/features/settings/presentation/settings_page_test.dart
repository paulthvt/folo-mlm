import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folo/app/app.dart';
import 'package:folo/app/shell/app_shell.dart';
import 'package:folo/features/auth/data/auth_repository.dart';
import 'package:folo/features/auth/domain/account.dart';
import 'package:folo/features/auth/domain/auth_failure.dart';
import 'package:folo/features/settings/presentation/settings_page.dart';

import '../../auth/fake_auth_repository.dart';

/// Through the real app, so the redirect after sign-out and the locale switch
/// are part of what is tested.
Future<FakeAuthRepository> _openSettings(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final fake = FakeAuthRepository()
    ..session = true
    ..account = const Account(firstName: 'Pauline', email: 'p@example.com');
  addTearDown(fake.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(fake)],
      child: const FoloApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byType(AccountButton));
  await tester.pumpAndSettle();
  return fake;
}

void main() {
  testWidgets('shows the account', (tester) async {
    await _openSettings(tester);

    expect(find.text('Pauline'), findsOneWidget);
    expect(find.text('p@example.com'), findsOneWidget);
  });

  testWidgets('choosing a language saves it and switches the app', (
    tester,
  ) async {
    final fake = await _openSettings(tester);

    // By key: French names itself only once its translations are pulled.
    await tester.tap(find.byKey(const ValueKey('language-fr')));
    await tester.pumpAndSettle();

    expect(fake.calls, ['updateLocale(fr)']);
    final context = tester.element(find.byType(SettingsPage));
    expect(Localizations.localeOf(context), const Locale('fr'));

    await tester.tap(find.text('Same as this device'));
    await tester.pumpAndSettle();
    expect(fake.calls.last, 'updateLocale(null)');
  });

  testWidgets('sign out asks the repository', (tester) async {
    final fake = await _openSettings(tester);

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(fake.calls, ['signOut()']);
  });

  testWidgets('delete asks first; cancel deletes nothing', (tester) async {
    final fake = await _openSettings(tester);

    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(fake.calls, isEmpty);
  });

  testWidgets('confirmed delete removes the account and lands on welcome', (
    tester,
  ) async {
    final fake = await _openSettings(tester);

    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(fake.calls, ['deleteAccount()']);
    expect(find.text('Continue with email'), findsOneWidget);
  });

  testWidgets('a failed delete says so and stays', (tester) async {
    final fake = await _openSettings(tester);
    fake.failWith = AuthFailure.network;

    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(
      find.text('We could not reach Folo. Check your connection.'),
      findsOneWidget,
    );
    expect(find.byType(SettingsPage), findsOneWidget);
  });
}
