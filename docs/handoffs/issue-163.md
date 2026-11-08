# Issue #163: Masonry thumbnail aspect ratios

## State

- Issue: https://github.com/timberpile/Boorusama/issues/163
- Branch: `bug/163-masonry-thumbnail-aspect-ratios`
- Base: `266a14c0f87f29213d48696bda7c806dc1d05b6e`
- Verified runtime candidate before the scrolling follow-up: `8fdc267aceb28348253b9ebaf34287e2ba899db1`
- Local implementation, scoped verification and independent review completed on
  2026-11-08. Subsequent handoff-only edits do not change the checked candidate.
- **Follow-up status:** intermittent Realbooru Masonry scrolling assertion remains
  unreproduced; issue #163 is `in-progress` again. See the follow-up below.
- Publication and integration are pending authorization. No push, PR, merge,
  issue closure or branch deletion was performed during this continuation.

## Result and remediation

Realbooru listing rows can lack poster dimensions, leaving Masonry tiles at a
fallback ratio after the displayed image decodes. The grid now observes the
already decoded visible rendition and updates its presentation ratio without
animation, additional media/detail requests, or persisted model changes.

Normal, cached-byte and fallback images report through the repository's local
`ExtendedImageController.imageInfo` API. Format probes reuse the winning decoded
image and retain its dimensions across callback and metadata updates.
Standard and Classic sizing retain their existing behavior.

The continuation fixed four verified boundaries:

- Replacing a decoded image with an empty source no longer reports stale
  controller dimensions. Late source and cached-byte callbacks are guarded.
- Direct controller observation replaces an ancestor `ValueListenableBuilder`:
  synchronous cached GIF delivery previously caused a build-phase FlutterError.
  Tile notifications run after the frame and validate the current callback,
  controller and image information.
- A retained candidate picker can report its already decoded dimensions when a
  callback becomes available or presentation metadata changes. The late-callback
  regression failed before the correction. Normal app layout switching recreates
  the grid subtree; that was not claimed as a reproduced app defect.
- Completed display state is checked at callback delivery. After a later-frame
  failure, retained primary pixels are hidden by the error/fallback surface;
  their old dimensions must not override the visible fallback. The new
  regression failed before this guard was added.

The requested analyzer run also exposed a pre-existing invalid benchmark override.
`benchmark/bookmark_mutation_latency_test.dart` now accepts and forwards the
repository's optional `addedAt` argument; application bookmark code is unchanged.

## Independent review

A separate agent, `/root/review_163`, inspected the implementation against the
base, local ExtendedImage fork, Masonry renderer and tests. It identified the
stale empty-source defect and coverage gaps, then re-reviewed the remediation
and benchmark signature correction with no remaining confirmed findings.
The reviewer performed source inspection only; the checks below were run by the
implementing agent. Device scrolling and visual jump behavior were not reviewed.

## Verification

The worktree used FVM Flutter 3.47.2 / Dart 3.13.2. Dependencies were resolved,
and missing generated outputs were restored with `./gen.sh`; generation produced
no tracked changes. Changed Dart files were formatted with `fvm dart format`.

Application tests and analysis ran on the runtime/test candidate above; the
benchmark source state is recorded separately below:

```bash
fvm flutter test --no-pub \
  --concurrency="$(python3 scripts/physical_core_count.py)" \
  test/core/images \
  test/boorus/gelbooru_v2/realbooru_video_thumbnail_test.dart \
  test/core/posts/listing \
  test/core/posts/details/progressive_post_image_test.dart

fvm flutter test --no-pub --concurrency=1 \
  benchmark/bookmark_mutation_latency_test.dart

fvm flutter analyze --no-pub --no-fatal-infos

git diff --check
```

- Affected application tests: **225 passed**, exit 0, six workers, no skips.
  Selection fixtures emitted hit-test warnings. Corrupt-animation tests emitted
  expected native decode errors. A non-failing native VM/finalizer diagnostic
  also appeared in the selection fixture; see the baseline check below.
- Serial benchmark fixture: **2 passed**, exit 0 on
  `a37035ec0115ca53a50873027bfa8926ff268800`. The later change only guards image
  reporting and adds its regression; benchmark code and behavior are unchanged.
  This validates the corrected override; no comparative performance or device
  timing claim is made.
- Analyzer: **0 errors, 0 warnings, 3,382 informational lints**, exit 0 with
  `--no-fatal-infos`. The initial default analyzer run failed with the benchmark
  override error and informational lints; it is not reported as a clean pass.
- Formatting and whitespace checks completed successfully.

Coverage includes decoded memory/fallback dimensions, candidate ownership and
handoff, actual non-square Masonry sizing, metadata-only updates, empty/source
replacement and stale callbacks. A real Masonry sliver verifies following-row
placement after height changes at 160 px width and 2x text. Standard/Classic
sizing, large cached GIFs, selection consumers and progressive viewer images are
included in the affected suites.

Detailed local logs remain under the ignored
`.worktrees/_artifacts/163-masonry-thumbnail-aspect-ratios/` directory in the
primary workspace (`final-affected-tests-v2.log`, `benchmark-smoke.log`,
`final-analyze-v2.log`, `format-final.log`, and `late-failure-format.log`).

## Native diagnostic baseline check

To trace the native VM/finalizer message, the listing suite was repeated with
JSON reporting at six workers and serially; both runs passed. Serial output
associated the message with `selection_action_parity_test.dart`.

A temporary detached worktree at the exact pre-issue base
`266a14c0f87f29213d48696bda7c806dc1d05b6e` then ran:

```bash
fvm flutter test --no-pub --concurrency=1 \
  test/core/posts/listing/selection_action_parity_test.dart
```

Both baseline tests passed and reproduced the same native message:
`Callbacks into the Dart VM are currently prohibited`, with the typed-data /
finalizer explanation. This demonstrates that the diagnostic predates #163;
its underlying engine/fixture cause was not resolved. The baseline worktree was
removed after verifying its tracked source was clean. Its log is preserved as
`baseline-selection.log` in the local artifact directory above.

## Intermittent scrolling assertion follow-up

After the initial review, the user reported
`object.dart:4323: debugNeedsLayout is not true` while scrolling Realbooru's
normal browse feed in Masonry. The user could not reproduce it by scrolling the
same feed again. A full first-exception stack trace is unavailable.

In the pinned SDK this assertion is in
`RenderObjectWithLayoutCallbackMixin.scheduleLayoutCallback`. It diagnoses an
inconsistent layout-callback state; the assertion alone does not identify the
originating widget or an earlier exception in the frame.
[Flutter issue #192030](https://github.com/flutter/flutter/issues/192030) reports
the same assertion on Flutter 3.47.2 with obstructed tooltip overlays and resizing.
That different reproduction is an investigation lead, not an established cause
for this scrolling report.

Added five scrolling tests in commit
`02cd164592c59fdb6a8f3292e95a84c88fc26099`:

- Actual post tiles scroll forward and backward with decoded-image resizing,
  recycled children and non-overlapping geometry. The Realbooru case uses the
  production thumbnail mapper, unknown dimensions, image-format probes and
  video posters across 100 rows.
- Deterministic child-ratio changes exercise 120 scrolling frames each in one,
  two and three columns, including leading-child eviction and reinsertion.

Verification on that test candidate:

```bash
fvm flutter test --no-pub \
  --concurrency="$(python3 scripts/physical_core_count.py)" \
  test/core/posts/listing/post_grid_item_test.dart \
  test/core/posts/listing/masonry_scroll_layout_test.dart \
  test/core/images \
  test/boorus/gelbooru_v2/realbooru_video_thumbnail_test.dart

fvm flutter analyze --no-pub --no-fatal-infos \
  test/core/posts/listing/post_grid_item_test.dart \
  test/core/posts/listing/masonry_scroll_layout_test.dart
```

Results: **76 tests passed**, exit 0, six workers; scoped analysis had **0 errors,
0 warnings and 3 pre-existing informational findings**, exit 0. Formatting and
`git diff --check` passed. Logs: `scroll-verification-final.log`,
`scroll-analyze-final.log`, and `scroll-format-final.log` in the artifact directory.

The available emulator was leased for a read of assertion messages and stack
frames only; no matching assertion was present, and the lease was released.
Its installed build's source correspondence was not established. No feed actions
were exercised on the device for this follow-up.

Runtime code is unchanged by this follow-up. The reported assertion remains
unresolved. If it recurs, preserve the **first full Flutter exception**, including
any earlier layout error, plus the active site/layout and action immediately
before the failure. Keep the issue `in-progress` pending distinguishing evidence.

## Remaining limits and next step

No APK, emulator/Maestro, physical-device or live Realbooru validation was run.
Actual scrolling and visual relayout jumps remain unvalidated. Widget checks
cover the constrained layout behavior; keyboard checks do not apply to these
non-editable tiles.

The complete local application/package/CLI/tooling regression has **not** run.
Before integration, obtain merge authorization and run that complete suite on the
final combined develop candidate. Keep the issue open and retain the task branch
until the authorized publication/integration workflow is completed.
