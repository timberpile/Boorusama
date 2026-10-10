# 0001 - Bound post viewer swipe work

- Priority: High
- Feature: Search and bookmark post viewers, including mixed-engine collections
- Base: `develop` at `f4972eb54119fce98360c4c2303bbce375b8e722`
- Branch: `fix/post-viewer-swipe-performance`
- Agent/session: ChatGPT, 2026-10-10
- Status: Implementation committed; blocked on Flutter verification and device acceptance.
- Isolation: Dedicated remote task branch and a local worktree containing only SHA-verified copies of the affected sources. This is not a full checkout; the user's checkout is untouched.

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

Implementation is present, but the behavioral criteria remain unchecked until the tests actually run.

- [ ] With identical direction history and local media, planning performs bounded resolution work for both 100 and 10,000 posts, including mixed profiles.
- [ ] Preload priorities, direct-entry thumbnails, current-media exclusion, profile isolation and cancellation remain correct across reversals, jumps, unresolved profiles and collection growth.
- [ ] Leaving a profile's relevant window cancels its stale active/pending work without accumulating managers for all previously visited profiles.
- [ ] A canceled request cannot erase a newer request for the same URL or mark canceled work as completed.
- [ ] Repeated inherited dependency changes do not multiply precise-page callbacks; replacing the controller disconnects the old controller.
- [ ] Settling another inactive page does not rebuild an unaffected media item; entering/leaving the active page still updates its media and pan constraints.
- [ ] Required formatting, related tests, affected-scope analysis and the complete local suite pass.
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

These tests are written but have NOT been executed in this environment.

## Verification record and blocker

- The six modified original source files were copied from the pinned base and verified against their Git blob SHA before editing; changes were reviewed against that baseline.
- `git diff --check` passed for the final staged diff. A Dart lexical/delimiter sanity check found no unmatched delimiters; this is not a Dart parser, formatter, analyzer or compilation result.
- An independent Python model compared old and bounded cancellation rules for 22,050 unique-URL cases, with matching decisions. This does not execute the Dart implementation and is not a substitute for its tests.
- Focused `fvm flutter test`, `fvm dart format`, affected-scope `fvm flutter analyze`, and the full application `fvm flutter test --no-pub --concurrency=2` were attempted but could not start: `fvm: command not found` (exit 127).
- Flutter, Dart and FVM are absent. Direct Git cloning also failed because `github.com` could not be resolved, so package/CLI tests and repository tooling suites could not be run from a complete checkout. No CI result or device benchmark is claimed.

Required next verification in a full Flutter-equipped checkout:

```sh
git diff --name-only f4972eb54119fce98360c4c2303bbce375b8e722 -- '*.dart' | xargs fvm dart format
fvm flutter test --no-pub test/core/posts/media_preload/preload_window_test.dart test/core/posts/details/post_viewer_swipe_lifecycle_test.dart test/preload_test.dart test/core/posts/details/mixed_post_details_page_test.dart test/core/posts/details/zoom_edge_page_gesture_test.dart
fvm flutter analyze --no-pub lib/core/posts/media_preload lib/core/posts/details/src/widgets/post_details_image_preloader.dart lib/core/posts/details/src/widgets/post_details_item.dart lib/core/posts/details/src/widgets/post_details_page_scaffold.dart test/core/posts/media_preload/preload_window_test.dart test/core/posts/details/post_viewer_swipe_lifecycle_test.dart
```

Then run the complete application, every package/CLI, and repository-tooling suite as specified in `docs/engineering_guidelines.md`. Resolve failures before moving this item to `done/`.

For device acceptance, compare the same loaded images with small/large collections, one/multiple profiles, automatic media loading enabled/disabled and the same image-cache state. Check rapid reversal, direct jumps, images/videos, pan/zoom, overlay actions, and volume-key navigation. Measure synchronous planning and frame timings in Profile mode. Cache-size-dependent behavior belongs to the separate cache work item.
