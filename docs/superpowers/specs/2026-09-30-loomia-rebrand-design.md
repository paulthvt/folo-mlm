# Loomia rebrand — design

Tracking: #81 (parent), #82 palette, #83 logo + icon, #84 rename.

## Decisions

- **Name:** Loomia. A loom weaves threads; the product weaves relationships.
- **Slogan:** "Weave your network. Tend every thread." — FR « Tisse ton réseau.
  Prends soin de chaque fil. ». "Grow together" was rejected: next to
  "network" it echoes MLM recruiting language, which the brief forbids.
- **Ids:** `app.loomia` on Android and iOS. Safe to change: nothing is
  published.
- **Code prefix:** `Folo*` becomes `Loomia*`.
- **Repo:** `folo-mlm` becomes `loomia`.

## Order

1. #82 palette — the logo's colours depend on it.
2. #83 logo + icon.
3. #84 rename — mechanical, independent of 1 and 2; can run in parallel.

Each on its own branch and PR.

## 1. Palette (#82)

Figma file `spz2vsSK8gbt1Ok2rW1sdQ`, new page `04 — Loomia palettes`, four
frames in the same format as N1–N4 on page `03`: 8 swatches, then a light and
dark Today mockup.

| Frame | Brand |
| --- | --- |
| L1 ocre pale | `#E8964A` |
| L2 rouge cuivré | `#C86C53` |
| L3 ocre flashy | `#E49329` |
| L4 marron beige | `#C6785B` |

**Brand vs primary.** White text on the four brand colours measures 2.36,
3.67, 2.47 and 3.37:1 — all below WCAG AA (4.5:1). The hero card, filled
buttons and selected nav put white on `primary`, so:

- `brand` = the given hex. Logo, icon, decorative marks. Never behind text.
- `primary` = same hue, darker, ≥ 4.5:1 with white. All fills with text.
- `primaryText` (dark mode ink) = same hue, lighter, ≥ 4.5:1 on dark surface.

Swatches per frame: brand, primary, prim-ctr, secondary, sec-ctr, accent,
acc-ctr, ink, border (brand added to N-format's eight).

**Secondary** gets a muted cool counterpoint (sage or teal) so "on pace"
reads distinctly from primary. **Accent** (date marks) moves off the current
gold, which would blend into ocre. `warning` stays distinguishable from both
brand and accent.

**After the pick:** update `lib/app/theme/app_colors.dart` (`AppColors`,
`FoloColors` + new `brand` field), `docs/design/design-system.md` §1, the
`app_theme_test.dart` expectations, and regenerate goldens through CI
(README → *Golden tests*).

## 2. Logo + app icon (#83)

Figma page `05 — Loomia logo`. Four concepts for the "oo" mark; "L" and "mia"
stay plain Plus Jakarta Sans Bold:

1. **Interlaced rings** — two o's linked, one passing over then under the other.
2. **Single thread** — one continuous stroke draws both o's, crossing between.
3. **Nodes + bridge** — two rings joined by a short woven band.
4. **Overlap** — two o's overlapping; the shared lens filled with `brand`.

Each concept shows: wordmark on light and dark, icon at 1024 / 180 / 48 px.
The 48 px render is the legibility test — a concept that turns to mush there
is out.

**Assets after the pick,** exported from Figma, no new dependency:

- Android: adaptive icon (`mipmap-anydpi-v26/ic_launcher.xml`, foreground +
  background) and legacy `mipmap-*dpi/ic_launcher.png`.
- iOS: `AppIcon.appiconset`, single 1024 image.
- Web: `favicon.png`, `icons/Icon-192/512.png`, maskable 192/512.
- In-app: wordmark on the Welcome screen and the desktop sidebar header.
  Format chosen at implementation time (SVG needs a dependency; PNG at 1x/2x/3x
  does not — PNG is the default).

## 3. Rename (#84)

- `pubspec.yaml` `name: loomia`; every `package:folo/` import.
- `Folo*` classes → `Loomia*`; `folo_*.dart` files → `loomia_*.dart`, tests
  mirrored.
- Android `namespace` / `applicationId` → `app.loomia`; move `MainActivity`
  package directory accordingly. iOS `PRODUCT_BUNDLE_IDENTIFIER` →
  `app.loomia` / `app.loomia.RunnerTests`.
- Visible name: Android `android:label`, iOS `CFBundleDisplayName` /
  `CFBundleName`, `NSContactsUsageDescription`, web `<title>`,
  `apple-mobile-web-app-title`, `manifest.json`.
- Deep link `io.supabase.folo` → `io.supabase.loomia` in
  `supabase_config.dart`, AndroidManifest, Info.plist and
  `supabase/config.toml`, then `supabase config push` (VPN off).
- EN/FR strings; slogan on the Welcome screen.
- README, CLAUDE.md, `docs/architecture.md`, `docs/design/*`,
  `release-please-config.json`. Past plans/specs under `docs/superpowers/`
  stay as written.
- GitHub repo rename; `git remote set-url`; `project_id` in `config.toml`.

**Breaks:** auth emails already sent carry the old deep link. Acceptable
pre-launch.

## Testing

- Palette: existing theme tests updated to the new values; goldens via CI;
  contrast of primary/white and primaryText/dark surface checked when picking
  the values.
- Logo: goldens of screens showing the wordmark.
- Rename: `flutter analyze` clean, `flutter test` green, a debug build on
  Android and web launches and completes the magic-link redirect.
