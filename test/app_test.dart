import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folo/app/app.dart';
import 'package:folo/core/layout/breakpoints.dart';

void main() {
  testWidgets('app boots to Today', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: FoloApp()));
    await tester.pumpAndSettle();

    // No repository yet, so Today is legitimately empty.
    expect(find.text('You are up to date'), findsOneWidget);
  });

  test('breakpoints map widths to layout classes', () {
    expect(Breakpoints.of(375), ScreenSize.mobile);
    expect(Breakpoints.of(Breakpoints.tablet), ScreenSize.tablet);
    expect(Breakpoints.of(Breakpoints.desktop), ScreenSize.desktop);
    expect(ScreenSize.mobile.usesSideNavigation, isFalse);
    expect(ScreenSize.desktop.usesSideNavigation, isTrue);
  });
}
