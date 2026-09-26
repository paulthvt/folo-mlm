import 'package:flutter_test/flutter_test.dart';
import 'package:folo/features/today/presentation/today_preview.dart';
import 'package:material_ui/material_ui.dart';

/// `flutter widget-preview start` builds each `@Preview` function directly, so
/// a preview's own `MaterialApp` is the only host its subject gets. The moment a
/// component reads `AppLocalizations`, a preview without the delegates throws —
/// and nothing else in the suite would notice, because no shipped screen goes
/// through these builders.
///
/// The Today previews are the ones that cover it: they render `ActionItem`,
/// `SectionHeader` and `EmptyState`, which between them read every localized
/// string the shared components use. The Components sheet is left out — it
/// trips assertions of its own at any viewport, which is not this file's
/// subject.
void main() {
  final previews = <String, Widget Function()>{
    'Today mobile light': todayMobileLight,
    'Today mobile dark': todayMobileDark,
    'Today desktop light': todayDesktopLight,
    'Today desktop dark': todayDesktopDark,
    'Today empty light': todayEmptyLight,
  };

  for (final MapEntry(key: name, value: preview) in previews.entries) {
    testWidgets('$name renders', (tester) async {
      tester.view
        ..physicalSize = const Size(1440, 2400)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(preview());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  }
}
