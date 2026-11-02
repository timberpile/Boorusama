# Kurumi UI design system: initial source audit

Date: 2026-11-02
Tracking issue: [#136 — Establish Kurumi UI Design System](https://github.com/timberpile/Boorusama/issues/136)
Reviewed source: `develop` at `74cdf43a5bd5205baa8f7cefb164986fe2656dd1`
Evidence level: **GitHub-source inspection, not a full repo-wide call-site scan or device UX review**.

## Objective and boundary

Catalog Kurumi, application wrappers, and standard Flutter controls; identify concrete reuse and consistency candidates. Preserve current interaction and density until screenshots and UX recommendations have been reviewed. Do not refactor app code as part of this evidence-gathering task. The existing independent radius issue [#105](https://github.com/timberpile/Boorusama/issues/105) remains the owner of any globally approved corner-radius adjustment.

## Structure established from repository tree

| Scope | Count | Interpretation |
| --- | ---: | --- |
| `packages/kurumi/lib/src/components/*.dart` | 73 | Component implementation **files**, not unique public classes |
| `lib/core/widgets/*.dart` | 36 | Core shared-widget **files**, including barrel and support files |
| `lib/**/widgets/**/*.dart` | 396 | Feature-widget **files** under named `widgets` directories; does not include UI files stored elsewhere |
| `lib/**/*.dart` | 2,794 | All Dart files in the app `lib` subtree, not only widgets |

A [file-by-file inventory](2026-11-02-kurumi-component-inventory.md) records the declaration families. The Kurumi public API is declared in `packages/kurumi/lib/kurumi.dart`. It already includes responsive/anchored menus, dialogs, sheets, inputs, chips, settings components, focus/accessibility primitives, theme roles, semantic colors, and duration helpers. `lib/dev/kurumi_gallery.dart` exists but needs to be evaluated as a valid reference gallery. These observations are grounded in source files and tree shape; they do **not** establish exact counts of call sites across the whole app.

## Evidence map: good reuse

| Pattern | Source evidence | Assessment |
| --- | --- | --- |
| App-specific empty state | `lib/core/widgets/no_data_box.dart` delegates to `KurumiNoDataBox` and provides a localized message and animation | Good separation of presentation and app assets |
| Searchable options | `lib/core/widgets/option_searchable_sheet.dart` delegates to `KurumiOptionSearchableSheet` while supplying localized hint, list filtering and navigation | Good reuse; surrounding `ListTile` is not automatically inconsistent |
| Responsive action overflow | `lib/core/widgets/adaptive_button_row.dart` delegates menu/scroll/wrap to `KurumiAdaptiveButtonRow` | Shared responsive primitive with useful app-specific option types |
| Settings controls | `lib/core/settings/src/pages/accessibility_page.dart` uses `KurumiSwitchListTile` and `KurumiSettingsTile` | Direct Kurumi reuse |
| Search tags | `lib/core/search/search/src/widgets/selected_tag_chip.dart` uses `KurumiMaterialChip` | Specialized semantic/tag behavior built on shared visual primitive |
| Post context menus | `lib/core/posts/listing/src/widgets/general_post_context_menu.dart` uses `KurumiContextMenu`, its tiles and dividers | Shared menu family in domain-specific actions |
| Download actions | `lib/core/download_manager/src/pages/download_manager_page.dart` uses `KurumiPopupMenuButton` and `KurumiPopupMenuItem` | Reference for inspecting other action menus |
| Settings layout | `lib/core/settings/src/pages/data_and_storage_page.dart` uses `KurumiSettingsCard` containing `ListTile` and `FilledButton` | Mixed construction can be intentional: visual parent is Kurumi, content is native Material |

## Evidence map: findings and review candidates

| Confidence | Finding | Evidence and implication | Recommendation |
| --- | --- | --- | --- |
| Confirmed source divergence; rendered impact **unverified** | Following Topics uses native Material popups while Download Manager uses Kurumi popups | `lib/core/search/following_topics/src/pages/following_topics_page.dart:339–409` uses `PopupMenuButton`/`PopupMenuItem`; Download Manager at `lib/core/download_manager/src/pages/download_manager_page.dart:142–153` uses Kurumi family | Compare both on-device for anchoring, density, focus, item sizing, keyboard and touch; migrate only if behavioral equivalence is established |
| Confirmed source divergence; visual impact **unverified** | Following Topics has three `AlertDialog` constructors and a direct `TextField` | `following_topics_page.dart:625–638`, `1366–1385`, `1669–1715`; Kurumi equivalents exist (`packages/kurumi/lib/src/components/dialog.dart`, `text_field.dart`) | Audit dialog layout and IME behavior, then define when native dialog/input is a justified exception |
| Confirmed design-literal usage; design decision **open** | Shared Kurumi components contain hard-coded dimensions | `packages/kurumi/lib/src/components/settings_card.dart` uses a 12px radius and margins; `button.dart` uses an 8px dense radius; `option_searchable_sheet.dart` has fixed padding, font size, and border radius | Inventory literal patterns, derive a small approved scale from actual screenshots, coordinate radii with #105; do not globally replace numbers blindly |
| Confirmed gallery limitation | "Existing" and "Kurumi" paths render the same controls for multiple items | `lib/dev/kurumi_gallery.dart`: both branches use the same `KurumiButton`, chip, settings card, text field, etc. | Replace misleading comparison with a component/state/reference gallery (or real legacy comparisons where needed), not a fake before/after presentation |
| Confirmed architecture | Kurumi remains bridged to Material themes | `packages/kurumi/lib/src/kurumi.dart`, `theme/material_theme.dart`, `theme/semantic_tokens.dart`, `lib/core/themes/theme/src/theme_buider.dart` | Use semantic colors and existing runtime theme as source; avoid fixed per-screen palettes in Penpot |
| Confirmed prior solution | Adaptive app-bar titles already exist | `packages/kurumi/lib/src/components/app_bar.dart` wraps bounded text using `KurumiFittedText`; related issue #130 was closed | Use established pattern, do not reopen #130 or add custom text fit wrappers |

These candidates are **not confirmed visual defects**. A native widget inside Kurumi may be the correct compositional choice. In particular, replacing `AlertDialog`, popup anchors, or text editors can alter navigation, focus, keyboard, or accessibility; assess those differences first.

## Design decisions recommended for approval

1. **Kurumi-first, not Kurumi-only:** public Kurumi controls are preferred for shared visuals, with explicit functional exceptions. Domain-specific widgets stay app-specific.
2. **Semantic token vocabulary, no immediate mass migration:** keep current theme and color scheme behavior; standardize spacing/radii only after approved examples and issue #105.
3. **Penpot represents approved canonical states, not every rendering combination:** see [Penpot strategy](2026-11-02-penpot-design-strategy.md).
4. **Agent enforcement is review-based:** code/test checks plus screenshot comparisons. Do not make an unconnected Penpot file a hard CI dependency or require pixel-perfect parity for all profiles/locales.

## Screenshot and UX verification matrix

Capture **current fork** screens on an Android emulator (according to `docs/android_emulator.md`) and desktop or a wide viewport where meaningful. Public upstream marketplace screenshots are not acceptable evidence of the current fork. Use known safe test content; do not publish credentials, private posts, or account metadata.

| Canonical screen/flow | Minimum states to capture | Additional checks |
| --- | --- | --- |
| Home and navigation | Default, sidebar open, destination selected | Narrow vs wide, selected/focus state |
| Search landing/editor | Empty, tags/options expanded, suggestions, keyboard | Site capabilities, long tags |
| Search results / post grid | Loaded, no results, selection mode, context menu | Grid density, action overflow |
| Post viewer/details | Loaded, toolbar overlay, information sheet, media error | Portrait/landscape, gesture vs controls |
| Bookmarks / groups | Overview, nested group, selected items, move/create sheet | Count, sorting, destructive action |
| Following Topics / feeds | Overview, selection, menu, edit/create, partial/error state | Compare popup and dialog families |
| Settings | Root, Appearance, Accessibility, Data and Storage | Density, section cards, long labels |
| Profiles / configuration | Profile chooser, edit field, theme options | Dynamic/AMOLED/profile colors |
| Download Manager | Active, empty, failure and popup actions | Compare popup consistency |
| Artists and engine-specific details | Artist overview, follow action, tags/details | Avoid erasing engine-specific semantics |

Base captures: representative phone dark+light; desktop/wide for relevant screens. Targeted captures: enlarged text, narrow width, keyboard shown, focus/hover, empty/loading/error. Record device dimensions, text scale, theme, platform, profile/engine, source commit, and screenshot filename. Compare tasks and interactions, not only surface colors.

## Reproducible next source pass

Use `python3 scripts/audit_ui_components.py` from a current local checkout. It enumerates Kurumi definitions and constructor/helper calls, Material call-site candidates, screen areas, hard-coded design-literal candidates, and exact file/line locations. Its reports are under ignored `.worktrees/_artifacts/ui-component-audit/`. Inspect the generated JSON and top sources; do not treat counts as proof of bad usage. This file is an initial confirmed sample; do not substitute its limited counts for the generated full-tree results.

## Verification already performed and limitations

- The `develop` tree and selected source files were inspected through the connected GitHub repository.
- There was no local full checkout in the execution environment; an attempted `git ls-remote` failed due to unavailable GitHub DNS/network from the container.
- The static audit tool was unit-tested against synthetic fixtures, **not** executed against the complete Boorusama tree.
- No actual fork screenshots or running Flutter emulator were available. No UX findings were reproduced on a device.
- No Flutter code or runtime behavior was changed; no full regression suite was run.
- The documents and scanner are prepared artifacts, **not committed to the repository** or an approved Penpot workspace. This distinction must be retained in handoff and issue status.
