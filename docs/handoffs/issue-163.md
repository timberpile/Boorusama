# Issue #163: diagnostic Masonry resize animation

## Current state

- Issue: https://github.com/timberpile/Boorusama/issues/163
- Branch: `bug/163-masonry-thumbnail-aspect-ratios`
- Diagnostic implementation and tested candidate:
  `9e3cf6775376506cc0e521157b8c15e51eb7ca84`
- Non-animated comparison base: `a4b99e080`.
- Status: `in-progress`; the original intermittent scrolling jump/assertion
  remains unreproduced. This iteration adds animation for visual evaluation.
- No merge, push, PR, issue closure, or branch deletion was performed.

The earlier decoded-ratio fix, independent review, and intermittent
`object.dart:4323: debugNeedsLayout` investigation are recorded in Git history at
`a4b99e080:docs/handoffs/issue-163.md` (local commit; publication is pending).
Those earlier review results do not constitute an independent review of this
animation iteration.

## Implementation

`_PostGridImage` wraps its size-producing image subtree in Flutter's
`AnimatedSize`: **300 ms**, `Curves.easeOutCubic`, `Alignment.topCenter`.
The surrounding card gets the animated image height, so its overlays, hit area
and following grid children track that height. Both the ordinary image path and
format-probing path use the same local wrapper.

Standard and Classic bypass the wrapper. Application Reduce Motion and system
`MediaQuery.disableAnimations` also bypass it. A keyed image subtree retains
in-flight probes and decoded image state when the preference changes. A test
caught picker recreation before that retention was added. Zero-duration
`AnimatedSize` produced a self-mutation layout assertion in the pinned SDK;
reduced motion therefore uses the unanimated content directly.

The first layout uses its full provisional/known size immediately. Only later
size changes animate. Existing ratio equality, stale-callback/failure guards,
quality changes, fallback chains, cached GIF policy and persistence are retained.
No animation controller, request, decoder, setting, ratio tolerance or scroll
compensation was added. The Masonry renderer is unchanged.

## Renderer investigation and optional diagnostics

Source inspection of `RenderSliverMasonryGrid` shows:

- `collectGarbage` stores each leading child's current `paintExtentOf(child)`
  with its column. This can be an intermediate animated height, rather than a
  final decoded target height.
- `insertAndLayoutLeadingChild` retrieves that historical height as
  `lastMainAxisExtent`. Leading-position reconstruction uses this saved extent;
  a recreated child's actual size may already differ.
- `positionChild` recomputes downstream placement from the laid-out child
  extents. Neighbors can therefore move while the viewport offset stays fixed.
- Existing `SliverGeometry.scrollOffsetCorrection` branches handle column-count
  reconstruction, exhausting leading children before reaching the requested
  offset, and negative reconstructed starting offsets. The viewport applies
  those corrections through `ScrollPosition.correctBy`.

These are source findings, not a diagnosis of the reported transient jump.
No renderer branch, cached-height policy, precision comparison, or offset
correction was changed.

Optional **test-harness-only** logging is disabled by default. Enable it with:

```bash
fvm flutter test --no-pub \
  --concurrency="$(python3 scripts/physical_core_count.py)" \
  --dart-define=BOORUSAMA_DEBUG_MASONRY_RESIZE=true \
  test/core/posts/listing/masonry_scroll_layout_test.dart
```

It records input versus actual scroll offset, the first retained child's index,
current height, historical height, layout offset, and pass-through `correctBy`
deltas. It adds no application logging or renderer behavior.

Observed evidence:

- **360 changing-height frames** across one, two and three columns produced
  cached/current height differences and reflow, with **zero viewport
  corrections** in those sequences.
- A separate constant-height column-count change produced a **-408 px**
  correction: offset **900 → 492**. This verifies the recorder distinguishes
  actual viewport correction from child/neighbor layout changes.
- Interpolation tests hold the tile's top position fixed and verify the next
  row follows its changing height through four samples in each direction.

## Automated verification

FVM Flutter 3.47.2 / Dart 3.13.2; six workers from the physical-core detector.
The final candidate passed:

```bash
fvm flutter test --no-pub \
  --concurrency="$(python3 scripts/physical_core_count.py)" \
  test/core/images \
  test/core/posts/listing \
  test/core/posts/details/progressive_post_image_test.dart \
  test/boorus/gelbooru_v2/realbooru_video_thumbnail_test.dart

fvm flutter analyze --no-pub --no-fatal-infos \
  lib/core/posts/listing/src/widgets/post_grid_item.dart \
  test/core/posts/listing/post_grid_item_test.dart \
  test/core/posts/listing/masonry_scroll_layout_test.dart

git diff --check
```

- **242 tests passed**, exit 0, no skips. Includes multi-frame growth/shrink,
  easing, overlay/hit geometry, request and decoded-image retention, both Reduce
  Motion sources, initial known sizing, preference changes during probing,
  source/fallback/error handling, cached GIFs, scrolling and viewer consumers.
- Scoped analysis: **0 errors, 0 warnings, 3 pre-existing informational
  findings**, exit 0 with `--no-fatal-infos`.
- Changed Dart files were formatted. Whitespace checks passed.
- Existing corrupt-animation tests emitted expected native decode errors;
  selection fixtures emitted hit-test warnings and the native VM/finalizer
  diagnostic previously reproduced on pre-issue base `266a14c0f`. The suite
  still completed successfully; that engine/fixture diagnostic is unresolved.

The complete application/package/CLI/tooling integration suite has not run.

## Android / live Realbooru comparison

Leased **emulator-5554**, used Maestro for UI actions, and retained app data.
Both APKs were built from this worktree with:

```bash
fvm flutter build apk --debug --flavor dev --target-platform android-x64
```

Build downloads initially failed. Existing local native libraries were reused
only after verifying their package-required MD5/SHA-256 checksums. No build or
dependency source was changed.

| Build | APK SHA-256 |
| --- | --- |
| Non-animated `a4b99e080` | `31b04b6feab4158927f9221d12510694399e54a539ee941082ef0c43457feaa8` |
| Final animated candidate | `a6c31bf518d151fec6d8100b4623ee24d6845d5953540425a3e2b1e275e559ce` |

The installed final APK hash matched the built APK. A temporary public Realbooru
profile exercised the normal **41-post browse feed**, Masonry, Medium grid,
Automatic thumbnail quality, Reduce Animations off. Recorded six forward and
four reverse swipes, including loading rows near the viewport and revisited
rows. The final recording started only after the feed's post count was visible.
An earlier animated recording containing startup was excluded from comparison.

The recordings show local thumbnail/neighbor geometry changing as rows load and
are revisited. **The original brief jump and `debugNeedsLayout` assertion did
not reproduce in these runs.** Filtered device Flutter logs contained zero
matching layout assertion lines. Live cache warmth and request arrival differed
between runs; the recordings are qualitative, not a timing benchmark. On-device
ratio-delivery/scroll-correction timestamps were not captured, so they do not
establish whether a particular above-viewport completion caused a viewport
shift. The controlled test observations above do not assign the live root cause.

The temporary profile and its profile-scoped search history were removed, the
original Default profile was selected again, global preferences were retained,
and the emulator was returned to its initial launcher state. The existing
Default site's loading/captcha problem was not changed. Both emulator leases
were released. The final diagnostic APK remains installed.

## Evidence and next step

Ignored durable artifacts are in the primary workspace under
`.worktrees/_artifacts/163-masonry-thumbnail-aspect-ratios/animation/`:

- `affected-tests-final.log`, `analyze-final.log`, `interpolation-final.log`.
- `renderer-diagnostics.log` for the opt-in correction/height trace.
- `baseline-build.log`, `animated-final-build.log`, `apk-correspondence.json`.
- `baseline-a4b99e080.apk`, `animated-final.apk`.
- `baseline-browse-scroll.mp4`, `animated-final-scroll.mp4` and geometry overviews.
- `device-layout-assertions.log` and `device-restoration.json`.

Evaluate the animation visually before choosing any scroll-offset or
aspect-ratio-threshold policy. Keep the original intermittent assertion open;
if it recurs, capture the first complete exception and preceding errors.
Publication and integration remain pending authorization and complete candidate
verification.
