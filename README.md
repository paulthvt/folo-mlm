# Folo

A cross-platform productivity app for people who run their business on
relationships: contacts, follow-ups, customers, prospects, team activity and
personal goals — all pointed at one question: **"What should I do today?"**

This repository currently contains the technical foundation only. No product
features, no design system, no backend.

## Platforms

| Platform | Status |
| --- | --- |
| Android | supported |
| iOS | supported |
| Web | supported, treated as a first-class responsive desktop app |

## Requirements

- Flutter 3.47+ / Dart 3.13+

## Running

```bash
flutter pub get
flutter run                 # current device
flutter run -d chrome       # web
```

### Auth and Supabase

The Supabase project URL and publishable key are committed in
`lib/core/supabase/supabase_config.dart` — the publishable key is public by
design and Row Level Security is the boundary. Nothing to configure locally.

Email confirmation, password recovery and Google sign-in return to
`io.supabase.folo://login-callback/`. On web there is no custom scheme, so the
project's **Site URL** is where those links land: set it to the origin you
develop on and run web on a fixed port (`flutter run -d chrome --web-port 5000`).
Both that origin and the custom scheme must be listed under allowed redirect
URLs, or Supabase silently falls back to the Site URL.

These project settings are managed in the Supabase dashboard, not in this repo:
email confirmations on, minimum password length 8, the Google provider, Site URL
and allowed redirect URLs. Sign in with Apple is not wired up — it needs a paid
Apple Developer account (issue #22).

## Checks

```bash
dart format .
flutter analyze
flutter test
```

## Translations

English lives in `lib/l10n/app_en.arb` and is the source of truth. Every other
language comes from [Tolgee](https://tolgee.io) and is machine-translated on
arrival.

- **Adding a string:** add the key *and its description* to `app_en.arb`. The
  description is what the machine translator reads — a key without one gets
  translated blind. Merging to `main` pushes it up automatically.
- **Getting translations back:** run the *l10n pull* workflow (or wait for
  Monday). It opens one pull request, `chore/l10n-sync`, containing every
  language. Review the copy and merge.
- **Adding a language:** add it in the Tolgee UI, then run *l10n pull*. The new
  `app_xx.arb` arrives in that pull request and the app supports it with no code
  change — `supportedLocales` is generated from the files present.
- **Never** edit English in Tolgee, and never hand-edit a translated `.arb`:
  each direction overwrites the other.

`.tolgeerc` is what makes the CLI speak Flutter ARB instead of its own JSON
format, and what keeps a pulled file named `app_fr.arb` rather than `fr.arb`.
Changing it breaks both directions; `test/l10n/tolgee_config_test.dart` pins the
parts that matter.

Generated Dart (`lib/l10n/app_localizations*.dart`) is not committed. Run
`flutter gen-l10n` after changing an ARB file, or just `flutter run`.

## Tracking work

Work is tracked on the
[Folo project board](https://github.com/users/paulthvt/projects/2). Every change
starts as an issue there.

1. Pick (or create) an issue on the board — that number is the ticket.
2. Branch off `main`: `feature/<issue>-<slug>`, `fix/<issue>-<slug>`,
   `chore/<issue>-<slug>` — e.g. `feature/21-today-screen`.
3. Open the PR with a Conventional Commit title and fill the **Ticket** section
   with `Closes #<issue>` so merging moves the card to Done.

## Architecture (short version)

```
lib/
  main.dart            # entry point, ProviderScope
  app/                 # app shell: root widget, router, theme
  core/                # cross-feature primitives (layout, constants, utils)
  features/<feature>/  # one folder per product area
```

Inside a feature:

```
features/contacts/
  presentation/   # widgets, screens, view state
  domain/         # entities and business rules
  data/           # repositories, API/DB access, DTOs
```

Layers are created **only when a feature needs them**. A feature that is pure UI
has just `presentation/`.

See [docs/architecture.md](docs/architecture.md) for the reasoning and the
conventions.

## Adding a feature

1. `mkdir -p lib/features/<name>/presentation`
2. Add the screen(s). Read colours/spacing from the theme, never hard-code them.
3. Add the path to `lib/app/router/routes.dart` and a `GoRoute` in
   `lib/app/router/app_router.dart`.
4. Add state with Riverpod providers next to the code that uses them
   (`presentation/` for UI state, `domain/` for business logic).
5. Add `domain/` and `data/` only when there is real logic or I/O.
6. Add tests under `test/features/<name>/`, mirroring the `lib/` path.
