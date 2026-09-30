# Edit workflows in Settings — design

Issue [#59](https://github.com/paulthvt/folo-mlm/issues/59), part of #53.
Depends on #57 (workflows) and #58 (rules on the server), both merged.
Mockups: Figma → Contacts, stages & workflows — `Settings / Workflows — mobile`
(100:1706), `Settings / Workflow editor — mobile` (100:1941), `Edit step sheet
— mobile` (100:2137).

## Intent

The defaults seeded by #57 become the user's own: they rename, reorder, add and
remove steps, create and delete workflows, and pick each stage's default. A
change applies to everyone on the workflow from their next step; what is done
stays in their history.

## Decisions

| Question | Decision |
| --- | --- |
| Someone's step is moved | People follow the **position**: they go on with whatever now sits at their place and meet the moved step where it landed. Same rule as remove and insert; no schema change. |
| Deleting a workflow | In scope. Its people get no workflow ("Nothing planned"); their history stays. |
| Re-seeding once everything is deleted (#57 carry-over) | Fixed: defaults are seeded once per account, ever, decided by the server. |
| Change-stage body joins two strings (#57 carry-over) | Stays parked. Replacing the key would leave it only in `app_fr.arb`, which `arb_keys_test` refuses, and FR is not touched. |
| Save model | No Save on the editor; every control writes when used. The step sheet has Save. |

## 1. Database — one migration

`supabase migration new edit_workflows`.

**Seed once.**

```sql
create table public.workflow_seeded (
  owner_id uuid primary key default auth.uid()
    references auth.users on delete cascade,
  seeded_at timestamptz not null default now()
);
```

RLS on, `select` / `insert` own row only (`owner_id = (select auth.uid())`),
no update or delete. Backfill one row for every owner that already has a
workflow. `seed_workflows` is replaced (same signature): after the advisory
lock it returns when the user's `workflow_seeded` row exists, otherwise seeds
as today and inserts the row. The old "any workflow exists" check goes.

**Default switch** — `set_default(p_workflow uuid, p_on boolean) returns void`,
plpgsql, security invoker, `search_path = ''`. On: clears `is_default` on the
user's other workflow of the same stage, then sets it on `p_workflow` (the
partial unique index never sees two). Off: clears it; the stage then has no
default and someone new there starts nothing. Unknown or foreign id raises
`P0002`. Revoke from `public, anon`, grant to `authenticated`.

**Plain writes**, covered by the existing RLS policies:

- workflow: insert (stage, name), update name, delete (steps cascade, people
  get `workflow_id = null` via the existing foreign key);
- workflow_step: insert, update label / days / note / position, delete.

**Rules** — all already given by `current_step_id` / `due_on` (#58):

- current step moved or removed → the first step at or after the person's
  position is current;
- step inserted or moved before the person's position → skipped for them;
- days changed → due day follows; rename → shows at once;
- no steps left → done.

## 2. Device — data and domain

`WorkflowRepository` gains, each throwing `PeopleFailure` only:

- `create(Stage stage, String name) → Workflow`, `rename(id, name)`,
  `delete(id)`, `setDefault(id, bool on)`;
- `addStep(workflowId, {label, days, note, position})`,
  `updateStep(stepId, {label, days, note})`, `moveStep(stepId, position)`,
  `removeStep(stepId)`.

`seed` stays; `WorkflowsController.build` calls it on every first load of an
account (the server no-ops once seeded) and lists after it. It still
invalidates `peopleProvider(owner)` after seeding, since seeding may start
people.

`lib/features/workflows/domain/workflow.dart` gains a pure function:

```dart
/// The position for a step dropped at [index] among [steps] (sorted, the
/// moved step already taken out): the midpoint of its new neighbours, or one
/// past either end. An empty list gives 1.
num positionAt(List<WorkflowStep> steps, int index);
```

New steps go last: `positionAt(steps, steps.length)`.

`WorkflowsController` gains `edit(Future<void> Function(WorkflowRepository))`:
runs the write, then invalidates itself and `peopleProvider(owner)` — every edit
can change the server's `current_step_id` / `due_on`. It rethrows the
`PeopleFailure`; screens show the usual SnackBar. Nothing is optimistic: the
screen shows the saved state until the reload lands.

## 3. Device — screens

Routes first in `routes.dart`: `/settings/workflows` and
`/settings/workflows/:id`. New `SettingsSection.workflows`. On desktop both show
in the Settings right pane (the editor replaces the list, back returns to it);
elsewhere each is pushed.

**Settings list** — a new group above Preferences with one row, "Workflows",
leading icon, chevron.

**Workflows (100:1706)** — top bar "Workflows"; intro "What you usually do with
someone, step by step. Folo puts the next step on Today when it comes due.";
one `SectionHeader` + `SettingsGroup` per stage that has workflows (PROSPECTS,
CUSTOMERS, TEAM), rows ordered by `forStage`, trailing "Default · 5 steps" /
"4 steps" (ICU plural) and a chevron; `New workflow` tonal button. Loading: a
spinner. Failed: "Couldn't load the workflows" + `Try again` (existing strings).

**New workflow** — `FoloDialog`: Name (required), STAGE chips (Prospect
selected), Cancel / Create. Create writes, then opens the editor on it.

**Editor (100:1941)**:

- eyebrow: the stage; title: the name;
- Name field — saves on submit or focus loss when changed; empty or unchanged
  restores the saved name without writing;
- STEPS header with `Add a step`; one row per step: number badge, label,
  "When you start" (days 0 on step 1) or "{days} days after" (ICU plural; also
  "Same day" for 0 after step 1); tap opens the step sheet; a trailing drag
  handle reorders (`ReorderableListView`, `buildDefaultDragHandles: false`);
  each row also has "Move up" / "Move down" semantics actions; a drop calls
  `moveStep(stepId, positionAt(...))`;
- no steps: "No steps yet." in the card;
- switch row "Default for new prospects" / "new customers" / "new team members" —
  `setDefault`;
- footer: "Each step comes due a number of days after you tick the one before.
  Changes apply to everyone on this workflow — steps already done stay in their
  history.";
- danger row "Delete workflow" → `FoloDialog` "Delete {name}?" with "{count}
  people follow it. They'll have nothing planned; their history stays." (ICU
  plural, counted from `peopleProvider`) or "No one follows it.", Cancel /
  Delete; after deleting, back to the list;
- the workflow disappears (deleted elsewhere): the editor shows "This workflow
  isn't here anymore" with `Back to workflows`.

**Step sheet (100:2137)** — `FoloDialog` with a form:

- title "Step {n}", or "New step";
- "What to do" (required, trimmed);
- "Days after the previous step" — "Days after starting" for step 1; digits
  only, 0–365; live hint "Comes due {days} days after you tick step {n-1}." /
  "Comes due {days} days after you start." (ICU plural, 0 → "the same day");
- "Note" (optional, multiline);
- Save (disabled while writing); edit mode adds `Remove this step`, no
  confirmation (people on it move on, history stays).

**Writes in flight** — the control that started it is disabled until the
answer. Failure: "Couldn't save. Check your connection and try again." SnackBar
(existing string), form input kept in sheets and dialogs.

Theme values only; `context.screenSize` for the desktop branch. EN strings in
`app_en.arb` with descriptions; `app_fr.arb` untouched (FR may lag; gen-l10n
falls back to English).

## 4. Docs

- `docs/design/screens.md` — a Settings → Workflows section as built.
- `docs/architecture.md` — defaults are seeded once per account; the server
  decides.

## 5. Tests

- **pgTAP** (`supabase/tests/edit_workflows_test.sql`): seed writes the marker;
  a second seed no-ops; after deleting every workflow, seed still no-ops;
  backfill covers existing owners; `set_default` on moves the default, off
  clears it, foreign id raises `P0002`; moving the current step moves the
  person on (`current_step_id`); deleting a workflow clears `workflow_id`;
  grants (anon cannot call `set_default`, cannot read `workflow_seeded`).
- **Dart unit**: `positionAt` — first, middle, last, empty, adjacent integers.
- **Widget** (`test/features/workflows/presentation/`): list grouped by stage,
  default first, step counts; empty stage hidden; New workflow creates and
  opens the editor; rename saves, empty reverts; add, edit, remove a step;
  reorder by drag and by the Move down action calls `moveStep` with the
  midpoint; default switch; delete with the people count, then back to the
  list; a failed write keeps the saved state with the SnackBar; loading and
  failed; desktop shows list and editor in the pane; every write reloads
  people (`FakePeopleRepository.calls` has a fresh `list`).
- **Controller**: `build` always calls `seed`; `edit` invalidates both.
- **Fakes**: `FakeWorkflowRepository` implements the writes and records calls;
  its seed no-ops after the first, like the server.
- **Goldens**: `@Preview` for the workflows list, the editor and the step
  sheet, regenerated through CI.

## Out of scope

- Translating seeded workflows; FR strings.
- Duplicating a workflow, undo, drag between stages.
- The change-stage string concat (see Decisions).
- Figma desktop frames for these screens.
