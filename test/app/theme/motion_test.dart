import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folo/app/theme/app_theme.dart';
import 'package:folo/core/ui/folo_progress_bar.dart';

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

Widget _bar(double value) => MaterialApp(
  theme: AppTheme.light,
  home: Scaffold(body: FoloProgressBar(value: value)),
);

double? _barValue(WidgetTester tester) => tester
    .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
    .value;

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

  testWidgets('progress grows into its new value instead of jumping', (
    tester,
  ) async {
    await tester.pumpWidget(_bar(0.2));
    expect(_barValue(tester), 0.2);

    await tester.pumpWidget(_bar(0.8));
    await tester.pump(AppMotion.medium ~/ 2);

    expect(_barValue(tester), greaterThan(0.2));
    expect(_barValue(tester), lessThan(0.8));

    await tester.pumpAndSettle();
    expect(_barValue(tester), 0.8);
  });
}
