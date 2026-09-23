# Screens — v1

Five product screens plus the six auth screens, built in Figma from component
instances only. Light on page `04 — Screens (Light)`, the same frames in dark on
`05 — Screens (Dark)` (clones bound to the `Dark` mode of `Folo/color`, so they
are not a second design to maintain).

| Frame | Size | Page |
| --- | --- | --- |
| Today — mobile | 390 × 844 | 04 / 05 |
| Contacts — mobile | 390 × 844 | 04 / 05 |
| Contact detail — mobile | 390 × 844 | 04 / 05 |
| Team — mobile | 390 × 844 | 04 / 05 |
| Goals — mobile | 390 × 844 | 04 / 05 |
| Today — desktop | 1440 × 900 | 04 / 05 |
| Contacts — desktop | 1440 × 900 | 04 / 05 |
| Welcome — mobile | 390 × 844 | 04 / 05 |
| Sign in — mobile | 390 × 844 | 04 / 05 |
| Create account — mobile | 390 × 844 | 04 / 05 |
| Forgot password — mobile | 390 × 844 | 04 / 05 |
| Check inbox — mobile | 390 × 844 | 04 / 05 |
| Choose a new password — mobile | 390 × 844 | 04 / 05 |
| Welcome — desktop | 1440 × 900 | 04 / 05 |
| Sign in — desktop | 1440 × 900 | 04 / 05 |

Content is the same fictional book of ~420 contacts across every screen, so the
screens read as one product and not as seven mockups.

---

## 1. Today — the home

**Mobile**

TopAppBar (`MONDAY 22 SEPTEMBER` / "Good morning, Pauline") → TodayHero →
`PRIORITY` + 3 ActionItems → `SEPTEMBER` + GoalCard + a two-up StatTile pair →
BottomNav.

The hero says *"Three people are worth a message today"* — a sentence, not a
number, so it cannot read as a quota. Below it, each ActionItem carries the reason
it exists: "Said she would decide after her holiday — she is back today", "Her
refill usually runs out around now", "Turns 42 tomorrow". The accent chip appears
only on the two items a real date drives.

Everything the user needs in the first viewport: what today is, how far through it
they are, and the first person to message. The goal is below the fold on purpose —
it is context, not the job.

**Desktop**

Sidebar → top bar (date eyebrow, `display` greeting, search, notifications,
account avatar) → two columns: 624px left (hero, then four priority items) and
400px right (GoalCard, stat pair, a team nudge card, "YOU TALKED TO").

The extra width buys one more priority item and moves context beside the actions
instead of below them. It is not the mobile column stretched: the right column
exists only here.

## 2. Contacts

**Mobile**

App bar → SearchField → filter chips (`Everyone` active, `Customers`,
`To follow up`, `Team`) → `NEEDS A NUDGE` (3, with the count as the header action)
→ `EVERYONE ELSE` → BottomNav.

The list is grouped by *whether the person needs something*, not alphabetically —
a 420-person alphabetical list is a database, and this product is not a database
(principle #3). Each row shows the last real contact; no completion meters.

**Desktop**

Sidebar → 440px list column (title + `Add` button, search, filters, grouped rows,
selected row washed with `primary/muted`) → 752px detail pane showing the selected
contact: header with actions, `NEXT STEP`, `HISTORY`, and a right column with
`WHAT YOU KNOW` plus the person's chips.

Selecting a row never navigates. This is the one screen whose desktop layout is
structurally different from mobile, and the reason is that a pointer can hold a
selection while a thumb cannot.

## 3. Contact detail (mobile)

"Back to contacts" bar → Avatar 56 + name (`headline`) + "Customer since March ·
Lyon" + two chips → `Message` / `Call` / overflow → `NEXT STEP` (one ActionItem) →
`HISTORY` (3 ActivityItems, "All 24") → BottomNav.

The screen answers one question: *what do I say to this person?* The next step is
above the history because the history is memory, not homework. The app bar title
is a back affordance, not a repeat of the name — the name is already the largest
thing on the screen (principle #2).

## 4. Team

App bar → a summary card ("6 people on your team" + AvatarGroup + "Two of them
could use a message this week. **Nobody is being measured here** — this is just who
might need you.") → `WORTH A CHECK-IN` (2 ActionItems about people, with the
reason: "Joined 3 weeks ago and has not added a contact yet") → `EVERYONE` (roster
of ContactRows) → BottomNav.

This is the screen most at risk of becoming an MLM tool, so it is the most
constrained: no volumes, no ranks, no comparison, no "downline". A team member is
a person who might need help, and the screen is built out of the same ActionItem
and ContactRow as Contacts. The copy states the rule out loud.

## 5. Goals

App bar (`11 DAYS LEFT IN SEPTEMBER` / "Goals") → GoalCard (1 840 of 2 800, "On
pace") → two StatTiles framed against the user's own intent ("of 40 you aimed
for") → `WHAT YOU SAID YOU WOULD DO` (3 TaskItems, two settled) → a pace card:
"At this pace you finish the month at about 2 650. Two more conversations a week
closes the gap. No pressure — the goal is yours to move."

Pace is stated, never judged. Nothing is red, nothing is compared to another
person, and the largest numeral on the screen is smaller than the screen title
(guardrail #4).

## 6. Auth — welcome, sign in, register, reset

Added 2026-09-23 for [#21](https://github.com/paulthvt/folo-mlm/issues/21). Full
design in
[docs/superpowers/specs/2026-09-23-auth-login-design.md](../superpowers/specs/2026-09-23-auth-login-design.md).

Six mobile frames and two desktop frames, all on the same shape: no navigation,
a single column capped at 400, centred, flat on `surface/canvas`. No card — a
card around a form is chrome (principle #6). This is the only part of the product
whose layout does **not** restructure across size classes; a form has one column
at every width, so only the horizontal centring and the vertical rhythm change.

`Welcome` carries the promise (`Know what to do next.`) and the three identity
paths. The social buttons live here and nowhere else, so a user who signed up
with Google is never shown a competing email form beside their real path.
`Sign in — mobile` is drawn in its **error state** to specify the form-level
failure: the clean state is trivially readable, the error state is the one with
decisions in it.

Three components were added to the library for these frames: `FormError`
(form-level errors, as opposed to TextField's field-level `State=Error`) and
`Brand/Google` / `Brand/Apple`, both placeholder artwork in Figma. The app ships
the official flat `G` from developers.google.com/identity instead
(`assets/images/google_g.png`); the Apple path is not built yet (issue #22).

`Choose a new password` has no back button: it is reached by a deep link, so
there is no previous screen to return to.

---

## Dark mode

The dark frames are clones with `setExplicitVariableModeForCollection` pointing at
the `Dark` mode — every fill resolves through a variable, so there is no second
set of values to keep in sync. Three things are worth looking at specifically:

- The hero keeps `primary/base` unchanged, so the one filled block still carries
  the brand on a near-black canvas; its secondary labels are white at 78%, which
  is why they hold in both modes.
- Accent chips become deep bronze containers with light amber ink instead of pale
  cream — the same meaning, re-tuned.
- Cards do not gain shadows; they step from `surface/canvas` to `surface/default`
  and keep the hairline.

---

## What these screens deliberately do not have

No onboarding, no settings, no add/edit forms, no notification centre, no
analytics view, no team performance comparison, no gamification of any kind. Each
would need either a product decision or a feature that does not exist yet
(CLAUDE.md: don't scaffold for later).

The screens are a design artefact. Implementation order, routing and state are not
decided here.
