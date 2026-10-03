# Business model at first run — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ask a new account "Which company do you work with?" (dōTERRA or
Other) as step 1 of `/start`, store the answer, and let the user change it in
Settings → Account. Issue #137, part of epic #136.

**Architecture:** A two-value enum `BusinessModel` in `lib/core/business_model/`,
stored in Supabase `user_metadata.business_model` (absent = Other), read into
`Account` like `theme` is. `FirstRunPage` becomes a two-step switcher holding
the step as local state; the existing screen becomes step 2. Settings → Account
gets a Company row that opens a two-option dialog.

**Tech Stack:** Flutter, `flutter_riverpod`, `go_router`, Supabase auth
metadata, ARB l10n, `flutter_test` widget tests, `@Preview` goldens.

**Spec:** `docs/superpowers/specs/2026-10-02-goals-design.md` §1 *Business
model* and §4 *First run*. Figma: First run step 1 `210:3226`, step 2
`212:3241`.

## Global Constraints

- Imports: `package:loomia/...` only; Material from `package:material_ui/material_ui.dart`.
- No hard-coded colour, radius, font size or spacing: `Theme.of(context)`, `AppSpacing.*`, `AppRadii.*`.
- No new dependency. No route added: both steps live under `/start`.
- Copy in `lib/l10n/app_en.arb` only, every key with a description, informal. Do not edit `app_fr.arb`; the *l10n sync* PR translates.
- Run `flutter gen-l10n` after editing the ARB (generated Dart is not committed).
- Stored value: `'doterra'` or absent. Never write `'other'`: Other is the absence, so accounts created before this ship are Other.
- Widgets never branch on `if (doterra)` for vocabulary; terms come through ARB. (Only the label helper switches on the enum.)
- Brand name is written `dōTERRA` (macron on the o) everywhere.
- Never commit goldens made locally; CI regenerates them (README → *Golden tests*).
- Quality gate before claiming done: `dart format .`, `flutter analyze` ("No issues found!"), `flutter test`.
- Branch `feature/137-business-model` off `feature/136-goals` (it carries the spec and this plan, so they land with the first PR). Conventional Commits. PR body fills `.github/PULL_REQUEST_TEMPLATE.md`, **Ticket**: `Closes #137`.

**Out of scope, moved:** the dōTERRA rank list and its check against official
documentation move to #139, the first screen that shows a rank. Nothing in
#137 reads it.

## Review Focus

1. A save that fails on step 1 (offline): the user stays on the question, sees the network error, and can tap again. → Task 2, `a failed save stays on the question`.
2. A double tap, or a tap on the other card while the first save is in flight, saves once. → Task 2, `a second tap while saving is ignored`.
3. The Android back gesture on step 2 returns to step 1, not out of the app. → Task 2, `back returns to the question`.
4. Going back and picking Other after dōTERRA clears the stored value (writes null), so the account is Other again. → Task 1 unit test (`stored`) and Task 2 (`back returns to the question` records both calls).
5. A stored value this build does not know (a newer build's company, a typo) reads as Other, with no crash. → Task 1, `an unknown value reads as Other`.

---

### Task 1: `BusinessModel`, on the account

**Files:**
- Create: `lib/core/business_model/business_model.dart`
- Create: `lib/core/business_model/business_model_copy.dart`
- Modify: `lib/features/auth/domain/account.dart`
- Modify: `lib/features/auth/data/auth_repository.dart` (`account` getter; new `updateBusinessModel`)
- Modify: `test/features/auth/fake_auth_repository.dart`
- Modify: `lib/l10n/app_en.arb`
- Test: `test/core/business_model/business_model_test.dart`

**Interfaces:**
- Produces:
  - `enum BusinessModel { other, doterra }` with `static BusinessModel parse(Object? stored)` and `String? get stored`.
  - `String businessModelLabel(AppLocalizations l10n, BusinessModel model)`.
  - `Account.businessModel` (`BusinessModel`, default `BusinessModel.other`).
  - `Future<void> AuthRepository.updateBusinessModel(BusinessModel model)`; throws `AuthFailure` only.
  - Fake records `updateBusinessModel(<name>)`, e.g. `updateBusinessModel(doterra)`, then updates `account` and emits `AuthChange.userUpdated`.
  - ARB keys `businessModelQuestion`, `businessModelDoterra`, `businessModelOther`.

- [ ] **Step 1: Write the failing test**

`test/core/business_model/business_model_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/core/business_model/business_model.dart';

void main() {
  test('nothing stored is Other', () {
    expect(BusinessModel.parse(null), BusinessModel.other);
  });

  test('doterra is read back', () {
    expect(BusinessModel.parse('doterra'), BusinessModel.doterra);
  });

  test('an unknown value reads as Other', () {
    expect(BusinessModel.parse('young_living'), BusinessModel.other);
    expect(BusinessModel.parse(42), BusinessModel.other);
  });

  test('Other is stored as nothing, so it round-trips', () {
    expect(BusinessModel.other.stored, isNull);
    expect(BusinessModel.doterra.stored, 'doterra');
    for (final model in BusinessModel.values) {
      expect(BusinessModel.parse(model.stored), model);
    }
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/core/business_model/business_model_test.dart`
Expected: FAIL, `business_model.dart` does not exist.

- [ ] **Step 3: Write the enum**

`lib/core/business_model/business_model.dart`:

```dart
/// The company the user works with, asked on the first-run screen. It only
/// changes words: Other keeps neutral terms, dōTERRA brings PV, OV, ranks and
/// LRPs (through ARB `select`s, never `if (doterra)` in a widget).
///
/// Stored in the user metadata as `business_model`; Other is the absence, so
/// accounts from before the question are Other.
enum BusinessModel {
  other,
  doterra;

  /// Anything this build does not know — a newer build's company, a typo —
  /// reads as Other rather than failing.
  static BusinessModel parse(Object? stored) =>
      values.asNameMap()[stored] ?? other;

  /// What goes in the metadata: null removes the key.
  String? get stored => this == other ? null : name;
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/core/business_model/business_model_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Add the copy**

In `lib/l10n/app_en.arb`, after the `firstRunSkip` entry (keep valid JSON — a comma after the preceding `}`):

```json
  "businessModelQuestion": "Which company do you work with?",
  "@businessModelQuestion": {
    "description": "Question on the first step of the first-run screen, and title of the dialog that changes the answer in Settings. Loomia uses the company's own words for volumes and ranks."
  },
  "businessModelDoterra": "dōTERRA",
  "@businessModelDoterra": {
    "description": "Company name, a brand: keep exactly as written (lowercase d, macron on the o, TERRA in capitals) in every language."
  },
  "businessModelOther": "Other",
  "@businessModelOther": {
    "description": "Choice for anyone not working with a company Loomia knows; the app then uses neutral terms. Also shown in Settings beside Company."
  },
```

Run: `flutter gen-l10n`

`lib/core/business_model/business_model_copy.dart`:

```dart
import 'package:loomia/core/business_model/business_model.dart';
import 'package:loomia/l10n/app_localizations.dart';

String businessModelLabel(AppLocalizations l10n, BusinessModel model) =>
    switch (model) {
      BusinessModel.doterra => l10n.businessModelDoterra,
      BusinessModel.other => l10n.businessModelOther,
    };
```

- [ ] **Step 6: Put it on the account**

`lib/features/auth/domain/account.dart`: add the import
`import 'package:loomia/core/business_model/business_model.dart';`, the
constructor parameter `this.businessModel = BusinessModel.other,` after
`this.onboarded = true,`, and the field after `onboarded`:

```dart
  /// Which company's words the app uses. Other until the user picks one.
  final BusinessModel businessModel;
```

`lib/features/auth/data/auth_repository.dart`: import
`package:loomia/core/business_model/business_model.dart`. In the `account`
getter, after `onboarded: metadata['onboarded'] == true,` add:

```dart
      businessModel: BusinessModel.parse(metadata['business_model']),
```

After `updateAppearance`, add:

```dart
  /// Stored as `business_model`; removed for [BusinessModel.other], like a
  /// system appearance.
  Future<void> updateBusinessModel(BusinessModel model) => _guard(
    () => _auth.updateUser(
      UserAttributes(data: {'business_model': model.stored}),
    ),
  );
```

- [ ] **Step 7: Teach the fake**

`test/features/auth/fake_auth_repository.dart`: import
`package:loomia/core/business_model/business_model.dart`. In **every** place
it rebuilds `Account(...)` (`updateLocale`, `updateFirstName`,
`updateAppearance`, `markOnboarded`) add `businessModel: current.businessModel,`
so another setting never resets the company. Then, after `updateAppearance`:

```dart
  @override
  Future<void> updateBusinessModel(BusinessModel model) async {
    await _record('updateBusinessModel(${model.name})');
    final current = account;
    if (current == null) return;
    account = Account(
      firstName: current.firstName,
      email: current.email,
      locale: current.locale,
      appearance: current.appearance,
      onboarded: current.onboarded,
      businessModel: model,
    );
    emit(AuthChange.userUpdated);
  }
```

- [ ] **Step 8: Check everything still builds and passes**

Run: `flutter analyze && flutter test`
Expected: "No issues found!", all tests pass (the fake must implement the new
method, or `auth_repository_test` fails to compile).

- [ ] **Step 9: Commit**

```bash
git add lib/core/business_model lib/features/auth lib/l10n/app_en.arb test/core/business_model test/features/auth/fake_auth_repository.dart
git commit -m "feat(onboarding): business model on the account"
```

---

### Task 2: First run in two steps

**Files:**
- Modify: `lib/features/auth/presentation/widgets/auth_scaffold.dart` (add `onBack`)
- Modify: `lib/features/onboarding/presentation/first_run_page.dart` (rewrite)
- Modify: `lib/l10n/app_en.arb`
- Test: `test/features/onboarding/presentation/first_run_page_test.dart`
- Modify: `test/features/auth/presentation/widgets/auth_widgets_test.dart` (one test for `onBack`)

**Interfaces:**
- Consumes: `BusinessModel`, `businessModelLabel`, `AuthRepository.updateBusinessModel`, fake's `updateBusinessModel(<name>)` call string (Task 1).
- Produces:
  - `AuthScaffold({required children, String? back, VoidCallback? onBack})`.
  - `FirstRunCompanyStep({required VoidCallback onChosen})` and `FirstRunPeopleStep({required VoidCallback onBack})`, both public `ConsumerStatefulWidget`s, used by Task 4's previews.
  - ARB keys `firstRunCompanyBody`, `firstRunDoterraDetail`, `firstRunOtherDetail`.

- [ ] **Step 1: Write the failing tests**

Replace `test/features/onboarding/presentation/first_run_page_test.dart` with:

```dart
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
```

In `test/features/auth/presentation/widgets/auth_widgets_test.dart`, add after
`AuthScaffold shows a back button only when asked` (the file already imports
`AppLocalizations` and `localizationsDelegates`):

```dart
  testWidgets('AuthScaffold: onBack shows a back button that calls it', (
    tester,
  ) async {
    var backs = 0;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AuthScaffold(onBack: () => backs++, children: const [Text('x')]),
      ),
    );

    await tester.tap(find.byType(BackButton));
    expect(backs, 1);
  });
```

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/onboarding test/features/auth/presentation/widgets/auth_widgets_test.dart`
Expected: FAIL — no `onBack` parameter, no company question.

- [ ] **Step 3: Add `onBack` to `AuthScaffold`**

In `auth_scaffold.dart`, change the constructor and add the field:

```dart
  const AuthScaffold({
    required this.children,
    this.back,
    this.onBack,
    super.key,
  });
```

```dart
  /// Instead of [back], for a step inside one screen: there is no route to go
  /// back to, only the previous step.
  final VoidCallback? onBack;
```

and the app bar:

```dart
      appBar: back == null && onBack == null
          ? null
          : AppBar(
              leading: BackButton(
                onPressed: onBack ?? () => backOr(context, back!),
              ),
            ),
```

- [ ] **Step 4: Add the step 1 copy**

In `lib/l10n/app_en.arb`, after the Task 1 keys:

```json
  "firstRunCompanyBody": "So Loomia speaks your language. You can change it in Settings.",
  "@firstRunCompanyBody": {
    "description": "Under the company question on the first step of the first-run screen."
  },
  "firstRunDoterraDetail": "dōTERRA terms, volumes and ranks",
  "@firstRunDoterraDetail": {
    "description": "Second line of the dōTERRA choice on the first-run screen: what picking it changes. Keep dōTERRA as written."
  },
  "firstRunOtherDetail": "Neutral terms",
  "@firstRunOtherDetail": {
    "description": "Second line of the Other choice on the first-run screen: the app keeps general words."
  },
```

Also update the description of `firstRunEyebrow` to: `"Large word at the top of the first step of the first-run screen, shown once after sign-up."`

Run: `flutter gen-l10n`

- [ ] **Step 5: Rewrite `first_run_page.dart`**

```dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loomia/app/router/routes.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/core/business_model/business_model.dart';
import 'package:loomia/core/business_model/business_model_copy.dart';
import 'package:loomia/core/ui/form_error.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/auth/domain/auth_failure.dart';
import 'package:loomia/features/auth/presentation/auth_failure_copy.dart';
import 'package:loomia/features/auth/presentation/widgets/auth_scaffold.dart';
import 'package:loomia/features/contacts/presentation/add_person_sheet.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// Shown once, after sign-up, in two steps: which company the user works
/// with, then who they already work with. One decision per step.
///
/// The step is local state, not a route, so the router's onboarding guard
/// stays as it is. Back on the second step — the button or the system
/// gesture — returns to the first.
class FirstRunPage extends StatefulWidget {
  const FirstRunPage({super.key});

  @override
  State<FirstRunPage> createState() => _FirstRunPageState();
}

class _FirstRunPageState extends State<FirstRunPage> {
  bool _askCompany = true;

  void _show({required bool company}) => setState(() => _askCompany = company);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _askCompany,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _show(company: true);
      },
      child: _askCompany
          ? FirstRunCompanyStep(onChosen: () => _show(company: false))
          : FirstRunPeopleStep(onBack: () => _show(company: true)),
    );
  }
}

/// Step 1. Tapping a company saves it and moves on: nothing is preselected
/// and there is no Next, the tap is the answer. A failure stays here.
class FirstRunCompanyStep extends ConsumerStatefulWidget {
  const FirstRunCompanyStep({required this.onChosen, super.key});

  final VoidCallback onChosen;

  @override
  ConsumerState<FirstRunCompanyStep> createState() =>
      _FirstRunCompanyStepState();
}

class _FirstRunCompanyStepState extends ConsumerState<FirstRunCompanyStep> {
  bool _busy = false;
  AuthFailure? _failure;

  Future<void> _choose(BusinessModel model) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      await ref.read(authRepositoryProvider).updateBusinessModel(model);
      if (mounted) widget.onChosen();
    } on AuthFailure catch (failure) {
      if (mounted) {
        setState(() {
          _busy = false;
          _failure = failure;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    final failure = _failure;

    return AuthScaffold(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.ms,
          children: [
            Text(l10n.firstRunEyebrow, style: text.displaySmall),
            Text(l10n.businessModelQuestion, style: text.titleLarge),
            Text(l10n.firstRunCompanyBody, style: text.bodyMedium),
          ],
        ),
        if (failure != null) FormError(authFailureCopy(l10n, failure)),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.ms,
          children: [
            for (final model in const [
              BusinessModel.doterra,
              BusinessModel.other,
            ])
              Card(
                key: ValueKey('business-model-${model.name}'),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  title: Text(businessModelLabel(l10n, model)),
                  subtitle: Text(switch (model) {
                    BusinessModel.doterra => l10n.firstRunDoterraDetail,
                    BusinessModel.other => l10n.firstRunOtherDetail,
                  }),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _busy ? null : () => _choose(model),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Step 2: who the user already works with. Every way out, Skip included,
/// marks the account onboarded, so it never comes back.
///
/// The web has no address book to read: there, only Add someone.
class FirstRunPeopleStep extends ConsumerStatefulWidget {
  const FirstRunPeopleStep({required this.onBack, super.key});

  /// Back to step 1.
  final VoidCallback onBack;

  @override
  ConsumerState<FirstRunPeopleStep> createState() =>
      _FirstRunPeopleStepState();
}

class _FirstRunPeopleStepState extends ConsumerState<FirstRunPeopleStep> {
  bool _busy = false;
  AuthFailure? _failure;

  /// Marks the account, then goes to [location], with [above] pushed on top
  /// so back returns to [location] rather than out of the app. A failure
  /// stays here.
  Future<void> _leaveTo(String location, {String? above}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      await ref.read(authRepositoryProvider).markOnboarded();
      if (!mounted) return;
      context.go(location);
      if (above != null) unawaited(context.push(above));
    } on AuthFailure catch (failure) {
      if (mounted) {
        setState(() {
          _busy = false;
          _failure = failure;
        });
      }
    }
  }

  Future<void> _add() async {
    final person = await showAddPerson(context);
    if (person != null && mounted) {
      await _leaveTo(Routes.contactLocation(person.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    final failure = _failure;

    // No "Welcome" here: step 1 said it (Figma 212:3241).
    return AuthScaffold(
      onBack: widget.onBack,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.ms,
          children: [
            Text(l10n.firstRunTitle, style: text.titleLarge),
            Text(
              kIsWeb ? l10n.firstRunBodyWeb : l10n.firstRunBody,
              style: text.bodyMedium,
            ),
          ],
        ),
        if (failure != null) FormError(authFailureCopy(l10n, failure)),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.ms,
          children: [
            if (kIsWeb)
              FilledButton(
                onPressed: _busy ? null : _add,
                child: Text(l10n.contactsAdd),
              )
            else ...[
              FilledButton.icon(
                onPressed: _busy
                    ? null
                    : () => _leaveTo(
                        Routes.contacts,
                        above: Routes.importContacts,
                      ),
                icon: const Icon(Icons.contacts_outlined),
                label: Text(l10n.contactsImport),
              ),
              OutlinedButton(
                onPressed: _busy ? null : _add,
                child: Text(l10n.contactsAdd),
              ),
            ],
            TextButton(
              onPressed: _busy ? null : () => _leaveTo(Routes.today),
              child: Text(l10n.firstRunSkip),
            ),
          ],
        ),
      ],
    );
  }
}
```

This is the old `_FirstRunPageState` body with two changes: `onBack:
widget.onBack` on the scaffold, and the `firstRunEyebrow` text removed.

- [ ] **Step 6: Run the tests to verify they pass**

Run: `flutter test test/features/onboarding test/features/auth`
Expected: PASS. If `back returns to the question` fails on `handlePopRoute`
returning false, the `PopScope` is not seeing the pop: check it wraps the
step widgets (it must be inside the `/start` page, which it is when it is the
root of `FirstRunPage.build`).

- [ ] **Step 7: Commit**

```bash
git add lib/features/auth/presentation/widgets/auth_scaffold.dart lib/features/onboarding lib/l10n/app_en.arb test/features/onboarding test/features/auth/presentation/widgets/auth_widgets_test.dart
git commit -m "feat(onboarding): ask which company the user works with"
```

---

### Task 3: Change it in Settings → Account

**Files:**
- Modify: `lib/features/settings/presentation/account_settings.dart`
- Modify: `lib/l10n/app_en.arb`
- Test: `test/features/settings/presentation/settings_page_test.dart`

**Interfaces:**
- Consumes: `BusinessModel`, `businessModelLabel`, `Account.businessModel`, `AuthRepository.updateBusinessModel` (Task 1); `SettingsOption`, `LoomiaDialog`, `SettingsAction.run` (existing).
- Produces: ARB key `settingsCompany`.

- [ ] **Step 1: Write the failing tests**

Add to `settings_page_test.dart` after `an empty name is refused` (add the
import `package:loomia/core/business_model/business_model.dart`):

```dart
  testWidgets('the account shows the company; choosing one saves it', (
    tester,
  ) async {
    final fake = await _openSection(tester, 'Pauline');
    expect(find.text('Company'), findsOneWidget);
    expect(find.text('Other'), findsOneWidget);

    await tester.tap(find.text('Company'));
    await tester.pumpAndSettle();
    expect(find.text('Which company do you work with?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('business-model-doterra')));
    await tester.pumpAndSettle();

    expect(fake.calls, ['updateBusinessModel(doterra)']);
    expect(fake.account!.businessModel, BusinessModel.doterra);
    expect(find.text('dōTERRA'), findsOneWidget);
  });

  testWidgets('picking the company already set saves nothing', (
    tester,
  ) async {
    final fake = await _openSection(tester, 'Pauline');

    await tester.tap(find.text('Company'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('business-model-other')));
    await tester.pumpAndSettle();

    expect(fake.calls, isEmpty);
  });
```

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/settings`
Expected: FAIL, no "Company" row.

- [ ] **Step 3: Add the copy**

In `lib/l10n/app_en.arb`, after `settingsSectionAccount`'s entry:

```json
  "settingsCompany": "Company",
  "@settingsCompany": {
    "description": "Row in Settings → Account: the company the user works with (dōTERRA or Other), which sets the words Loomia uses for volumes and ranks."
  },
```

Run: `flutter gen-l10n`

- [ ] **Step 4: Add the row and the dialog**

In `account_settings.dart`, import
`package:loomia/core/business_model/business_model.dart`,
`package:loomia/core/business_model/business_model_copy.dart` and
`package:loomia/features/settings/presentation/widgets/settings_option.dart`.
Update the class doc to `/// Name, email, company, delete account.`

In `_AccountSettingsState`, after `_editName`:

```dart
  Future<void> _editCompany(BusinessModel current) async {
    final chosen = await LoomiaDialog.show<BusinessModel>(context, (context) {
      final l10n = AppLocalizations.of(context);
      return LoomiaDialog(
        title: l10n.businessModelQuestion,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
        ],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final model in const [
              BusinessModel.doterra,
              BusinessModel.other,
            ])
              SettingsOption(
                key: ValueKey('business-model-${model.name}'),
                label: businessModelLabel(l10n, model),
                selected: model == current,
                onTap: () => Navigator.pop(context, model),
              ),
          ],
        ),
      );
    });
    if (chosen != null && chosen != current) {
      await run((auth) => auth.updateBusinessModel(chosen));
    }
  }
```

In `build`, in the first `SettingsGroup`, after the email `ListTile`:

```dart
              ListTile(
                title: Text(l10n.settingsCompany),
                subtitle: Text(businessModelLabel(l10n, account.businessModel)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: busy ? null : () => _editCompany(account.businessModel),
              ),
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `flutter test test/features/settings`
Expected: PASS, including the existing desktop/tablet tests.

- [ ] **Step 6: Commit**

```bash
git add lib/features/settings/presentation/account_settings.dart lib/l10n/app_en.arb test/features/settings
git commit -m "feat(settings): change the company in Account"
```

---

### Task 4: Previews, goldens and design docs

**Files:**
- Create: `lib/features/onboarding/presentation/first_run_preview.dart`
- Modify: `test/previews_test.dart`
- Modify: `docs/design/design-principles.md` (§5)
- Modify: `docs/design/screens.md` (§9, and the "deliberately do not have" line)

**Interfaces:**
- Consumes: `FirstRunCompanyStep`, `FirstRunPeopleStep` (Task 2).
- Produces: preview functions `firstRunCompanyLight`, `firstRunPeopleLight`; goldens `first_run_company_light.png`, `first_run_people_light.png` (made by CI).

- [ ] **Step 1: Write the previews**

`lib/features/onboarding/presentation/first_run_preview.dart`:

```dart
import 'package:flutter/widget_previews.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/features/onboarding/presentation/first_run_page.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:loomia/l10n/localizations_delegates.dart';
import 'package:material_ui/material_ui.dart';

/// Both first-run steps, for `flutter widget-preview start`. Nothing is
/// tapped, so the repository is never read. Nothing in the app imports this
/// file.
@Preview(group: 'First run', name: 'Company — light', size: Size(390, 844))
Widget firstRunCompanyLight() =>
    _app(FirstRunCompanyStep(onChosen: () {}));

@Preview(group: 'First run', name: 'People — light', size: Size(390, 844))
Widget firstRunPeopleLight() => _app(FirstRunPeopleStep(onBack: () {}));

Widget _app(Widget step) {
  return ProviderScope(
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      // The preview is its own app: without the delegates, any component that
      // reads AppLocalizations throws here.
      localizationsDelegates: localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.light,
      home: step,
    ),
  );
}
```

- [ ] **Step 2: Add them to the golden test**

In `test/previews_test.dart`, import
`package:loomia/features/onboarding/presentation/first_run_preview.dart` and
add after the `contacts_desktop_light` entry:

```dart
    'first_run_company_light': (const Size(390, 844), firstRunCompanyLight),
    'first_run_people_light': (const Size(390, 844), firstRunPeopleLight),
```

Run: `flutter test test/previews_test.dart`
Expected on macOS: PASS (renders without exception; pixels compared on Linux
only). Do **not** run `--update-goldens` locally.

- [ ] **Step 3: Record the rank exception**

`docs/design/design-principles.md` §5, after the *In practice* paragraph:

```markdown
*The one exception:* a rank, when the user's company has ranks (dōTERRA), is a
private target the user sets for themselves — "Aiming for Elite" — or a fact
they write on a team member's page. Never a badge, never shown outside Goals
and that page, never compared or ranked against anyone.
```

- [ ] **Step 4: Update the screen notes**

`docs/design/screens.md` §9: replace the paragraph starting
`**First run** is one screen` with:

```markdown
**First run** has two steps, shown once after sign-up, in the auth shape (one
column capped at 400, no navigation). Step 1 (`Welcome`, [#137](https://github.com/paulthvt/loomia/issues/137)):
`Which company do you work with?`, two cards, dōTERRA and Other. The tap is the
answer — no preselection, no Next — saved as `business_model` in the Supabase
user metadata (absent for Other) and changeable in Settings → Account. Step 2:
`Who do you already work with?`, with a back button to step 1. On a phone:
Import from your contacts (primary), Add someone, Skip for now. On the web
there is no address book to read, so Add someone is the primary and the body
says the phone app can import. Every way out of step 2 — Skip included — marks
the account (`onboarded`), so it never comes back, on any device. The step is
local state under `/start`: the router guard does not change. Importing stays
in Contacts: an icon in the toolbar and a text button under the empty state,
both absent on the web.
```

Add `Frames First run step 1 (210:3226) and step 2 (212:3241).` to the frames
line, and in *What these screens deliberately do not have* change `beyond the
one first-run screen` to `beyond the two first-run steps`.

- [ ] **Step 5: Commit**

```bash
git add lib/features/onboarding/presentation/first_run_preview.dart test/previews_test.dart docs/design
git commit -m "docs(onboarding): first-run previews and the rank exception"
```

---

### Task 5: Quality gate, PR, goldens from CI

- [ ] **Step 1: Run the gate**

```bash
dart format .
flutter analyze
flutter test
```

Expected: no formatting diff left, "No issues found!", all tests pass. Commit
any formatting change as `style: dart format`.

- [ ] **Step 2: Push and open the PR**

```bash
git push -u origin feature/137-business-model
```

Open the PR against `main` with `gh pr create --repo paulthvt/loomia --base
main --title "feat(onboarding): ask which company the user works with"`, body
from `.github/PULL_REQUEST_TEMPLATE.md`: **Ticket** `Closes #137`; say the
spec and plan for #136 ride along, and that the rank list moved to #139.

- [ ] **Step 3: Generate the two new goldens on CI**

Follow README → *Golden tests*:

```bash
gh workflow run CI --ref feature/137-business-model -f update-goldens=true
```

then the README's remaining steps to pull the CI-made PNGs onto the branch.
Check both images match Figma `210:3226` and `212:3241` before merging.
