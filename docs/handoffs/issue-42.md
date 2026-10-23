# Issue #42 — Local acceptance handoff

Branch: `feature/42-bookmark-group-filter`  
Base: `565a504cf714fa9de19053b22f5f761561a35f54`  
Issue: https://github.com/timberpile/Boorusama/issues/42

## Implementation

The bookmark overview has a local name field with Clear, a search-empty illustration and reset action, and keyboard dismissal on submit/scroll. Matching trims the query and uses a case-insensitive substring of the displayed name, including localized All and Ungrouped cards. Existing card ordering is retained when the filter is empty.

The browser now also has folders. The toolbar toggles the initially hidden search field. Folder matching includes descendants: a folder remains visible if its own name or any nested folder/group name matches. Post contents are not searched. Breadcrumbs and creation remain available. Each folder route owns its filter, and returning preserves the previous overview's filter. Existing card actions still operate by stable group/folder IDs, including duplicate names. Changing the filter clears bulk selection so hidden cards cannot be deleted accidentally. Library updates re-evaluate matching; no repository, membership, snapshot, post-fetch, or within-group tag-search logic changed.

The existing 12-pixel overview spacing and ordinary application text-field patterns are reused. Search, Clear, and the empty-state wording reuse existing localized resources, so no localization generation is required for changed inputs. Preview caches are not invalidated by typing; normal thumbnail rendering remains unchanged.

## Tests and verification status

Added `test/core/bookmarks/bookmark_group_name_filter_test.dart`: trimming/case/substrings, localized names, duplicate identities and preserved order, narrow/enlarged-text filter clearing, and the reset action. Inspected the existing group preview and name-dialog tests and folder picker/browser behavior.

**No Dart formatting, Flutter analysis/tests, or device checks have run.** The remote environment lacks FVM/Flutter and cannot clone GitHub. This branch is not accepted or integration-ready.

## Required local acceptance

1. Fetch into an isolated worktree and follow `AGENTS.md`; bootstrap the pinned SDK, dependencies, and missing generated files as needed.
2. Format changed Dart files, analyze the affected bookmark scope, and run `fvm flutter test test/core/bookmarks` with `--concurrency` from `python3 scripts/physical_core_count.py`. Include the existing folder UX tests, group browser tests, and selection tests because filtering changes the selectable index set.
3. Extend the full browser widget fixtures to verify actual card counts and All/Ungrouped matching, not just the pure matcher. Check empty/whitespace queries, case differences, duplicate group names, no matches, clear, rename into/out of a match, duplication, deletion, creation while filtered, nested folders/back, and selected items disappearing after external updates.
4. Verify opening a filtered group still uses the unchanged tag-search page and that filtering does not request post metadata. Check a narrow Android view, enlarged text, keyboard open, and scrolling. Follow the exclusive emulator lease procedure before using a device.
5. Review the full diff and fix small defects on this branch. Record exact commands/results, checked commit, skips, and remaining limitations. Run `./scripts/run_regression_tests.sh` on the final combined develop candidate before any approved integration.

## Coordination

Independent of other quick-win branches. `fix/bookmark-mutation-latency` may touch nearby bookmark presentation code: preserve both changes during any later approved integration and rerun bookmark tests. No merge, PR, issue closure, or deletion is authorized. A later integration subject must include `#42`; keep `Refs #42` until acceptance passes.

## Local acceptance evidence (2026-10-22)

This section supersedes the earlier unrun-verification status. Checked runtime/test commit: `e97404385db3001a465db1df3ed004d9e7574ff1`.

- Formatted the changed Dart files with `fvm dart format` and passed `git diff --check`.
- `fvm flutter test --no-pub --reporter=expanded --concurrency=6 test/core/bookmarks`: **462 passed**.
- `fvm flutter analyze --no-pub --no-fatal-infos lib/core/bookmarks test/core/bookmarks`: passed with informational lints, no errors or warnings.
- Expanded the real browser fixtures for empty/whitespace and case-insensitive filtering, localized All/Default cards, duplicate identities, external rename/deletion and selection reconciliation, filtered duplication/opening, independent nested-folder filters/back, and creation while filtered at 320 pixels with 2x text and keyboard insets. The current English localized special-card label is **Default**; the handoff's earlier “Ungrouped” wording did not require renaming it.
- Opening a filtered card reaches the existing group route. Source review confirms filtering does not call post metadata repositories or change the group's tag-search implementation.

Flutter 3.47.2 / Dart 3.13.2 were used. Six workers came from `python3 scripts/physical_core_count.py`. Fresh-worktree dependencies and missing generated files were initialized with `fvm dart pub get` at the root and in `packages/boorusama_cli`, then `./gen.sh`. Generated files remain ignored. An isolated copy of the same pinned SDK avoided an unrelated SDK startup lock.

### Android follow-up

The emulator later became available and passed its health check. After acquiring its exclusive lease, `fvm flutter pub get --offline` initialized the missing native plugin registry; `fvm flutter build apk --debug --flavor dev --target-platform android-x64 --no-pub` then passed. The initial build without that registry failed Android resource linking and is not counted as a pass. No tracked dependency files changed.

Installed this branch's dev APK with `adb -s emulator-5554 install -r`, preserving app data. Artifact SHA-256: `ef6b9b1ac6573014df0560dcf7750e5c7f160b14891733900bc946011cd70b37`. Maestro flows passed on the installed candidate: open Bookmarks, enter spaced uppercase `DEF`, retain Default and hide All with the keyboard open; show the no-match state; reset through Clear; open All; type in the existing in-group tag-search field. Checked 360 dp portrait width, normal text and 2x system text. Screenshots are under `/tmp/boorusama-acceptance/42-{filter-keyboard,no-match-2x,group-open-2x,group-search-keyboard-2x}.png`.

The existing device bookmark library was empty, so populated-library scrolling and tag-result behavior were not established on-device; the browser/selection/creation regression fixtures supply the automated evidence described above. No metadata-request counts were captured on-device. No merge, push, PR, issue closure, branch deletion, or combined-develop qualification occurred.

## Acceptance feedback follow-up (2026-10-23)

Search is now hidden by default and toggled by the top-bar search action. Hiding it clears the query and dismisses the keyboard. Matching remains local and case-insensitive, and now retains every ancestor of a matching nested folder or bookmark group. Group identity/order, selection reconciliation, localized special groups and per-route query state remain intact; no post metadata requests were added. This supersedes the earlier current-folder-only behavior.

Checked the runtime/test tree committed with this handoff. `fvm flutter test --no-pub --reporter=expanded --concurrency=6 test/core/bookmarks`: **464 passed**, including new recursive path and rendered browser regressions, toolbar hide/show/reset, nested navigation/back, and existing narrow/2x/keyboard coverage. Focused analysis with `--no-fatal-infos`: **passed with 11 informational lints, no warnings/errors** (existing styling, context and bridge diagnostics). Formatted changed Dart files; `git diff --check` passed. Logs: `/tmp/boorusama-42-followup/{tests-final,analyze-final}.log`. Flutter 3.47.2 / Dart 3.13.2, six workers.

No new device run or complete regression was performed for this scoped follow-up. Earlier device/integration limits remain; a combined integration candidate still needs complete verification. Local only; no merge, push, PR, closure or deletion.

## Immediate typing and autofocus follow-up (2026-10-23)

The overview search field now requests focus when mounted, so toggling it on immediately opens text input at the root and in folders. It remains hidden initially; hiding clears the query, dismisses input, and reopening focuses the new field again. Reused TextField autofocus rather than adding a separate delayed focus lifecycle.

The reported root-only submit delay did not reproduce on the pre-change source: continuous IME/composing edits updated both root and folder results, including through the production navigation shell. The user confirmed that a full rebuild restored per-keystroke updates everywhere after a hot restart had not. No filtering algorithm or additional submission behavior was changed. The missing focus/keyboard behavior did reproduce in both root/folder tests before the autofocus fix.

Checked runtime/test tree: the local commit containing this section. `fvm flutter test --no-pub --reporter=expanded --concurrency=6 test/core/bookmarks test/application/bookmark_collection_selection_flow_test.dart test/application/bookmark_library_flow_test.dart`: **474 passed**. New coverage types several successive composing values without submitting or re-focusing, verifies each intermediate result, and checks keyboard/focus through hide/show cycles at 320 pixels with 2x text. The application regression opens the real root Bookmarks destination, requires autofocus, and types directly into it. Focused analysis of the changed widget/tests with `--no-fatal-infos`: **passed with 4 informational test lints, no warnings/errors**. Formatting and `git diff --check` passed. Logs: `/tmp/boorusama-42-live-input-{before,after,tests,analyze}.log` and `/tmp/boorusama-42-shell-input-before.log`. Flutter 3.47.2 / Dart 3.13.2, six workers.

An Android diagnostic build was started, then canceled (exit 130, not a build pass) after the user's full-rebuild confirmation made the device reproduction unnecessary. No app installation or emulator UI operation occurred, and no emulator lease was acquired. No complete regression or new device acceptance is claimed for this scoped autofocus follow-up. Local only; no merge or publication.


## Authorized combined integration verification (2026-10-23)

The user's subsequent instruction authorizes integrating the eight reviewed issues if verification passes, superseding earlier local-only statements for this operation. #52, #71 and unrelated bookmark-freeze work remain excluded.

Starting branch head: `4e412c4f3b9cb80b3eed8a84bc88f88267d45b87`. Combined runtime/test candidate: `e9b0b7916bd95e3ca134dd7fb797b81e43007503`, built on develop `afc04f4933aa0e442b9f80b2662f0fc5ad277379`. Subsequent handoff edits are documentation only.

Preserved develop's covered-route `TickerMode`/`_visibleLibrary` retention and empty-selection behavior while adding opt-in, focused, recursive name filtering. The user's later recursive-ancestor requirement supersedes the review's earlier current-folder-only wording. The combined browser fixture retains both develop's covered-browser test and the branch's filter/action tests.

Maestro on the combined APK created `QA Integration Parent` and its child group `QA Integration Needle`. From the root, typing `Needle` immediately retained the ancestor folder and hid All without submitting; typing `qxz` displayed No content. Repeated live matching, empty state, clear and toolbar hide inside the folder. Showing Search automatically focused the field and opened the keyboard. Removed only the created folder/group after checking the deletion summary (one folder, one group); final absence verified. Populated IDs/action/rename/duplicate/selection and narrow/2x/keyboard variants also pass in the complete suite.

The required `./scripts/run_regression_tests.sh` completed with **exit 0**, using six physical-core workers: **4,734 application tests**, all **13 package/CLI suites** (Kurumi **161 passed**), both shell tooling suites, and **72 Python tooling tests**. The two existing go_router skips remain. The first combined run exposed three obsolete domain-label expectations in #48's profile-switch fixtures; after reconciling with #47's requested labels, the entire unchanged final candidate was rerun successfully. No failing/incomplete run is counted as a pass.

Full command/results, APK correspondence, cross-branch reconciliation and limits are consolidated in [issue-48.md](issue-48.md#combined-verification-evidence-and-limits). This entry supersedes earlier pending combined-candidate qualification, without relabeling historical device checks as current evidence.

Cleanup verification: the created bookmark folder/group and Topic are absent, the original three profiles remain, system font scale is restored to 1.0, the original viewport/orientation were not changed, and the exact emulator lease was released. The dev APK/data remain installed; no app-data reset or phone operation occurred.
