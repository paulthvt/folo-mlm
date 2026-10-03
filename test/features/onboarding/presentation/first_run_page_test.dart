import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/core/business_model/business_model.dart';
import 'package:loomia/features/auth/domain/account.dart';
import 'package:loomia/features/auth/domain/auth_failure.dart';
import 'package:loomia/features/contacts/presentation/contact_list.dart';
import 'package:loomia/features/contacts/presentation/import_contacts_page.dart';
import 'package:loomia/features/onboarding/presentation/first_run_page.dart';
import 'package:loomia/features/today/presentation/today_page.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/app_harness.dart';
import '../../auth/fake_auth_repository.dart';

const _phone = Size(390, 844);
const _question = 'Which company do you work with?';
const _people = 'Who do you already work with?';

FakeAuthRepository _newAccount() => FakeAuthRepository()
  ..session = true
  ..account = const Account(
    firstName: 'Pauline',
    email: 'p@example.com',
    onboarded: false,
  );

Future<void> _choose(WidgetTester tester, String company) async {
  await tester.tap(find.text(company));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a new account is asked its company first', (tester) async {
    await pumpLoomia(tester, size: _phone, auth: _newAccount());

    expect(find.byType(FirstRunPage), findsOneWidget);
    expect(find.text(_question), findsOneWidget);
    expect(find.text('dōTERRA'), findsOneWidget);
    expect(find.text('Other'), findsOneWidget);
    // The tap is the answer: nothing chosen yet, nothing to confirm.
    expect(find.byIcon(Icons.check_rounded), findsNothing);
    expect(find.text('Next'), findsNothing);
  });

  testWidgets('a tap saves the company and moves on', (tester) async {
    final auth = _newAccount();
    await pumpLoomia(tester, size: _phone, auth: auth);

    await _choose(tester, 'dōTERRA');

    expect(auth.calls, ['updateBusinessModel(doterra)']);
    expect(auth.account!.businessModel, BusinessModel.doterra);
    expect(auth.account!.onboarded, isFalse);
    expect(find.text(_people), findsOneWidget);
    expect(find.text(_question), findsNothing);
  });

  testWidgets('back returns to the question, and a new answer is saved', (
    tester,
  ) async {
    final auth = _newAccount();
    await pumpLoomia(tester, size: _phone, auth: auth);
    await _choose(tester, 'dōTERRA');

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text(_question), findsOneWidget);

    await _choose(tester, 'Other');
    // The system back gesture too: the question, not out of the app.
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(find.text(_question), findsOneWidget);

    expect(auth.calls, [
      'updateBusinessModel(doterra)',
      'updateBusinessModel(other)',
    ]);
    expect(auth.account!.businessModel, BusinessModel.other);
  });

  testWidgets('a failed save stays on the question', (tester) async {
    final auth = _newAccount()..failWith = AuthFailure.network;
    await pumpLoomia(tester, size: _phone, auth: auth);

    await _choose(tester, 'dōTERRA');

    expect(find.text(_question), findsOneWidget);
    expect(
      find.text('We could not reach Loomia. Check your connection.'),
      findsOneWidget,
    );

    auth.failWith = null;
    await _choose(tester, 'dōTERRA');
    expect(find.text(_people), findsOneWidget);
  });

  testWidgets('a second tap while saving is ignored', (tester) async {
    final auth = _newAccount()..gate = Completer<void>();
    await pumpLoomia(tester, size: _phone, auth: auth);

    await tester.tap(find.text('dōTERRA'));
    await tester.pump();
    await tester.tap(find.text('Other'));
    await tester.pump();
    auth.gate!.complete();
    await tester.pumpAndSettle();

    expect(auth.calls, ['updateBusinessModel(doterra)']);
    expect(find.text(_people), findsOneWidget);
  });

  testWidgets('Skip goes to Today, for good', (tester) async {
    final auth = _newAccount();
    await pumpLoomia(tester, size: _phone, auth: auth);
    await _choose(tester, 'Other');

    await tester.tap(find.text('Skip for now'));
    await tester.pumpAndSettle();

    expect(auth.calls, contains('markOnboarded()'));
    expect(auth.account!.onboarded, isTrue);
    expect(find.byType(TodayPage), findsOneWidget);
  });

  testWidgets('Import goes to the phone contacts', (tester) async {
    await pumpLoomia(tester, size: _phone, auth: _newAccount());
    await _choose(tester, 'Other');

    await tester.tap(find.text('Import from your contacts'));
    await tester.pumpAndSettle();

    expect(find.byType(ImportContactsPage), findsOneWidget);

    // The system back gesture: Contacts, not out of the app.
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(find.byType(ContactList), findsOneWidget);
  });

  testWidgets('an onboarded account never sees it', (tester) async {
    await pumpLoomia(tester, size: _phone);

    expect(find.byType(FirstRunPage), findsNothing);
  });
}
