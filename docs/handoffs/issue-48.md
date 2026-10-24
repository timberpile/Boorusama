# Issue #48 — Local acceptance handoff

Branch: `feature/48-tag-category-colors`  
Base: `565a504cf714fa9de19053b22f5f761561a35f54`  
Issue: https://github.com/timberpile/Boorusama/issues/48

## Implementation

Selected search chips now receive the actual search profile from `SelectedTagListWithData`. A small category-aware wrapper around the unchanged interactive `SelectedTagChip` uses the item's supplied category first, otherwise the existing **local-only** `booruTagTypeProvider` cache. It resolves the color through the same `tagColorProvider` and engine generator as ordinary autocomplete. Raw syntax and metatag values do not trigger tag-category lookup. The neutral chip foreground, operator/metatag styling, edit/remove callbacks, context menus, and query execution remain intact. Callers without an explicit profile stay neutral rather than borrowing the active browse profile; bookmark chips retain their explicit origin-aware color.

The default generator now returns no color for absent/unrecognized metadata instead of guessing General, while preserving known numeric/name mappings. Renaming a selected tag drops stale autocomplete category metadata; changing only its operator retains it.

Bookmark autocomplete and selected chips already share `bookmarkTagColorProvider`. That provider now uses each originating engine's palette, custom tag colors, and the same dynamic-color transform as regular search. Stored canonical categories and cached engine codes both use that palette. Existing path-isolated cache lookup, ambiguous-color neutral fallback, and no-network behavior are preserved.

## Surface audit

- Ordinary autocomplete: `DefaultTagSuggestionItem` already uses `tagColorProvider`; receives the shared unknown-category fix.
- Selected search chips: newly wired explicit profile + cached metadata.
- Bookmark autocomplete and selected chips: existing shared provider upgraded, no browse-profile fallback introduced.
- Post-detail `TagChip` / `AutoCategoryTagChip`: already use the same category/color providers and local cache; existing light/dark chip treatment retained.
- `BookmarkTagTiles`: already resolves the post's origin profile before rendering the shared detail tag UI; no new remote tag requests introduced for color.

## Tests and current limits

Added `test/core/tags/tag_category_color_consistency_test.dart` for numeric/semantic mappings in both brightness modes, unknown fallback, stale category invalidation, origin palettes, and no-cache access when snapshot metadata exists. Existing bookmark tag-index tests cover source isolation, conflicts, and cache failure.

**Dart formatting, Flutter analysis/tests, and device checks have not run.** No FVM/Flutter SDK or clone-capable network is available in this remote environment. This is not accepted or integration-ready.

## Required local acceptance

1. Fetch into a separate worktree; follow `AGENTS.md` and bootstrap normally. Format changed files and analyze affected tags/search/bookmark scope.
2. Run related suites under `test/core/tags`, `test/core/search`, and `test/core/bookmarks` with the physical-core concurrency helper. Add rendered category-aware chip/provider tests using existing profile fixtures, including a missing/failing cache, metatags/raw queries, and profile switching.
3. Check whether any engine-specific generator still guesses General for an unknown sentinel; make unsupported categories neutral there without discarding genuine site-specific codes. Preserve existing site-specific palettes and run their tests.
4. Verify light/dark/custom/dynamic themes across suggestions, selected chips, detail tags, and mixed-origin bookmarks. Check Artist, Character, Copyright, General, Meta, unknown and conflicting categories. Confirm changing the active browse profile does not recolor a mixed bookmark collection incorrectly and no network requests occur solely for colors.
5. Exercise edit/remove/operator controls at narrow width, enlarged text, and with keyboard open. Ordinary selected-list height/scaling policy was not redesigned; fix any demonstrated clipping locally without changing search behavior. Follow the emulator lease before device use.
6. Review the full diff, fix small defects on this branch, and record exact commands/results, checked commit, skips, and remaining limitations. Run `./scripts/run_regression_tests.sh` on the final integration candidate because shared color/query metadata is affected.

## Coordination

The branch is independent; #51 can reuse the existing color providers without stacking on it. `feature/71-search-options` changes nearby selected-tag UI: reconcile that work with this profile-aware wrapper during any separately approved integration. No merge, PR, issue closure, or deletion is authorized. Include `#48` in the eventual approved integration commit subject and keep `Refs #48` until acceptance passes.

## Local acceptance evidence (2026-10-22)

This section supersedes the earlier unrun-verification status. Checked runtime/test commit: `fea07af2a2f60c54b871c47abd7a336554852895` (the complete pass covered the same runtime/test tree before its commit).

- Formatted changed Dart files and passed `git diff --check`. Fresh-worktree dependencies and missing generated files were initialized through FVM and `./gen.sh`; generated output remains ignored.
- The first affected-directory run exposed errors in the newly added acceptance fixtures, subsequently corrected (valid profile IDs and the correct Material host). The corrected selected-chip fixture file passes **7 tests**.
- `./scripts/run_regression_tests.sh`: **passed**, including **4,471 application tests**, all **13 package/CLI suites**, both shell tooling suites, and **72 Python tooling tests**. The existing go_router skips remain: `routing config works with shell route` and `Obsolete branches in StatefulShellRoute are cleaned up after route configuration change`.
- `fvm dart analyze lib/core/bookmarks/src/providers/suggestion_provider.dart lib/boorus/e621/tags/color.dart lib/boorus/zerochan/tags/color.dart lib/boorus/philomena/tags/color.dart test/core/tags/selected_tag_category_widget_test.dart`: no errors or warnings; informational lints only.
- Fixed unknown-category fallbacks in Zerochan, Philomena, and e621 color generators while retaining their explicitly supported categories/palettes. Added rendered profile-switch/cache-failure/raw/metatag and callback checks, plus site-specific category regressions. No network color lookup was introduced.

Flutter 3.47.2 / Dart 3.13.2 and six detected physical-core workers were used. Commands used an isolated copy of the same SDK to avoid an unrelated startup lock.

**Acceptance remains pending the live visual theme/surface matrix** (light/dark/custom/dynamic, mixed-origin bookmarks, edit/remove/operator controls, keyboard). The leased emulator failed its health check and was released; later it was leased to another task. Automated rendering/provider coverage is not a device result. No merge, push, PR, closure, branch deletion, or combined-develop candidate verification occurred.

## Final candidate follow-up (2026-10-23)

Final runtime/test candidate: `765c1cc43c90281968ed2f4833991db404785266`. The earlier full pass above predates two additional device-discovered corrections; this section records verification of the final candidate.

- A real cold-cache suggestion selection dropped its supplied category on both mobile and desktop, leaving selected chips neutral. Preserved the supplied category through those actual selection paths. Two application regressions reproduced the null-category failure before the fix.
- Category metadata also changed search-item equality, allowing duplicate query terms. Kept presentation metadata out of query identity and enriched an existing term in place while preserving order and known metadata. Three new regressions failed before this correction. Direct identity, mobile/desktop application, category and profile-switch consumers then passed **66 tests** together.
- `fvm flutter test --no-pub --reporter=expanded --concurrency=6 test/search_tag_set_test.dart test/search/tag_search_item_test.dart test/application/search_suggestion_category_flow_test.dart test/core/tags test/core/search/search_profile_switch_test.dart test/core/search/navigation_search_profile_test.dart`: **66 passed**.
- Final affected Flutter/Dart analyses passed without errors or warnings, with one informational lint in each invocation (`curly_braces_in_flow_control_structures` in the application fixture and `prefer_foreach` in the tag-set loop).
- `./scripts/run_regression_tests.sh`: **passed, exit 0** on the final candidate. **4476 application tests**, all **13 package/CLI suites**, both shell tooling suites and **72 Python tooling tests** passed. Kurumi: **133 passed**. The same two existing go_router skips listed above remain. Log: `/tmp/boorusama-acceptance/48-final-full-rerun.log`.
- `fvm flutter build apk --debug --flavor dev --target-platform android-x64 --no-pub`: **passed** on the final candidate. Installed with `adb -s emulator-5554 install -r` under the exclusive lease, preserving data. Final APK SHA-256: `9b6a5cedde1cbaf3674a73bec94eb6b3c5b817afb13a59e1aa64eea8a17a87dc`.
- Maestro verified the selected `hatsune_miku` Character chip is now green after choosing the live suggestion. At 360 dp width and 2x system text, opened its editor with keyboard, changed only the operator to `-hatsune_miku`, confirmed the Character color stayed green with separate operator styling, and removed the chip. Screenshots: `/tmp/boorusama-acceptance/48-{final-selected-character-dark,edit-keyboard-2x,operator-category-2x}.png`.

The live pass covers this dark-theme selection/edit/remove path. The light/custom/dynamic and mixed-origin bookmark/detail surface matrix still has automated/provider evidence rather than a complete Android matrix. No device request-count trace was captured for color-only work. No merge, push, PR, issue closure, branch deletion or combined-develop qualification occurred.

After all nine candidates' device work, normal text (1.0), portrait and the original 720×1600 / 320 dpi physical viewport were restored. Temporary acceptance profiles and Topics were removed; the original three profiles and empty Topic overview were verified. The exact emulator lease was released. No phone operation occurred.

## Selected-chip background consistency follow-up (2026-10-23)

Acceptance found that selected Search tags retained the blue secondary-container background even when their text had the correct category color. Confirmed the cause in SelectedTagChip: its background was hardcoded independently of tagColor. Four rendered theme/palette regressions failed before the fix.

Colored selected chips now resolve the same booruChipColorsProvider palette as ordinary detail tags, applying its foreground, background and border together. This preserves custom/dynamic color handling and also fixes the shared selected chip in Bookmark search, which already supplies its origin-aware category color. The remove icon uses the category foreground to remain readable on colored backgrounds. Unknown/raw/metatag chips use a neutral surface background; their existing operator/metatag accents and editing/removal behavior remain. No category lookup, query identity or network behavior changed.

Checked runtime/test tree: the local commit containing this section. `fvm flutter test --no-pub --reporter=expanded --concurrency=6 test/core/tags test/search_tag_set_test.dart test/search/tag_search_item_test.dart test/application/search_suggestion_category_flow_test.dart test/core/search/search_profile_switch_test.dart test/core/search/navigation_search_profile_test.dart test/core/bookmarks/bookmark_search_bar_test.dart test/core/bookmarks/bookmark_search_controller_test.dart test/core/bookmarks/bookmark_search_test.dart test/core/bookmarks/bookmark_tag_index_test.dart`: **138 passed**. Rendered assertions cover foreground/background/border/remove-icon contrast, light/dark themes with and without harmonization, neutral syntax, profile switching and cold-cache suggestion selection in the actual mobile/desktop UI paths. Existing narrow/2x/keyboard bookmark and search-profile fixtures pass. Bookmark fixtures now provide their matching chip palette and assert its contrast foreground instead of the old raw category foreground.

Focused analysis of all four changed Dart files with `--no-fatal-infos`: **passed with 7 informational test lints, no warnings/errors**. Formatting and `git diff --check` passed. Dependencies were refreshed with `fvm flutter pub get --offline`; no tracked dependency files changed. Logs: `/tmp/boorusama-48-background-{before,accepted,accepted-analyze}.log`. Flutter 3.47.2 / Dart 3.13.2, six workers.

No new device run or complete regression was performed for this scoped presentation fix. The earlier full-suite/device results describe the older runtime tree and do not qualify this final candidate for integration. Existing live theme/origin acceptance limits remain. Local only; no merge, push, PR, closure or deletion.

## Tag label font-weight follow-up (2026-10-23)

The user cancelled the shared-renderer refactor and requested bold tag names only. All uncommitted renderer replacements and their new/adapted fixtures were reverted to `5ffbd553d` before applying this follow-up. Existing category-color and query-metadata fixes are preserved. The final source diff changes only tag-label font weights: selected Search/Bookmark tags and remaining tag displays use `FontWeight.w600`, matching ordinary post tags. The existing stronger newly-added-tag marker remains `w900`. Components, outlines, padding, sizes, callbacks and metadata resolution retain their preceding implementations.

Checked runtime tree: the local commit containing this section, based on `5ffbd553d`.

- Formatted all 16 changed Dart files; `git diff --check` passed. `fvm dart analyze` on those files: **no issues found**.
- `fvm flutter test --no-pub --reporter=expanded --concurrency=6 test/core/tags test/core/search test/core/bookmarks/bookmark_search_bar_test.dart test/core/posts/listing/post_grid_item_test.dart test/application/search_suggestion_category_flow_test.dart test/application/search_history_flow_test.dart test/application/tag_selection_scope_flow_test.dart`: **691 passed**.
- `fvm flutter test --no-pub --reporter=expanded --concurrency=6 test/application/favorite_tag_flow_test.dart test/core/themes/theme_previewer_test.dart test/core/posts/details_parts test/search/tag_search_item_test.dart test/search_tag_set_test.dart`: **90 passed**. Logs: `/tmp/boorusama-48-bold-{tests,consumers,analysis}.log`.
- `fvm flutter build apk --debug --flavor dev --target-platform android-x64 --no-pub`: **passed**, exit 0. Installed under the exclusive emulator lease with `adb -s emulator-5554 install -r`, preserving data. APK SHA-256: `037ff82adca706e90ba480404d8e942460bf5a1ad9ac44fd3aa9a62683c7f6ae`.
- Maestro selected the live Gelbooru `hatsune_miku` suggestion and confirmed its bold green label with the preceding chip appearance. Screenshot: `/tmp/boorusama-48-bold-selected.png`. Removed the temporary selection and returned to Browse. The original Gelbooru profile, physical viewport and normal text scale were retained/restored, and the exact lease was released. No search was submitted and no profile or Topic was created.

No complete regression is claimed for this typography-only candidate. Runs of the cancelled refactor are not final-candidate evidence. Narrow/enlarged-text and keyboard paths have affected widget-test coverage; this final device spot check covers dark theme at normal scale. The broader live theme/origin matrix remains pending. Local only; no merge, push, PR, issue closure or deletion.

## Eight-branch review: R1/R2 remediation (2026-10-23)

Starting commit: `ff854f2ac63e91dc6d4a67ee0ad676c23e4ef741`. Compared the review's pinned `51de9949f685337c4206c974d40d2c420acdfbd7` with this local head: the subsequent category-background and bold-label fixes remain intact. The final checked runtime/test tree is the local commit containing this section.

- **R1 confirmed and fixed:** the cross-profile snapshot restore retained autocomplete categories from the source. It now reconstructs ordinary terms with the destination extractor and no category hint, preserving raw terms separately. Destination-local cache resolution supplies the new category or a neutral fallback. Same-profile `withQuery`, operator edits, rename invalidation, query identity, in-place metadata enrichment and cold-cache suggestion selection are unchanged. No network category lookup was added.
- Global real-menu regressions now start with a supplied Artist category and cover both same-engine/different-site and cross-engine switches, each with a destination Character cache entry or no entry. They assert the destination lookup key, final color, exact query/raw terms, draft selection, search state and normal request behavior. Destination-local Following navigation also transfers supplied metadata while retaining its Topic/folder and independent global profile.
- **R2 confirmed and fixed:** a valid Philomena `TagDto` with a null/default category is normalized to `general` by its adapter. The Philomena generator also recognizes the legacy cached empty string as its normal category. A missing cache entry, failed cache and unknown value remain neutral; no global unknown-to-General fallback was restored. A complete DTO fixture exercises adapter, actual engine color providers, ordinary autocomplete and selected chips in light/dark themes, including specialized Species and legacy cache behavior. The nullable category is also present in the [primary server model](https://github.com/philomena-dev/philomena/blob/master/lib/philomena/tags/tag.ex).

Verification actually executed:

- Before the fixes, new global-switch assertions observed the retained foreign `artist` hint and DTO assertions observed `''` instead of `general`. An initial destination-local fixture incorrectly added a typed term beside an existing raw query; corrected its setup to preserve the same query as typed plus raw terms. The corrected three files pass **20 tests** after remediation. Logs: `/tmp/boorusama-review-48-{before,after}.log`.
- `fvm flutter test --no-pub --reporter=expanded --concurrency=6 test/search_tag_set_test.dart test/search/tag_search_item_test.dart test/application/search_suggestion_category_flow_test.dart test/core/tags test/core/search/search_profile_switch_test.dart test/core/search/navigation_search_profile_test.dart test/core/bookmarks/bookmark_search_bar_test.dart test/core/bookmarks/bookmark_tag_index_test.dart`: **108 passed** (`/tmp/boorusama-review-48-focused.log`).
- `./scripts/run_regression_tests.sh`: **passed, exit 0**, **4,494 application tests**, all **13 package/CLI suites** (Kurumi **133 passed**), both shell tooling suites and **72 Python tooling tests**. The two existing go_router skips remain as listed above. Log: `/tmp/boorusama-review-48-full.log`. Six detected physical-core workers, Flutter 3.47.2 / Dart 3.13.2; no exclusions, reduced concurrency or timeout changes.
- Formatted the seven affected/new Dart files and passed `git diff --check`. `fvm dart analyze` on those files: **no errors/warnings; 13 informational test diagnostics** (`/tmp/boorusama-review-48-final-analysis.log`). No generated runtime/dependency files changed.

This qualifies the standalone branch tree, not a combined develop candidate. No new #48 APK/device run was performed for R1/R2. Light/dark DTO rendering and existing harmonized-palette, origin-aware bookmark and narrow/keyboard fixtures are automated evidence; the broader live light/custom/dynamic and populated mixed-origin bookmark matrix remains open.

Preservation audit: current develop is `afc04f4933aa0e442b9f80b2662f0fc5ad277379`, newer than the review's `4129eae5...`. Its incremental `_bookmarkTagIndexBuilderProvider`/`BookmarkTagIndexBuilder.update`, viewer-visible retention, obsolete-load guard and direct membership/origin resolution were inspected and left untouched. This remediation does not replace the bookmark suggestion provider. Future authorized integration must layer this branch's palettes onto that newer provider and retain #59's `additionalBoorus` alongside this branch's `autocompleteCategories`. Neither shared backend nor any other issue branch was overwritten. No merge/replay, push, PR, issue closure, branch deletion or worktree deletion occurred.


## Authorized combined integration verification (2026-10-23)

The user's subsequent instruction authorizes integrating the eight reviewed issues if verification passes, superseding earlier local-only statements for this operation. #52, #71 and unrelated bookmark-freeze work remain excluded.

Starting branch head: `063f0e04e2a82e3f4c5911e909e27bbb2cfa913f`. Combined runtime/test candidate: `e9b0b7916bd95e3ca134dd7fb797b81e43007503`, built on develop `afc04f4933aa0e442b9f80b2662f0fc5ad277379`. Subsequent handoff edits are documentation only.

R1's transfer-boundary fix remains: cross-profile intent restoration drops source-specific category hints, resolves the destination's local metadata, and preserves operators, raw queries, draft selection and search state. R2's DTO normalization and Philomena legacy-empty category support remain. Added a regression that exposed one remaining bookmark consumer dropping the known empty code; it failed with null before the resolver fix and now uses the originating Philomena General palette. Truly absent/unknown metadata stays neutral.

Preserved develop's incremental bookmark index, viewer-visible retention, obsolete-load guard, direct membership access and origin URL resolution. Added eight actual bookmark-color provider cases: light/dark × default/custom palette × dynamic harmonization, with origin-specific General, conflicting Artist/Character neutrality and missing-tag neutrality. The user's cancelled shared-renderer refactor remains reverted; existing renderers are retained and labels use w600.

Maestro visually confirmed the live Character suggestion produces a bold green selected Search chip with matching background/border. At 360 dp width and 2x system text, opened the editor with keyboard, changed only its exclusion operator, confirmed the edited chip and removed it. Theme preview checks covered Light, Coral Pink and dynamic Midnight; previews were cancelled without applying. Mixed-origin/source/category and complete theme combinations are executed provider/widget evidence, not a claim of every combination being exercised on Android.

The required `./scripts/run_regression_tests.sh` completed with **exit 0**, using six physical-core workers: **4,734 application tests**, all **13 package/CLI suites** (Kurumi **161 passed**), both shell tooling suites, and **72 Python tooling tests**. The two existing go_router skips remain. The first combined run exposed three obsolete domain-label expectations in #48's profile-switch fixtures; after reconciling with #47's requested labels, the entire unchanged final candidate was rerun successfully. No failing/incomplete run is counted as a pass.

Full command/results, APK correspondence, cross-branch reconciliation and limits are consolidated in [issue-48.md](issue-48.md#combined-verification-evidence-and-limits). This entry supersedes earlier pending combined-candidate qualification, without relabeling historical device checks as current evidence.


### Combined verification evidence and limits

- Bootstrap: pinned FVM Flutter 3.47.2/Dart 3.13.2; CLI/root pub get and `./gen.sh` for missing fresh-worktree output. Ignored generated files remain untracked. No tracked dependency change.
- `fvm flutter test --no-pub --concurrency=6 --reporter=expanded test/core/search/following_topics/topic_query_tag_categories_test.dart test/core/search/following_topics/topic_query_display_test.dart test/core/search/following_topics/untracked_topic_preview_widget_test.dart test/core/search/following_topics/realbooru_preview_production_path_test.dart test/core/bookmarks/bookmark_folder_ux_test.dart test/application/search_suggestion_category_flow_test.dart test/application/config_lifecycle_flow_test.dart`: 98 passed before the final extra cases (`/tmp/eight-integration-targeted.log`).
- `fvm flutter test --no-pub --concurrency=6 --reporter=expanded test/core/bookmarks/bookmark_tag_palette_test.dart test/core/tags test/core/search/following_topics/untracked_topic_preview_widget_test.dart test/core/search/following_topics/topic_query_tag_categories_test.dart`: **60 passed** (`/tmp/eight-final-focused-clean.log`). Philomena bookmark regression failed before the resolver correction (`/tmp/eight-combined-before.log`); local-only Topic resolution failed with an unexpected remote access before correction (`/tmp/eight-topic-before.log`).
- `fvm flutter test --no-pub --concurrency=6 --reporter=expanded test/core/search/search_profile_switch_test.dart test/core/navigation/profile_context_menu_test.dart`: **9 passed** after all label expectations were reconciled (`/tmp/eight-profile-reconciliation-final.log`).
- `./scripts/run_regression_tests.sh`: **exit 0** on `e9b0b7916`; log `/tmp/eight-final-regression-rerun.log`. Package counts, in runner order: 104, 254, 59, 191, 59, 47, 31, 45, 65, 436 (2 existing skips), 32, 161, 16. Existing go_router skips: `routing config works with shell route` and `Obsolete branches in StatefulShellRoute are cleaned up after route configuration change`.
- Formatted changed Dart files and passed `git diff --check`. `fvm flutter analyze --no-pub --no-fatal-infos` on all **59 changed Dart paths under lib/packages**: exit 0, **14 informational diagnostics, no warnings/errors** (`/tmp/eight-full-scope-analyze.log`). Additional analysis of the seven new integration-fix paths passed with nine informational diagnostics (`/tmp/eight-final-analyze.log`).
- `fvm flutter build apk --debug --flavor dev --target-platform android-x64 --no-pub`: exit 0 on the runtime candidate; repeated unchanged after the initial generated-build notice (`/tmp/eight-final-build-confirm.log`). Later commits change tests only. Installed preserving data on exclusively leased `emulator-5554`. Local APK and installed base.apk SHA-256 both **13ba1535b3fabbb581786f032e55ff1904e3cebddae7616587528ecd2d32fdd7**.
- Current-source device evidence: `/tmp/eight-pixiv.png`, `/tmp/eight-pixiv-picker-2x.png`, `/tmp/eight-selected-chip-2x.png`, `/tmp/eight-topic-2x.png`, `/tmp/eight-theme-{light,custom,dynamic}-preview.png`, `/tmp/eight-view-options-{visible,hidden}.png`, `/tmp/eight-scroll-top.png`. Maestro's initial exact-text/route assumptions sometimes failed; hierarchy inspection and subsequent real actions/screenshots established the results above. A successful command flow alone is not treated as feature acceptance.
- Complete base-to-head review retains develop's covered bookmark route, selection and incremental suggestion-index changes, newer feed-preview activity/cache behavior, #51 formatting plus #65 independent/feed preview behavior, and both shared fake-backend additions. Parsed en-US diff contains exactly `following_topics.preview_error` and `pixiv.experimental.{label,description}`. No common tag renderer, #52 media work or #71 search redesign is included.

Verification limits: no physical-phone run, live Pixiv authentication, full Android theme × source × category cross-product, populated authenticated mixed-profile/feed live matrix or fresh combined-APK Realbooru network trace is claimed. Those unchanged contracts have focused controlled tests and, for Realbooru HTML, the earlier source-specific live trace recorded in #65. The additional Android pass covers the constrained interactions described per issue. Existing unrelated baseline visual limitations are retained explicitly above. These are scope limits, not a replacement for the required complete candidate pass, which succeeded.

Cleanup verification: the created bookmark folder/group and Topic are absent, the original three profiles remain, system font scale is restored to 1.0, the original viewport/orientation were not changed, and the exact emulator lease was released. The dev APK/data remain installed; no app-data reset or phone operation occurred.
