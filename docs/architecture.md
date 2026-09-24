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

Navigation shells (bottom bar on mobile, sidebar on desktop) will be a
`StatefulShellRoute` wrapping the authenticated branches — one shell widget that
picks its chrome from `context.screenSize`. Not built yet.

### Theming

`ThemeData` is built in exactly one place from three token files. The current
colours and type ramp are **placeholders** derived from a seed colour; the visual
identity is a separate step. Replacing `app_colors.dart` and
`app_typography.dart` re-skins the whole app, because widgets are required to
read `Theme.of(context)` and the `AppSpacing`/`AppRadii` scales.

Component themes (cards, inputs, buttons…) belong in `app_theme.dart`, not in
widgets.

### Responsiveness

Three layout classes — `mobile`, `tablet`, `desktop` — behind
`context.screenSize`. Screens branch on the enum, never on raw pixel widths, so
thresholds move in one file. `Breakpoints.maxContentWidth` caps line length on
very wide screens.

The visual identity stays identical across platforms; only layout and navigation
patterns adapt.

### Not yet present, by design

Firebase Cloud Messaging, a profiles table, account deletion, localisation,
local persistence beyond the Supabase session, analytics, CI. Each will be added
when the feature that needs it is built.

Supabase arrived with auth (#21): the client is a provider in
`core/supabase/`, its project URL and publishable key are committed there, and
all access sits behind `features/<x>/data/` repositories. The service-role key
is not in this repo and must never be.
