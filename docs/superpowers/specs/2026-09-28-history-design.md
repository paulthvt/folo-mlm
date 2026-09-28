# History — Log something, the ⋯ menu, stage changes

Issue [#56](https://github.com/paulthvt/folo-mlm/issues/56), part of
[#53](https://github.com/paulthvt/folo-mlm/issues/53). Design decided
2026-09-28. Builds on [2026-09-28-people-design.md](2026-09-28-people-design.md).
Mockups: [Figma → Contacts, stages & workflows](https://www.figma.com/design/spz2vsSK8gbt1Ok2rW1sdQ/Folo?node-id=97-1360)
— Contact actions sheet (`101:2004`), Log something (`101:2118`), Change stage
(`99:2426`), Contact detail — customer (`97:1491`).

---

## 1. Scope

In:

- A person's history: the `HISTORY` section, Log something, deleting an entry.
- Stage changes, moving forward and back, recorded in the history.
- The full ⋯ menu for everything above, plus Edit details and Delete.
- "Customer since …" read from when the stage began, not from when the person
  was added.

Out, moved to [#57](https://github.com/paulthvt/folo-mlm/issues/57) with the
workflows:

- Pause.
- FOLLOW WITH and the first-step date on the Change stage sheet.
- The Change workflow row.
- The `step` activity kind.

History entries are never edited, only deleted.

## 2. Database

Migration `supabase/migrations/<timestamp>_history.sql`, made with
`supabase migration new history`.

### `person`

```sql
alter table public.person add column stage_since timestamptz;
update public.person set stage_since = created_at;
alter table public.person
  alter column stage_since set not null,
  alter column stage_since set default now();

-- Target of the composite foreign key below.
alter table public.person add constraint person_id_owner_key unique (id, owner_id);
```

### `activity`

```sql
create type public.activity_kind as enum
  ('note', 'call', 'message', 'order', 'meeting', 'stage');

create table public.activity (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid()
    references auth.users on delete cascade,
  person_id uuid not null,
  kind public.activity_kind not null,
  happened_on date not null default current_date,
  text text,
  stage public.person_stage,
  created_at timestamptz not null default now(),
  -- An entry always belongs to the person's owner.
  foreign key (person_id, owner_id)
    references public.person (id, owner_id) on delete cascade,
  constraint stage_entry_shape check (
    (kind = 'stage' and stage is not null and text is null)
    or (kind <> 'stage' and stage is null
        and text is not null and length(trim(text)) > 0)
  )
);

create index activity_person_id_owner_id_idx
  on public.activity (person_id, owner_id);

alter table public.activity enable row level security;
-- select and delete on owner_id = (select auth.uid());
-- delete also requires kind <> 'stage';
-- insert checks owner_id = (select auth.uid()) and kind <> 'stage'.
revoke all on public.activity from anon, authenticated;
grant select, insert, delete on public.activity to authenticated;
```

A deviation from the #48 conventions: there is no `updated_at` and no update
grant, because entries are never edited. `docs/architecture.md` gets one line
saying a table without updates drops `updated_at`.

The client cannot write stage entries. Only the trigger below can.

### Trigger `person_stage_changed`

```sql
create function public.person_stage_changed() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  new.stage_since = now();
  if new.stage <> 'prospect' then
    new.prospect_status = null;
  end if;
  insert into public.activity (owner_id, person_id, kind, stage)
    values (new.owner_id, new.id, 'stage', new.stage);
  return new;
end $$;

create trigger person_stage_changed before update of stage on public.person
  for each row when (old.stage is distinct from new.stage)
  execute function public.person_stage_changed();
```

`security definer` lets it insert past the `kind <> 'stage'` insert policy. It
only writes the row's own owner and id, both taken from the row being updated,
which RLS has already allowed.

### Test: `supabase/tests/activity_test.sql` (pgTAP)

- Changing the stage writes one stage entry, sets `stage_since`, and clears the
  prospect status.
- Updating only the name writes no entry and leaves `stage_since` alone.
- User B sees none of A's entries; delete affects zero rows.
- A stage entry cannot be deleted, even by its owner.
- Inserting a `stage` entry directly fails.
- Inserting an entry on another user's person fails (the composite foreign key).
- `anon` sees nothing.

## 3. Domain and data (`lib/features/contacts/`)

### `domain/activity.dart`

- `enum ActivityKind { note, call, message, order, meeting, stage }`.
- `Activity`, immutable: `id`, `personId`, `kind`, `happenedOn`, `text`,
  `stage`, `createdAt`. An assert mirrors the `stage_entry_shape` check.
- `DateTime get day`: `happenedOn` for every entry except a stage entry, which
  uses the local date of `createdAt`. The trigger's `current_date` is a UTC day,
  and "today" is decided on the device (#48 conventions).
- `typedef ActivityDraft = ({ActivityKind kind, DateTime happenedOn, String text})`,
  what Log something collects. It is never a stage entry.

### `domain/person.dart`

- `Person` gains `stageSince` and loses `createdAt`, which nothing reads any
  more. The column stays in the database.

### `data/`

- `_guard` moves from `PeopleRepository` to one shared function in `data/`,
  used by both repositories. `PeopleFailure` covers both.
- `PeopleRepository.setStage(String id, Stage stage)` returns `Person`: it
  updates only `stage` and returns the row as the trigger left it.
- `data/activity_repository.dart`, concrete, no interface:
  - `Future<List<Activity>> list(String personId)`: every entry of one person.
    `// ponytail: whole history in one fetch, paginate when a person has hundreds`.
  - `Future<Activity> add(String personId, ActivityDraft draft)`.
  - `Future<void> delete(String id)`.
  - Row mapping both ways; `happened_on` as `yyyy-MM-dd`. An unknown kind
    throws `PeopleFailure.unknown`.
  - `activityRepositoryProvider` builds it from `supabaseClientProvider`.

### `presentation/history_controller.dart`

- `historyProvider = AsyncNotifierProvider.autoDispose.family<HistoryController,
  List<Activity>, String>`, keyed on the person id. It is fetched when the
  contact page opens and dropped when the page closes. Person ids are uuids, so
  no account can see another's cached history.
- The list is sorted by `day` descending, then `createdAt` descending.
- `add(draft)` waits for the server, then places the new entry. On failure it
  rethrows and leaves `state` as it was.
- `remove(activity)` takes the entry out immediately. If the delete fails, it
  puts it back and rethrows.

### `PeopleController.moveTo(Person person, Stage stage)`

It waits for the server, since the trigger decides `stageSince` and the status.
On success it replaces the person in the list and calls
`ref.invalidate(historyProvider(person.id))`. On failure it rethrows and nothing
changes.

## 4. Screens

All copy goes in `app_en.arb` with a description; `app_fr.arb` is never
touched. Copy never guesses a contact's pronouns: it uses the name or
"them".

### The ⋯ menu

The same items on every platform, in this order:

1. Log something
2. One "Move to …" row for each stage other than the current one: "Move to
   prospects", "Move to customers", "Move to team".
3. Edit details
4. "Delete Sarah", red, in its own group.

On mobile it is a bottom sheet with the person's name as the title and Cancel
at the bottom, as in the frame. On desktop it stays a `PopupMenuButton` with the
same items.

### Change stage

It is a bottom sheet on mobile and a dialog on desktop, like Add someone.

- The title depends on the new stage: "Sarah is now a customer", "Sarah is now
  on your team", "Sarah is a prospect again".
- The body reads "Everything you noted stays with them." When a prospect with a
  status leaves prospects, it adds "Where it stands is cleared."
- The Move button is labelled like the row ("Move to customers") and shows
  progress while saving. There is a Cancel button.
- On failure it shows a `FormError` and stays open. On success it closes.

### Log something

It is a bottom sheet on mobile and a dialog on desktop. It opens from the ⋯ menu
and from `HISTORY` → Add.

- The title is "Log something with Claire".
- Kind is a row of `ChoiceChip`s: Note / Call / Message / Order / Meeting.
  Note is selected by default.
- When: a field showing "Today, 28 September". Tapping it opens the date
  picker, Cupertino on iOS and Material elsewhere. Future days can't be picked.
- What happened: required, with the usual field error when empty.
- Save and Cancel. On failure it shows a `FormError` and keeps the input.

### `HISTORY`

The section sits below `WHAT YOU KNOW`, on mobile and in the desktop pane. The
header action is Add.

- Entries use the existing `ActivityItem`, with the rail.
  - Ordinary entry: the text as title, "13 October · Call" as meta.
  - Stage entry: "Became a customer", "Joined your team" or "Back to
    prospects" as title, the date alone as meta.
  - Dates drop the year when it is the current year: "13 October", but
    "13 October 2024".
- It shows the latest 3 entries. "See all 18" expands the rest in place, through
  local `setState`. There is no route.
- Empty: "Nothing logged yet", plus Add.
- Loading: a small progress indicator inside the section only.
- Error: "Couldn't load the history" with Retry, inside the section. The rest of
  the page still works.

### Deleting an entry

- Long-press on mobile or right-click on desktop opens a confirmation dialog,
  "Delete this entry?", with Delete and Cancel. Screen readers get a "Delete"
  custom semantics action.
- The entry disappears at once. If the delete fails, it comes back with a
  SnackBar.
- Stage entries don't react to the gesture and have no action.

### Header

The subtitle "Customer since October 2024" reads `stageSince`.

### Navigation

No new route.

## 5. Errors

| Where | What the user sees |
| --- | --- |
| History load | Error line + Retry inside the section; the rest of the page works |
| Log something save | `FormError` in the sheet; the input is kept |
| Move stage | `FormError` in the sheet; nothing changes |
| Delete entry | The entry comes back, with a SnackBar |

The copy reuses the existing `network` and `unknown` messages. The only new
error string is "Couldn't load the history".

## 6. Tests

- SQL: `activity_test.sql` (§2).
- Plain Dart:
  - activity row mapping both ways, including an unknown kind;
  - `day` for a stage entry created just after midnight local time;
  - `HistoryController` with `FakeActivityRepository` (in memory, `failWith`,
    `gate`, like `FakePeopleRepository`): add places the entry, sorting, remove
    rolls back on failure;
  - `PeopleController.moveTo`: success replaces the person and reloads the
    history; failure leaves the list unchanged.
- Widget:
  - the ⋯ sheet on mobile and the menu on desktop show the right Move rows for
    each stage;
  - Change stage: success, failure, the note about clearing the status;
  - Log something: validation, failure, success;
  - `HISTORY`: 3 entries, See all, empty, error with Retry, deleting an entry,
    a stage entry ignoring the gesture;
  - the header reads `stageSince`.
- Goldens: only for a new `@Preview`, regenerated through CI (README → *Golden
  tests*). None is expected, since `ActivityItem` already exists.

## 7. Delivery

One branch, `feature/56-history`, and one PR that closes #56. It contains the
migration, the pgTAP test, the domain, data, state and screens, and the EN
strings.

After the merge, the migration reaches the hosted project with `supabase db push`
from the user's own terminal, with the VPN off. Until then the hosted app fails
on `stage_since`.

Once the spec is committed, #57 gets a comment listing what moved to it: Pause,
FOLLOW WITH, Change workflow, and the `step` kind.
