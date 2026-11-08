# Plan 03: restore picker fidelity and make diagnostics useful

Read the [lead handoff](../../handoffs/final-rollout-remediation-2026-11-08.md). Scope: the #156/#158 Bookmark regression and diagnostic consumers. The user's first supplied screenshot is the desired old visual design; the second is the rejected current design. No new visual redesign is authorized.

## A. Restore the Bookmark picker

### Established causes and uncertain parts

At the audited combined head:

- `bookmark_folder_picker_contents.dart` gives the create-group item `title: ''` inside a fixed 64dp box. The missing Group label is explicit, not a font/localization issue.
- `BookmarkPickerSplitRow` reserves 80dp of text width, adds a visible directional start border, and forces a 48dp minimum; `BookmarkPickerMenuItem` also imposes 48dp.
- `KurumiPopupMenuItem` additionally owns its internal padding. The older implementation relied on its natural content height instead of these Bookmark-specific minimums.
- Recent still exists in `bookmark_group_picker.dart` and `recent_bookmark_groups_provider.dart`. Its absence in the screenshot is a reported regression, but whether it is caused by data migration, interaction recording, provider invalidation or constrained layout is not established. Do not claim that the feature was deleted from source.

Use these files:

- `lib/core/bookmarks/src/widgets/bookmark_folder_picker_contents.dart`
- `bookmark_group_picker.dart`, `bookmark_batch_dialog.dart`, `bookmark_group_destination_picker.dart`, and all context-menu callers.
- `lib/core/bookmarks/src/providers/recent_bookmark_groups_provider.dart` and the manual-interaction recording path.
- `lib/core/bookmarks/src/data/hive/unified_bookmark_group_repository.dart`, the delegated legacy reader and organization migration.
- `packages/kurumi/lib/src/components/popup_menu.dart`, dialog and anchor primitives.

The old visual source reference is the same picker path at `develop` commit `266a14c0f87f29213d48696bda7c806dc1d05b6e`. Use it for visual metrics, not for restoring the retired folder persistence model or old interaction ownership.

### Exact visual and interaction contract

1. Restore the old typography, leading-icon size/baseline, compact vertical rhythm, surface styling, outer/inset spacing and Recent section. The user's 'about half' request concerns the excessive empty spacing in the new screenshot, not a mandate to halve font size or create unusable 24dp rows. Compare both at the same logical width, font scale and pixel density. Remove stacked padding/min-height inflation rather than multiplying screenshot pixels into dp.
2. Restore the localized `+ Group` label using the existing translation and normal compact header item. The create action must not become an icon-only control on ordinary phone widths. In subgroups retain the left Back/path and right create action without clipping; at Home do not restore a visible Back-to-close row. System Back still closes at Home.
3. Parent rows use the old folder-like navigation visual; leaf rows use the established Bookmark visual. Preserve direct membership indication on both. This does not reintroduce a separate Folder model. Retain source group order unless an existing approved ordering contract requires otherwise.
4. Chevrons are at the far trailing edge with the old small edge inset. Remove all vertical borders/separators before chevrons. A long Group title can use the width up to a small gap before the glyph, rather than stopping 80dp early.
5. The trailing navigation touch region is approximately 20% of the full row width and spans its height. The leading approximately 80% selects/toggles direct membership. Visual text width and navigation hit width are independent. Implement an ordinary painted full-width row plus two well-defined hit/semantic regions, or equivalent existing Kurumi composition; do not reserve the entire trailing hit area as blank text padding.
6. Tapping anywhere in the trailing parent region navigates exactly once and never changes membership. Tapping the leading region selects once and never navigates. Expose both actions independently to keyboard/screen reader. Keep directional layout correct in RTL. Leaves have one full-row selection target and no chevron; no self-only child screen or repeated 'Save here' row.
7. Restore Recent as a recognizable titled section with compact rows and inline ancestor context, as in the old reference. Successful manual selections/creation must record it; cancelled/failed actions and background sync must not manufacture recency. Preserve valid existing recency data through migration. Deleted groups disappear; renamed/moved groups retain their IDs and updated labels. The section must remain reachable alongside the main list on small screens, including after reopening and restart.
8. Apply the shared result to normal anchored Bookmark context, modal picker, saved Group/Page targets, batch Add/Remove, and destination consumers. Keep caller semantics distinct: an add-only batch operation must not turn into a toggle; moving groups still prevents cycles. Do not globally restyle all application popup rows to fix one picker.
9. Keep the wider phone surface already requested, with small screen gutters and a reasonable large-screen cap. Do not return to the old 80%-screen dialog-width limitation. Preserve accessibility growth at large text scale rather than squeezing labels to a fixed small height.

### Verification

First seed real Recent interactions and inspect storage IDs/provider output before changing layout. Distinguish genuinely empty recency from a footer clipped by the navigation/list flex constraints. Test failed writes and loading states explicitly.

Create deterministic visual/geometry comparisons with neutral fixture names, emoji, short/long labels, parent and leaf rows, membership states and Recent. Compare the old and corrected designs at identical dimensions. Do not commit the user's image backgrounds/private library data.

Pointer-test left, right, split boundary and far-right edge; require exactly one appropriate callback. Verify label width reaches near the glyph while trailing touches still navigate. Verify no vertical divider exists and '+ Group' is visible. Test 320dp, ordinary width, short height, keyboard and 2x text, modal and anchored presenters, Back/Escape and naming-dialog ownership. Screenshots from the ordinary app are part of final QA, not only a widget preview.

## B. Debug Logs: newest first

`lib/core/debug/src/pages/debug_logs_page.dart` currently displays `logs[index]` in capture order, filters by returning empty widgets, and offers Scroll to Bottom. Change the viewing projection, not the underlying append/eviction algorithm just to reverse the screen.

1. Show newest entries at the top by default. Use stable arrival order for equal timestamps. Do not combine reversing the data and `reverse: true` in a way that cancels the intended order or anchors the newest item at the bottom.
2. Filter the projected rows before supplying `itemCount`; do not build thousands of empty placeholders for another category. Keep category controls, selection/copy and redaction working.
3. Replace the bottom-jump behavior with an appropriate 'latest/top' action. New entries may update the top while a reader at the top follows naturally; do not continually yank a reader away from older expanded content. Preserve stable row identity/scroll anchoring.
4. Define export/copy ordering explicitly. Existing chronological file ordering may remain for compatibility, but the UI must be newest-first and the choice must be documented/tested. Do not reverse the logger's live buffer in place.

Tests: initial/new entries, equal timestamps, category changes, empty categories, bounded buffer eviction, expanded older entry, top navigation, copy/export and redaction. Keep large log lists lazy.

## C. Add actionable redacted diagnostics

Reuse `Logger.handledError`, the existing debug categories, formatter and redaction pipeline. No new logging subsystem.

For Pixiv images and source access, include safe failure codes, stage (resolution/cache/request/decode), engine and destination host, rendition kind, HTTP status when available, logical request correlation and required-header presence flags. Distinguish expected cancellation from a failed media request. Do not log header values, full signed/query URLs, tokens, cookies, imported payloads or personal tag lists.

For Favorites Sync, report whether stable actor identity, target revision, disk write or remote dispatch failed. For import, report counts and timing/memory spans around preparation, dependency projection, per-source preview, acknowledgement, UI publication and apply. For covers, distinguish unused slots, missing descriptors, visibility filtering, cache miss and actual download failure.

Coalesce repeated identical failures per operation/source so one broken timeline does not flood the console and add more jank. A debug toggle may enable extra detail, but ordinary caught failures need enough evidence to diagnose a Retry-only screen. Verify that normal secrets-redaction still applies to these new fields.
