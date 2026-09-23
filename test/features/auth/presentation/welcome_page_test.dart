import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folo/app/theme/app_theme.dart';
import 'package:folo/features/auth/data/auth_repository.dart';
import 'package:folo/features/auth/domain/auth_failure.dart';
import 'package:folo/features/auth/presentation/welcome_page.dart';

import '../fake_auth_repository.dart';

Widget _host(FakeAuthRepository fake, {double textScale = 1}) => ProviderScope(
  overrides: [authRepositoryProvider.overrideWithValue(fake)],
  child: MaterialApp(
    theme: AppTheme.light,
    builder: (context, child) => MediaQuery.withClampedTextScaling(
      minScaleFactor: textScale,
      maxScaleFactor: textScale,
      child: child!,
    ),
    home: const WelcomePage(),
  ),
);

void main() {
  testWidgets('offers the identity paths and the register link', (
    tester,
  ) async {
    await tester.pumpWidget(_host(FakeAuthRepository()));

    expect(find.text('Continue with Google'), findsOneWidget);
    // Google requires its own mark beside the label.
    expect(
      find.image(const AssetImage('assets/images/google_g.png')),
      findsOneWidget,
    );
    // Apple needs a paid developer account: issue #22.
    expect(find.text('Continue with Apple'), findsNothing);
    expect(find.text('Continue with email'), findsOneWidget);
    expect(find.text('Create an account'), findsOneWidget);
    expect(find.text('Know what to do next.'), findsOneWidget);
  });

  testWidgets('Google calls the repository once', (tester) async {
    final fake = FakeAuthRepository();
    await tester.pumpWidget(_host(fake));

    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();

    expect(fake.calls, ['signInWithGoogle()']);
  });

  testWidgets('a failed OAuth attempt shows a form error', (tester) async {
    final fake = FakeAuthRepository()..failWith = AuthFailure.network;
    await tester.pumpWidget(_host(fake));

    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();

    expect(
      find.text('We could not reach Folo. Check your connection.'),
      findsOneWidget,
    );
  });

  testWidgets('the footer fits the column at large text sizes', (tester) async {
    await tester.pumpWidget(_host(FakeAuthRepository(), textScale: 2));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('two taps in the same frame start one OAuth flow', (
    tester,
  ) async {
    final fake = FakeAuthRepository()..gate = Completer<void>();
    await tester.pumpWidget(_host(fake));

    await tester.tap(find.text('Continue with Google'));
    await tester.tap(find.text('Continue with Google'));
    await tester.pump();

    fake.gate!.complete();
    await tester.pumpAndSettle();

    expect(fake.calls, ['signInWithGoogle()']);
  });
}
