# People — database conventions and contacts with a stage

Issues [#48](https://github.com/paulthvt/folo-mlm/issues/48) and
[#55](https://github.com/paulthvt/folo-mlm/issues/55), part of
[#53](https://github.com/paulthvt/folo-mlm/issues/53). Design decided
2026-09-28. Mockups: [Figma → Contacts, stages & workflows](https://www.figma.com/design/spz2vsSK8gbt1Ok2rW1sdQ/Folo?node-id=97-1360),
light and dark pages. Rules and frames: `docs/design/screens.md` §7.

This is the first product table and the first real data in the app. It also
brings the second navigation destination, so the shell gains its mobile bottom
bar.

---

## 1. Scope

In:

- The database conventions every table follows (#48), applied in the first
  migration: `person`.
- `person` with its stage, its prospect status and its facts.
- The Contacts list, the contact detail screen (mobile and the desktop pane),
  Add someone, Edit details, Delete.
- Message and Call, through `url_launcher`.
- Pull to refresh, plus a silent reload when the app returns to the foreground.

Out, each in its own issue:

- History, Log something, the full ⋯ menu, stage changes, Pause: #56.
- Workflows, `NEXT STEP`, "How did it end?", and the "Needs a nudge" grouping: #57.
- Today on real data: #58.
- Team profile fields: #60.
- Import: #61.
- The shared offline presentation: #46. This spec only needs an error state with Retry.
- Realtime. Nothing updates across devices without a refresh. Revisit if people
  really use two devices at once.

## 2. Database

### Conventions (#48, recorded in `docs/architecture.md`)

- Every table has RLS enabled. The default policies (select, insert, update,
  delete) check `owner_id = (select auth.uid())`. The `(select …)` form lets
  Postgres evaluate it once per query instead of once per row, as the Supabase
  linter recommends. Team visibility is a later decision.
- `id uuid primary key default gen_random_uuid()`.
- `owner_id uuid not null default auth.uid() references auth.users on delete
  cascade`. The `delete-account` function relies on this: deleting the user
  deletes everything they own.
- `created_at` and `updated_at timestamptz not null default now()`, with
  `updated_at` kept up to date by one shared trigger function,
  `set_updated_at()`.
- **Hard delete.** "Not now" is a status and Pause is a flag (#56). Neither one
  needs rows kept around after deletion.
- **Dates.** A calendar day (a due date, a birthday) is `date`. An instant is
  `timestamptz`. "Today" is computed on the device, in the device's timezone,
  never on the server.
- Grants go to `authenticated` only; `anon` gets nothing.
- Enums are Postgres enum types. Adding a value is a migration, which is the
  point.

### Migration `supabase/migrations/<timestamp>_people.sql`

```sql
create function public.set_updated_at() returns trigger
language plpgsql set search_path = '' as $$
begin
  new.updated_at = now();
  return new;
end $$;

create type public.person_stage as enum ('prospect', 'customer', 'team');
create type public.prospect_status as enum
  ('interested', 'thinking', 'not_now', 'no_reply');

create table public.person (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid()
    references auth.users on delete cascade,
  name text not null check (length(trim(name)) > 0),
  stage public.person_stage not null,
  prospect_status public.prospect_status,
  phone text,
  email text,
  instagram text,
  needs text,
  products text,
  profession text,
  address text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint status_only_for_prospects
    check (prospect_status is null or stage = 'prospect')
);

create index person_owner_id_idx on public.person (owner_id);

create trigger person_set_updated_at before update on public.person
  for each row execute function public.set_updated_at();

alter table public.person enable row level security;
-- four policies, one per command, all on owner_id = (select auth.uid())
revoke all on public.person from anon;
grant select, insert, update, delete on public.person to authenticated;
```

`needs` and `products` are free text ("Sleep, stress, dry skin"). This makes
entry fast and imports straight from a spreadsheet. Filtering by product
later can search inside the text.

### Test: `supabase/tests/person_rls_test.sql` (pgTAP)

The test creates two users. User A inserts a person. As user B, it checks that
select returns zero rows, update and delete affect zero rows, and inserting a
row with `owner_id` set to user A fails. It also checks that `anon` sees
nothing. It runs in CI after `supabase db reset` with `supabase test db`.

## 3. Domain and data (`lib/features/contacts/`)

### `domain/person.dart`

- `enum Stage { prospect, customer, team }`.
- `enum ProspectStatus { interested, thinking, notNow, noReply }`.
- `Person`, an immutable class. Fields: `id`, `name`, `stage`, `prospectStatus`,
  `phone`, `email`, `instagram`, `needs`, `products`, `profession`, `address`,
  `notes`, `createdAt`. It has `withStatus(status)`; Edit builds a new `Person`
  from its fields, so there is no generic `copyWith`. When the stage is not prospect,
  `prospectStatus` is null (the database enforces this too).
- `PersonDraft`, a record used by Add someone: name, stage, and the optional
  channels.
- `ContactChannel guessChannel(String input)`, the single field in Add someone:
  - trimmed input containing `@` followed by a dot means email;
  - input made only of digits, spaces, `+`, `.`, `-` and `()`, with at least 6
    digits, means phone;
  - anything else means Instagram, with a leading `@` removed.
- `String searchKey(String)`: lowercase with accents removed, so "helene"
  finds "Hélène". A small fold table, no package.

### `domain/people_failure.dart`

`enum PeopleFailure { network, unknown }`. A screen reacts to exactly these
two, the same way `AuthFailure` works.

### `data/people_repository.dart`

This is a concrete class with no interface.

- `Future<List<Person>> list()`: `from('person').select()`. The controller
  sorts by `searchKey(name)`, so "Élodie" sorts with the E's.
- `Future<Person> add(PersonDraft)`: `insert(...).select().single()`.
- `Future<Person> update(Person)`: `update(...).eq('id', id).select().single()`.
- `Future<void> delete(String id)`.
- Row mapping in both directions: snake_case columns to Dart names, and
  `not_now` to `ProspectStatus.notNow`. An unknown enum value throws
  `PeopleFailure.unknown`. It is never silently defaulted.
- Every call goes through `_guard`, which turns errors into `PeopleFailure`.
  `SocketException`, `TimeoutException` and `http.ClientException` become
  `network`; everything else becomes `unknown`.
- `peopleRepositoryProvider` builds it from `supabaseClientProvider`.

The comment on `AuthRepository` saying it is "the only file that imports
`supabase_flutter`" changes to say only `data/` files import it.

### `presentation/people_controller.dart`

- `peopleProvider = AsyncNotifierProvider<PeopleController, List<Person>>`.
  - `build()` watches `accountProvider`, so signing out or switching accounts
    reloads, and user B never sees user A's cached list. It returns
    `repository.list()`.
  - `add`, `save` and `remove` call the repository, then replace `state` with
    the updated list, keeping it sorted by name.
  - On failure, those three rethrow the `PeopleFailure` and leave `state` as it
    was, so the list never blanks because of a failed save.
  - `setStatus(person, status)` updates the list immediately. If the save
    fails, it puts the previous value back and rethrows.
  - `refresh()` reloads while keeping the old list visible:
    `ref.refresh(peopleProvider.future)` from the screens.
- There is no `personProvider`: the detail pane finds its id in
  `peopleProvider`'s list. There is no second fetch.
- The search text and the stage filter live in the list screen's local
  `setState`.

### Foreground reload

In `ContactsPage`, an `AppLifecycleListener(onResume: ...)` calls `refresh()`
if the last load finished more than a minute ago. The controller keeps
`loadedAt`.

## 4. Navigation

- In `routes.dart`, first: `contacts = '/contacts'` and `contact = '/contacts/:id'`,
  plus `contactLocation(id)`.
- The router keeps its plain `ShellRoute`. `/contacts` (with a child route
  `:id`) gets its own nested `ShellRoute`, which on desktop keeps the list
  built beside the pane. There is no `StatefulShellRoute`: a tab does not keep
  its own stack. Settings stays where it is, reached from the account avatar
  (mobile) or the account block (sidebar), as now.
- `AppShell`:
  - On mobile it shows a `NavigationBar` with Today and Contacts. Team and Goals
    join when they exist, never as placeholders.
  - The sidebar and rail get a Contacts item.
  - On mobile the bottom bar stays visible on `/contacts/:id`, as in the
    mockups. It is hidden only on Settings, which has its own back button.
- On desktop (`usesSideNavigation` and `isDesktop`), `/contacts` and
  `/contacts/:id` both render the split: a 440px list column plus the detail
  pane. Selecting a row calls `context.go(Routes.contactLocation(id))`: the URL
  changes, there is no push, and the list keeps its scroll position. With no
  selection, the pane shows an empty state. On tablet, the list and the detail
  are separate screens, as on mobile.

## 5. Screens

All copy goes in `app_en.arb` with a description. `app_fr.arb` is never
touched: Tolgee provides French through the l10n pull. The vocabulary is
prospect / customer / team, and never "prospecting", "recruit" or "lead".

### Contacts list (`presentation/contacts_page.dart`)

- The top bar shows "Contacts", Add, and on side navigation a refresh
  `IconButton` (a mouse cannot pull).
- A SearchField matches `searchKey(name)`.
- Stage `ChoiceChip`s: Everyone / Prospects / Customers / Team.
- Each row is a `ContactRow`: avatar, name, a neutral stage chip, and a subtitle
  showing the first filled of profession, then needs.
- Rows are sorted by name, with no grouping.
- `RefreshIndicator` around the list.
- States:
  - Loading: a progress indicator.
  - Empty book: `EmptyState` with an Add action.
  - Nothing matches the search or filter: a one-line "Nobody matches" message.
  - Error: a message with Retry. #46 replaces it with the shared offline
    presentation.

### Contact detail (`presentation/contact_page.dart`)

- Header: avatar 56, name, then "Prospect since March 2026" (the stage plus
  the `createdAt` month and year), then a stage chip.
- Message and Call:
  - Call launches `tel:`.
  - Message launches `sms:` when a phone exists, otherwise
    `https://instagram.com/<handle>`.
  - A button is hidden when its channel is empty. When neither exists, the row
    is hidden too.
  - Email shows as a fact and opens `mailto:` when tapped.
- ⋯ opens a menu (`PopupMenuButton`) with Edit details and Delete. Delete is the only red item.
  It asks for confirmation first ("Delete Sarah? Her details are removed for
  good."). The remaining items arrive in #56.
- For prospects, `WHERE IT STANDS` shows the four `ChoiceChip`s, saved as soon
  as one is tapped. Tapping the selected chip again clears it.
- `WHAT YOU KNOW` has `FactRow`s for filled fields only: needs, products,
  profession, reach (phone, email, Instagram), address, notes. Edit is the
  section header action. With nothing filled in, it shows one line, "Nothing
  yet", plus Edit.
- `RefreshIndicator` around the scroll view.
- A missing id (deleted elsewhere, or a bad URL) shows "This person isn't here
  anymore" with a back-to-Contacts action.
- There is no `NEXT STEP` or `HISTORY` yet. Those sections arrive whole, with
  #57 and #56.

### Add someone (bottom sheet on mobile, dialog on desktop)

- Name (required), then "Phone, email or Instagram" (optional, one field, read
  with `guessChannel`), then the stage chips (default Prospect).
- Save stays on the sheet while the insert runs. On failure it shows a
  `FormError`. On success the sheet closes and the new person's detail opens.

### Edit details (the same scrolling sheet as Add someone on mobile, dialog on desktop)

- Every field of §3 except the stage, which moves through the ⋯ menu in #56.
  The prospect status is edited on the detail screen, not here.
- Save and Cancel. On failure it shows a `FormError` and keeps the input.

### Components

- `FactRow` joins `core/ui/`: label over value, which grows with its content.
- `ContactRow` joins `core/ui/` (avatar, name, subtitle, trailing chip).
- Any new component gets an `@Preview` and a golden.

## 6. Errors

| Where | Failure | What the user sees |
| --- | --- | --- |
| List load | network / unknown | Error state + Retry |
| Refresh | any | SnackBar; the old list stays |
| Add / Edit save | any | `FormError` in the form; the input is kept |
| Status chip | any | The chip reverts, with a SnackBar |
| Delete | any | SnackBar; the person stays |
| Launch (tel/sms/url) | cannot launch | SnackBar "Couldn't open …" |

Copy: "Couldn't save. Check your connection and try again." for `network`,
"Something went wrong. Try again." for `unknown`.

## 7. Dependency

`url_launcher`. Pubspec comment: *Opens the dialer, SMS, email and Instagram
from Message / Call. Nothing in the SDK launches another app.* Android 11+ needs
`<queries>` for the `tel`, `sms`, `mailto` and `https` intents in
`AndroidManifest.xml`. iOS needs `LSApplicationQueriesSchemes` for `tel` and
`sms` in `Info.plist`.

## 8. Tests

- SQL: the RLS test (§2).
- Plain Dart:
  - row mapping in both directions, including an unknown enum value;
  - `guessChannel`;
  - `searchKey`;
  - the controller with `FakePeopleRepository` (in memory, `failWith`, `gate`,
    like `FakeAuthRepository`): add, save and remove update the list; a failure
    keeps the list and rethrows; `setStatus` rolls back on failure; switching
    account reloads.
- Widget:
  - List: filter, search, empty, no match, error + Retry, pull to refresh.
  - Detail: status chips, buttons hidden without a channel, delete
    confirmation, missing person.
  - Add sheet: validation, failure, success opens detail.
  - Edit: save and failure.
- Router: on mobile, the bottom bar stays on a person and is hidden on
  Settings; on desktop, the split with a selection keeps the list's filter.
- Goldens for every new `@Preview`, regenerated through CI (README → *Golden
  tests*).

## 9. Delivery

1. **`feature/48-db-conventions`**, which closes #48. It contains the migration,
   the RLS test and the `supabase test db` step in CI, the conventions in
   `docs/architecture.md`, and `domain/`, `data/`, the controller, the fake and
   their tests. No UI.
2. **`feature/55-people`**, which closes #55. It contains the routes, the shell
   with two destinations, the screens, `url_launcher`, the strings, the goldens
   and the widget tests.

After merging (1), the migration reaches the hosted project by hand with
`supabase db push`, as documented.
