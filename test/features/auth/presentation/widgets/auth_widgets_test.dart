import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folo/app/theme/app_theme.dart';
import 'package:folo/features/auth/domain/auth_failure.dart';
import 'package:folo/features/auth/presentation/auth_failure_copy.dart';
import 'package:folo/features/auth/presentation/widgets/auth_scaffold.dart';
import 'package:folo/features/auth/presentation/widgets/form_error.dart';
import 'package:folo/features/auth/presentation/widgets/password_field.dart';
import 'package:folo/features/auth/presentation/widgets/submit_button.dart';
import 'package:folo/l10n/app_localizations.dart';

Widget _host(Widget child) => MaterialApp(
  theme: AppTheme.light,
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

/// The copy mapper needs an [AppLocalizations], which only exists under a
/// localized widget tree.
Future<AppLocalizations> _localizations(WidgetTester tester) async {
  late AppLocalizations l10n;
  await tester.pumpWidget(
    _host(
      Builder(
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
  group('authFailureCopy', () {
    testWidgets('never names the field that was wrong', (tester) async {
      final l10n = await _localizations(tester);

      expect(
        authFailureCopy(l10n, AuthFailure.invalidCredentials),
        'Email or password is incorrect.',
      );
    });

    testWidgets('covers every failure with its own sentence', (tester) async {
      final l10n = await _localizations(tester);

      final copies = AuthFailure.values
          .map((failure) => authFailureCopy(l10n, failure))
          .toSet();
      expect(copies.length, AuthFailure.values.length);
      expect(copies.every((copy) => copy.endsWith('.')), isTrue);
    });
  });

  testWidgets('FormError shows the message', (tester) async {
    await tester.pumpWidget(_host(const FormError('Something went wrong.')));
    expect(find.text('Something went wrong.'), findsOneWidget);
  });

  testWidgets('SubmitButton fires once when idle', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(SubmitButton(label: 'Sign in', onPressed: () => taps++)),
    );

    await tester.tap(find.text('Sign in'));
    expect(taps, 1);
  });

  testWidgets('SubmitButton swallows a second tap while busy', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(
        SubmitButton(label: 'Sign in', busy: true, onPressed: () => taps++),
      ),
    );

    expect(find.text('Sign in'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byType(SubmitButton));
    expect(taps, 0);
  });

  testWidgets('PasswordField hides the value until the toggle is tapped', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        PasswordField(
          controller: TextEditingController(text: 'hunter22'),
          label: 'Password',
        ),
      ),
    );

    expect(
      tester.widget<EditableText>(find.byType(EditableText)).obscureText,
      isTrue,
    );

    await tester.tap(find.byType(IconButton));
    await tester.pump();

    expect(
      tester.widget<EditableText>(find.byType(EditableText)).obscureText,
      isFalse,
    );
  });

  testWidgets('AuthScaffold shows a back button only when asked', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const AuthScaffold(children: [Text('Welcome')]),
      ),
    );
    expect(find.byType(BackButton), findsNothing);
    expect(find.byType(AppBar), findsNothing);
    expect(find.text('Welcome'), findsOneWidget);
  });
}
