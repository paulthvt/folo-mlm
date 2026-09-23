import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folo/app/theme/app_theme.dart';
import 'package:folo/features/auth/data/auth_repository.dart';
import 'package:folo/features/auth/domain/auth_failure.dart';
import 'package:folo/features/dashboard/presentation/dashboard_page.dart';

import '../../auth/fake_auth_repository.dart';

Widget _host(FakeAuthRepository fake) => ProviderScope(
  overrides: [authRepositoryProvider.overrideWithValue(fake)],
  child: MaterialApp(theme: AppTheme.light, home: const DashboardPage()),
);

void main() {
  testWidgets('signs out from the trailing action', (tester) async {
    final fake = FakeAuthRepository()..session = true;
    await tester.pumpWidget(_host(fake));

    await tester.tap(find.byTooltip('Sign out'));
    await tester.pumpAndSettle();

    expect(fake.calls, ['signOut()']);
  });

  testWidgets('a failed sign out does not crash the screen', (tester) async {
    final fake = FakeAuthRepository()
      ..session = true
      ..failWith = AuthFailure.network;
    await tester.pumpWidget(_host(fake));

    await tester.tap(find.byTooltip('Sign out'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Folo'), findsOneWidget);
  });
}
