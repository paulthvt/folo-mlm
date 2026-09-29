# Workflows — NEXT STEP, Pause, FOLLOW WITH, Change workflow

Issue [#57](https://github.com/paulthvt/folo-mlm/issues/57), part of
[#53](https://github.com/paulthvt/folo-mlm/issues/53). Design decided
2026-09-29. Builds on [2026-09-28-history-design.md](2026-09-28-history-design.md).
Mockups: [Figma → Contacts, stages & workflows](https://www.figma.com/design/spz2vsSK8gbt1Ok2rW1sdQ/Folo?node-id=97-1360)
— Contact detail prospect (`99:1295`), team member (`99:1429`), customer
(`97:1491`), workflow done (`102:2196`), Change stage (`99:2426`), Contact
actions (`101:2004`).

---

## 1. Scope

In:

- The `workflow` and `workflow_step` tables and a person's place in a workflow.
- Default workflows, seeded once per user in English or French.
- The `NEXT STEP` card on the contact detail: tick a step, workflow done, "How
  did it end?", paused, nothing planned.
- Pause and Resume in the ⋯ menu.
- FOLLOW WITH and the first-step date on the Change stage sheet.
- The Change workflow sheet and its ⋯ row.
- The `step` activity kind.
- The edit rules (days changed, step removed, step inserted, rename), as pure
  Dart logic with unit tests. Nothing in the UI edits a workflow yet.

Out:

- Editing workflows in Settings: [#59](https://github.com/paulthvt/folo-mlm/issues/59).
- Today suggesting due steps: [#58](https://github.com/paulthvt/folo-mlm/issues/58).
- Repeating or chained workflows. A finished workflow stays finished until the
  user picks another.
- Picking the tick date, and undoing a tick. Deleting the step entry from the
  history is the escape hatch; it does not move the person back.

Decisions:

- A person follows at most one workflow at a time, or none.
- Someone new starts the default workflow of their stage, counted from the day
  they are added.
- Pause is a flag (`paused_at`). The card hides, the person keeps their step.
  Pausing a prospect also sets the status to Not now. Resume brings the same
  step back, due counted from the day of resuming.
- "Not now" on the "How did it end?" card is Pause.
- Workflows are the user's own data once seeded. They are never translated
  again.

## 2. Database

Migration `supabase/migrations/<timestamp>_workflows.sql`, made with
`supabase migration new workflows`. Every table follows the #48 conventions:
RLS with four policies on `owner_id = (select auth.uid())`, grants to
`authenticated` only, `set_updated_at` trigger.

```sql
alter type public.activity_kind add value 'step';

create table public.workflow (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid()
    references auth.users on delete cascade,
  stage public.person_stage not null,
  name text not null check (length(trim(name)) > 0),
  is_default boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  -- Target of the composite foreign keys below.
  unique (id, owner_id)
);

-- One default per stage.
create unique index workflow_default_idx
  on public.workflow (owner_id, stage) where is_default;

create table public.workflow_step (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid()
    references auth.users on delete cascade,
  workflow_id uuid not null,
  -- Sparse: an inserted step takes the midpoint, so no other position moves.
  position numeric not null,
  label text not null check (length(trim(label)) > 0),
  days int not null check (days >= 0),
  note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (workflow_id, owner_id)
    references public.workflow (id, owner_id) on delete cascade,
  unique (workflow_id, position)
);

alter table public.person
  add column workflow_id uuid,
  add column at_position numeric,
  add column last_tick date,
  add column paused_at timestamptz,
  add foreign key (workflow_id, owner_id)
    references public.workflow (id, owner_id) on delete set null (workflow_id);

create index person_workflow_id_idx on public.person (workflow_id);
```

A person's place:

- **Current step**: the first step with `position >= at_position`. None means
  the workflow is done.
- **Due**: `last_tick + current.days`.
- **Paused**: `paused_at is not null`.

Because the current step is found by position, not by id:

- days changed: the due date follows at once;
- current step removed: the next step becomes current;
- step inserted before the current one: its position is below `at_position`,
  so it is skipped;
- rename: shows at once. History keeps the old label, copied at tick time.

`person_stage_changed` also sets `new.paused_at = null`. The workflow fields of
a stage change travel in the same update as the stage.

### `seed_workflows(p_lang text, p_today date)`

`security invoker`, one transaction.

- Returns at once if the user already has a workflow.
- Inserts the five workflows of §2.1 in `p_lang` (`'fr'` for French, anything
  else English), positions 1, 2, 3…, one default per stage.
- Starts every existing person with no workflow on their stage's default:
  `at_position` = the first step's position, `last_tick = p_today`.
- `p_today` comes from the device: "today" is decided on the device (#48).

### `complete_step(p_person uuid, p_step uuid, p_next_position numeric, p_on date)`

`security invoker`, one transaction.

- Inserts `activity (person_id, kind 'step', text = the step's label,
  happened_on = p_on)`, the label read from `workflow_step`.
- Sets the person's `at_position = p_next_position`, `last_tick = p_on`.
- Returns the updated person row.

Dart computes `p_next_position` (§3), so the rule lives in one place.

Step entries are ordinary entries: the insert policy (`kind <> 'stage'`)
allows them, and they can be deleted.

### 2.1 Default workflows

Days are "days after the previous step" (after the start, for step 1).

| Workflow | Stage | Default | Steps (EN / FR, days) |
| --- | --- | --- | --- |
| Samples / Échantillons | prospect | yes | Send a first message / Envoyer un premier message (0) · Send the samples / Envoyer les échantillons (1) · Samples arrived / Échantillons reçus (4) · Ask how the samples went / Demander comment ça s'est passé (3) · Follow up / Relancer (7) |
| Health professionals / Professionnels de santé | prospect | no | Introduce yourself / Se présenter (0) · Share a product sheet / Partager une fiche produit (2) · Offer a sample kit / Proposer un kit d'échantillons (5) · Follow up / Relancer (7) |
| New customer / Nouveau client | customer | yes | Thank them for the order / Remercier pour la commande (0) · Order arrived / Commande reçue (5) · Check in on the products / Prendre des nouvelles des produits (14) · Suggest a refill routine / Proposer un réassort régulier (21) |
| Refill check-in / Point réassort | customer | no | Ask how supplies are going / Demander où en sont les réserves (25) · Help with the next order / Aider pour la prochaine commande (3) |
| Getting started / Premiers pas | team | yes | Welcome call / Appel de bienvenue (0) · Unboxing call / Appel de déballage (5) · First training / Première formation (3) · First goal together / Premier objectif ensemble (7) · Two-week check-in / Point à deux semaines (14) |

### Test: `supabase/tests/workflow_test.sql` (pgTAP)

- User B sees none of A's workflows or steps; update and delete affect zero
  rows.
- A step can't point at another user's workflow; a person can't point at
  another user's workflow (composite foreign keys).
- `seed_workflows` twice inserts five workflows once, one default per stage.
- The seed starts an existing person on their stage's default.
- `complete_step` writes one `step` entry with the label and moves the person.
- Deleting a workflow sets its people's `workflow_id` to null.
- A stage change clears `paused_at`.
- `anon` sees nothing.

## 3. Domain, data and state

Workflows get their own feature, `lib/features/workflows/`, since #59 edits them
from Settings. Contacts reads it.

### `workflows/domain/workflow.dart`

- `WorkflowStep`: `id`, `position` (`num`), `label`, `days`, `note`.
- `Workflow`: `id`, `stage`, `name`, `isDefault`, `steps` sorted by position.

### `workflows/domain/progress.dart`

Pure functions; this is where the edit rules are tested.

- `sealed class WorkflowProgress`:
  - `Paused(DateTime since)`;
  - `Done(Workflow workflow)`;
  - `OnStep(Workflow workflow, WorkflowStep step, int index, int total, DateTime due)`,
    `index` 1-based for "3 of 5", `due = lastTick + step.days`.
- `WorkflowProgress? progressOf(Person person, Workflow? workflow)`: `null` when
  the person has no workflow (or it isn't in the list). Paused wins over
  everything else. A workflow with no steps is done.
- `num nextPosition(Workflow workflow, WorkflowStep current)`: the next step's
  position, or `current.position + 1` after the last step.
- `({num atPosition, DateTime lastTick}) start(Workflow workflow, {required DateTime firstDue})`:
  `atPosition` = the first step's position, `lastTick = firstDue - first.days`.
  That is how FOLLOW WITH sets the first step's date.
- `DateTime firstDueDefault(Workflow workflow, DateTime today)`:
  `today + first.days`.

### `workflows/data/workflow_repository.dart`

Concrete, no interface, calls go through the shared `guard` and fail with
`PeopleFailure`.

- `Future<List<Workflow>> list()`: `from('workflow').select('*, workflow_step(*)')`.
- `Future<void> seed(String lang, DateTime today)`: the RPC.
- Row mapping; `position` read as `num`.
- `workflowRepositoryProvider` from `supabaseClientProvider`.

### `workflows/presentation/workflows_controller.dart`

- `workflowsProvider = AsyncNotifierProvider.family<WorkflowsController, List<Workflow>, String?>`,
  keyed on the account email like `peopleProvider`. `[]` when signed out.
- `build()` lists. When the list is empty it seeds (`'fr'` when the app locale
  is French, else `'en'`), lists again, and invalidates `peopleProvider`, since
  the seed started people on a workflow.

### `contacts/domain/person.dart`

`Person` gains `workflowId`, `atPosition` (`num?`), `lastTick` (a date) and
`pausedAt`. `PeopleRepository` maps them both ways (`last_tick` as
`yyyy-MM-dd`).

### `PeopleRepository` and `PeopleController`

Each waits for the server, then replaces the person in the list. On failure it
rethrows and leaves `state` as it was.

- `add(draft)`: the insert carries the stage's default workflow, started with
  `firstDueDefault(workflow, today)`. No default (not seeded yet): no workflow.
- `completeStep(person, step)`: `complete_step` with `nextPosition` and today;
  invalidates `historyProvider(person.id)`.
- `pause(person)`: `paused_at = now()`, plus `prospect_status = not_now` for a
  prospect.
- `resume(person)`: `paused_at = null`, `last_tick = today`.
- `setWorkflow(person, Workflow? workflow, DateTime? firstDue)`: Change
  workflow; `null` is "Nothing for now" and clears all three fields.
- `moveTo(person, stage, {Workflow? workflow, DateTime? firstDue})`: stage and
  workflow fields in one update.

## 4. Screens

All copy goes in `app_en.arb` with a description; `app_fr.arb` is never
touched. Copy uses the name or "them", never a guessed pronoun.

### `NEXT STEP` card

Between `WHERE IT STANDS` and `WHAT YOU KNOW`, on mobile and in the desktop
pane. A new component in `core/ui/` with an `@Preview`.

- **On a step**: header "NEXT STEP", trailing "Samples · 3 of 5". Avatar, the
  step label as title, a round tick button. Second line: the due date — "Due
  today", "Due tomorrow", "Due in 3 days" (up to 6), "Due October 2" (later),
  "1 day late" / "3 days late" — then the step's note if any. The tick button's
  semantics label is `Mark "Ask how the samples went" done`.
  - Tick completes the step today. The card moves on when the server answers;
    on failure a SnackBar, and the card stays.
- **Done, prospect** (`102:2196`): "SAMPLES — DONE", "How did it end with
  Sarah?", "All 5 steps are done. Their notes and history stay whatever you
  pick." Became a customer opens Change stage for customers. Not now pauses.
- **Done, customer or team**: "NEW CUSTOMER — DONE", "All 4 steps are done with
  Claire.", "Follow with…" opens Change workflow.
- **Paused**: "Paused since July 12", Resume.
- **No workflow**: "Nothing planned", "Follow with…".
- **Workflows loading**: a small progress indicator in the card. **Error**:
  "Couldn't load the workflows" with Retry, inside the card.

### Follow-with block

One widget, used by Change stage and Change workflow.

- A radio list of the target stage's workflows: "New customer · Suggested · 4
  steps" for the default, "Health professionals · 4 steps" otherwise, then
  "Nothing for now". The default is selected.
- Below it, a date field labelled with the selected workflow's first step
  ("First order" is the label, "Today, September 28" the value), defaulting to
  `firstDueDefault`. Tapping opens the date picker, Cupertino on iOS, Material
  elsewhere. Past days can't be picked. Hidden when "Nothing for now" is
  selected.

### Change stage sheet

Adds the follow-with block for the new stage. When the person is on a
workflow, the body adds "The Samples workflow ends here."

### Change workflow sheet

Bottom sheet on mobile, dialog on desktop, like Change stage. Title "Change
Sarah's workflow". The follow-with block for the person's stage, with their
current workflow selected, or the default if they have none. Save and Cancel;
on failure a `FormError`, and it stays open.

### ⋯ menu

After the Move rows: "Change workflow" with the current workflow's name as
trailing text, then "Pause — not now", or "Resume" while paused. Same items on
the mobile sheet and the desktop popup.

### Contacts list

A paused person's subtitle: "Not now · paused in July" for a prospect whose
status is Not now, "Paused in July" otherwise.

### History

A step entry: the label as title, "October 13 · Step" as meta. It can be
deleted like any ordinary entry. Figma's "— step 2 done" suffix and the
workflow name in the meta would need more columns on `activity`; left out.

### Figma

`102:2196`: "Her notes" becomes "Their notes". The NEXT STEP cards' second line
becomes the due line.

## 5. Errors

| Where | What the user sees |
| --- | --- |
| Workflows load or seed | Error line + Retry inside the card; the rest of the page works |
| Tick, Pause, Resume | SnackBar; the card stays as it was |
| Change stage, Change workflow | `FormError` in the sheet; it stays open |

The copy reuses `network` and `unknown`. The only new error string is
"Couldn't load the workflows".

## 6. Tests

- SQL: `workflow_test.sql` (§2). Existing tests keep passing.
- Plain Dart:
  - `progress.dart`: each edit rule (days changed, current step removed, step
    inserted before, rename), done, paused, no steps, `start` with a chosen
    first date, `nextPosition` on the last step;
  - row mapping for workflow, step, and the new person fields;
  - `WorkflowsController` with `FakeWorkflowRepository` (in memory, `failWith`,
    `gate`): empty list seeds once, then invalidates people; a seeded account
    doesn't seed;
  - `PeopleController`: `completeStep`, `pause`/`resume`, `setWorkflow`,
    `moveTo` with a workflow, `add` with the default workflow, each with its
    failure case.
- Widget:
  - the card in its five states, plus loading and error;
  - tick success and failure;
  - How did it end → Became a customer / Not now;
  - the ⋯ rows: Change workflow, Pause or Resume;
  - the follow-with block: default selected, Nothing for now hides the date,
    the date;
  - the Change workflow sheet: save and failure;
  - the paused subtitle in the list.
- Goldens: the card's `@Preview`, regenerated through CI (README → *Golden
  tests*).

## 7. Delivery

One branch, `feature/57-workflows`, one PR that closes #57: the migration, the
pgTAP test, the workflows feature, the contacts changes, the EN strings, and
the card states in `docs/design/screens.md`.

After the merge, the migration reaches the hosted project with `supabase db push`
from the user's own terminal, with the VPN off. Until then the hosted app fails
on the new columns.
