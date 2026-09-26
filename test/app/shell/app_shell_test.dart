import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folo/app/app.dart';
import 'package:folo/app/shell/app_shell.dart';
import 'package:folo/features/auth/data/auth_repository.dart';
import 'package:folo/features/auth/domain/account.dart';
import 'package:folo/features/settings/presentation/settings_page.dart';

import '../../features/auth/fake_auth_repository.dart';

Future<void> _launch(WidgetTester tester, Size size) async {
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
}

void main() {
  testWidgets('mobile: no sidebar, Settings opens from the top bar', (
    tester,
  ) async {
    await _launch(tester, const Size(390, 844));

    expect(find.text('Folo'), findsNothing);
    await tester.tap(find.byType(AccountButton));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsPage), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
  });

  testWidgets('tablet: an icon rail, its items labelled for screen readers', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _launch(tester, const Size(800, 1000));

    expect(find.byType(AccountButton), findsNothing);
    expect(find.text('Folo'), findsNothing);
    // Activated the way a screen reader would, through the semantics action.
    tester.semantics.tap(find.semantics.byLabel('Settings'));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsPage), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('desktop: the sidebar, its account block opens Settings', (
    tester,
  ) async {
    await _launch(tester, const Size(1440, 900));

    expect(find.text('Folo'), findsOneWidget);
    expect(find.byType(AccountButton), findsNothing);
    await tester.tap(find.text('Pauline'));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsPage), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
  });
}
