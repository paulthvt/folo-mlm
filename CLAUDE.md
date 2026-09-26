# Claude Code Configuration

Quick reference. Full docs:

- **[docs/architecture.md](docs/architecture.md)** — layering, decisions, what is deliberately absent
- **[README.md](README.md)** — setup, platforms, how to add a feature

## What this project is

Folo — cross-platform productivity app (Android / iOS / Web) for people running
a business on relationships: contacts, follow-ups, customers, prospects, team
activity, goals. Everything points at one question: **"What should I do today?"**

It must not read as an MLM or sales tool. No leaderboards, no rank badges, no
"recruit" language in UI copy or naming.

Current state: design system, Supabase auth, EN/FR localisation, Today screen on
sample data. No database tables and no product data model yet.

## Essential Commands

```bash
flutter pub get

# Run
flutter run                   # current device
flutter run -d chrome         # web

# Quality (run all three before claiming done)
dart format .
flutter analyze               # must be "No issues found!"
flutter test

# Builds
flutter build web --release
flutter build apk --release
flutter build appbundle --release
flutter build ipa --release
```

No code generation step. No `--dart-define-from-file`. Keep it that way until a
feature forces otherwise.

## Stack

| Concern | Choice |
| --- | --- |
| State | `flutter_riverpod` (no codegen, no `riverpod_lint`) |
| Routing | `go_router`, router built inside a `Provider` |
| Backend (later) | Supabase — Postgres, Auth, Storage, Edge Functions |
| Push (later) | Firebase Cloud Messaging |

Only two runtime dependencies exist. **Adding a dependency requires a reason
stated in the pubspec comment next to it.** Check stdlib, Flutter SDK, and the
already-installed packages first.

## Conventions

- **Feature-first**: `lib/features/<feature>/{presentation,domain,data}`. Create
  `domain/` and `data/` only when the feature has real logic or I/O. No
  interface with a single implementation.
- **Layering**: `presentation → domain ← data`. Widgets never touch HTTP/DB.
- **Theme**: read `Theme.of(context).colorScheme`, `AppSpacing.*`, `AppRadii.*`.
  Never hard-code a colour, radius, font size or spacing value in a widget.
  Component styling belongs in `lib/app/theme/app_theme.dart`.
  `app_colors.dart` / `app_typography.dart` are placeholders — do not treat the
  current seed-based Material 3 look as the design.
- **Responsive**: branch on `context.screenSize` (`mobile` / `tablet` /
  `desktop`), never on raw pixel widths. Mobile gets compact/bottom navigation,
  desktop a sidebar, wide screens multi-column. Visual identity stays identical
  across platforms; layout adapts.
- **Routing**: add the path to `lib/app/router/routes.dart` first, then the
  `GoRoute`. No path literals in widgets.
- **State**: Riverpod providers for anything shared or async; `setState` is fine
  for purely local widget state (a toggle, an animation). Providers live next to
  their consumer, not in a global folder.
- **Imports**: `package:folo/...` always (`always_use_package_imports`).
  Material comes from `package:material_ui/material_ui.dart`, never
  `flutter/material.dart` (frozen, and its classes don't match).
- **Pickers** (date, time): Cupertino on iOS, Material on Android and Web.
  Everything else is Material everywhere. See docs/architecture.md.
- **Tests**: `test/` mirrors `lib/`. Widget test for screens, plain Dart unit
  test for domain logic.
- **Commits**: Conventional Commits (`feat`/`fix`/`docs`/`style`/`refactor`/
  `perf`/`test`/`chore`). Branch off `main`, issue number first:
  `feature/<issue>-<slug>`, `fix/<issue>-<slug>`, `chore/<issue>-<slug>`.
- **Tracking**: every change has an issue on the
  [project board](https://github.com/users/paulthvt/projects/2). PRs must fill
  the **Ticket** section with `Closes #<issue>`.
- **Never commit**: `google-services.json`, `GoogleService-Info.plist`,
  `lib/firebase_options.dart`, Supabase service-role keys, `.env`, `build/`.

## Working rules

- Don't scaffold for later. No placeholder screens, no fake data, no empty
  abstraction layers. If it isn't needed by the task, leave it out.
- Don't introduce Firebase until a feature needs it. Supabase: single client
  provider in `core/supabase/`, access behind repositories in
  `features/<x>/data/`. Schema changes only via `supabase/migrations/`
  (`supabase migration new`), auth settings only via `supabase/config.toml` —
  never the dashboard.
- Flag a significant architectural decision before making it, briefly.
