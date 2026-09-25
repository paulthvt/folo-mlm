import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folo/features/auth/domain/auth_validation.dart';
import 'package:folo/features/auth/presentation/auth_validation_copy.dart';
import 'package:folo/l10n/app_localizations.dart';

/// The mappers need an [AppLocalizations], which only exists under a
/// localized widget tree. Pumping one and capturing it is cheaper than
/// loading the delegate by hand in every test.
Future<AppLocalizations> _localizations(WidgetTester tester) async {
  late AppLocalizations l10n;
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          l10n = AppLocalizations.of(context);
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return l10n;
}

void main() {
  testWidgets('every email problem has copy', (tester) async {
    final l10n = await _localizations(tester);

    expect(emailProblemCopy(l10n, EmailProblem.empty), isNotEmpty);
    expect(emailProblemCopy(l10n, EmailProblem.malformed), isNotEmpty);
  });

  testWidgets('a null problem has no copy', (tester) async {
    final l10n = await _localizations(tester);

    expect(emailProblemCopy(l10n, null), isNull);
    expect(passwordProblemCopy(l10n, null), isNull);
    expect(firstNameProblemCopy(l10n, null), isNull);
    expect(passwordConfirmationProblemCopy(l10n, null), isNull);
  });

  // The minimum is a constant, not a literal in the sentence: a change to
  // minPasswordLength must reach the message without a copy edit.
  testWidgets('the too-short message names the minimum', (tester) async {
    final l10n = await _localizations(tester);

    expect(
      passwordProblemCopy(l10n, PasswordProblem.tooShort),
      contains('$minPasswordLength'),
    );
  });

  testWidgets('the other problems have copy', (tester) async {
    final l10n = await _localizations(tester);

    expect(passwordProblemCopy(l10n, PasswordProblem.empty), isNotEmpty);
    expect(firstNameProblemCopy(l10n, FirstNameProblem.empty), isNotEmpty);
    expect(
      passwordConfirmationProblemCopy(l10n, PasswordConfirmationProblem.empty),
      isNotEmpty,
    );
    expect(
      passwordConfirmationProblemCopy(
        l10n,
        PasswordConfirmationProblem.mismatch,
      ),
      isNotEmpty,
    );
  });
}
