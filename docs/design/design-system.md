# Design system

Direction B (Fresh & Energetic) with the **N1 Forest → Olive** analogous palette,
circular avatars, light and dark fully specified.

Source of truth: [Figma → Folo](https://www.figma.com/design/spz2vsSK8gbt1Ok2rW1sdQ/Folo),
page `Foundations`. Variables: collection `Folo/color` (modes `Light` / `Dark`)
and `Folo/scale` (single mode). Every fill, stroke, padding and radius in every
component and screen is **bound to a variable** — no literal colour exists
outside the two exploration pages.

The tokens live in `lib/app/theme/` (see §8 for the file-by-file mapping) and are
visible in `flutter widget-preview start` — group **Tokens**. Components and
screens are not implemented yet.

---

## 1. Colour

### Why these hues

Primary and secondary are **neighbours on the wheel** (forest → olive), not
opposites. Material 3 derives secondary and tertiary by rotating hue away from
the seed; we deliberately do not, because a single hue arc reads as one brand
rather than a set of status colours, and it structurally prevents the
colour-coded-urgency failure mode that Direction B risks. The contrast the layout
needs is bought back with **lightness**: a dark forest block carrying a bright
olive bar.

Accent (amber-olive) is the third stop on the same arc. It is reserved for things
anchored to a real moment — a birthday, a promised call-back — never for
judgement (guardrail #2).

### Semantic tokens

| Token | Light | Dark | Use |
| --- | --- | --- | --- |
| `surface/canvas` | `#FBFBF8` | `#0C1210` | App background. Warm off-white / hue-tinted near-black, never `#000`. |
| `surface/default` | `#FFFFFF` | `#151E19` | Cards, rows, bars. |
| `surface/raised` | `#FFFFFF` | `#1C2620` | Menus, sheets, dialogs. In dark, raised steps *up* a surface instead of deepening a shadow. |
| `surface/sunken` | `#F4F4EE` | `#111814` | Search field, sidebar, wells. |
| `surface/disabled` | `#F2F2EC` | `#1A211C` | Disabled controls. |
| `border/subtle` | `#E6E8E1` | `#26312B` | The default 1px hairline. |
| `border/strong` | `#C9CFC0` | `#3A4840` | Unchecked controls, dividers that must be seen. |
| `text/primary` | `#16201A` | `#ECF1ED` | Names, headings, values. |
| `text/secondary` | `#4C5751` | `#B7C2BA` | Body, reasons, descriptions. |
| `text/muted` | `#64706A` | `#97A59D` | Metadata, overlines, captions. |
| `text/on-primary` | `#FFFFFF` | `#FFFFFF` | Text on `primary/base` — same in both modes, because the hero block is the same colour in both modes. |
| `text/on-secondary` | `#14200A` | `#14200A` | Text on `secondary/base`. |
| `text/disabled` | `#A2A99F` | `#5C6861` | |
| `primary/base` | `#235C46` | `#235C46` | The filled hero, primary buttons. **Identical in both modes** — a saturated block on a dark canvas stays readable, and the brand colour is not diluted. |
| `primary/hover` | `#1B4A38` | `#2C6E55` | Pointer hover; also the hero's own progress track. |
| `primary/text` | `#1F5540` | `#66BE94` | Primary used as *ink* — this is the token that must flip, since the base fails contrast on dark surfaces. |
| `primary/container` | `#DAE8DF` | `#16291F` | Tinted blocks, active nav pill, avatar background. |
| `primary/on-container` | `#143C2C` | `#8BD1AE` | Ink on `primary/container`. |
| `primary/muted` | `#EDF3EF` | `#101A15` | Hover wash, selected row. |
| `secondary/base` | `#6F9339` | `#A8C765` | Progress bars. The pace colour. |
| `secondary/text` | `#4F6B1F` | `#A8C765` | "On pace", pace labels. |
| `secondary/container` | `#E9EFD6` | `#232C12` | Tinted stat tile. |
| `secondary/on-container` | `#41590F` | `#C2DA8C` | |
| `secondary/track` | `#D7E2B6` | `#38471C` | Progress track under `secondary/base`. |
| `accent/base` | `#B08B2A` | `#D9B75E` | Date-anchored marks only. |
| `accent/container` | `#F6EBCD` | `#2E2612` | Date chips (birthday, promised call-back). |
| `accent/on-container` | `#6E5410` | `#E6CE8E` | |
| `semantic/success` | `#2E7D5B` | `#5FC196` | Confirmation of a system action. |
| `semantic/success-container` | `#DCEFE4` | `#13291F` | |
| `semantic/warning` | `#8A5A16` | `#E2A85C` | System states only (sync, permission). Deliberately a deeper bronze so it cannot be confused with `accent`. |
| `semantic/warning-container` | `#F7E2C8` | `#2F2513` | |
| `semantic/error` | `#A83B2A` | `#F08E7C` | Destructive actions and genuine validation errors. Never "overdue" (principle #4). |
| `semantic/error-container` | `#FADEDA` | `#33201C` | |
| `semantic/on-error` | `#FFFFFF` | `#241110` | |
| `semantic/info` | `#2C6B7A` | `#74BDCB` | Neutral system notice. |
| `semantic/info-container` | `#DDEDF1` | `#14282E` | |
| `state/focus` | `#235C46` | `#66BE94` | 2px focus-visible ring. |

Scopes are set on every variable (`FRAME_FILL, SHAPE_FILL` for surfaces,
`TEXT_FILL` for ink, `STROKE_COLOR` for borders) so the Figma colour picker only
offers tokens that make sense in the slot being edited.

### Rules that come out of the palette

1. **One filled colour block per screen** — the Today hero. Everything else is
   surface plus hairline (guardrail #1).
2. **Tinted pairs, not tinted everything** — at most one `primary/container` /
   `secondary/container` pair per screen (the stat tiles).
3. **Accent means "a date made this urgent"**, never "you are behind".
4. **Red only destroys.** The one exception is a field-level validation error.
5. **Dark is not an inversion.** Canvas is hue-tinted near-black, surfaces step
   up, the hero keeps its light-mode colour, and every *ink* use of primary /
   secondary / accent switches to the lighter tint.

### Contrast

All body and label pairs clear WCAG AA (4.5:1); `text/muted` on `surface/canvas`
is 4.7:1 light and 5.6:1 dark. `text/on-primary` on `primary/base` is 7.1:1 in
both modes. The hero's secondary labels are white at 78% opacity, which holds in
both modes precisely because the block colour does not change.

---

## 2. Typography

**Plus Jakarta Sans**, one family, four weights (Regular / Medium / Bold used;
variable font, so four weights cost one file).

Why: wide apertures and a tall x-height keep 13px legible on Android; true
tabular figures keep goal numbers from shifting as they update; the skeleton is
geometric enough to read as a product and neutral enough not to carry an opinion
of its own. A serif display face was considered (Direction C) and dropped — it
adds a webfont on Web and is the wrong risk for a 25–65 audience.

| Style | Size / line | Weight | Tracking | Use |
| --- | --- | --- | --- | --- |
| `display` | 32 / 38 | Bold | −1.5% | Desktop greeting, contact name on desktop detail. |
| `headline` | 24 / 30 | Bold | −1% | Mobile screen title, contact name on mobile. |
| `title-lg` | 20 / 26 | Bold | −0.5% | Hero headline, dialog title, empty-state title. |
| `title` | 17 / 24 | Bold | — | Person's name in a row. The most-used heading in the product. |
| `body-lg` | 16 / 24 | Regular | — | Input values, dialog body, sentences that matter. |
| `body` | 15 / 22 | Regular | — | Default body. |
| `body-sm` | 13 / 18 | Regular | — | The reason line under a name. |
| `label-lg` | 15 / 20 | Bold | — | Buttons, sidebar items. |
| `label` | 13 / 16 | Bold | — | Field labels, small actions. |
| `caption` | 12 / 16 | Medium | — | Metadata, pace, nav labels. |
| `overline` | 11 / 14 | Bold | +10%, UPPER | Section headers, stat-tile labels, date eyebrows. |
| `numeric-lg` | 30 / 34 | Bold | −1% | Stat-tile values. |
| `numeric` | 20 / 24 | Bold | −0.5% | Goal values. |

Numerals use `FontFeature.tabularFigures()` in Flutter. Goal numerals cap at
30px and never exceed the greeting (guardrail #4). Uppercase is only ever
`overline` — never a heading, never a button.

---

## 3. Spacing

A 4-based scale, in `Folo/scale`:

| Token | px | Typical use |
| --- | --- | --- |
| `space/xs` | 4 | Name → reason, chip internals. |
| `space/sm` | 8 | Chip gaps, label → field, icon → text. |
| `space/ms` | 12 | Row internals, list item gaps. |
| `space/md` | 16 | Card padding, screen horizontal padding (mobile). |
| `space/lg` | 24 | Between groups inside a screen. |
| `space/xl` | 32 | Between sections on desktop, desktop pane padding. |
| `space/xxl` | 48 | Desktop main-column horizontal padding. |
| `space/xxxl` | 64 | Reserved for marketing / empty screens. |

This replaces the placeholder `AppSpacing` (which lacks 12, 16-as-`lg`, 20 and
64) — see the Flutter mapping below.

---

## 4. Shape

| Token | px | Applies to |
| --- | --- | --- |
| `radius/sm` | 8 | Chips. |
| `radius/md` | 12 | Inputs, list rows with a hover/selected wash. |
| `radius/lg` | 16 | Cards, tiles, action items. |
| `radius/xl` | 20 | The Today hero, dialogs, bottom sheets. |
| `radius/pill` | 999 | Buttons, icon buttons, progress tracks, nav pill, **avatars at every size**. |

**Avatars are circular, always, everywhere** — 24 (inline), 32 (dense list /
stacks), 40 (list row), 56 (detail header). Decided 2026-09-22; squircle was the
alternative and lost on legibility at 24px and on photo crops.

Nothing is rounder than its container: a 16px card holds 12px inputs and 8px
chips.

---

## 5. Elevation

Three levels. Only two of them cast a shadow.

| Level | Spec | Where |
| --- | --- | --- |
| flat | no shadow, `surface/default`, 1px `border/subtle` | All content: cards, rows, tiles, bars. |
| `elevation/raised` | `0 1 2 @6%` + `0 2 8 @5%` | Menus, dropdowns, snackbars. **Never on a content card.** |
| `elevation/overlay` | `0 8 28 @12%` | Dialogs and bottom sheets only. Scrim: `text/primary` at 40%. |

In dark mode, raised and overlay surfaces step up a surface token
(`surface/default` → `surface/raised`) rather than deepening the shadow —
shadows are close to invisible on a near-black canvas.

A UI of floating cards is the thing this system is built to avoid (principle #6).

---

## 6. Iconography

**Material Symbols Rounded, outlined, weight 300** — 20px in dense contexts
(chips, inline), 24px default (nav, app bar, buttons). Stroke 1.75 at 20px.

Rationale: available through Flutter's bundled icon font, so it costs no
dependency (see CLAUDE.md — "adding a dependency requires a reason"); rounded
terminals agree with the pill/16px radii; outlined keeps icons quieter than the
names beside them.

Icons never carry meaning alone — every icon in navigation, and every icon-only
button, has a visible label or an accessible label. No icon is ever the only
indicator of state.

In Figma, icons are an `Icon` component used as an `INSTANCE_SWAP` slot with a
placeholder glyph; the production glyph comes from the Flutter font, so the
library deliberately does not ship 200 vector icons.

---

## 7. Motion

Restrained. Motion explains what moved, it never celebrates.

| Duration | Use |
| --- | --- |
| 120ms | Hover, pressed, focus ring. |
| 180ms | Chip/toggle state, small fades. |
| 240ms | Row collapse on completion, list reorder, tab change. |
| 320ms | Sheet and dialog present/dismiss, page transition. |

Easing: standard `cubic(0.2, 0, 0, 1)`, decelerate `cubic(0, 0, 0, 1)` for
entering, accelerate `cubic(0.3, 0, 1, 1)` for leaving.

Rules: no bounce or overshoot; no scale above 1.02; completing an action is a
check plus a 240ms row collapse (no confetti, no counter, no streak — principle
#5); no looping animation except an indeterminate loader; all of it respects
"reduce motion" by collapsing to a 120ms opacity change.

Fluidity comes from every screen using the same four durations and three curves,
not from springs. If a new interaction does not fit the table below, the
interaction is wrong before the table is.

### 7.1 Decision table

| Interaction | Duration | Curve | Flutter |
| --- | --- | --- | --- |
| Hover, press, focus ring | 120ms | standard | `InkWell` / `Material` states — state the wash, let the ink time it |
| Icon swap in place (reveal toggle) | 120ms | standard | `AnimatedSwitcher` |
| Tinted container changing tone | 120–180ms | standard | `AnimatedContainer` |
| Ink colour changing with state | 180ms | standard | `AnimatedDefaultTextStyle` |
| Label ↔ spinner on a button | 180ms | decelerate in, accelerate out | `AnimatedSwitcher` |
| Inline message appearing | 180ms | decelerate | `TweenAnimationBuilder` over opacity + `Align.heightFactor` |
| Progress bar value | 240ms | standard | `TweenAnimationBuilder` |
| Row collapse on completion, list reorder, tab change | 240ms | standard | `AnimatedSize` / `AnimatedList` |
| Page transition along one flow (auth) | 320ms in, 240ms out | standard in, accelerate out | `foloPage(..., sharedAxis: true)` — fade plus an 8px shift |
| Page transition between contexts | 320ms in, 240ms out | standard in, accelerate out | `foloPage(...)` — fade through |
| Sheet, dialog | 320ms | standard | Material defaults from the component themes |

Leaving is one step quicker than arriving: the user already knows the screen
they are going back to.

### 7.2 The reduce-motion contract

Durations never reach a widget as a literal. They arrive through
`context.motion(AppMotion.medium)` (`lib/app/theme/app_theme.dart`), which
returns 120ms whenever the platform asks for reduced motion. A movement whose
shape would still read as movement at 120ms — the 8px page shift — drops out
entirely instead; everything else keeps its fade. Using a raw `Duration` in a
widget is the bug, not the animation itself.

### 7.3 Never

Bounce, overshoot, elastic and spring curves. Scale above 1.02. Parallax.
Looping animation of any kind except an indeterminate loader. Staggered or
sequenced entrances — a list appears at once, or it is not ready. Page-load
fades on content that was already there. Any motion that reads as celebration:
counting numbers up, filling a ring, confetti, a streak (principle #5).

---

## 8. Mapping to Flutter

Implemented. One file per concern, no new dependency, no codegen.

- `lib/app/theme/app_colors.dart` — `AppColors.light` / `AppColors.dark`
  (`ColorScheme`) plus `FoloColors`, a `ThemeExtension` holding the tokens
  `ColorScheme` has no slot for (`surface/default|sunken|raised|disabled`,
  `border/subtle|strong`, `text/muted|disabled`, `primary/hover|text|muted`,
  `secondary/text|track`, `accent/*`, success / warning / info, `state/focus`).
  Read it with `FoloColors.of(context)`. A palette change is then one file.
- `lib/app/theme/app_spacing.dart` — `AppSpacing` (`xs` 4 → `xxxl` 64) and
  `AppRadii` (`sm` 8 → `pill`).
- `lib/app/theme/app_typography.dart` — `fontFamily = 'PlusJakartaSans'`, all 13
  styles as statics; the ones Material has a slot for are also wired into
  `TextTheme` (`displaySmall`, `headlineSmall`, `titleLarge`, `titleMedium`,
  `body*`, `label*`). `overline`, `numericLarge` and `numeric` have no Material
  slot and are used directly. The font is one bundled variable file, so each
  style sets the `wght` axis as well as `fontWeight`.
- `lib/app/theme/app_theme.dart` — the two `ThemeData`s and every component
  theme (buttons, input, card, chip, progress, dialog, sheet, menu, nav bar,
  list tile, tooltip), plus `AppElevation` (the two shadow sets and the scrim)
  and `AppMotion` (durations and easing) plus the `Motion` extension on
  `BuildContext` — `context.motion(duration)`, the one place "reduce motion" is
  honoured (§7.2).
- `lib/app/router/page_transitions.dart` — `foloPage`, the `CustomTransitionPage`
  every `GoRoute` uses. `sharedAxis: true` for a move inside one flow.
- `lib/app/theme/theme_preview.dart` — `@Preview` token sheets (colour, type,
  spacing/shape/elevation, components) in both modes. `flutter widget-preview
  start`, group **Tokens**. Nothing in the app imports it.

Accent, success, warning and info deliberately do **not** occupy
`ColorScheme.tertiary`: one home per token, and Material widgets should not
reach a date-only colour by accident.

Widgets read `Theme.of(context)` and the extension only. The Figma variable name
`primary/container` maps to `FoloColors.primaryContainer`; the code syntax for
every variable is already set in Figma (`WEB`: `var(--folo-primary-container)`,
`ANDROID`/`iOS`: `FoloColors.primaryContainer`), so Dev Mode reads the same names
the code uses.

---

## 9. Changing the palette later

Cheap by construction: ~24 values in one Figma variables panel and one Dart
file. What is *not* cheap: the token names and structure, the lightness
relationships the layouts depend on (dark primary block carrying a bright olive
bar), and the number of accents. Hue is a value; the structure is the commitment.
