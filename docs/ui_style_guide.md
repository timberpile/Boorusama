# Boorusama UI style guide (baseline)

Status: **proposed baseline**, pending review and acceptance under [#136](https://github.com/timberpile/Boorusama/issues/136). This document describes existing patterns and conservative rules; it does not authorize a redesign or supersede approved feature specifications.

See the [Kurumi component index](designs/2026-11-02-kurumi-component-inventory.md), [source audit](designs/2026-11-02-ui-design-system-audit.md) and [Penpot design strategy](designs/2026-11-02-penpot-design-strategy.md).

## Design intent

Boorusama is a compact, information-dense booru client. Prioritize fast search, browsing, multi-selection, and context actions without sacrificing readability, accessibility, responsive behavior, or platform input methods. Preserve established task flows and features. Do not trade density for ornamental spacing or introduce controls solely to match a mockup.

## Component ownership

1. **`packages/kurumi` owns reusable visual behavior**: theme foundations, app bars, buttons, menus, inputs, chips, settings surfaces, dialogs, sheets, focus and interaction primitives. Prefer a public Kurumi component when its behavior meets the use case. Check `packages/kurumi/lib/kurumi.dart` for its supported API before adding a wrapper. Some `KurumiMaterial...` types are intentional `typedef` aliases to Flutter Material widgets, not custom-rendered controls.
2. **`lib/core/widgets` owns application integration**: localization (`context.t`), profile-aware behavior, booru-specific color metadata, asset choices, and app-specific defaults. For example `NoDataBox` delegates to a Kurumi primitive while selecting localized text and an animation; `OptionSearchableSheet` delegates to `KurumiOptionSearchableSheet`. Keep useful wrappers; do not move app/domain policy into Kurumi.
3. **Feature widgets own domain workflows**: post grids, bookmarks, the viewer, artists, following, and engine-specific UI. Factor out a shared component only if real consumers benefit and its behavior is genuinely shared.
4. **Flutter Material/Cupertino widgets remain valid building blocks**, including `Scaffold`, `ListTile` inside a standardized card, and basic buttons as implementation details. The presence of Material in code is not, by itself, a style defect. Evaluate the rendered control, interaction semantics, and context before replacing it.

### Preferred patterns

| Need | First check | Allowed alternative / exception |
| --- | --- | --- |
| App bar / bounded toolbar title | `KurumiAppBar`, `KurumiSliverAppBar`, built-in adaptive title behavior | Specialized sliver/route shell when existing navigation constraints require it |
| Popup, context or anchored menu | `KurumiPopupMenuButton`, `KurumiContextMenu`, `KurumiAnchor` and relevant rows | Material menu only where Kurumi cannot preserve required semantics/behavior; document the reason |
| Sheets and dialogs | Kurumi adaptive sheet and dialog helpers/components | Existing Material dialog where a Kurumi replacement is not behaviorally equivalent |
| Settings sections and entries | `KurumiSettingsCard`, `KurumiSettingsHeader`, `KurumiSettingsTile`, `KurumiSwitchListTile`, `KurumiSettingsEntryTile` | `ListTile` as content of a Kurumi section when it matches density and semantics |
| Input, search, choice | `KurumiTextField`, `KurumiTextFormField`, `KurumiSearchBar`, option selector components | Plain `TextField` for exceptional IME, sizing, editor, or interaction requirements |
| Chips, search tags | Kurumi chip families and the existing selected-tag widgets | Specialized tags when site categories or accessibility behavior require them |
| Empty/error/feedback state | Existing `NoDataBox`, Kurumi no-data and toast/status components | Domain-specific recovery/action UI when appropriate |
| Responsive actions | Existing `AdaptiveButtonRow` / `KurumiAdaptiveButtonRow` | Feature-specific action layout only when overflow behavior differs meaningfully |

**Menu rule:** do not combine differently styled Material and Kurumi rows *inside the same popup*. Compare opening, anchoring, item density, focus, keyboard control, scrolling, dismissal, and touch behavior before migration. Do not automatically rewrite every Material `PopupMenuButton` without inspecting the widget tree.

## Foundations and tokens

- Use **semantic color roles**, not fixed palette hex values in new feature UI: `context.kurumiColors` / `Kurumi.semanticColorsOf(context)` when available, or the active `ThemeData.colorScheme` and theme text colors. The palette can change with system/light/dark/AMOLED modes, dynamic color, premium settings, and per-profile overrides. Engine/tag category colors are intentional semantic exceptions.
- Use `ThemeData.textTheme` / Kurumi theme typography. Reuse `KurumiFittedText` or adaptive Kurumi title behavior in bounded title contexts; do not forcibly shrink long body copy. Follow already completed title work in [#130](https://github.com/timberpile/Boorusama/issues/130).
- Reuse existing spacing, padding, density, radius, and control styles from comparable screens. Do **not** introduce new project-wide numeric design tokens or replace existing constants until representative screenshots have been reviewed and their values agreed. The radius scale is owned by [#105](https://github.com/timberpile/Boorusama/issues/105).
- Prefer `KurumiDurations` and existing reduced-motion behavior to arbitrary animation timings. Do not add transitions that interfere with rapid navigation or image browsing.
- Use established icon semantics, localized labels (`context.t`), and reasonable contrast in every color mode. Avoid unlabelled icon-only actions; provide tooltips/semantics as appropriate. The completed label/icon initiative [#50](https://github.com/timberpile/Boorusama/issues/50) remains the baseline.
- Avoid fixed heights and widths that break with text scaling, keyboard insets, small screens, or desktop. A compact visual control can have a larger accessible hit target; see [#116](https://github.com/timberpile/Boorusama/issues/116) for a specific 48×48 logical-pixel touch-target precedent.

## Current theme contract

The roles in `packages/kurumi/lib/src/theme/semantic_tokens.dart` alias the active
Material theme; they do not define a second palette:

| Kurumi role | Runtime source | Use |
| --- | --- | --- |
| `accent` / `onAccent` | `primary` / `onPrimary` | Primary action and its content |
| `accentContainer` / `onAccentContainer` | Material container pair | Selected/emphasized surface and content |
| `surface`, `surfaceContainer{Low,High,Highest}` | Corresponding Material surface roles | Page, grouped settings, raised/stronger containers |
| `content` / `contentSecondary` | `onSurface` / `onSurfaceVariant` | Main and supporting text |
| `contentMuted`, `outline`, `outlineVariant` | `outline`, `outline`, `outlineVariant` | Muted content and boundaries; verify contrast at the actual size |
| `danger` / `onDanger` | `error` / `onError` | Error/destructive emphasis and content |
| `overlay{,Dim}` / `onOverlay{,Dim}` | Kurumi extended color scheme | Content over media; preserve the backing overlay |

`Kurumi.generateColorScheme` uses built-in light/dark/AMOLED schemes when dynamic
schemes are unavailable. Both dynamic light and dark schemes must exist to enter
the dynamic branch. AMOLED retains its black/surface hierarchy and copies only
the dynamic primary pair. `ThemeBuilder` applies premium-enabled global or
profile appearance before the Kurumi Material bridge, then attaches
`BoorusamaColors`. Theme fixtures must include the app extension when a consumer
uses it. A profile can therefore legitimately look different from the built-in
reference palette. Do not infer a contrast pass from the semantic role name.

Keep background/content pairs together when sampling colors in a design tool.
The current built-in error and muted roles still require rendered contrast
review; this audit does not certify them. Source references:
`packages/kurumi/lib/src/kurumi.dart:47`,
`packages/kurumi/lib/src/theme/theme.dart`, and
`lib/core/themes/theme/src/theme_buider.dart:24`.

## Choosing a menu or editor

Match the interaction before the class name. Following Topics' sort menu uses
Material's selected value and icon/text `PopupMenuActionLabel`; Download
Manager's Kurumi menu dispatches actions. A migration must explicitly preserve
selection announcements, disabled items, focus return, outside/Back dismissal,
scrolling, and anchor containment. Compare these different tasks without assuming
they should expose identical rows.

`KurumiTextField` forwards Material text-editing options and applies Kurumi
behavior; a native editor is not proof of a different palette. Keep specialized
tag editing, completion, submission, and cancellation in its existing app
wrapper. Dialogs must preserve Navigator ownership, IME insets, scrollable
content, validation, and cancellation before component substitution.

## Responsive and interaction rules

- Inspect an existing **mobile and desktop counterpart** before changing navigation, search, selection, or dialogs. Preserve screen-specific interactions rather than mechanically scaling a phone mockup.
- Keep actions reachable by touch, mouse, keyboard, and screen reader when the widget exposes those modalities. Check hover, focus, disabled, selected, loading, empty, and error states.
- Account for display cutouts, navigation UI, keyboard, text scaling, long localized labels, RTL where supported, nested overlays, and scroll position restoration.
- Preserve the shared post/snapshot architecture and site/profile-specific capabilities. A common visual pattern must not merge different account, site, or data semantics.
- Keep performance-sensitive image grids and viewer components specialized; avoid unnecessary widget wrappers, expensive rebuilds, or animated layout changes.

## Design reference authority

**Existing behavior:** production code and tests are authoritative until an explicit design change is approved. **New or redesigned visuals:** an approved Penpot reference (where available) plus this guide defines target appearance; approved interaction specs and tests define behavior. **Tokens and components:** Kurumi code owns runtime implementation; Penpot reflects approved semantic tokens and variants. If design and code disagree, report drift and resolve it; do not silently overwrite one with the other.

A Penpot screenshot is not a requirement to achieve identical pixels for every device, font scale, theme, language, content length, or platform. Specify invariants (hierarchy, spacing intent, component choice, interaction) and representative dimensions instead.

## UI change review checklist

- [ ] Existing similar screen and Kurumi API inspected; reuse/exception recorded.
- [ ] No redundant widget abstraction or parallel styling implementation introduced.
- [ ] Semantic color/typography and existing spacing/density conventions followed.
- [ ] Menu/sheet/dialog behavior, keyboard, focus, and dismissal preserved.
- [ ] Narrow layout, enlarged text, and keyboard-open layout checked where relevant.
- [ ] Mouse/keyboard navigation and screen-reader semantics checked where relevant.
- [ ] Light/dark/AMOLED/dynamic color effects considered where relevant.
- [ ] Screenshots compared against representative approved references when available.
- [ ] Scope-specific tests performed; all untested device behavior reported explicitly.

## Repeatable audit

From a local Boorusama checkout:

```sh
python3 scripts/audit_ui_components.py
```

The script writes a **lexical call-site candidate inventory** in JSON and a summary Markdown report under the ignored `.worktrees/_artifacts/ui-component-audit/` directory. It covers selected symbol families, not every constructor or indirect consumer. The inventory is a triage aid, not an AST parser or a visual acceptance test. Confirm candidates manually. The report is not a second task tracker: log accepted remediation tasks in GitHub Issues, linking to source evidence and screenshots.

For a repeatable visual-drift review, record the source commit and any runtime
diff, installed APK hash/provenance, device/platform, logical viewport, density,
text scale, theme/dynamic/profile settings, engine, route and interaction state.
Capture the same state before and after a UI change with safe public content.
Compare hierarchy, density, reachability, anchoring and state feedback; classify
differences caused by content, font rendering, insets or dynamic palettes before
calling them drift. Use the [canonical capture matrix](designs/2026-11-02-ui-design-system-audit.md#screenshot-and-ux-verification-matrix)
and add only the states touched by the change. Store raw local captures in durable
ignored task artifacts; share only reviewed, sanitized evidence. A successful
Maestro command or a matching APK hash alone is not visual acceptance.
