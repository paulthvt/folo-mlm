import 'package:flutter_test/flutter_test.dart';
import 'package:folo/features/auth/domain/account.dart';
import 'package:folo/features/contacts/presentation/contact_list.dart';
import 'package:folo/features/contacts/presentation/import_contacts_page.dart';
import 'package:folo/features/onboarding/presentation/first_run_page.dart';
import 'package:folo/features/today/presentation/today_page.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/app_harness.dart';
import '../../auth/fake_auth_repository.dart';

const _phone = Size(390, 844);

FakeAuthRepository _newAccount() => FakeAuthRepository()
  ..session = true
  ..account = const Account(
    firstName: 'Pauline',
    email: 'p@example.com',
    onboarded: false,
  );

void main() {
  testWidgets('a new account starts here; Skip goes to Today, for good', (
    tester,
  ) async {
    final auth = _newAccount();
    await pumpFolo(tester, size: _phone, auth: auth);
    expect(find.byType(FirstRunPage), findsOneWidget);

    await tester.tap(find.text('Skip for now'));
    await tester.pumpAndSettle();

    expect(auth.calls, contains('markOnboarded()'));
    expect(auth.account!.onboarded, isTrue);
    expect(find.byType(TodayPage), findsOneWidget);
  });

  testWidgets('Import goes to the phone contacts', (tester) async {
    await pumpFolo(tester, size: _phone, auth: _newAccount());

    await tester.tap(find.text('Import from your contacts'));
    await tester.pumpAndSettle();

    expect(find.byType(ImportContactsPage), findsOneWidget);

    // The system back gesture: Contacts, not out of the app.
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(find.byType(ContactList), findsOneWidget);
  });

  testWidgets('an onboarded account never sees it', (tester) async {
    await pumpFolo(tester, size: _phone);

    expect(find.byType(FirstRunPage), findsNothing);
  });
}
