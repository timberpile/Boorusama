# 0001 - Bound post viewer swipe work

> **Archive disposition (2026-10-20): Completed on `develop`.** The implementation is integrated. Earlier claims, status text, outstanding manual checks and verification notes below are historical, not an active local task.

- Priority: High
- Feature: Search and bookmark post viewers, including mixed-engine collections
- Base: `develop` at `f4972eb54119fce98360c4c2303bbce375b8e722`
- Branch: `fix/post-viewer-swipe-performance`
- Agent/session: Codex local continuation, 2026-10-10
- Status: Done (implemented on develop; historic device verification notes below)
- Worktree: `/home/timber/code/Boorusama/.worktrees/post-viewer-swipe-performance` (full checkout on the existing task branch).

## Problem

Crossing the halfway point of a post swipe synchronously resolves the entire viewer collection for mixed-profile preloading. Cancellation planning scans the collection again, even without active downloads. Large bookmark groups amplify the cost. Further avoidable work comes from copying preload completion history, duplicate precise-page listener registration, and rebuilding inactive mounted items when another page settles.

Reproduce by repeatedly swiping between two loaded images in a normal search and in a large bookmark group, including a group containing multiple profiles. Compare collections of approximately 100 and 10,000 posts. Device timings from the investigation are observations, not a measured baseline.

## Scope and approach

1. Resolve only the direction-dependent preload window plus the small neighborhood needed to retain active downloads. Preserve original page indices and profile-specific authentication/media URL selection.
2. Eliminate collection-wide cancellation lookups. With no active downloads, do no cancellation lookup work. Preserve current/nearby download retention, directional priorities, direct-entry thumbnail-only loading, and stale-work cancellation.
3. Keep mixed-profile manager bookkeeping bounded to the current window. Do not copy the complete preload success history on each swipe.
4. Bind the scaffold's precise-page listener exactly once per controller, detach on controller replacement/disposal, and preserve volume-key navigation.
5. Rebuild a mounted media item for settlement only when its own active/inactive state changes. Preserve pan constraints, playback and zoom-edge behavior.
6. Add deterministic behavioral regression tests; use operation counts rather than device-independent millisecond assertions.

The broader mixed-viewer presentation/scaffold refactor is deferred until device profiling after these targeted fixes. The image disk cache, metadata persistence and cache eviction are explicitly excluded: they are being handled in another work item. No cache clearing, schema changes or UI redesign are part of this task.

## Acceptance criteria

The automated criteria below were exercised locally with the pinned FVM SDK. Visible stutter and frame-time improvement still require physical-device acceptance.

- [x] With identical direction history and local media, planning performs bounded resolution work for both 100 and 10,000 posts, including mixed profiles.
- [x] Preload priorities, direct-entry thumbnails, current-media exclusion, profile isolation and cancellation remain correct across reversals, jumps, unresolved profiles and collection growth.
- [x] Leaving a profile's relevant window cancels its stale active/pending work without accumulating managers for all previously visited profiles.
- [x] A canceled request cannot erase a newer request for the same URL or mark canceled work as completed.
- [x] Repeated inherited dependency changes do not multiply precise-page callbacks; replacing the controller disconnects the old controller.
- [x] Settling another inactive page does not rebuild an unaffected media item; entering/leaving the active page still updates its media and pan constraints.
- [x] Required formatting, related tests and affected-scope analysis pass.
- The complete local suite must pass before readiness; see the initial results and final-repeat logs below.
- [ ] Profile-mode verification on a physical device confirms improvement in normal feeds and large bookmark groups without mixed-engine regressions.

## Implementation

- `DirectionBasedPreloadStrategy.getResolutionIndices()` shares the bounded preload/retention window with the mixed-profile coordinator. Cancellation starts with active URLs minus desired URLs, then retains only matching URLs in the nearby zone. The full-list `buildUrlIndexMap()` helper is no longer called by this strategy.
- `GroupedPreloadManager` resolves each relevant index once per planning pass, keeps global collection indices, dispatches media to the correct authentication group, and cancels/removes managers leaving the window. Resolution is rebuilt locally on every pass so changed media, unresolved origins and appended posts do not require a persistent index.
- The mixed widget delegates to this coordinator and reads the profile collection once per pass. The existing media representation rules, including video thumbnails and avoiding original-image prefetch, are unchanged.
- `PreloadManager` uses a read-only completion-set view during synchronous strategy calculation. Disabled managers return before media resolution. A finishing request can mark completion or release its slot only while it still owns that URL's cancellation token; canceled successes do not poison completion history.
- The scaffold rebinds its precise-page listener and volume-key navigator only when the inherited controller changes. Its playback listener follows a replacement details controller, and disposal avoids inherited-context lookup.
- Each `PostDetailsItem` stores its own settled/not-settled state. Only changes to that state trigger settlement rebuilds; the duplicate inner global settlement builder is removed. Both media activation and pan constraints use the same state, including after item index/controller replacement.

A deliberately improved edge case: if a media URL occurs both nearby and far away, any relevant nearby occurrence can retain the active download. The previous complete URL map kept only the last occurrence and could incorrectly cancel it.

## Added regression coverage

- `test/core/posts/media_preload/preload_window_test.dart`: bounded work with/without active downloads; desired/current/nearby URL retention; duplicate URLs; confident forward/backward cancellation; boundaries; mixed profiles and unresolved origins; same URL with different authentication; jumps, stale active/pending work, changed media, appended posts; canceled-request replacement races; disabled preloading.
- `test/core/posts/details/post_viewer_swipe_lifecycle_test.dart`: actual mixed-widget collection reads for 100/10,000 posts; unchanged inactive media-widget identity; pan/activation synchronization; reused index/controller subscriptions; dependency changes, inherited controller replacement and listener cleanup.

## Local continuation and corrections (2026-10-10)

- Fetched origin and continued `8c81fb586d8252166d9c46f795757528c239773c` in the full task worktree above. No later branch commits were present; no rebase or replacement implementation was needed. The primary checkout was preserved.
- Installed checkout dependencies with `fvm flutter pub get` and CLI `fvm dart pub get`; ran `./gen.sh` because generated outputs were absent. The historical missing-SDK/partial-checkout blockers are resolved.
- Corrected the lifecycle test's missing `TranslationProvider` import and supplied explicit initial-profile and thumbnail-settings fixtures. Removed the unused collection import and formatted all nine changed Dart files with pinned Dart.
- Corrected both mixed and single-profile preloaders to detach old page-controller listeners, cancel stale work, reset direction history, and initialize from the replacement controller's current page. Deferred initialization ignores a replaced controller or disposed widget; disposal avoids inherited-context access.
- Replaced the mixed-widget test's empty-profile setup with resolvable mixed profiles and assertions on actual dispatched URLs. Added reversal/jump operation counts, missing/ambiguous-profile rejection, video/original-quality thumbnail rules, both preloader subscription lifecycles, and scaffold volume-key rebinding/disposal coverage. Meaningful original assertions were retained.

## Local verification

- Pinned SDK: Flutter 3.47.2 / Dart 3.13.2 through FVM.
- Requested five-file focused regression command: **106 passed**.
- Affected-scope `fvm flutter analyze --no-pub` covering media preload, the three viewer widgets and both new test files: **no issues**.
- Deterministic planning: no-active strategy resolves 3 media positions; active-download cancellation resolves at most 8, with equal work at 100 and 10,000 posts. Grouped direct-entry planning resolves exactly 5 positions at either size. The actual mixed widget resolves at most 6 positions per pass, with identical per-pass counts for both sizes across navigation `[50, 51, 52, 51, 50, 80, 50]`. No timing or visible-stutter improvement is inferred from these counts.
- Complete local suite: first application run **3,029 passed / 2 failed**; all **831 tests across 12 test-bearing packages passed** (booru_clients 76, boorusama_cli 239, cache_manager 23, coreutils 190, dtext 59, extended_image 47, filename_generator 31, flutter_sqlite3_migration 45, foundation 45, i18n_cli 32, kurumi 33, retriable 11). Both shell tooling suites passed; Python repository tooling **30 passed**. No individual skips were reported.
- Initial application failures: `share_original_copy_test.dart` / “copying Original prepares the exact image and reports success” missed the Copied toast after its fixed 150 ms wait; `progressive_non_admitted_cache_test.dart` / “progressive live handoff reuses the exact decoded completer when decoded cache admission is disabled” saw a missing pending request after a fixed wait. The sharing test passed its named standalone rerun. The cache test initially failed standalone at a later image-read assertion, then passed on the original base and on the corrected branch under quieter conditions. This is evidence of timing sensitivity, not proof of baseline-only failures; these files and cache implementation remain unchanged.
- Second complete run after the work-item update: application **3,029 passed / 2 failed**; all 831 package tests and all tooling passed again. The previous sharing/cache failures passed in this run. Both failures were in `test/bulk_downloads/providers/downloads/session_test.dart`: “Session Cancellation should cancel only the specified session mid-download” and “Session Resume should mark dry run session as pending when interrupted”, reporting access to an already disposed ProviderContainer. In a filtered two-test rerun, resume passed and cancellation failed. The identical cancellation failure reproduced against the original develop base in a temporary source snapshot at `/tmp/boorusama-swipe-baseline`; bulk-download sources/tests are unchanged by this patch. This pre-existing failure remains outside the viewer/cache scope.
- Final complete-suite recheck after recording those blockers: execution records are `/tmp/swipe-full-recorded/results.json` and corresponding per-suite `.log` files; the final handoff reports that recheck's outcome. Earlier full records are `/tmp/swipe-full-initial/` and `/tmp/swipe-full-final/`; isolated cancellation baseline evidence is `/tmp/swipe-session-baseline.log`. A failing complete run still blocks readiness even when a filtered rerun passes.
- `git diff --check` passed. Reviewed the implementation against original base `f4972eb54119fce98360c4c2303bbce375b8e722` and the local corrections against `8c81fb586d8252166d9c46f795757528c239773c`.
- Checked source/test diff SHA-256 (`git diff f4972eb54119fce98360c4c2303bbce375b8e722 -- lib test`): `ec89a61ee1a37b8f35d8b772fa68e198aa05fdf3d38af50e8f7ff7c82a43c700`. The final local continuation commit contains this diff and this work item. Full verification was repeated after the final work-item edit.
- The known libavif native-hook warning (`File modified during build. Build must be rerun.`) appeared; suite exit codes determine the results, as documented in `docs/build_troubleshooting.md`.

## Remaining acceptance

A passing complete-suite run is still required before readiness. The known full-suite blocker is the existing bulk-download session lifecycle failure above, reproduced on the original base; its follow-up must preserve this task’s viewer scope. Physical-device baseline-versus-branch profiling was not performed. No device was operated on, cache cleared, or cache implementation changed. Profile-mode synchronous preload-planning timings and slow-frame counts remain unmeasured; the visible stutter is **not claimed eliminated**.

Compare baseline `f4972eb54119fce98360c4c2303bbce375b8e722` and this corrected task branch on the same physical device, with comparable loaded media and cache conditions. Exercise normal feeds and large bookmark groups, one/multiple profiles, preloading enabled/disabled, repeated reversals and direct jumps, images/videos, zoom/pan, overlays and volume-key navigation. Keep gains from the separate cache work item out of this comparison. Move to `done/` only after these acceptance checks pass.

Local correction commits are authorized. No merge into develop, push, PR, or branch/worktree deletion was performed.
