import 'package:flutter_test/flutter_test.dart';
import 'package:folo/app/theme/app_colors.dart';
import 'package:folo/app/theme/app_spacing.dart';
import 'package:folo/app/theme/app_theme.dart';
import 'package:folo/app/theme/app_typography.dart';
import 'package:material_ui/material_ui.dart';

/// Captures the theme as a widget actually sees it.
Future<(ThemeData, FoloColors)> _resolve(
  WidgetTester tester,
  ThemeData theme,
) async {
  late ThemeData resolved;
  late FoloColors folo;
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Builder(
        builder: (context) {
          resolved = Theme.of(context);
          folo = FoloColors.of(context);
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return (resolved, folo);
}

void main() {
  for (final (name, theme, expected) in <(String, ThemeData, FoloColors)>[
    ('light', AppTheme.light, FoloColors.light),
    ('dark', AppTheme.dark, FoloColors.dark),
  ]) {
    group(name, () {
      testWidgets('FoloColors resolves from the theme', (tester) async {
        final (resolved, folo) = await _resolve(tester, theme);

        expect(folo.borderSubtle, expected.borderSubtle);
        expect(folo.accent, expected.accent);
        expect(resolved.colorScheme.primary, const Color(0xFF235C46));
      });

      testWidgets('typography and shape come from the tokens', (tester) async {
        final (resolved, _) = await _resolve(tester, theme);

        expect(resolved.textTheme.titleMedium!.fontSize, 17);
        expect(
          resolved.textTheme.titleMedium!.fontFamily,
          AppTypography.fontFamily,
        );
        // Unmapped slots keep the Material default but inherit the family.
        expect(
          resolved.textTheme.displayLarge!.fontFamily,
          AppTypography.fontFamily,
        );
        expect(resolved.cardTheme.elevation, 0);
        expect(
          resolved.cardTheme.shape,
          isA<RoundedRectangleBorder>().having(
            (s) => s.borderRadius,
            'radius',
            BorderRadius.circular(AppRadii.lg),
          ),
        );
      });
    });
  }

  test('primary ink flips between modes, the primary fill does not', () {
    expect(AppColors.light.primary, AppColors.dark.primary);
    expect(FoloColors.light.primaryText, isNot(FoloColors.dark.primaryText));
  });

  test('numerals are tabular so goal values do not shift', () {
    expect(
      AppTypography.numericLarge.fontFeatures,
      contains(const FontFeature.tabularFigures()),
    );
    expect(
      AppTypography.numeric.fontFeatures,
      contains(const FontFeature.tabularFigures()),
    );
  });
}
