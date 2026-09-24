import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folo/app/app.dart';
import 'package:folo/features/auth/data/auth_repository.dart';

import '../../features/auth/fake_auth_repository.dart';

/// go_router picks `NoTransitionPage` whenever it cannot find the `MaterialApp`
/// class it was compiled against — which is every time here, because it looks
/// for `package:material_ui`'s and the app builds `flutter/material`'s. The
/// symptom is silent: screens still work, they just stop animating. So assert
/// the page type rather than the animation.
void main() {
  testWidgets('routes build a page that carries the platform transition', (
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

    await tester.tap(find.text('Continue with email'));
    await tester.pumpAndSettle();

    final pages = tester
        .state<NavigatorState>(find.byType(Navigator).last)
        .widget
        .pages;

    expect(pages, isNotEmpty);
    expect(pages, everyElement(isA<MaterialPage<void>>()));
  });
}
