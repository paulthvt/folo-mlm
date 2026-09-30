# Loomia rename Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every trace of "Folo" in code, platform ids, copy and docs becomes "Loomia"; the repo becomes `paulthvt/loomia`.

**Architecture:** Mechanical rename in four reviewable slices: Dart symbols, platform ids + deep link, user-facing copy + docs, repository. No behaviour changes except the deep-link scheme, which must be changed in lockstep in four places.

**Tech Stack:** Flutter, Supabase CLI, `gh`.

**Spec:** `docs/superpowers/specs/2026-09-30-loomia-rebrand-design.md` §3. Issue #84.

## Global Constraints

- Dart package `loomia`. Android/iOS id `app.loomia`; iOS tests `app.loomia.RunnerTests`.
- Deep link `io.supabase.loomia://login-callback/`.
- Slogan EN "Weave your network. Tend every thread." / FR « Tisse ton réseau. Prends soin de chaque fil. »
- `docs/superpowers/**` stays as written (history) — never rewrite it.
- Imports always `package:loomia/...`. No new dependency.
- Branch `chore/84-loomia-rename` off `main`. Conventional Commits.
- `dart format .`, `flutter analyze` (No issues found!), `flutter test` green at the end of every task.

## Review Focus

- `MainActivity.kt` left in `com/folo/folo` with `package com.folo.folo` while `namespace` is `app.loomia` → app crashes at launch with `ClassNotFoundException`. Task 2 moves it and runs `flutter build apk --debug`.
- Deep link changed in the app but not in the hosted Supabase auth allow-list → magic link / reset lands on the Site URL instead of the app. Task 2 pushes `config.toml` and checks the redirect list.
- A leftover `folo` identifier anywhere outside `docs/superpowers/` → Task 3 ends with a grep that must return nothing.
- The desktop sidebar test asserts `find.text('Folo')` → updated in Task 3, not deleted.
- Goldens showing the sidebar wordmark (`today_desktop_*`, `contacts_desktop_light`) → regenerated through CI in Task 3.

---

### Task 1: Dart package, classes and files

**Files:**
- Modify: `pubspec.yaml:1-2`, every `.dart` file under `lib/` and `test/`
- Rename: `lib/core/ui/folo_{avatar,chip,dialog,progress_bar,top_bar}.dart` → `loomia_*.dart`, and any `test/core/ui/folo_*_test.dart`

**Interfaces:**
- Produces: `LoomiaApp`, `LoomiaAvatar`, `LoomiaAvatarGroup`, `LoomiaChip`, `LoomiaColors`, `LoomiaDialog`, `LoomiaProgressBar`, `LoomiaTopBar`.

- [ ] **Step 1:** `pubspec.yaml`: `name: loomia`, description `"Loomia — a cross-platform productivity app for people who manage relationships, follow-ups and personal goals."`
- [ ] **Step 2:** Rename files:

```bash
for f in $(git ls-files 'lib/**/folo_*.dart' 'test/**/folo_*.dart'); do git mv "$f" "${f//folo_/loomia_}"; done
```

- [ ] **Step 3:** Rewrite symbols and imports:

```bash
git ls-files '*.dart' | grep -v '^lib/l10n/app_localizations' | xargs sed -i '' \
  -e 's#package:folo/#package:loomia/#g' \
  -e 's#/folo_\([a-z_]*\)\.dart#/loomia_\1.dart#g' \
  -e 's/\bFolo\(App\|Avatar\|AvatarGroup\|Chip\|Colors\|Dialog\|ProgressBar\|TopBar\)\b/Loomia\1/g'
```

(macOS `sed` has no `\b`/`\|`: run with `gsed` if installed, else `perl -pi -e 's/\bFolo(App|Avatar|AvatarGroup|Chip|Colors|Dialog|ProgressBar|TopBar)\b/Loomia$1/g'` for the third expression.)

- [ ] **Step 4:** Check: `grep -rnE "package:folo/|\bFolo[A-Z]|folo_[a-z_]+\.dart" lib test` → no output. Rename the local `folo` variable in `test/app/theme/app_theme_test.dart` to `colors`.
- [ ] **Step 5:** `flutter pub get && flutter gen-l10n && dart format . && flutter analyze && flutter test` — all pass (goldens unchanged: nothing visible changed yet).
- [ ] **Step 6: Commit** `git commit -am "refactor: rename the Dart package and Folo* symbols to Loomia (#84)"` (plus `git add` for moved files — `git mv` already staged them).

### Task 2: Platform ids, visible app name, deep link

**Files:**
- Modify: `android/app/build.gradle.kts:8,19`, `android/app/src/main/AndroidManifest.xml:11,37,42`
- Move: `android/app/src/main/kotlin/com/folo/folo/MainActivity.kt` → `android/app/src/main/kotlin/app/loomia/MainActivity.kt`
- Modify: `ios/Runner.xcodeproj/project.pbxproj` (6 lines), `ios/Runner/Info.plist:6,12,20,33,36`
- Modify: `web/index.html:26,32`, `web/manifest.json:2-3`
- Modify: `lib/core/supabase/supabase_config.dart:19`, `supabase/config.toml:165`
- Test: `test/core/supabase/supabase_config_test.dart`

- [ ] **Step 1: Failing test.** In `supabase_config_test.dart` change the expected redirect to `'io.supabase.loomia://login-callback/'`. Run `flutter test test/core/supabase/supabase_config_test.dart` → FAIL.
- [ ] **Step 2:** `supabase_config.dart:19` → `'io.supabase.loomia://login-callback/'`. Test → PASS.
- [ ] **Step 3: Android.** `namespace = "app.loomia"`, `applicationId = "app.loomia"`, `android:label="Loomia"`, `android:scheme="io.supabase.loomia"`, comment on line 37 → `io.supabase.loomia://login-callback/`. Then:

```bash
mkdir -p android/app/src/main/kotlin/app/loomia
git mv android/app/src/main/kotlin/com/folo/folo/MainActivity.kt android/app/src/main/kotlin/app/loomia/MainActivity.kt
sed -i '' 's/^package com.folo.folo$/package app.loomia/' android/app/src/main/kotlin/app/loomia/MainActivity.kt
```

- [ ] **Step 4: iOS.** `sed -i '' 's/com\.folo\.folo/app.loomia/g' ios/Runner.xcodeproj/project.pbxproj`. `Info.plist`: `NSContactsUsageDescription` → "Loomia shows your contacts so you can pick who to bring in. Only the people you pick are saved.", `CFBundleDisplayName` → `Loomia`, `CFBundleName` → `loomia`, both URL-scheme strings → `io.supabase.loomia`.
- [ ] **Step 5: Web.** `<title>Loomia</title>`, `apple-mobile-web-app-title` → `Loomia`; manifest `"name": "Loomia"`, `"short_name": "Loomia"`, and `"description": "Weave your network. Tend every thread."`.
- [ ] **Step 6: Supabase.** `config.toml:165` → `["io.supabase.loomia://login-callback/", "http://localhost:5000/**"]`. With VPN off: `supabase config push`. Confirm in the push diff that `additional_redirect_urls` now lists `io.supabase.loomia://login-callback/`. (A "temp role" error means the VPN is on.)
- [ ] **Step 7: Build check.** `flutter build apk --debug` succeeds; `unzip -p build/app/outputs/flutter-apk/app-debug.apk AndroidManifest.xml | strings | grep -c app.loomia` ≥ 1. Launch on an emulator: app opens (no `ClassNotFoundException` in `adb logcat`). Request a magic link, tap it on the device: app opens signed in.
- [ ] **Step 8:** `flutter analyze && flutter test` green. Commit `chore: app.loomia ids, Loomia app name and deep link (#84)`.

### Task 3: Copy, slogan, docs

**Files:**
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_fr.arb`
- Modify: `lib/app/app.dart:23`, `lib/app/shell/app_shell.dart:105`, `lib/features/auth/presentation/welcome_page.dart:56-59`
- Modify: `test/app/shell/app_shell_test.dart:25,40,54`, `test/features/auth/presentation/welcome_page_test.dart`
- Modify: `README.md`, `CLAUDE.md`, `docs/architecture.md`, `docs/design/*.md`, `release-please-config.json:21`

- [ ] **Step 1: Failing tests.** In `app_shell_test.dart` replace the three `find.text('Folo')` with `find.text('Loomia')`. In `welcome_page_test.dart` add:

```dart
  testWidgets('shows the Loomia name and slogan', (tester) async {
    await tester.pumpWidget(_host(FakeAuthRepository()));
    expect(find.text('Loomia'), findsOneWidget);
    expect(find.text('Weave your network. Tend every thread.'), findsOneWidget);
  });
```

Run both files → FAIL.
- [ ] **Step 2:** `'Folo'` → `'Loomia'` in `app.dart`, `app_shell.dart`, `welcome_page.dart` (keep the `ponytail:` comment above it; #83 replaces the text with the logo).
- [ ] **Step 3: Slogan.** `app_en.arb`: `"authWelcomeHeadline": "Weave your network. Tend every thread."`, description "Slogan on the signed-out welcome screen, under the Loomia wordmark.". `app_fr.arb`: `"authWelcomeHeadline" : "Tisse ton réseau. Prends soin de chaque fil."` (replaces "Sachez quoi faire ensuite." on line 51). `authWelcomeBody` stays.
- [ ] **Step 4:** Every other "Folo" in both `.arb` files → "Loomia" (EN lines 56, 58, 405, 977, 1146, 1150, 1169, 1173; FR line 20). `flutter gen-l10n`.
- [ ] **Step 5:** Tests from Step 1 → PASS.
- [ ] **Step 6: Docs.** Replace "Folo" → "Loomia", `folo` → `loomia`, `FoloColors` → `LoomiaColors`, `Folo/color` → `Loomia/color` in `README.md`, `CLAUDE.md`, `docs/architecture.md`, `docs/design/*.md`; `release-please-config.json` `"package-name": "loomia"`. Leave `docs/superpowers/**` alone.
- [ ] **Step 7: Leftover check.**

```bash
git grep -n -i folo -- ':!docs/superpowers' ':!supabase/config.toml'
```

Expected: no output. (`config.toml` `project_id` changes in Task 4.)
- [ ] **Step 8:** `dart format . && flutter analyze && flutter test` — green apart from sidebar goldens on CI. Commit `chore: Loomia name and slogan in copy and docs (#84)`.
- [ ] **Step 9:** Push, regenerate goldens through CI (README → *Golden tests*), check `today_desktop_*` and `contacts_desktop_light` show "Loomia", commit `test(goldens): Loomia wordmark`, open PR with `Closes #84`.

### Task 4: Repository (after the PR merges; outward-facing — confirm with the owner first)

- [ ] **Step 1:** `gh repo rename loomia -R paulthvt/folo-mlm`.
- [ ] **Step 2:** `git remote set-url origin git@github-perso:paulthvt/loomia.git && git fetch`.
- [ ] **Step 3:** `supabase/config.toml:5` `project_id = "loomia"`. This is the local stack's id only; the hosted project is unaffected. Commit on a new branch `chore/84-loomia-project-id`, PR `Closes #84` follow-up or amend the open PR if it has not merged.
- [ ] **Step 4:** Check the project board 2 still links the issues (GitHub redirects renamed repos).
