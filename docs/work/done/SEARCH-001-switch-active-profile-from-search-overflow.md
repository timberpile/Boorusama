# Switch the active profile from search overflow

Priority: Normal  
Affected feature: Normal post search, selected-tag controls, and global profile selection  
Status: Completed  
Agent: Codex / SEARCH-001  
Branch: `agent/search-001`  
Worktree: `.worktrees/search-001`

## Problem

Switching booru profiles while composing or viewing search results currently requires leaving the search context and using the main navigation. A separate permanent profile selector would consume unnecessary UI space.

## Expected behavior and acceptance criteria

- [x] Add a `Switch Profile` action to the existing selected-tag overflow menu beside `Remove all selected tags` and `Bulk Download`. It opens a nested menu listing configured profiles; the globally active profile has a checkmark.
- [x] Show a distinguishable label for profiles with duplicate or empty display names (for example, include the site URL). A single configured profile remains clearly marked.
- [x] Choosing another profile updates the **global active profile** through the existing configuration state, rather than introducing a search-only profile setting.
- [x] Stay on the Search screen, retain the raw search text and selected tag/query terms, then reload suggestions/results with the new profile's repositories and engine configuration. Old-profile results must not remain mislabeled or appear as new-profile results.
- [x] Preserve the user's search intent across different supported booru engines without silently dropping terms; safely reinitialize any engine-specific controller/parser/provider state needed after the switch.
- [x] Selecting the already active profile causes no unnecessary navigation or request. The menu introduces no new persistent toolbar row, chip row, or separate selector.
- [x] Focused widget tests cover checked state, duplicate names, switching while results are shown, retention of typed terms, global profile update, different engines, and unchanged no-switch behavior. Validate menu placement at narrow width and enlarged text.

## Context and implementation note

The proposed overflow is `SelectedTagList` / `SelectedTagListWithData`, which currently renders only while selected tags exist. Use that existing surface as requested; do not add an extra row to support an empty query. Existing profile switching remains available through main navigation when the selected-tag overflow is absent. Preserve the current layout rather than creating a new permanently visible action.

Normal search is dispatched through an engine-specific `SearchPage` builder. `SearchPageScaffold` owns tag/search controllers, some constructed using the active config; a global profile change must not accidentally reuse a stale extractor. `PinnedSearchesPage._open()` already demonstrates updating `currentBooruConfigProvider` before navigation; reuse the profile state semantics, not pinned-search navigation.

- [Selected-tag menu](../../../lib/core/search/search/src/widgets/selected_tag_list.dart)
- [Selected-tag wiring](../../../lib/core/search/search/src/widgets/selected_tag_list_with_data.dart)
- [Search page dispatcher](../../../lib/core/search/search/src/pages/search_page.dart)
- [Search scaffold/controller lifecycle](../../../lib/core/search/search/src/widgets/search_page_scaffold.dart)
- [Global profile switch reference](../../../lib/core/search/subscriptions/src/pages/pinned_searches_page.dart)

Dependencies: None.

## Decision

2026-10-08: Use the global-profile behavior (not a separate search-only profile), nested checked submenu, no additional search UI height, and preserve the search when switching.

## Implementation and verification

- Added a nested Kurumi profile menu to the existing selected-tag overflow. It checks the global profile and disambiguates duplicate/empty names with URLs (and a list position when both name and URL match). No additional search row is introduced.
- Switching updates `currentBooruConfigProvider`, follows that global profile within the current route, and replaces the engine subtree. Search snapshots retain exact text/selection, raw query groups, typed terms, and search state; typed terms are reparsed with the destination extractor. Results restart with a fresh controller, and shared fallback suggestions are cleared. Initial route profile scoping remains intact until an explicit switch.
- Four focused widget tests passed: same-engine and cross-engine switching from results; global state and query retention; new parser/suggestion context; checked single profile and no-op requests; unchanged clear/download actions; nested menu at 320 px, 2x text, and keyboard insets.
- Final handoff is gated on the complete local suite from `docs/engineering_guidelines.md`: application, every package with tests (including CLI), both shell tooling suites, and Python tooling tests. Final results are reported with the committed change.
- Device/live-site validation was not performed; the affected interactions are covered with widget tests and controlled repositories. No deployment, integration, or publication is included.
