import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/launch_splash.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/core/ui/loomia_mark.dart';
import 'package:material_ui/material_ui.dart';

Widget _host({bool reduceMotion = false}) => MaterialApp(
  theme: AppTheme.light,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
    child: LaunchSplash(child: child!),
  ),
  home: const Text('app'),
);

List<double> _dots(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(
    find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter is LoomiaMarkPainter,
    ),
  );
  return (paint.painter! as LoomiaMarkPainter).dots;
}

void main() {
  testWidgets('dots grow in smallest first, then the splash leaves', (
    tester,
  ) async {
    await tester.pumpWidget(_host());
    expect(find.text('app'), findsOneWidget, reason: 'built underneath');
    expect(_dots(tester), [0, 0, 0]);

    await tester.pump(const Duration(milliseconds: 180));
    final [small, middle, large] = _dots(tester);
    expect(small, greaterThan(middle));
    expect(middle, greaterThan(large));

    await tester.pump(const Duration(milliseconds: 320));
    expect(_dots(tester), [1, 1, 1]);

    await tester.pumpAndSettle();
    expect(
      find
          .byType(CustomPaint)
          .evaluate()
          .where((e) => (e.widget as CustomPaint).painter is LoomiaMarkPainter),
      isEmpty,
    );
  });

  testWidgets('reduce motion: the dots are already there, only a fade', (
    tester,
  ) async {
    await tester.pumpWidget(_host(reduceMotion: true));
    await tester.pump();
    expect(_dots(tester), [1, 1, 1]);

    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump();
    expect(find.byType(LaunchSplash), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is LoomiaMarkPainter,
      ),
      findsNothing,
    );
  });
}
