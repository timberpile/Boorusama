# Kurumi UI design system: source and interaction audit

Date: 2026-11-02
Tracking issue: [#136 — Establish Kurumi UI Design System](https://github.com/timberpile/Boorusama/issues/136)
Reviewed source: issue branch at `fc601be07b2859eceb8297d10348c68d9611860c`, based on `origin/develop` at `74cdf43a5bd5205baa8f7cefb164986fe2656dd1` (0 behind / 1 ahead at fetch). Runtime files are unchanged from that develop base.
Evidence level: **local full-tree lexical scan and verified source samples**; screenshot/interaction coverage is recorded below. Proposed baseline; owner acceptance remains pending.

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

## Captured fork evidence and independent review

The audit APK was built with `fvm flutter build apk --debug --flavor dev --no-pub`
from `fc601be07b2859eceb8297d10348c68d9611860c`, after documented FVM/CLI setup
and generation of missing ignored outputs. `git diff HEAD -- lib packages android
pubspec.yaml pubspec.lock` was empty. APK SHA-256:
`56e6955a78a75994b3aa184bd70fccdfcb6a04d2d6fe5d6ab168bbb877b0bf6e`.

Maestro controlled a leased Android 17 emulator. Phone captures use 720×1600
physical pixels / 320 dpi, or 360×800 logical pixels, system font scale 1.0 unless
noted. The active engine was Safebooru using the Danbooru API, with no account
credentials visible in the selected evidence. The app displayed its existing
black default appearance; Appearance reported Colors = Default. The preview
selected Midnight, but the persisted global/profile scheme was not independently
extracted, so these images do not certify every built-in/dynamic/profile mode.

Thirty local captures cover navigation, search with keyboard and no results,
post grid, viewer and details, bookmark groups/default group, Following Topics,
settings/Appearance/Accessibility/storage, public profiles, theme previews and
the Danbooru artists list with an expanded artist. All 30 captures and their [manifest](136-evidence/manifest.json) are retained
unchanged in the repository and imported into the Penpot evidence page; the
manifest records their design IDs. Build
logs and APK restoration evidence remain in durable ignored task artifacts. The
selected screenshots below show the most relevant findings.

| Evidence | State / observation | Limit |
| --- | --- | --- |
| [01](136-evidence/01-following.png) | Following empty state and primary action | No topic mutation performed |
| [02](136-evidence/02-following-sort.png) / [06](136-evidence/06-downloads-menu.png) | Material sort popup highlights the current row; Kurumi action popup is denser and dims the background differently. Both stayed inside the viewport and Back dismissed them. | Different task semantics; desktop focus/keyboard traversal not exercised |
| [03](136-evidence/03-following-editor-keyboard.png) | **Device-confirmed:** Follow Topic's selected profile overflows right by 14 pixels with the keyboard open at scale 1.0. Query and actions remain visible. | Fix not implemented |
| [21](136-evidence/21-following-editor-text2.png) | Same dialog at system font scale 2.0: overflow banner reports 106 pixels. | Font scaling is platform-dependent; this is Android's actual scaled rendering |
| [23](136-evidence/23-following-editor-wide.png) | 1600×1000 physical / 800×500 logical, scale 1.0: title/actions remain visible but form content is not visible above the IME. | Short-height screenshot concern; all possible scroll/assistive paths were not established |
| [07](136-evidence/07-settings.png) | Existing compact settings navigation | Reference, not a new target design |

**First remediation proposal:** constrain the selected profile slot before changing
control families. `_FollowTopicQueryDialog` uses `DropdownButtonFormField` without
`isExpanded` at `following_topics_page.dart:1686`. Its selected
`FollowingTopicProfileOption` already contains flexible, ellipsizing text
(`following_topic_profile_caption.dart:32–52`), but Material's dropdown only
expands that slot when `isExpanded` is enabled. `isExpanded: true` is the smallest
source-supported hypothesis, not a verified fix. Verify with long names,
360px width, enlarged text and the keyboard; separately ensure short-height form
content remains reachable. Keep profile selection, cancellation and submission
semantics unchanged. Effort: small for width; medium if the short-height form
needs a layout change. Risk: dropdown/dialog sizing and keyboard navigation.

An independent Luna Max reviewer performed the source inventory, screenshot
review and counter-review described by the expert prompt. The primary agent
rechecked the findings against screenshots/source. This caught and removed an
incorrect checkmark claim: Material `initialValue` highlights the current row;
`PopupMenuActionLabel` only supplies icon/text. The final review preserves the
profile overflow, preset-contrast concern and gallery truthfulness finding, and
rejects blanket Material migration. No extra follow-up issue was created.

Coverage limits: the initial bookmark capture was a spinner; later captures
show the loaded All/Default groups and the Default group. Grid thumbnails are
visible, but the viewer capture contains a media placeholder; opening the route
and details does not prove decoded full-resolution media. Light/dark images are
**theme-preview states**, not applied global themes. No profile credentials form,
TalkBack session, desktop mouse/hover/focus pass, live mutations, performance
benchmark, or exhaustive loading/error/selection matrix was completed. Nothing
here implies those checks passed.

## Completed local source pass

`python3 scripts/audit_ui_components.py --output-dir ../_artifacts/136-kurumi-ui-design-system/audit`
ran on the local checkout, with no Dart runtime edits. The scanner reports HEAD
`fc601be0` and a dirty repository because the audit/tooling was being revised.
Its generated JSON/Markdown and validation logs are durable ignored artifacts.

| Measure | Final lexical result | Meaning |
| --- | ---: | --- |
| Included app/package Dart files | 3,382 | Generated suffixes and `generated/` trees excluded |
| Kurumi package declarations | 148 | Named declarations, including aliases/support types; not widgets |
| App Kurumi constructor/helper candidates | 1,569 | Direct `lib/` source matches; not instances or indirect consumers |
| App Material constructor candidates | 967 | Selected symbol families; not violations |
| Menu/dialog/input review candidates | 124 in 46 files | Human triage only |
| Kurumi literal candidates | 156 | Includes padding expressions; not all numeric constants |
| Read errors | 0 | All included files read successfully |

The initial scanner missed named constructors. Verified examples include
`FilledButton.icon` and `Dialog.fullscreen`, plus
`KurumiAdaptiveButtonRow.menu/scrollable/wrap` and `KurumiDismissible.route`.
Focused allowlists now recover 38 Material and 7 Kurumi app call sites while
excluding helpers such as `FilledButton.styleFrom` and `Scaffold.maybeOf`.
Generated `booru_clients/lib/src/generated/` files exposed another omission and
are now excluded, with a fixture covering that directory form.

Limitations remain explicit: this is lexical, not import/AST resolution. It masks
string interpolation, misses unlisted named constructors, tear-offs and indirect
composition, and may count constructor declarations in raw package usage
records. App totals filter to `lib/`. The component consumer matrix manually
traces wrappers and engine extension points which direct-call counts cannot show.
Do not compare old/new totals without using the same scanner, generated exclusions,
source revision and input state.

## Prioritized source proposals

| Priority / evidence | User impact and minimum change | Effort / risk | Validation before implementation |
| --- | --- | --- | --- |
| After responsive remediation: gallery truthfulness, source-confirmed | Replace the false Existing/Kurumi comparison with actual component states, using existing APIs. Keep it a dev reference; no app redesign. | Small / low; separate runtime scope | Component smoke test and a reviewed render; enabled/disabled/selected/focus cases must actually differ |
| Investigate: primary text contrast, source-calculated | Built-in light primary/onPrimary `#7289DA`/`#FFFFFF` gives 3.33:1; dark/AMOLED `#5663E9`/`#DCDCDC` gives 3.51:1. Validate enabled small button labels before accepting these palettes as the visual baseline. | Small investigation; palette adjustment has broad visual risk | Resolve actual widget state/theme, compare screenshots, then approve color changes separately |
| Conditional: menu consistency, source-confirmed alternatives | Preserve sort selection/highlighting and action semantics. Native sort menu and Kurumi action menu have different APIs; no mechanical replacement. | Medium / medium; focus/navigation/selection | Side-by-side rendered menus, selected/disabled state, keyboard/focus return and outside/Back dismissal |
| Conditional: token extraction, source-confirmed literals | Repeated 8px control radii, 12px settings card radius and 8/12/16/20px paddings describe current roles, not a new universal scale. Coordinate radius decisions with #105. | Medium / broad regression risk | Agreed representative components across width/text scale/theme; avoid changing density by averaging constants |

Contrast ratios above are calculated from explicit source sRGB values using
relative luminance and `(lighter + .05) / (darker + .05)`. They are not sampled
anti-aliased pixels or a whole-app accessibility certification. [W3C's contrast
minimum guidance](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html)
uses 4.5:1 for ordinary text and 3:1 for large text, with inactive controls
excepted. Dynamic/profile palettes and widget state overrides need separate
assessment. Dark error-as-text on the dark page also deserves review (2.42:1),
while the error/onError pair is 5.34:1; pairing a role with the wrong surface is
not equivalent to using its paired content role.

## Verification and acceptance boundary

Tooling tests and the full local scan establish source inventory confidence.
Application code, persistence, navigation and visual behavior remain unchanged.
All 76 repository Python tooling tests passed, including the four expanded
audit fixtures; Python compilation, documentation/source/image links and
`git diff --check` passed. Full Flutter regression is not required for this documentation/scanner-only
local milestone and was not run. Integration still requires the final combined
candidate's complete local suite under AGENTS.md.

The style guide and Penpot remain proposed until owner review. Uncaptured device,
wide/desktop, screen-reader, live-service and theme states remain unverified;
no source-only observation above is promoted to a reproduced visual bug.
