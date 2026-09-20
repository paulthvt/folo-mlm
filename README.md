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

## Checks

```bash
dart format .
flutter analyze
flutter test
```

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
