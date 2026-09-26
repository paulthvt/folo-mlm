# Architecture

Scope of this document: the decisions baked into the foundation, and why. Kept
short on purpose.

## Principles

1. **Feature-first.** Code is grouped by product area, not by technical kind.
   Deleting a feature is deleting one folder.
2. **Layers on demand.** `presentation / domain / data` exist inside a feature
   only when that feature needs them. No empty abstractions, no interface with a
   single implementation.
3. **One source of truth per concern.** Colour, typography, spacing, routes: one
   file each. If a value appears in a widget, it is a bug.
4. **The UI never talks to infrastructure.** Widgets read providers; providers
   own the logic; repositories own I/O. This is what will keep Supabase
   swappable and testable.

## Directory map

```
lib/
  main.dart                      # runApp + ProviderScope
  app/
    app.dart                     # MaterialApp.router, theme + router wiring
    router/
      routes.dart                # every path/name constant
      app_router.dart            # GoRouter inside a provider
    theme/
      app_colors.dart            # light/dark ColorScheme  (PLACEHOLDER)
      app_typography.dart        # text ramp               (PLACEHOLDER)
      app_spacing.dart           # spacing + radius scale
      app_theme.dart             # the only place ThemeData is built
  core/
    layout/breakpoints.dart      # ScreenSize + context.screenSize
    supabase/                    # client provider + committed project config
    constants/ extensions/ utils/
  features/
    auth/                        # welcome, sign in, register, reset, guard
    dashboard/ contacts/ follow_ups/ team/ goals/
test/                            # mirrors lib/
```

## Decisions

### State management — Riverpod

Chosen over Bloc and `provider`: compile-time-safe dependency lookup, no
`BuildContext` required to read state (so domain logic is testable as plain
Dart), and trivial override of any provider in tests — which is what will make
Supabase mockable without writing an interface for every repository.

Code generation (`riverpod_generator`) is deliberately **not** set up. It buys
little at this size and adds a build step. Add it when the number of providers
makes hand-written ones noisy.

`riverpod_lint` / `custom_lint` were also left out: they need a second analysis
pipeline (`dart run custom_lint`) that `flutter analyze` does not run, and the
current versions pin older transitive packages. Add later if provider misuse
actually shows up.

### Routing — GoRouter

URL-based, which the web build needs to behave like a real web app (shareable
links, back button, browser history), and it gives mobile deep links from the
same route table.

The router lives in a `Provider` rather than a global, so that when
authentication arrives it can `ref.watch` session state and use `redirect` to
separate authenticated from unauthenticated areas. `app_router.dart` documents
those extension points inline.

Signed-in screens sit in a `ShellRoute` whose `AppShell` (`lib/app/shell/`)
picks its chrome from `context.screenSize`: a sidebar on desktop, the same
sidebar as an icon rail on tablet, nothing on mobile. Settings is not a
destination — it opens from the account block at the bottom of the sidebar, or
from the avatar in the top bar on mobile. Its sections (`/settings/account`,
`/settings/language`, `/settings/appearance`) are nested routes: on desktop they fill a pane beside the
Settings list without a transition; on mobile and tablet each is its own pushed
screen. The mobile bottom bar and a
`StatefulShellRoute` (one stack per tab) arrive with the second destination.

### Theming

`ThemeData` is built in exactly one place from three token files. The current
colours and type ramp are **placeholders** derived from a seed colour; the visual
identity is a separate step. Replacing `app_colors.dart` and
`app_typography.dart` re-skins the whole app, because widgets are required to
read `Theme.of(context)` and the `AppSpacing`/`AppRadii` scales.

Component themes (cards, inputs, buttons…) belong in `app_theme.dart`, not in
widgets.

### Design packages — material_ui, cupertino_ui

Since Flutter 3.47, Material and Cupertino ship as the pub packages
`material_ui` and `cupertino_ui`. The framework's `flutter/material.dart` and
`flutter/cupertino.dart` are frozen. Import `package:material_ui/material_ui.dart`,
never `flutter/material.dart`: they define separate `MaterialApp`, `Theme` and
`MaterialLocalizations` classes. A widget from the old library would not see
this app's theme or strings, and go_router would not detect the app
(`test/app/router/page_test.dart`). For the same reason, register
`lib/l10n/localizations_delegates.dart`, not
`AppLocalizations.localizationsDelegates`.

Material is the design system on every platform. The exception is **system
pickers** (date, time): they follow the platform, because a Material calendar
feels foreign on an iPhone. Use Cupertino (`CupertinoDatePicker` in a modal
popup) on iOS. Use Material (`showDatePicker`) on Android and the web; on the
web, a mouse and keyboard suit the Material calendar better than a wheel. Branch
on `!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS`. `cupertino_ui`
becomes a direct dependency with the first picker.

### Responsiveness

Three layout classes — `mobile`, `tablet`, `desktop` — behind
`context.screenSize`. Screens branch on the enum, never on raw pixel widths, so
thresholds move in one file. `Breakpoints.maxContentWidth` caps line length on
very wide screens.

The visual identity stays identical across platforms; only layout and navigation
patterns adapt.

### Backend — Supabase

Supabase arrived with auth (#21): the client is a provider in
`core/supabase/`, its project URL and publishable key are committed there, and
all access sits behind `features/<x>/data/` repositories. The service-role key
is not in this repo and must never be.

The project itself is described by `supabase/` (#28), not by the dashboard:

- `supabase/config.toml` holds the auth settings (Site URL, redirect URLs,
  email confirmation, password length, Google). It was pulled from the hosted
  project; a change there is a PR here first. Secrets are `env(...)` references,
  never values.
- `supabase/migrations/` is the only way the schema changes. CI replays every
  migration onto an empty database, so a migration that does not apply cleanly
  fails the PR.

Anything the client must not do with its own key runs in an Edge Function in
`supabase/functions/` — so far only `delete-account`, which deletes the caller
and nobody else. The user's language choice is in `user_metadata`, next to their
first name, so it follows them across devices.

Migrations and functions reach the hosted project by hand, after merge, with
`supabase db push` and `supabase functions deploy`. One maintainer, rare
migrations: a deploy job would be more secrets than it saves. Automate it when either stops being true.

### Not yet present, by design

Firebase Cloud Messaging, database tables (a `profiles` table included — the
user's first name lives in auth `user_metadata` until something needs more),
local persistence beyond the Supabase session, analytics.
Each will be added when the feature that needs it is built.
