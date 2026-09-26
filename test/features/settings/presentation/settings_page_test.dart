import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folo/app/app.dart';
import 'package:folo/app/shell/app_shell.dart';
import 'package:folo/core/layout/breakpoints.dart';
import 'package:folo/features/auth/data/auth_repository.dart';
import 'package:folo/features/auth/domain/account.dart';
import 'package:folo/features/auth/domain/auth_failure.dart';
import 'package:folo/features/settings/presentation/settings_page.dart';
import 'package:folo/l10n/app_localizations.dart';

import '../../auth/fake_auth_repository.dart';

/// Through the real app, so the redirect after sign-out and the locale switch
/// are part of what is tested.
Future<FakeAuthRepository> _openSettings(
  WidgetTester tester, {
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
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
  switch (Breakpoints.of(size.width)) {
    case ScreenSize.mobile:
      await tester.tap(find.byType(AccountButton));
    case ScreenSize.tablet:
      // The rail shows only an avatar; its label is for screen readers.
      final semantics = tester.ensureSemantics();
      tester.semantics.tap(find.semantics.byLabel('Settings'));
      semantics.dispose();
    case ScreenSize.desktop:
      await tester.tap(find.text('Pauline'));
  }
  await tester.pumpAndSettle();
  return fake;
}

Future<FakeAuthRepository> _openSection(WidgetTester tester, String row) async {
  final fake = await _openSettings(tester);
  await tester.tap(find.text(row));
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
    final fake = await _openSection(tester, 'Language');

    // By key: French names itself only once its translations are pulled.
    await tester.tap(find.byKey(const ValueKey('language-fr')));
    await tester.pumpAndSettle();

    expect(fake.calls, ['updateLocale(fr)']);
    final context = tester.element(find.byType(SettingsPage));
    expect(Localizations.localeOf(context), const Locale('fr'));

    // The screen itself is now in French.
    final fr = lookupAppLocalizations(const Locale('fr'));
    await tester.tap(find.text(fr.settingsLanguageSystem));
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
    final fake = await _openSection(tester, 'Pauline');

    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(fake.calls, isEmpty);
  });

  testWidgets('confirmed delete removes the account and lands on welcome', (
    tester,
  ) async {
    final fake = await _openSection(tester, 'Pauline');

    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(fake.calls, ['deleteAccount()']);
    expect(find.text('Continue with email'), findsOneWidget);
  });

  testWidgets('a failed delete says so and stays', (tester) async {
    final fake = await _openSection(tester, 'Pauline');
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

  testWidgets('the list shows the language in use', (tester) async {
    await _openSettings(tester);

    expect(find.text('Same as this device'), findsOneWidget);
  });

  testWidgets('editing the name saves it', (tester) async {
    final fake = await _openSection(tester, 'Pauline');

    await tester.tap(find.text('First name'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '  Paula ');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(fake.calls, ['updateFirstName(Paula)']);
    expect(find.text('Paula'), findsOneWidget);
  });

  testWidgets('an empty name is refused', (tester) async {
    final fake = await _openSection(tester, 'Pauline');

    await tester.tap(find.text('First name'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), ' ');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Enter your first name.'), findsOneWidget);
    expect(fake.calls, isEmpty);
  });

  testWidgets('mobile: delete confirms in a bottom sheet', (tester) async {
    await _openSection(tester, 'Pauline');
    // A gesture/navigation bar at the bottom of the screen.
    tester.view.padding = const FakeViewPadding(bottom: 48);

    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(tester.getBottomLeft(find.text('Cancel')).dy, lessThan(844 - 48));
  });

  testWidgets('desktop: the list beside the open section', (tester) async {
    await _openSettings(tester, size: const Size(1440, 900));

    // Account is open until another section is chosen.
    expect(find.text('Delete account'), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);

    await tester.tap(find.text('Language'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('language-fr')), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
  });

  testWidgets('desktop: delete confirms in a dialog', (tester) async {
    await _openSettings(tester, size: const Size(1440, 900));

    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
  });

  testWidgets('tablet: a section opens on its own screen', (tester) async {
    await _openSettings(tester, size: const Size(800, 1000));

    expect(find.byType(BackButton), findsNothing);
    await tester.tap(find.text('Language'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('language-fr')), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Sign out'), findsOneWidget);
  });
}
