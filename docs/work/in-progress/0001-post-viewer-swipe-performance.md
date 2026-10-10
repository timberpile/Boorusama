# 0001 - Bound post viewer swipe work

- Priority: High
- Feature: Search and bookmark post viewers, including mixed-engine collections
- Base: `develop` at `f4972eb54119fce98360c4c2303bbce375b8e722`
- Branch: `fix/post-viewer-swipe-performance`
- Agent/session: ChatGPT, 2026-10-10
- Isolation: Dedicated remote task branch. This GitHub API session has no full local checkout/worktree; the user's checkout is not touched.

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

- [ ] With identical direction history and local media, planning performs bounded resolution work for both 100 and 10,000 posts, including mixed profiles.
- [ ] Preload priorities, direct-entry thumbnails, current-media exclusion, profile isolation and cancellation remain correct across reversals, jumps, unresolved profiles and collection growth.
- [ ] Leaving a profile's relevant window cancels its stale active/pending work without accumulating managers for all previously visited profiles.
- [ ] A canceled request cannot erase a newer request for the same URL or mark canceled work as completed.
- [ ] Repeated inherited dependency changes do not multiply precise-page callbacks; replacing the controller disconnects the old controller.
- [ ] Settling another inactive page does not rebuild an unaffected media item; entering/leaving the active page still updates its media and pan constraints.
- [ ] Required formatting, related tests, affected-scope analysis and the complete local suite pass.
- [ ] Profile-mode verification on a physical device confirms improvement in normal feeds and large bookmark groups without mixed-engine regressions.

## Verification plan

Add focused preload and viewer lifecycle regressions. Run them alongside the existing preload, mixed-viewer and zoom-edge tests, then the complete local suite described in `docs/engineering_guidelines.md`.

For device acceptance, compare the same loaded images with small/large collections, one/multiple profiles, automatic media loading enabled/disabled and the same image-cache state. Check rapid reversal, direct jumps, images/videos, pan/zoom, overlay actions, and volume-key navigation. Measure synchronous planning and frame timings in Profile mode. Cache-size-dependent behavior belongs to the separate cache work item.

## Progress and blockers

- Source investigation completed; no device benchmark is available.
- Task branch created from the verified `develop` commit.
- Implementation in progress.
- Local Flutter/FVM and a full repository checkout are unavailable in this environment; direct Git cloning fails because `github.com` cannot be resolved. Required Flutter, analyzer, formatter and complete-suite verification must be completed in a Flutter-equipped checkout before this item can move to `done/`.
