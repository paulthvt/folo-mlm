import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folo/features/auth/domain/auth_validation.dart';
import 'package:folo/features/auth/presentation/auth_validation_copy.dart';
import 'package:folo/l10n/app_localizations.dart';

/// Pumps a widget that hands the English AppLocalizations to [body].
Future<void> _withL10n(
  WidgetTester tester,
  void Function(AppLocalizations l10n) body,
) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          body(AppLocalizations.of(context));
          return const SizedBox.shrink();
        },
      ),
    ),
  );
}

void main() {
  testWidgets('a valid value has no error', (tester) async {
    await _withL10n(tester, (l10n) {
      expect(emailFieldError(l10n, 'pauline@example.com'), isNull);
      expect(passwordFieldError(l10n, 'abcdefgh'), isNull);
      expect(firstNameFieldError(l10n, 'Pauline'), isNull);
      expect(
        passwordConfirmationFieldError(l10n, 'abcdefgh', 'abcdefgh'),
        isNull,
      );
    });
  });

  testWidgets('each problem maps to its own sentence', (tester) async {
    await _withL10n(tester, (l10n) {
      expect(emailFieldError(l10n, ''), 'Enter your email address.');
      expect(
        emailFieldError(l10n, 'pauline'),
        'That address does not look right.',
      );
      expect(passwordFieldError(l10n, ''), 'Enter a password.');
      expect(firstNameFieldError(l10n, '  '), 'Enter your first name.');
      expect(
        passwordConfirmationFieldError(l10n, '', 'abcdefgh'),
        'Confirm your password.',
      );
      expect(
        passwordConfirmationFieldError(l10n, 'nope', 'abcdefgh'),
        'Those passwords do not match.',
      );
    });
  });

  // The message states the number, so the number must come from the constant.
  // Bumping minPasswordLength must not leave the copy behind.
  testWidgets('the too-short message names minPasswordLength', (tester) async {
    await _withL10n(tester, (l10n) {
      expect(
        passwordFieldError(l10n, 'a' * (minPasswordLength - 1)),
        'At least $minPasswordLength characters.',
      );
    });
  });
}
