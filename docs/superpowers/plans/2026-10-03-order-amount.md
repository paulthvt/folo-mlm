# Amount on orders — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** An `order` entry can carry an amount in the business model's unit
(PV for dōTERRA, a plain number for Other). Log something shows an Amount
field for Order, and the history reads "Order · 100 PV". The database also
accepts an own order (no person, amount required) for Goals to log later.
Issue #138, part of epic #136.

**Architecture:** One migration adds `activity.amount`, makes `person_id`
nullable for own orders, and replaces the entry-shape check. `Activity` and
`ActivityDraft` gain `amount`. A pure `parseAmount` reads what the user typed.
Unit and title come from ARB `select`s on `BusinessModel.name`, read from
`accountProvider` in the sheet and in HISTORY.

**Tech Stack:** Supabase Postgres + pgTAP, Flutter, `flutter_riverpod`, ARB
l10n (`intl` `decimalPattern` for the amount), `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-10-02-goals-design.md` §2 *Amounts and
own orders on `activity`* and §4 *Log activity sheet*. Figma: Log order with
amount `204:2840`, history entry `204:3020`, own order `204:3039`.

## Global Constraints

- Imports: `package:loomia/...` only; Material from `package:material_ui/material_ui.dart`.
- No hard-coded colour, radius, font size or spacing.
- No new dependency. No route added.
- Copy in `lib/l10n/app_en.arb` only, every key with a description, informal. Do not edit `app_fr.arb`. Run `flutter gen-l10n` after editing the ARB.
- Widgets never `if (doterra)`: the unit and the title come through ARB `select` on `model.name`.
- Schema only via `supabase migration new`. No Docker on the dev machine: `supabase test db` runs in CI (`Supabase migrations` job); check that job before claiming the SQL works.
- Currency: none. An amount is a plain number, `numeric(12,2)`, `> 0`.
- No golden changes expected (no preview shows the sheet or an order). If one fails, regenerate through CI, never locally.
- Quality gate: `dart format .`, `flutter analyze` ("No issues found!"), `flutter test`.
- Branch `feature/138-order-amount` off `main`. Conventional Commits. PR fills `.github/PULL_REQUEST_TEMPLATE.md`, **Ticket**: `Closes #138`.

**Out of scope, moved:** the own-order *sheet* (Log something without a
person). Its only entry point is `Log my own order` on the Goals tab, so it
ships with #142; building it now would leave a sheet nothing opens. This PR
ships the database side (nullable `person_id`, the rule, pgTAP), which #141's
`month_progress` reads. `activityFromRow` keeps `personId` non-null: it only
reads one person's history, which never holds an own order.

## Review Focus

1. Order picked, `100` typed, then Call picked and text saved: the call is saved with no amount (the hidden field must not leak). → Task 3, `an amount typed under Order is dropped for another kind`.
2. `6,000` typed by someone who means six thousand: refused with a message, never saved as 6. → Task 2 (`parseAmount`) and Task 3, `a bad amount is refused`.
3. French `12,5`: saved as 12.5. → Task 2, `a comma is a decimal point`.
4. An order with an amount and an empty note saves with `text` null; HISTORY reads "Order · 100 PV" over the day alone. → Task 3, `an amount alone saves`, and `Log an order from ⋯ reads Order · 100 PV`.
5. An Other account: no unit next to the field; the title reads "Order · 100". → Task 1 copy test and Task 3, `Other shows no unit`.

---

### Task 1: Migration, pgTAP, and the copy

**Files:**
- Create: `supabase/migrations/<timestamp>_order_amount.sql` (via `supabase migration new order_amount`)
- Create: `supabase/tests/order_test.sql`
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/features/contacts/domain/activity.dart`
- Modify: `lib/features/contacts/presentation/people_copy.dart`
- Modify: `lib/features/contacts/presentation/history_section.dart`
- Test: `test/features/contacts/domain/activity_test.dart`, `test/features/contacts/presentation/people_copy_test.dart`

**Interfaces:**
- Produces: `Activity.amount` (`double?`); `activityTitle(AppLocalizations l10n, Activity activity, BusinessModel model)`; ARB `orderUnit(String model)`, `historyOrder(String model, num amount)`, `historyOrderMeta(String day, String note)`.

- [ ] **Step 1: Create the migration**

Run: `supabase migration new order_amount`, then write:

```sql
-- Orders (#138): an order can say how much it was worth, in the business
-- model's unit (PV for dōTERRA, a plain number otherwise). An own order is
-- the user's, with no person: an order with an amount. Goals logs those.
-- A null person_id skips the (person_id, owner_id) foreign key (MATCH SIMPLE);
-- RLS still pins the row to its owner.

alter table public.activity
  add column amount numeric(12,2) check (amount > 0),
  alter column person_id drop not null;

-- Text is optional on an order with an amount, never blank when present.
alter table public.activity drop constraint stage_entry_shape;
alter table public.activity add constraint entry_shape check (
  (kind = 'stage' and stage is not null and text is null)
  or (kind <> 'stage' and stage is null
      and (text is null or length(trim(text)) > 0)
      and (text is not null or (kind = 'order' and amount is not null)))
);

alter table public.activity add constraint amount_only_on_orders
  check (amount is null or kind = 'order');

alter table public.activity add constraint person_or_own_order
  check (person_id is not null or (kind = 'order' and amount is not null));
```

- [ ] **Step 2: Write the pgTAP file**

`supabase/tests/order_test.sql`:

```sql
-- Orders: an amount only on an order, an order needs text or an amount, and
-- an own order (no person) needs an amount and stays with its owner.
-- Run with `supabase test db`.
begin;
create extension if not exists pgtap with schema extensions;
select plan(13);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000000a', 'a@example.com'),
  ('00000000-0000-0000-0000-00000000000b', 'b@example.com');

set local role authenticated;
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';

insert into public.person (id, name, stage) values
  ('00000000-0000-0000-0000-0000000000a1', 'Marlène', 'customer');

select lives_ok(
  $$ insert into public.activity (id, person_id, kind, amount) values
     ('00000000-0000-0000-0000-0000000000c1',
      '00000000-0000-0000-0000-0000000000a1', 'order', 100.50) $$,
  'an order with an amount and no text saves'
);
select is(
  (select amount from public.activity
    where id = '00000000-0000-0000-0000-0000000000c1'), 100.50::numeric,
  'the amount is stored as given'
);
select lives_ok(
  $$ insert into public.activity (person_id, kind, text) values
     ('00000000-0000-0000-0000-0000000000a1', 'order', 'Two creams') $$,
  'an order with text and no amount still saves'
);
select throws_ok(
  $$ insert into public.activity (person_id, kind) values
     ('00000000-0000-0000-0000-0000000000a1', 'order') $$,
  '23514', null,
  'an order with neither text nor amount is refused'
);
select throws_ok(
  $$ insert into public.activity (person_id, kind, text, amount) values
     ('00000000-0000-0000-0000-0000000000a1', 'order', '  ', 100) $$,
  '23514', null,
  'blank text is refused, even with an amount'
);
select throws_ok(
  $$ insert into public.activity (person_id, kind, amount) values
     ('00000000-0000-0000-0000-0000000000a1', 'order', 0) $$,
  '23514', null,
  'a zero amount is refused'
);
select throws_ok(
  $$ insert into public.activity (person_id, kind, text, amount) values
     ('00000000-0000-0000-0000-0000000000a1', 'call', 'Called', 100) $$,
  '23514', null,
  'only an order has an amount'
);
select lives_ok(
  $$ insert into public.activity (id, kind, amount) values
     ('00000000-0000-0000-0000-0000000000c2', 'order', 80) $$,
  'an own order (no person) with an amount saves'
);
select throws_ok(
  $$ insert into public.activity (kind, text) values ('order', 'For me') $$,
  '23514', null,
  'an own order needs an amount'
);
select throws_ok(
  $$ insert into public.activity (kind, text) values ('call', 'Nobody') $$,
  '23514', null,
  'only an order can have no person'
);

-- As B.
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000b", "role": "authenticated"}';

select is(
  (select count(*)::int from public.activity where person_id is null), 0,
  'another user does not see the own order'
);
select throws_ok(
  $$ insert into public.activity (owner_id, kind, amount) values
     ('00000000-0000-0000-0000-00000000000a', 'order', 10) $$,
  '42501', null,
  'another user cannot write an own order for the owner'
);

-- Back as A.
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';

delete from public.activity where id = '00000000-0000-0000-0000-0000000000c2';
select is(
  (select count(*)::int from public.activity where person_id is null), 0,
  'the owner deletes their own order'
);

select * from finish();
rollback;
```

- [ ] **Step 3: Add the ARB keys**

In `lib/l10n/app_en.arb`, after `logWhatRequired`:

```json
  "logAmount": "Amount",
  "@logAmount": {
    "description": "Label of the amount field in Log something, shown when the kind is Order. The amount is in the company's unit (PV for dōTERRA), never money."
  },
  "logNote": "Note",
  "@logNote": {
    "description": "Label of the text field in Log something when the kind is Order: optional once an amount is given. Other kinds keep logWhat."
  },
  "logAmountInvalid": "Use a number above 0, like 100 or 99.5.",
  "@logAmountInvalid": {
    "description": "Shown under the amount field when what was typed is not a positive number with at most two decimals."
  },
  "logOrderRequired": "Add an amount or a note.",
  "@logOrderRequired": {
    "description": "Shown under the note when an order has neither an amount nor a note."
  },
  "orderUnit": "{model, select, doterra{PV} other{}}",
  "@orderUnit": {
    "description": "Unit shown after the amount field. dōTERRA: PV (personal volume, not translated). Other: no unit, keep empty.",
    "placeholders": {
      "model": {
        "type": "String"
      }
    }
  },
```

After `historyMeta`:

```json
  "historyOrder": "{model, select, doterra{Order · {amount} PV} other{Order · {amount}}}",
  "@historyOrder": {
    "description": "Title of an order with an amount in a person's history. PV is not translated. Other: the number alone.",
    "placeholders": {
      "model": {
        "type": "String"
      },
      "amount": {
        "type": "num",
        "format": "decimalPattern"
      }
    }
  },
  "historyOrderMeta": "{day} · {note}",
  "@historyOrderMeta": {
    "description": "Line under an order with an amount: the day, then the note the user wrote. Without a note, the day alone shows.",
    "placeholders": {
      "day": {
        "type": "String"
      },
      "note": {
        "type": "String"
      }
    }
  },
```

Run: `flutter gen-l10n`
Expected: no error (an empty `other{}` branch and a `num` inside a `select` both generate; checked while planning).

- [ ] **Step 4: Write the failing tests**

Append to `test/features/contacts/domain/activity_test.dart`:

```dart
  test('an order may have an amount and no text', () {
    final order = Activity(
      id: 'a5',
      personId: 'p1',
      kind: ActivityKind.order,
      happenedOn: DateTime(2026, 9, 28),
      amount: 100,
      createdAt: DateTime.utc(2026, 9, 28),
    );

    expect(order.text, isNull);
    expect(order.amount, 100);
  });

  test('an order with neither text nor amount is a bug', () {
    expect(
      () => Activity(
        id: 'a6',
        personId: 'p1',
        kind: ActivityKind.order,
        happenedOn: DateTime(2026, 9, 28),
        createdAt: DateTime.utc(2026, 9, 28),
      ),
      throwsA(isA<AssertionError>()),
    );
  });

  test('an amount on anything but an order is a bug', () {
    expect(
      () => Activity(
        id: 'a7',
        personId: 'p1',
        kind: ActivityKind.call,
        happenedOn: DateTime(2026, 9, 28),
        text: 'Called',
        amount: 100,
        createdAt: DateTime.utc(2026, 9, 28),
      ),
      throwsA(isA<AssertionError>()),
    );
  });
```

In `test/features/contacts/presentation/people_copy_test.dart`, add the import
`package:loomia/core/business_model/business_model.dart`, then pass
`BusinessModel.other` as the third argument to every existing `activityTitle`
call. Append:

```dart
  group('an order with an amount', () {
    Activity order({String? text}) => Activity(
      id: 'a1',
      personId: 'p1',
      kind: ActivityKind.order,
      happenedOn: DateTime(2026, 10, 13),
      text: text,
      amount: 1840,
      createdAt: DateTime(2026, 10, 13, 12),
    );

    test('dōTERRA reads the amount in PV, the note under it', () {
      final entry = order(text: 'Wild Orange');
      expect(
        activityTitle(l10n, entry, BusinessModel.doterra),
        'Order · 1,840 PV',
      );
      expect(activityMeta(l10n, entry, today), 'October 13 · Wild Orange');
    });

    test('Other reads the number alone', () {
      expect(
        activityTitle(l10n, order(), BusinessModel.other),
        'Order · 1,840',
      );
    });

    test('without a note, the day alone', () {
      expect(activityMeta(l10n, order(), today), 'October 13');
    });

    test('French groups with a narrow no-break space', () {
      final fr = lookupAppLocalizations(const Locale('fr'));
      // Until the l10n sync PR, FR falls back to the English words, but the
      // number is formatted for French.
      expect(
        activityTitle(fr, order(), BusinessModel.doterra),
        contains('1\u202F840'),
      );
    });
  });

  test('an order without an amount reads as before', () {
    final order = entry(kind: ActivityKind.order);
    expect(
      activityTitle(l10n, order, BusinessModel.doterra),
      'Asked about the cream',
    );
    expect(activityMeta(l10n, order, today), 'October 13 · Order');
  });
```

`l10n.yaml` lists untranslated keys in `l10n_missing.json`; the French class
uses the English message until the sync PR, so the French test holds before
and after it.

- [ ] **Step 5: Run the tests, see them fail**

Run: `flutter test test/features/contacts/domain/activity_test.dart test/features/contacts/presentation/people_copy_test.dart`
Expected: compile errors: no `amount` parameter, `activityTitle` takes 2 arguments.

- [ ] **Step 6: Implement**

`lib/features/contacts/domain/activity.dart`, replace the constructor, the
`text` doc and add `amount`:

```dart
  Activity({
    required this.id,
    required this.personId,
    required this.kind,
    required this.happenedOn,
    required this.createdAt,
    this.text,
    this.stage,
    this.amount,
  }) : assert(
         kind == ActivityKind.stage
             ? stage != null && text == null && amount == null
             : stage == null &&
                   (text == null
                       ? kind == ActivityKind.order && amount != null
                       : text.trim().isNotEmpty) &&
                   (amount == null || (kind == ActivityKind.order && amount > 0)),
         'A stage entry has a stage only; any other has no stage and non-blank '
         'text, except an order, which needs text or an amount; only an order '
         'has an amount',
       );
```

```dart
  /// What happened; null on stage entries and on an order given by its
  /// amount alone.
  final String? text;

  /// What an order was worth, in the business model's unit (PV for dōTERRA).
  /// Orders only.
  final double? amount;
```

`lib/features/contacts/presentation/people_copy.dart` (import
`package:loomia/core/business_model/business_model.dart`):

```dart
/// What the user wrote; for a stage entry, what changed; for an order with an
/// amount, "Order · 100 PV". A person is never created with a stage entry, so
/// one to prospects is always a way back.
String activityTitle(
  AppLocalizations l10n,
  Activity activity,
  BusinessModel model,
) {
  final amount = activity.amount;
  if (amount != null) return l10n.historyOrder(model.name, amount);
  return switch (activity.stage) {
    null => activity.text!,
    Stage.prospect => l10n.historyBackToProspects,
    Stage.customer => l10n.historyBecameCustomer,
    Stage.team => l10n.historyJoinedTeam,
  };
}
```

```dart
/// "13 October · Call"; a stage entry has the day alone. An order with an
/// amount already says Order in its title: the day, then its note if any.
String activityMeta(AppLocalizations l10n, Activity activity, DateTime today) {
  final day = dayLabel(l10n, activity.day, today);
  if (activity.amount != null) {
    final note = activity.text;
    return note == null ? day : l10n.historyOrderMeta(day, note);
  }
  final kind = kindLabel(l10n, activity.kind);
  return kind == null ? day : l10n.historyMeta(day, kind);
}
```

`lib/features/contacts/presentation/history_section.dart`: import
`package:loomia/core/business_model/business_model.dart` and
`package:loomia/features/auth/data/auth_repository.dart`. In
`_HistorySectionState.build`, after `final today = DateTime.now();`:

```dart
    final model =
        ref.watch(accountProvider)?.businessModel ?? BusinessModel.other;
```

Pass `model: model` to each `_Entry`. In `_Entry`, add
`required this.model` to the constructor, `final BusinessModel model;`, and
`title: activityTitle(l10n, activity, model),`.

- [ ] **Step 7: Run the tests, see them pass**

Run: `flutter test test/features/contacts/domain/activity_test.dart test/features/contacts/presentation/people_copy_test.dart && flutter analyze`
Expected: all pass, "No issues found!".

- [ ] **Step 8: Commit**

```bash
git add supabase/migrations/*_order_amount.sql supabase/tests/order_test.sql lib/l10n/app_en.arb lib/features/contacts/domain/activity.dart lib/features/contacts/presentation/people_copy.dart lib/features/contacts/presentation/history_section.dart test/features/contacts/domain/activity_test.dart test/features/contacts/presentation/people_copy_test.dart
git commit -m "feat(contacts): an order can carry an amount"
```

---

### Task 2: `parseAmount`, the draft and the repository

**Files:**
- Modify: `lib/features/contacts/domain/activity.dart` (`parseAmount`, `ActivityDraft`)
- Modify: `lib/features/contacts/data/activity_repository.dart`
- Modify: `test/features/contacts/fake_activity_repository.dart`
- Modify: every `ActivityDraft` record literal (`flutter analyze` lists them: `log_activity_sheet.dart`, `history_controller_test.dart`, `people_controller_test.dart`, `activity_repository_test.dart`, and any other)
- Test: `test/features/contacts/domain/activity_test.dart`, `test/features/contacts/data/activity_repository_test.dart`

**Interfaces:**
- Consumes: `Activity.amount` (Task 1).
- Produces: `double? parseAmount(String input)`; `typedef ActivityDraft = ({ActivityKind kind, DateTime happenedOn, String text, double? amount})`. `text` may be blank only on an order with an amount; the row writes it as null.

- [ ] **Step 1: Write the failing tests**

Append to `test/features/contacts/domain/activity_test.dart`:

```dart
  group('parseAmount', () {
    test('a whole number, or up to two decimals', () {
      expect(parseAmount('100'), 100);
      expect(parseAmount('99.5'), 99.5);
      expect(parseAmount('99.50'), 99.5);
    });

    test('a comma is a decimal point', () {
      expect(parseAmount('12,5'), 12.5);
    });

    test('spaces are ignored, the French narrow one too', () {
      expect(parseAmount(' 1 840 '), 1840);
      expect(parseAmount('1\u202F840'), 1840);
    });

    test('three decimals are a thousands separator: refused, not 6', () {
      expect(parseAmount('6,000'), isNull);
      expect(parseAmount('6.000'), isNull);
    });

    test('zero, negative, text, empty or too big: refused', () {
      expect(parseAmount('0'), isNull);
      expect(parseAmount('0.00'), isNull);
      expect(parseAmount('-5'), isNull);
      expect(parseAmount('abc'), isNull);
      expect(parseAmount(''), isNull);
      expect(parseAmount('12345678901'), isNull);
    });

    test('the largest the column holds is accepted', () {
      expect(parseAmount('9999999999.99'), 9999999999.99);
    });
  });
```

In `test/features/contacts/data/activity_repository_test.dart`, add
`'amount': null,` to `_row`, then add to the `activityFromRow` group:

```dart
    test('reads an order amount, whole or not', () {
      expect(
        activityFromRow(_row({'kind': 'order', 'amount': 100})).amount,
        100,
      );
      expect(
        activityFromRow(
          _row({'kind': 'order', 'text': null, 'amount': 99.5}),
        ).amount,
        99.5,
      );
    });
```

Replace the existing `activityDraftToRow` test with:

```dart
  test('activityDraftToRow writes the day as yyyy-MM-dd and trims', () {
    expect(
      activityDraftToRow('p1', (
        kind: ActivityKind.order,
        happenedOn: DateTime(2026, 3, 4),
        text: '  Two creams ',
        amount: null,
      )),
      {
        'person_id': 'p1',
        'kind': 'order',
        'happened_on': '2026-03-04',
        'text': 'Two creams',
        'amount': null,
      },
    );
  });

  test('activityDraftToRow: an amount alone writes no text', () {
    expect(
      activityDraftToRow('p1', (
        kind: ActivityKind.order,
        happenedOn: DateTime(2026, 3, 4),
        text: '   ',
        amount: 100,
      )),
      {
        'person_id': 'p1',
        'kind': 'order',
        'happened_on': '2026-03-04',
        'text': null,
        'amount': 100,
      },
    );
  });
```

- [ ] **Step 2: Run the tests, see them fail**

Run: `flutter test test/features/contacts/domain/activity_test.dart test/features/contacts/data/activity_repository_test.dart`
Expected: compile errors: `parseAmount` undefined, the draft has no `amount`.

- [ ] **Step 3: Implement**

`lib/features/contacts/domain/activity.dart`, replace the typedef and add
`parseAmount` below it:

```dart
/// What Log something collects. Never a stage entry. [text] may be blank only
/// on an order with an [amount]; [amount] is set only on an order.
typedef ActivityDraft = ({
  ActivityKind kind,
  DateTime happenedOn,
  String text,
  double? amount,
});

/// An order's amount as typed: digits, then `.` or `,` and at most two
/// decimals (the column is numeric(12,2)). Spaces are ignored, so "1 840" is
/// 1840. Null for anything else, zero included. "6,000" is refused rather
/// than read as 6: three decimals can only be a thousands separator.
double? parseAmount(String input) {
  final match = RegExp(
    r'^(\d{1,10})(?:[.,](\d{1,2}))?$',
  ).firstMatch(input.replaceAll(RegExp(r'\s'), ''));
  if (match == null) return null;
  final value = double.parse('${match[1]}.${match[2] ?? '0'}');
  return value > 0 ? value : null;
}
```

`lib/features/contacts/data/activity_repository.dart`: in `activityFromRow`
add `amount: (row['amount'] as num?)?.toDouble(),` (PostgREST returns
`numeric` as a JSON number, whole ones as `int`). Replace
`activityDraftToRow`:

```dart
Map<String, dynamic> activityDraftToRow(String personId, ActivityDraft draft) {
  assert(
    draft.kind.byUser,
    'Only the database writes stage entries; step entries come from complete_step',
  );
  assert(
    draft.amount == null || draft.kind == ActivityKind.order,
    'Only an order has an amount',
  );
  final text = draft.text.trim();
  return {
    'person_id': personId,
    'kind': draft.kind.name,
    'happened_on': dayColumn(draft.happenedOn),
    'text': text.isEmpty ? null : text,
    'amount': draft.amount,
  };
}
```

`test/features/contacts/fake_activity_repository.dart`, in `add`:

```dart
    final text = draft.text.trim();
    final activity = Activity(
      id: 'a-${_next++}',
      personId: personId,
      kind: draft.kind,
      happenedOn: draft.happenedOn,
      text: text.isEmpty ? null : text,
      amount: draft.amount,
      createdAt: DateTime.utc(2026, 9, 28, 12),
    );
```

Every other `ActivityDraft` record literal gains `amount: null`. In
`log_activity_sheet.dart` that is a placeholder until Task 3 wires the field.

- [ ] **Step 4: Run the tests, see them pass**

Run: `flutter analyze && flutter test test/features/contacts`
Expected: "No issues found!", all pass.

- [ ] **Step 5: Commit**

```bash
git add lib/features/contacts test/features/contacts
git commit -m "feat(contacts): read and write an order's amount"
```

---

### Task 3: Amount in Log something

**Files:**
- Modify: `lib/features/contacts/presentation/log_activity_sheet.dart`
- Modify: `test/features/contacts/presentation/form_harness.dart` (an `account` parameter)
- Modify: `test/features/contacts/presentation/contacts_page_test.dart` (an `auth` parameter on `openContacts` / `openMarie`)
- Modify: `docs/design/screens.md` (the Log something line)
- Test: `test/features/contacts/presentation/log_activity_sheet_test.dart`, `test/features/contacts/presentation/contacts_page_test.dart`

**Interfaces:**
- Consumes: `parseAmount`, `ActivityDraft.amount` (Task 2); `orderUnit`, `logAmount`, `logNote`, `logAmountInvalid`, `logOrderRequired`, `historyOrder` (Task 1); `accountProvider` (`lib/features/auth/data/auth_repository.dart`).

- [ ] **Step 1: Let the harnesses take an account**

`form_harness.dart`: add the parameter
`Account account = const Account(firstName: 'Pauline', email: 'p@example.com'),`
to `pumpFormHarness` and use `..account = account` instead of the literal.

`contacts_page_test.dart`: add `FakeAuthRepository? auth` to `openContacts`
(passed to `pumpLoomia(auth: auth)`) and to `openMarie` (passed to
`openContacts`). Import `../../auth/fake_auth_repository.dart`,
`package:loomia/features/auth/domain/account.dart` and
`package:loomia/core/business_model/business_model.dart` if not already there.

- [ ] **Step 2: Write the failing tests**

In `log_activity_sheet_test.dart`, import
`package:loomia/core/business_model/business_model.dart`,
`package:loomia/core/ui/labeled_field.dart` and
`package:loomia/features/auth/domain/account.dart`. Change `open` to:

```dart
  Future<void> open(
    WidgetTester tester, {
    BusinessModel model = BusinessModel.doterra,
  }) => pumpFormHarness(
    tester,
    people: FakePeopleRepository([_claire]),
    activities: activities,
    account: Account(
      firstName: 'Pauline',
      email: 'p@example.com',
      businessModel: model,
    ),
    open: (context) => showLogActivity(context, _claire),
    result: (_) {},
  );

  Finder field(String label) => find.descendant(
    of: find.widgetWithText(LabeledField, label),
    matching: find.byType(TextFormField),
  );

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
  }
```

Append:

```dart
  testWidgets('Order asks for an amount in PV and a note', (tester) async {
    await open(tester);
    expect(find.text('Amount'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Order'));
    await tester.pumpAndSettle();

    expect(field('Amount'), findsOneWidget);
    expect(find.text('PV'), findsOneWidget);
    expect(field('Note'), findsOneWidget);
    expect(find.text('What happened'), findsNothing);
  });

  testWidgets('Other shows no unit', (tester) async {
    await open(tester, model: BusinessModel.other);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Order'));
    await tester.pumpAndSettle();

    expect(field('Amount'), findsOneWidget);
    expect(find.text('PV'), findsNothing);
  });

  testWidgets('an amount alone saves', (tester) async {
    await open(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Order'));
    await tester.pumpAndSettle();

    await tester.enterText(field('Amount'), '100');
    await save(tester);

    final saved = activities.store.single;
    expect(saved.kind, ActivityKind.order);
    expect(saved.amount, 100);
    expect(saved.text, isNull);
  });

  testWidgets('an amount and a note save together', (tester) async {
    await open(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Order'));
    await tester.pumpAndSettle();

    await tester.enterText(field('Amount'), '12,5');
    await tester.enterText(field('Note'), 'Wild Orange');
    await save(tester);

    final saved = activities.store.single;
    expect(saved.amount, 12.5);
    expect(saved.text, 'Wild Orange');
  });

  testWidgets('an order with neither is refused', (tester) async {
    await open(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Order'));
    await tester.pumpAndSettle();

    await save(tester);

    expect(find.text('Add an amount or a note.'), findsOneWidget);
    expect(activities.calls, isNot(contains('add(p1)')));
  });

  testWidgets('a bad amount is refused', (tester) async {
    await open(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Order'));
    await tester.pumpAndSettle();

    for (final typed in ['6,000', '0', 'abc']) {
      await tester.enterText(field('Amount'), typed);
      await save(tester);
      expect(
        find.text('Use a number above 0, like 100 or 99.5.'),
        findsOneWidget,
        reason: typed,
      );
    }
    expect(activities.calls, isNot(contains('add(p1)')));
  });

  testWidgets('an amount typed under Order is dropped for another kind', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Order'));
    await tester.pumpAndSettle();
    await tester.enterText(field('Amount'), '100');

    await tester.tap(find.widgetWithText(ChoiceChip, 'Call'));
    await tester.pumpAndSettle();
    await tester.enterText(field('What happened'), 'Called back');
    await save(tester);

    final saved = activities.store.single;
    expect(saved.kind, ActivityKind.call);
    expect(saved.amount, isNull);
  });
```

In `contacts_page_test.dart`, after `Log something from ⋯ adds to the history`:

```dart
  testWidgets('Log an order from ⋯ reads Order · 100 PV', (tester) async {
    final auth = FakeAuthRepository()
      ..session = true
      ..account = const Account(
        firstName: 'Pauline',
        email: 'p@example.com',
        businessModel: BusinessModel.doterra,
      );
    await openMarie(tester, auth: auth);

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log something'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Order'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.widgetWithText(LabeledField, 'Amount'),
        matching: find.byType(TextFormField),
      ),
      '100',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    await reveal(tester, find.text('Order · 100 PV'));
    expect(find.text('Order · 100 PV'), findsOneWidget);
  });
```

(`pumpLoomia` registers `addTearDown(auth.dispose)` for the auth it is given;
do not dispose it again.)

- [ ] **Step 3: Run the tests, see them fail**

Run: `flutter test test/features/contacts/presentation/log_activity_sheet_test.dart test/features/contacts/presentation/contacts_page_test.dart`
Expected: the new tests fail (no Amount field); the old ones pass.

- [ ] **Step 4: Implement**

`log_activity_sheet.dart`: import
`package:loomia/core/business_model/business_model.dart` and
`package:loomia/features/auth/data/auth_repository.dart`.

State: add `final _amount = TextEditingController();` and dispose it with
`_text`.

In `_submit`, the draft:

```dart
      await ref.read(historyProvider(widget.person.id).notifier).add((
        kind: _kind,
        happenedOn: _day,
        text: _text.text.trim(),
        // Typed under Order, then another kind picked: not this entry's.
        amount: _kind == ActivityKind.order ? parseAmount(_amount.text) : null,
      ));
```

In `build`, after `final currentDay = today();`:

```dart
    final order = _kind == ActivityKind.order;
    final unit = l10n.orderUnit(
      (ref.watch(accountProvider)?.businessModel ?? BusinessModel.other).name,
    );
```

Between the When field and the text field:

```dart
            if (order)
              LabeledField(
                label: l10n.logAmount,
                child: TextFormField(
                  controller: _amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    suffixText: unit.isEmpty ? null : unit,
                  ),
                  validator: (value) {
                    final typed = (value ?? '').trim();
                    return typed.isEmpty || parseAmount(typed) != null
                        ? null
                        : l10n.logAmountInvalid;
                  },
                ),
              ),
```

The text field: `label: order ? l10n.logNote : l10n.logWhat,` and

```dart
                validator: (value) {
                  if ((value ?? '').trim().isNotEmpty) return null;
                  if (!order) return l10n.logWhatRequired;
                  return _amount.text.trim().isEmpty
                      ? l10n.logOrderRequired
                      : null;
                },
```

`docs/design/screens.md`, the `HISTORY → Add` sentence becomes: "…opens the
same Log something sheet (note / call / message / order / meeting, date,
text). Order adds an amount in the business model's unit (PV for dōTERRA,
none for Other); the note is then optional, and the history reads
"Order · 100 PV"."

- [ ] **Step 5: Run the tests, see them pass**

Run: `flutter test test/features/contacts && flutter analyze`
Expected: all pass, "No issues found!".

- [ ] **Step 6: Commit**

```bash
git add lib/features/contacts/presentation/log_activity_sheet.dart test/features/contacts docs/design/screens.md
git commit -m "feat(contacts): log an order's amount"
```

---

### Task 4: Quality gate and PR

- [ ] **Step 1: Gate**

Run: `dart format . && flutter analyze && flutter test`
Expected: 0 files changed by format (commit any it changes as
`style: dart format`), "No issues found!", all tests pass.

- [ ] **Step 2: Push and open the PR** (only once the user says so)

```bash
git push -u origin feature/138-order-amount
gh pr create --base main --title "feat(contacts): amount on orders" --body-file <filled template>
```

Body: **Ticket** `Closes #138`. What & why: the amount, the sheet, the
history title, the own-order database rule; the own-order sheet moves to #142
with its entry point. Screenshots: none (no preview changed).

- [ ] **Step 3: Watch CI**

Run: `gh pr checks <number> --watch`
Expected: all green, including `Supabase migrations` (pgTAP `order_test.sql`
and the existing `activity_test.sql`, whose blank-note test must still pass
under `entry_shape`).
