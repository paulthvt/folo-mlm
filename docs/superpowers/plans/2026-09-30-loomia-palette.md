# Loomia palette Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show four warm Loomia palettes in Figma, let the owner pick one, and make it the app's colour tokens.

**Architecture:** Figma is the source of truth for colour (`lib/app/theme/app_colors.dart` is its Dart projection). Task 1 draws L1–L4 in Figma from the values in the appendix; Task 2 is a human gate; Task 3 projects the chosen palette into `AppColors` / `FoloColors` and adds a `brand` token.

**Tech Stack:** Figma MCP (`use_figma`, skill `figma:figma-use`), Flutter, `material_ui`.

**Spec:** `docs/superpowers/specs/2026-09-30-loomia-rebrand-design.md` §1. Issue #82.

## Global Constraints

- Brand hexes exactly: L1 `#E8964A`, L2 `#C86C53`, L3 `#E49329`, L4 `#C6785B`.
- `brand` never sits behind text. White text only on `primary` (≥ 4.5:1).
- No new dependency. No colour literal outside `app_colors.dart`.
- No MLM/sales wording in Figma notes or code comments.
- Goldens only from CI (README → *Golden tests*). Never commit local goldens.
- Run `dart format .`, `flutter analyze` (No issues found!), `flutter test` before claiming done.

## Review Focus

- White on `primary`, both modes, below 4.5:1 → must fail a test (pinned in Task 3).
- `primaryText` on dark `surfaceDefault` below 4.5:1 → must fail a test (Task 3).
- L2 copper primary read as an error state → error moved to crimson `#CF3046`; the Figma frame shows both side by side (Task 1).
- Ochre brand confused with `warning` → warning is olive-gold `#8A690F`; shown side by side (Task 1).
- `FoloColors.lerp` forgets the new `brand` field → theme animation snaps; the lerp test covers it (Task 3).

---

### Task 1: Figma palettes L1–L4

**Files:** Figma file `spz2vsSK8gbt1Ok2rW1sdQ`, new page `04 — Loomia palettes`.

- [ ] **Step 1:** Load skill `figma:figma-use` (mandatory before `use_figma`).
- [ ] **Step 2:** Create page `04 — Loomia palettes`. Clone frame `22:157` (N4 — Clay → Amber) four times, at y = 200, 1200, 2200, 3200. Rename to `L1 — Ocre pale`, `L2 — Rouge cuivré`, `L3 — Ocre flashy`, `L4 — Marron beige`.
- [ ] **Step 3:** Per frame, swatch row becomes nine: brand, primary, prim-ctr, secondary, sec-ctr, accent, acc-ctr, ink, border, with values from the appendix. Description line: brand/primary split and secondary choice (slate blue for L1/L3, olive for L2/L4).
- [ ] **Step 4:** Recolour both mockups (light/dark) with the appendix tokens: hero = primary with white text, progress = secondary on secondary.track, chips = accent/cont, stat tiles = prim-ctr and sec-ctr, nav selection = primary.muted with primary.ink.
- [ ] **Step 5:** Under the mockups add one strip per frame: brand chip, error chip, warning chip, side by side, labelled — the confusion check from Review Focus.
- [ ] **Step 6:** `get_screenshot` each frame; confirm nothing still shows N4's colours and text is legible.
- [ ] **Step 7:** Send the page link to the owner.

### Task 2: Pick (human gate)

- [ ] **Step 1:** Owner picks one of L1–L4, possibly with tweaks. Tweaks go into Figma first, then into the appendix table of the chosen palette; re-run the contrast checks in Task 3 Step 1 against them.
- [ ] **Step 2:** Rename the chosen frame `Loomia — chosen`, leave the others.

### Task 3: Apply the chosen palette

**Files:**
- Modify: `lib/app/theme/app_colors.dart`
- Modify: `docs/design/design-system.md` §1
- Test: `test/app/theme/app_theme_test.dart`

**Interfaces:**
- Produces: `FoloColors.brand` (`Color`), used by #83 for the wordmark mark and icon background.

- [ ] **Step 1: Write the failing tests** (append to `test/app/theme/app_theme_test.dart`, inside `main`)

```dart
  double contrast(Color a, Color b) {
    final la = a.computeLuminance(), lb = b.computeLuminance();
    return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
  }

  test('white text on primary meets AA in both modes', () {
    for (final scheme in [AppColors.light, AppColors.dark]) {
      expect(contrast(scheme.onPrimary, scheme.primary), greaterThanOrEqualTo(4.5));
    }
  });

  test('primary ink meets AA on its surface', () {
    expect(contrast(FoloColors.light.primaryText, FoloColors.light.surfaceDefault),
        greaterThanOrEqualTo(4.5));
    expect(contrast(FoloColors.dark.primaryText, FoloColors.dark.surfaceDefault),
        greaterThanOrEqualTo(4.5));
  });

  test('brand is the chosen Loomia hex and lerps', () {
    expect(FoloColors.light.brand, const Color(0xFFC86C53)); // chosen brand hex
    expect(FoloColors.light.lerp(FoloColors.dark, 1).brand, FoloColors.dark.brand);
  });
```

Add `import 'dart:math' as math;` at the top. The hex in the brand test is the chosen palette's brand (the example shows L2).

- [ ] **Step 2:** `flutter test test/app/theme/app_theme_test.dart` — expect compile failure (`brand` undefined).
- [ ] **Step 3:** In `app_colors.dart`:
  - add `required this.brand,` to the constructor and the field, documented `/// Logo, app icon, decorative marks. Never behind text — too light for white ink.`;
  - add `brand: c(brand, other.brand),` to `lerp`;
  - replace every value in `AppColors.light/dark` and `FoloColors.light/dark` with the chosen palette + shared tokens from the appendix. Mapping: `primary`=primary.fill, `primaryHover`=primary.hover, `primaryText`=primary.ink (dark: dark ink), `primaryContainer`=primary.cont, `onPrimaryContainer`=primary.onCont, `primaryMuted`=primary.muted, `secondary`=secondary.fill, `secondaryText`=secondary.text, `secondaryContainer`=secondary.cont, `onSecondaryContainer`=secondary.onCont, `secondaryTrack`=secondary.track, `onSecondary`=onSecondary, `accent`/`error`/`warning` = the (base) row, `…Container`/`on…Container` = cont/onCont, `focus`=primaryText, neutrals from the shared table (`shadow`/`scrim`/`inverseSurface` = onSurface light; dark `shadow`/`scrim` stay `#000000`). `success` and `info` unchanged.
  - Keep `brand` the same in both modes.
- [ ] **Step 4:** In the same test file, replace the hard-coded `const Color(0xFF235C46)` (the `resolved.colorScheme.primary` expectation, ~line 41) with the chosen primary.fill. Then `flutter test test/app/theme/app_theme_test.dart` — PASS. The other equality checks compare against `FoloColors.light/dark` themselves, so they follow the new values.
- [ ] **Step 5:** Update the table in `docs/design/design-system.md` §1 with the same values and a `brand/base` row. Rename the Figma collection reference from `Folo/color` to `Loomia/color` only if #84 has merged; otherwise leave it for #84.
- [ ] **Step 6:** `dart format . && flutter analyze && flutter test` — all green except golden mismatches (expected on Linux CI only).
- [ ] **Step 7: Commit**

```bash
git add lib/app/theme/app_colors.dart test/app/theme/app_theme_test.dart docs/design/design-system.md
git commit -m "feat(theme): Loomia palette (#82)"
```

- [ ] **Step 8:** Push, regenerate goldens through CI (README → *Golden tests*), open every PNG, commit `test(goldens): Loomia palette`, open PR with `Closes #82`.

Conflict note: #84 renames `FoloColors` → `LoomiaColors`. Whichever PR merges second rebases and re-applies its side.

---

## Appendix — palette values

Derived from each brand hue (lightness walked until the contrast target holds) and validated: white on primary ≥ 5.0, primaryText ≥ 5.5 light / 6.0 dark, on-containers ≥ 7, secondary ink ≥ 5.5. Neutrals are today's neutrals re-hued to warm (30°) at the same lightness, so their contrast calibration carries over.

### Shared by all four

| Token | Light | Dark |
| --- | --- | --- |
| surface | `#FBFAF8` | `#120F0C` |
| onSurface | `#201B16` | `#F1EEEC` |
| onSurfaceVariant | `#57524C` | `#C2BCB7` |
| surfaceSunken | `#F4F1EE` | `#181411` |
| surfaceDisabled | `#F2EFEC` | `#211E1A` |
| borderStrong | `#CFC8C0` | `#48413A` |
| borderSubtle | `#E8E4E1` | `#312C26` |
| textMuted | `#706A64` | `#A59E97` |
| textDisabled | `#A9A49F` | `#68625C` |
| surfaceDefault | `#FFFFFF` | `#1E1A15` |
| surfaceRaised | `#FFFFFF` | `#26211C` |
| accent (base) | `#A94C8D` | `#BF87AE` |
| accent.cont | `#EDE3EA` | `#231B20` |
| accent.onCont | `#71335E` | `#D1A9C5` |
| error (base) | `#CF3046` | `#D5818C` |
| error.cont | `#F0E0E2` | `#25181A` |
| error.onCont | `#88202E` | `#E0A3AC` |
| warning (base) | `#8A690F` | `#BC9529` |
| warning.cont | `#F2EDDE` | `#272316` |
| warning.onCont | `#604A0B` | `#DAB758` |

### L1 ocre pale — brand `#E8964A`

| Token | Light | Dark |
| --- | --- | --- |
| primary.fill | `#A75C15` | `#A75C15` |
| primary.hover | `#8C4C12` | `#C26A19` |
| primary.ink | `#995413` | `#D38A45` |
| primary.cont | `#F2E8DE` | `#271E16` |
| primary.onCont | `#713E0E` | `#E0AB7B` |
| primary.muted | `#F9F5F1` | `#1A140F` |
| secondary.fill | `#697DAB` | `#909FC1` |
| secondary.text | `#495B83` | `#909FC1` |
| secondary.cont | `#E5E7EB` | `#1B1D22` |
| secondary.onCont | `#3D4B6C` | `#AAB5CF` |
| secondary.track | `#CBCFD8` | `#2D3139` |
| onSecondary | `#0B111E` | `#0B111E` |

### L2 rouge cuivré — brand `#C86C53`

| Token | Light | Dark |
| --- | --- | --- |
| primary.fill | `#B25339` | `#B25339` |
| primary.hover | `#9B4832` | `#C46146` |
| primary.ink | `#A34C34` | `#C88A7A` |
| primary.cont | `#EFE4E2` | `#241B19` |
| primary.onCont | `#783826` | `#D7AA9E` |
| primary.muted | `#F7F3F2` | `#181211` |
| secondary.fill | `#6B923F` | `#85B450` |
| secondary.text | `#516F2F` | `#85B450` |
| secondary.cont | `#E8EDE3` | `#1F231A` |
| secondary.onCont | `#3C5223` | `#9EC374` |
| secondary.track | `#D2DAC8` | `#343B2B` |
| onSecondary | `#151E0B` | `#151E0B` |

### L3 ocre flashy — brand `#E49329`

| Token | Light | Dark |
| --- | --- | --- |
| primary.fill | `#9A6013` | `#9A6013` |
| primary.hover | `#7E4F10` | `#B57017` |
| primary.ink | `#8C5712` | `#CF8A30` |
| primary.cont | `#F2E9DE` | `#272016` |
| primary.onCont | `#6D440E` | `#DEAF72` |
| primary.muted | `#F9F5F1` | `#1A150F` |
| secondary.fill | `#657DB3` | `#8E9FC7` |
| secondary.text | `#435889` | `#8E9FC7` |
| secondary.cont | `#E4E6EC` | `#1A1D23` |
| secondary.onCont | `#384971` | `#A6B4D3` |
| secondary.track | `#C9CED9` | `#2C303A` |
| onSecondary | `#0B111E` | `#0B111E` |

### L4 marron beige — brand `#C6785B`

| Token | Light | Dark |
| --- | --- | --- |
| primary.fill | `#A7573A` | `#A7573A` |
| primary.hover | `#904C32` | `#BD6442` |
| primary.ink | `#985035` | `#C48D79` |
| primary.cont | `#EEE5E2` | `#241C19` |
| primary.onCont | `#723C27` | `#D3AB9C` |
| primary.muted | `#F7F4F2` | `#181311` |
| secondary.fill | `#6E9047` | `#8CB262` |
| secondary.text | `#567138` | `#8CB262` |
| secondary.cont | `#E8ECE4` | `#1F231A` |
| secondary.onCont | `#3F5228` | `#A5C284` |
| secondary.track | `#D2D9C9` | `#333A2C` |
| onSecondary | `#151E0B` | `#151E0B` |
