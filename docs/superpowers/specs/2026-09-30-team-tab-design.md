# Team tab — design

Epic [#101](https://github.com/paulthvt/loomia/issues/101). Built in two PRs:
[#102](https://github.com/paulthvt/loomia/issues/102) (tab and roster), then
[#103](https://github.com/paulthvt/loomia/issues/103) (worth a check-in).
Figma: "Team — mobile".

## Intent

The Team tab answers "who on my team might need me?", never "who is
performing?". It is the screen most at risk of reading as an MLM tool
(`docs/design/screens.md` §4), so it says its rule out loud: *nobody is being
measured here*.

A team member is a `person` at the `team` stage in the user's own book.
Everything on the screen comes from the user's own data. Nothing comes from a
member's own book: that is private (#67, principle 2).

## Decisions

| Question | Decision |
| --- | --- |
| Who is on the team | `peopleProvider` filtered to `Stage.team`. No new provider, no new table. |
| What puts someone in WORTH A CHECK-IN | **New** or **Quiet** (below). A due workflow step is not a reason here: Today already shows it. |
| "Has not added a contact yet" (Figma) | Not built. It reads the member's own book (#67). |
| When did we last talk | Computed field `last_contact_on(person)` in Postgres, read like `due_on`, never written. |
| Circle on a check-in | Opens the existing Log activity sheet. Logging refreshes people, so they drop out. |
| Tap on a row | Existing `openContact`: the contact opens under `/contacts/:id`, so the nav marks Contacts. A `/team/:id` route waits until that bothers someone. |
| Desktop and tablet | One 624px column, like Today. The sidebar gains Team. |
| Goals tab | Still absent. The shell gains Team only. |

## Check-in rules (#103)

A pure function `checkIns(List<Person> team, DateTime today)` in
`lib/features/team/domain/check_in.dart`. `today` is local midnight.

- **New**: on the team for less than 30 days (`stageSince`) and nothing logged
  since joining (`lastContactOn` null or before the joining day). Chip `New`.
  Reason: "Joined 3 weeks ago and nothing is logged since".
- **Quiet**: the last contact — or the joining day when nothing is logged —
  is 14 days ago or more. Chip `Quiet 2 weeks` (whole weeks). Reason: "You
  last talked on September 12".
- New wins over Quiet: one row per person. Oldest day first, then by
  `searchKey(name)`.

`last_contact_on` is the latest `happened_on` of an activity whose kind is not
`stage`: a stage change is the database talking, not the user.

## Screen

`lib/features/team/presentation/team_page.dart`: `TeamPage` reads providers,
`TeamView` takes an `AsyncValue` and callbacks, like `TodayView`, so it can be
previewed and tested without providers.

1. Top bar "Team". Mobile: `AccountButton`. With a sidebar: refresh.
2. Summary card: "6 people on your team" + `LoomiaAvatarGroup`, then one
   paragraph. #102: "Nobody is being measured here — this is just who might
   need you." #103 puts the count first: "Two of them could use a message this
   week." / "Everyone has heard from you lately."
3. `WORTH A CHECK-IN` (#103), hidden when empty: `ActionItem` per person.
4. `EVERYONE` with the count as the header action: `ContactRow` per member,
   sorted as the book is. Subtitle "Team · joined 3 weeks ago" (#102), then
   "Team · talked yesterday" once something is logged since joining (#103).

States: loading spinner, `EmptyState` with retry on failure, `EmptyState` "No
one on your team yet" / "Move someone to Team from their page." when the team
is empty. Pull to refresh reuses `refreshPeople`.

## Routing and shell

`Routes.team = '/team'`, a `GoRoute` in the shell. `AppShell` gets a third
destination (bottom nav and sidebar), selected on `/team`.

## Testing

- Unit: `checkIns` — New, Quiet, both (New wins), neither, ordering, the 14
  and 30 day edges.
- Widget: `TeamView` — loading, error, empty, roster, check-ins.
- `@Preview` for the screen, golden regenerated through CI.
