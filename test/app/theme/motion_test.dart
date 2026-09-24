import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folo/app/app.dart';
import 'package:folo/app/theme/app_theme.dart';
import 'package:folo/features/auth/data/auth_repository.dart';

import '../../features/auth/fake_auth_repository.dart';

/// Reads `context.motion` under a chosen `disableAnimations` flag.
Future<Duration> _resolve(
  WidgetTester tester, {
  required bool disableAnimations,
  required Duration duration,
}) async {
  late Duration resolved;
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Builder(
        builder: (context) {
          resolved = context.motion(duration);
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return resolved;
}

void main() {
  testWidgets('a duration passes through when motion is allowed', (
    tester,
  ) async {
    final resolved = await _resolve(
      tester,
      disableAnimations: false,
      duration: AppMotion.slow,
    );

    expect(resolved, AppMotion.slow);
  });

  testWidgets('reduce motion collapses every duration to the 120ms fade', (
    tester,
  ) async {
    for (final duration in [
      AppMotion.quick,
      AppMotion.medium,
      AppMotion.slow,
    ]) {
      final resolved = await _resolve(
        tester,
        disableAnimations: true,
        duration: duration,
      );

      expect(resolved, AppMotion.fast);
    }
  });

  testWidgets('every route animates', (tester) async {
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
    // Mid-transition: the arriving page is on screen but not yet opaque.
    await tester.pump();
    await tester.pump(AppMotion.slow ~/ 2);

    final fade = tester.widget<FadeTransition>(
      find
          .ancestor(
            of: find.text('Welcome back'),
            matching: find.byType(FadeTransition),
          )
          .last,
    );
    expect(fade.opacity.value, greaterThan(0));
    expect(fade.opacity.value, lessThan(1));

    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
  });
}
