import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folo/app/app.dart';
import 'package:folo/core/layout/breakpoints.dart';
import 'package:folo/features/auth/data/auth_repository.dart';

import 'features/auth/fake_auth_repository.dart';

void main() {
  testWidgets('a signed-out launch lands on the welcome screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        ],
        child: const FoloApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Continue with email'), findsOneWidget);
  });

  testWidgets('a restored session lands on the dashboard', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository()..session = true,
          ),
        ],
        child: const FoloApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Folo'), findsOneWidget);
  });

  test('breakpoints map widths to layout classes', () {
    expect(Breakpoints.of(375), ScreenSize.mobile);
    expect(Breakpoints.of(Breakpoints.tablet), ScreenSize.tablet);
    expect(Breakpoints.of(Breakpoints.desktop), ScreenSize.desktop);
    expect(ScreenSize.mobile.usesSideNavigation, isFalse);
    expect(ScreenSize.desktop.usesSideNavigation, isTrue);
  });
}
