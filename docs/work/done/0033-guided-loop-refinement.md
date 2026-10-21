# 0033 — Guided Loop Refinement and Seamless GIF Preview

> **Archive disposition (2026-10-20): Completed on `develop`.** The implementation is integrated. Earlier claims, status text, outstanding manual checks and verification notes below are historical, not an active local task.

Priority: Normal
Affected feature: Android GIF Editor / Video-to-GIF Export
Dependencies: IDEA-028 (Video-to-GIF, completed)
Status: Done (implemented on develop; historical follow-ups preserved)

## Trim-dialog follow-up

The requester approved Variant A (overview + detail), Start/End here, Source/Loop,
a preview-only slowdown control, and removal of timeline thumbnails. See
[Trim editor handoff](../../gif_trim_editor.md) for the implemented interaction,
preview frame-buffer approach, local integration fixes and manual review protocol.
The latest matcher and held-position Play behavior are preserved. This follow-up
supersedes the earlier inline pinch/thumbnail interface described in historical
progress entries below. Real-video and touch acceptance remain with the requester.

## Problem

The existing GIF editor lets users select a video segment for export as an infinitely looping GIF. Selecting the exact start and end of a seamless animation manually is difficult: a difference of even one or two frames can produce a visible jump.

An isolated Python/FFmpeg prototype (v4) demonstrated guided refinement of approximate user selections. Integrate that algorithm into Boorusama's existing Android GIF editor.

The current source-video preview loops the selected region through an asynchronous Dart-side `seekTo()` call. This introduces a perceptible interruption between repetitions and makes loop quality hard to judge. Fix the preview independently of the final GIF encoder.

Preserve the existing GIF conversion architecture, export settings, source ownership, and Save/Share behavior.

## 1. Expected user experience

### 1.1 Refine Loop

Add a localized **Refine Loop** button near the existing trim timeline.

1. The user selects approximately one complete animation cycle with the existing trim controls.
2. The user presses **Refine Loop**.
3. The app checks small regions around the selected start and end.
4. When a sufficiently convincing match is found, it adjusts the existing selection to exact frame boundaries.
5. The user can immediately review the revised loop, adjust it manually, or undo the refinement.

No separate screen, configuration dialog, automatic whole-video search, or additional timestamp inputs.

### 1.2 Visibility and availability

- **Hide Refine Loop for a full-source selection.** Show it only after the user moves at least one trim boundary inward; hide it again when the selection returns to the whole source.
- Account for timestamp rounding when distinguishing a full-source selection from a shortened one.
- Disable refinement while it is already running, during conversion, or in another incompatible editor state.
- Show a lightweight running indicator with a cancellation action; prevent duplicate operations.
- Do not start analysis automatically upon opening the editor.

### 1.3 Result types

- **`refined_repetition`:** A sequence after the proposed end matches the sequence at the proposed start. Apply the refined boundaries.
- **`seam_hint`:** There is insufficient subsequent footage to verify repetition, but the end-to-start visual transition is plausible. Because the user explicitly requested refinement, the suggested boundaries may be applied; do not claim that repetition was proven.
- **`no_reliable_match`:** No convincing candidate is found. Preserve the current selection and show short, non-disruptive feedback.

These classifications are internal; do not expose technical similarity scores, thresholds, or alternative candidate lists in the UI.

### 1.4 Undo and user state

- Store the previous start and end together before applying a successful refinement; provide a straightforward **Undo** action.
- Undo restores only the boundaries. FPS, playback speed, resolution, and other export settings remain unchanged.
- Normal manual trim adjustment remains available immediately afterward.
- Failures, cancellation, and outdated asynchronous results must never modify the current selection.
- Do not introduce user-facing sensitivity, search-width, or algorithm-mode controls.

## 2. Dynamic search radius

Compute a search radius from the duration of the **current selection**, capped at a conservative maximum:

```text
selectionDuration = selectedEnd - selectedStart
searchRadius = min(500 milliseconds, selectionDuration * 0.25)
```

Examples:

| Selected duration | Radius per boundary |
| --- | --- |
| 0.5 s | ±125 ms |
| 1.0 s | ±250 ms |
| 1.5 s | ±375 ms |
| 2.0 s | ±500 ms |
| 5.0 s | ±500 ms |

Let `S` and `E` be the currently selected start and end, `D` the source duration, and `R` the derived radius:

```text
startMin = max(0, S - R)
startMax = min(D, S + R)
endMin   = max(0, E - R)
endMax   = min(D, E + R)
```

Requirements:

- Search candidate starts and ends **only** within their respective windows, never beyond ±500 ms of either chosen boundary.
- Clamp windows to the known source duration; enforce existing minimum-selection-duration and GIF eligibility rules.
- Candidate boundaries must represent actual decoded source-frame timestamps or a valid exclusive source-end boundary; do not scan arbitrary timestamp increments.
- If the window contains no reliable candidate, keep the user's selection rather than expanding the window automatically.
- Isolate this radius formula so it can be tuned later without UI changes.

## 3. Guided detection algorithm

Port the behavior of the isolated **Boorusama Loop Detection Prototype v4** guided-refinement logic to the existing Flutter/Android architecture. Python code is a behavioral reference, not a runtime dependency. The rules below define the intended behavior when the archive is unavailable.

### 3.1 Inputs and result

The refinement service receives the prepared local MP4/WebM path, source metadata and duration, selected start/end, derived search radius, and a cancellation signal. It returns a result classification, proposed start/end if applicable, and internal diagnostics for testing/debugging.

The service must **not** mutate editor selection directly; the editor controller applies still-current results.

### 3.2 Region-limited decoding

Decode only the neighborhood required for candidate discovery and verification:

```text
decodeStart = max(0, S - R - 100ms)
decodeEnd   = min(D, E + R + 450ms)
```

Additional context allows boundary and short post-end sequence comparisons. The decoder may seek to an earlier keyframe if necessary, but unnecessary output frames should not be retained.

- Support selections anywhere within a source, including sources much longer than 30 seconds.
- Do not scan unrelated intro/outro footage or the entire source.
- Do not impose the old prototype's 30-second source limit or historical six-second trim limit on GIF export.
- Keep analysis work and memory bounded for long selections.

### 3.3 Frame fingerprints and timestamps

For every decoded original source frame in the analyzed region:

1. Preserve its presentation timestamp (PTS), normalized to the source timeline.
2. Apply the intended display rotation consistently.
3. Produce a compact grayscale fingerprint, nominally **64×64** pixels with consistent aspect-ratio normalization and stable area-style downscaling.
4. Store the fingerprint alongside its original PTS.

**Do not resample to a fixed FPS.** In particular, do not use FFmpeg's `fps` filter for detection: that can drop exactly the boundary frame being sought.

Support constant and variable frame rate. Align sequences using timestamps and a tolerance, not original frame indices or required exact timestamp equality. Reject unusable/non-monotonic timestamps instead of inventing frame positions. Obtain frame bytes and PTS from the same decode pass, or ensure equivalent reliable alignment.

### 3.4 Candidate generation

Generate start/end candidates from decoded source-frame timestamps falling within the two search windows; the known exact source end may also be an exclusive end.

Require:

```text
0 <= candidateStart < candidateEnd <= sourceDuration
```

Candidates must also satisfy existing GIF selection validity. Treat starts as inclusive and ends as exclusive: the last displayed frame precedes the candidate end.

### 3.5 Similarity metric

Use normalized mean absolute error over fingerprints:

```text
MAE(A, B) = mean(abs(A - B)) / 255
```

Lower is more similar. Use v4's thresholds as initial heuristics, not probabilistic confidence guarantees, and keep the constants independently configurable in code.

### 3.6 Reject static or visually uninformative candidates

A held frame, black screen, or nearly static segment may match nearly any proposed boundary. Require sufficient appearance variation across the proposed cycle:

```text
diversity = percentile_85(
    MAE(firstSelectedFrame, eachSelectedFrame)
)
require diversity >= 0.018
```

Keep a conservative no-match result for subtle motion rather than lowering the threshold simply to increase recall.

### 3.7 Verify a following repetition when footage is available

For a candidate period `T = candidateEnd - candidateStart`, compare the beginning of the selected segment with frames one cycle later:

```text
span = min(400ms, T * 0.45)
compare F(t) with F(t + T)
```

Match the nearest suitable source frame by PTS, within:

```text
tolerance = clamp(medianFrameInterval * 0.75, 18ms, 80ms)
```

Initial verification requirements:

- At least **three** timestamp-aligned frame pairs.
- Matching evidence spanning at least `min(160ms, span * 0.70)`.
- Mean normalized MAE ≤ **0.041**.
- 95th-percentile normalized MAE ≤ **0.077**.

Matching a single pair of boundary frames does **not** count as verified repetition. If enough subsequent footage is present and contradicts the proposed recurrence, reject the candidate; do not downgrade contradictory evidence into a seam hint.

### 3.8 Single-cycle seam assessment

When subsequent footage is insufficient for repetition verification, assess the prospective seam between the last included frame (just before the exclusive end) and the first included frame.

Compare seam error with normal adjacent-frame changes within the candidate:

```text
usualMotion = percentile_80(adjacentFrameMAE)
seamThreshold = min(0.075, max(0.010, usualMotion * 1.8))
seamValid = seamMAE <= seamThreshold
```

Require meaningful visual variation. Classify a plausible transition as `seam_hint`, not verified repetition. A seam hint must not override contrary evidence from available following frames.

### 3.9 Ranking valid candidates

Prefer stronger evidence in this order:

1. Verified following repetition.
2. Plausible seam with no contradicting repetition evidence.
3. No reliable match.

Within a category, prefer lower visual error and smaller movement from the user's selection.

For verified repetitions:

```text
displacement = (
    abs(candidateStart - S) + abs(candidateEnd - E)
) / R
score = meanSequenceMAE + 0.0015 * displacement + 0.10 * seamMAE
```

For plausible seams:

```text
score = seamMAE + 0.004 * displacement
```

Lowest score wins; break ties in favor of smaller displacement. Do not separately prefer the shortest or longest detected period: the user has already indicated approximately which cycle to keep. In particular, avoid shrinking a roughly one-second selection to an unrelated half-second subcycle merely because similar poses recur.

### 3.10 No-match outcomes

Keep the original selection whenever all candidates fail, including due to insufficient visual diversity, weak correspondence, contradicting following frames, missing frame/PTS alignment, invalid bounds, decode failure, or analysis resource limits. Do not force a nearby match to produce visible changes.

## 4. Performance, cancellation, and safety

### 4.1 Native frame extraction

Reuse the current Android FFmpegKit integration (`ffmpeg_kit_flutter_new_min` **3.6.7**) where suitable, verifying the actual minimal native build's available filters. No advanced similarity filters or machine-learning components are required.

Prefer one regional decode yielding PTS-aligned small grayscale fingerprints. Do not buffer full-resolution frames or retain unneeded intermediate video files.

### 4.2 Resource budgets

- Run detection off the UI thread; keep trim interaction responsive.
- Retain compact fingerprints only, not decoded full-resolution image history.
- Bound memory, decoded frames, and native allocations. Start with approximately **4,500 analyzed frames** as the provisional cap, then adjust only from engineering measurements.
- Bound work by the selected interval, not by the whole source duration.
- Exceeding a safety budget must not disable or change normal GIF export.

### 4.3 Cancellation and stale results

On cancellation, terminate active native decode work when possible, stop comparison work, and clean up temporary resources. Do not apply partial results.

Invalidate or cancel outstanding work when the user edits the trim, changes the source, closes the editor, explicitly cancels, or begins a conflicting operation. Guard result application with current-selection/source identity or generation IDs to prevent a late result overriding newer user input.

### 4.4 Source ownership

Use the already downloaded/prepared source and existing source lease lifecycle. Analysis must not modify the source or create another download. Preserve error propagation, cleanup, and native cancellation semantics. No remote state changes.

## 5. Preview playback improvements

### 5.1 Autoplay, resumable playback and temporary controls

Preserve the existing Play/Pause control; do not add another playback control.

- **Pause:** Freeze at the current position and leave the current frame visible.
- **Open:** Start the preview automatically.
- **Play:** Resume at the held position. If an edited selection no longer contains it, seek to the new selected start.
- **Background:** Suspend native playback while preserving user intent; resume on return only if playback was active before suspension.
- **Controls:** Hide the Pause overlay after two seconds of playback; tapping the video reveals it briefly. Keep Play visible while paused and controls available with accessible navigation.
- Editing selection boundaries or applying refinement must not unexpectedly resume a paused preview.
- Respect the existing playback-speed setting.

### 5.2 Continuous selected-region looping

The current video preview's Dart listener calls `seekTo(selection.start)` after reaching the selected end. Repeating this asynchronous seek introduces a gap and can make a correct loop appear broken.

Replace it with a mechanism that loops the **selected region** without an artificial hold or pause between cycles. Consider Android-native clipped looping playback, a temporary prepared preview segment with native looping, or another solution demonstrated to avoid repeated seek interruptions; select the simplest reliable integration.

Requirements:

- Loop exactly the active inclusive-start/exclusive-end interval, not the full source.
- Avoid duplicate/held boundary frames, decoder recreation per cycle, or gratuitous re-encoding while dragging trim handles.
- Honor playback speed and current selection changes.
- Keep preview state stable across many repetitions and after a refined selection is applied.
- Avoid adding artificial loop delays, or claiming gaplessness without technical evidence.
- Do not merely move the existing `seekTo()` trigger earlier as an unverified workaround.

### 5.3 Timeline navigation

The approved Trim-dialog follow-up uses a permanent source overview and an
image-free detail ruler, with explicit zoom controls and **To selection**.
Overview navigation and detail panning preserve trim; dragging visible edges or
a fully visible selected interval edits it. Navigation never automatically
follows playback. Display the current preview playhead, including decoded-buffer
playback. Timeline thumbnails are removed from this editor path.

Source-FPS preview changes are explicitly deferred by the requester; keep the existing source-FPS export setting and playback-speed preview.

### 5.4 Finished GIF preview

Preserve the existing finished-GIF preview, result actions, and GIF output timing. Preview playback fixes must not alter source FPS selection, GIF frame timing, palette generation, dithering, resolution choices, output validation, or the encoder pipeline.

## 6. Architecture and UI integration

Relevant existing files:

- `lib/core/posts/shares/src/gif_editor_page.dart`
- `lib/core/posts/shares/src/gif_editor_controller.dart`
- `lib/core/posts/shares/src/gif_editor_selection.dart`
- `lib/core/posts/shares/src/gif_conversion_service.dart`
- `lib/core/posts/shares/src/gif_ffmpeg_backend.dart`
- `lib/core/posts/shares/src/gif_ffmpeg_runner.dart`
- `lib/core/posts/shares/src/gif_export_contract.dart`

Keep algorithmic work in a small testable refinement service, separate from widgets. It should determine search windows, extract PTS-aligned fingerprints, generate and verify candidates, rank matches, and return a typed result. Keep progress, cancellation, undo, stale-result guards, and editor-state updates in the controller or established state-management layer.

Reuse the existing GIF preparation, leases, FFmpegKit runner, metadata/rotation handling, selection validation, and export pipeline. Do not create a parallel source-preparation stack.

The isolated Python/FFmpeg **Loop Detection Prototype v4** is a behavioral reference, not a production dependency. If new Python diagnostics are needed, manage dependencies through **uv**.

Follow Boorusama's established UI patterns: existing controls, spacing, typography, and localized strings via `context.t`. Reuse Kurumi components where applicable. Keep touch targets accessible on narrow displays and with enlarged text. Do not add an unrelated popup or menu style.

## 7. Acceptance criteria

### Guided refinement

- [ ] Refine Loop appears only for shortened selections and never starts automatically when the editor opens.
- [ ] The existing trim interval drives guided refinement; no user-facing search configuration is introduced.
- [ ] Search radius is 25% of selected duration, capped at **±500 ms per boundary**; source bounds and minimum trim validation are enforced.
- [ ] Candidate boundaries use original decoded source frames and PTS, without FPS resampling.
- [ ] The refinement service implements visual similarity, diversity rejection, following-sequence verification, single-cycle seam assessment, and candidate ranking as specified.
- [ ] Verified repetitions and plausible seams remain distinguishable internally.
- [ ] A successful refinement updates only start/end and can be undone.
- [ ] No reliable match, error, cancellation, or stale result leaves the current selection untouched.
- [ ] Longer source videos work with region-limited decoding; normal GIF export duration/size eligibility remains unchanged.
- [ ] Cancellation stops native work where possible and respects source ownership/cleanup.

### Preview

- [ ] Existing Play/Pause control is retained.
- [ ] Preview starts automatically; Pause holds the current frame and Play resumes at that position.
- [ ] Returning from the background restores the prior playback intent.
- [ ] Playing controls hide after two seconds and tapping the picture reveals them; paused and accessible controls stay available.
- [ ] Overview/detail navigation, explicit zoom and To selection work with long videos; horizontal panning preserves selection.
- [ ] The image-free timelines show current preview position without automatically scrolling.
- [ ] Automatic playback repeats the selected interval without an artificial inter-loop pause.
- [ ] Preview respects current trim, playback speed, and paused/playing state when settings change or refinement completes.
- [ ] Finished-GIF playback and encoded output timing are unchanged.

### Integration and quality

- [ ] Follow established Boorusama UI conventions and localization.
- [ ] Do not ship a Python runtime or unnecessary native dependencies.
- [ ] Preserve existing source leases, cancellation, and cleanup behavior.
- [ ] Add focused automated tests for radius calculation, frame/timestamp handling, candidate classification/ranking, no-match behavior, selection/undo state, cancellation, and preview controls.
- [ ] Run the normal repository checks required by `AGENTS.md`, including the complete local test suite; report any blocked verification honestly.
- [ ] GIF encoding, downloads, Save/Share, and the measured **100-MB output ceiling** remain unchanged.

**Manual acceptance:** The requester will evaluate the actual refinement accuracy and visual loop continuity with real videos after implementation. The implementer is **not** required to assemble, download, annotate, or verify a real-world sample corpus as part of this work item. This does not waive automated regression tests or standard repository checks.

## 8. Non-goals

- Fully automatic whole-video loop detection or auto-refinement when opening the editor.
- User-configurable search radius, sensitivity, or thresholds.
- Machine learning, optical flow, or new heavyweight native dependencies.
- Identifying multiple unrelated loops in one source.
- Changing GIF encoding quality, compression, timing, export duration limits, downloads, Save/Share, or unrelated media players.
- A real-world video sample verification campaign by the implementing agent.

## 9. Context and workflow

Related documents:

- `docs/work/done/IDEA-028-video-to-gif.md`
- `docs/gif_conversion_evaluation.md`
- `docs/gif_loop_detection_handoff.md`
- Isolated Python/FFmpeg Loop Detection Prototype v4

Follow `AGENTS.md` and `docs/work/README.md`. Implement in a dedicated task branch and worktree; do not reuse or modify an active feature worktree without coordination. When claiming, record implementer/session, branch, and worktree. Keep scope restricted to the guided refinement and GIF-editor preview changes; do not modify remote state as part of implementation.


## Implementation progress — 2026-10-10

- Implementer/session: OpenAI, guided GIF refinement implementation.
- Branch: `feature/guided-gif-loop-refinement`.
- Base: `develop` at `f4972eb54119fce98360c4c2303bbce375b8e722`.
- Isolated editing worktree: `/mnt/data/Boorusama-guided-loop`.
- Environment: Git clone is blocked by network/DNS restrictions; relevant files
  are read through the connected GitHub API at the pinned base. The local
  worktree is a partial source snapshot, not a complete Flutter checkout.
- Publication uses a Git tree based on the original upstream tree, retaining
  all unmodified repository files. No merge or PR is requested.
- Flutter/FVM/Android tooling is not installed in this environment. Required
  Dart formatting, analysis, complete repository tests and Android validation
  remain outstanding; do not treat this item as done without those checks.

### Implemented in this branch

- Guided pure-Dart matcher with original PTS, the specified dynamic radius,
  sequence/seam classification and conservative no-match behavior. Uses a
  capped pairwise-error cache; no sampling or candidate thinning on overflow.
- An FFmpeg raw-gray extraction capability on the existing session runner.
  Integer PTS/time-base records and frame bytes come from the same decode.
  Native work is cancelled per session and awaited before deleting its files.
- Source-lease retention, off-UI-isolate comparison, cancellation, trim-only Undo,
  stale-selection rejection and revalidation through existing export rules.
- Localized Refine Loop/Cancel/Undo controls in the current trim editor. New
  English/German strings use Slang supplemental wildcard-locale JSON files;
  normal i18n generation merges them without modifying existing translations.
  The language-list generator ignores these files because they do not declare
  a language name. Other locales keep the existing English fallback policy.
- An editor-local media_kit/libmpv A/B-loop preview using the dependency already
  present in the application. Native repetition replaces Dart position polling.
  Pause holds the current frame; Play seeks precisely to the selected start.
  Serialized updates prevent a stale operation from resuming a paused preview.
  Native decoder-dependent seam continuity is NOT yet verified on Android.
- No final encoder, GIF timing/quality, source preparation/download, Save/Share,
  dependency version or output-size validation changes.

### Checks actually performed and remaining blockers

- Matched all three edited existing source files byte-for-byte to their upstream
  Git blob SHA before patching; the partial checkout is not an invented base.
- Host FFmpeg extraction check on synthetic CFR, VFR and nonzero-start MP4s:
  51, 41 and 51 extracted frames respectively, with exact normalized source PTS
  correspondence. A context-end rounding frame can be present within one stream
  time-base tick; candidate bounds are independently enforced. This tests the
  extraction command, NOT the Dart implementation or Android native binary.
- Both supplemental translation JSON files parse successfully.
- Added 29 focused Dart/widget test definitions for algorithm, frame extraction,
  editor state/Undo/cancellation, playback serialization and narrow UI layout.
  They have NOT been executed here.
- Attempts to run `fvm dart format`, `fvm flutter analyze`, and the required
  application test suite fail because `fvm` is not installed. Package suites,
  repository tooling suites and i18n generation are also unrun: the environment
  has neither a complete checkout nor a Flutter SDK. No CI pass is claimed.
- Before integration: use a complete checkout, install dependencies with the
  pinned FVM SDK, run `./gen.sh i18n` (and other required fresh-checkout generation),
  format/analyze the affected files, run the focused tests and the entire local
  suite specified in `docs/engineering_guidelines.md`. Fix any compilation,
  generation, native API or test issues exposed there. This branch is an
  implementation for local validation, not a verified merge-ready change.
- Real-video quality and visual loop continuity remain the requester's manual
  acceptance, as agreed. No real-world sample corpus was added or evaluated.

## Local completion handoff — 2026-10-10

This section supersedes the earlier environment blockers and supplemental-locale
assumptions. Feature acceptance remains in progress until the requester evaluates
refinement accuracy and visible loop continuity on real videos.

- Implementer: Codex, local continuation of the existing implementation.
- Branch: `feature/guided-gif-loop-refinement`, continuing `2e1222bba7` without
  reset, redesign, integration, or publication.
- Actual complete worktree:
  `/home/timber/code/Boorusama/.worktrees/guided-gif-loop-refinement`.
- Bootstrap: pinned FVM Flutter 3.47.2, root dependency resolution, CLI dependency
  resolution, `./gen.sh`, and an explicit `./gen.sh i18n` all succeeded.

### Significant fixes

- Repository i18n validation rejected the supplemental `[en]-US.json` and
  `[de]-DE.json` files. Moved their six keys into the conventional `en-US.json`
  and `de-DE.json` files and removed the supplements. Slang now validates and
  generates the required accessors with the ordinary 23 locales, including one
  English and one German locale; existing translations were preserved.
- Contradictory following footage now rejects a candidate even when fewer than
  three pairs are available. Previously it could become a seam-only success.
  The existing similarity thresholds and conservative search radius are unchanged.
- Preview initialization awaits asynchronous video-output creation and source
  metadata before seeking. Failed output creation is handled, and the Android-only
  native adapter is not initialized by desktop widget hosts.
- The locked media_kit 1.2.6 `setProperty` ignores native return codes. The adapter
  now reads loop properties back and rejects unapplied values. Renderer errors
  from `vo/*`, omitted by that version's `stream.error`, also disable the preview.
- Preview notifier disposal now calls its superclass exactly once while retaining
  serialized native shutdown. Fixed the generated-localization test import and
  the widget test's completer creation zone, then formatted all implementation
  and focused-test Dart files with FVM.
- Added regression coverage for contradicting partial following footage,
  cancellation waiting for native completion before deleting frame files, and
  native preview failure pausing playback and preventing subsequent Play.
- Encoder quality/timing, export settings and eligibility, source preparation,
  downloads, Save/Share, dependency versions and the measured 100-MB ceiling were
  not changed.

### Executed technical checks

- Affected analysis (`lib/core/posts/shares/src` and `test/core/posts/shares`):
  **No issues found** after the final implementation changes.
- Four focused guided-loop suites: **32 tests passed**. Existing
  `share_sheet_gif_test.dart`: **15 tests passed**; combined run **47 passed**.
  These cover narrow widths, 2x text and keyboard insets as applicable.
- Initial complete local run exposed nine GIF sharing/widget failures caused by
  native output initialization on the desktop host. Those integration failures
  were corrected and the entire 15-test GIF sharing suite reran successfully.
  All 12 package/CLI suites and all three repository-tooling suites in that first
  complete run passed. A superseded application rerun was stopped after further
  renderer-error handling was added; it is not counted as a completed check.
- Exclusive emulator: `emulator-5556`. A temporary synthetic-only Dart harness
  exercised the production frame decoder and preview controller with a verbatim
  copy of the private native adapter. Native FFmpeg yielded **30 CFR frames**
  with exact original PTS. Regional timestamp checks matched the source PTS for
  a nonzero-origin source (**18 frames**), VFR (**12 frames**), and a rotated
  source (**18 frames**).
- With video decoding enabled and libmpv output set to `null`, native assertions
  passed for pause holding position, Play restarting at the selected start,
  an EOF-ending range looping within `[2s, 3s)`, rapid range changes followed by
  Pause, property readback and disposal. This is command/decoder integration
  evidence, not visual continuity or an editor UI acceptance pass.
- Visible output on that emulator failed when its EGL/GPU surface was attached
  (`EGL_BAD_ATTRIBUTE`), unloading the native track. Renderer failure now has
  explicit preview error handling. Maestro MCP discovery returned no Android
  devices, although ADB could address the leased emulator; no Maestro UI flow
  or physical-phone operation was performed. App data was not cleared.
- The normal Android development build command is
  `fvm flutter build apk --debug --flavor dev --no-pub`. The first normal build
  succeeded; the final normal artifact is rebuilt after the integration fixes,
  replacing the temporary harness artifact. Delivery path:
  `/home/timber/code/Boorusama/.worktrees/guided-gif-loop-refinement/build/app/outputs/flutter-apk/app-dev-debug.apk`.

### Final local commit gate and remaining acceptance

After this documentation edit, rerun the complete suite from
`docs/engineering_guidelines.md`: application tests with concurrency 2, all 12
package/CLI suites, PR-policy tests, Android-release script tests, and Python
repository-tooling tests. Commit locally only after all 16 suites exit
successfully and the final normal APK build succeeds. The final handoff reports
those observed results and the local commit; the earlier failed/incomplete runs
above do not satisfy this gate.

Keep this item in progress. The requester still needs to assess real-video
refinement accuracy, actual displayed frame transitions, and perceived loop
continuity on their device. No real-world samples were downloaded or evaluated,
no visual gaplessness is claimed, and no push, PR, merge or release is authorized.


## Preview and timeline follow-up — 2026-10-11

This follow-up supersedes the historical restart-on-Play behavior recorded above.
It continues `feature/guided-gif-loop-refinement` in the same isolated worktree;
no integration or remote publication is authorized.

### Approved behavior and implementation

- Autoplay, Pause/Play at the held position, preserved playback intent across
  background suspension, and a two-second transient Pause overlay. Tapping the
  picture reveals controls without toggling playback. Accessible navigation
  retains visible controls.
- Pinch zoom initially centers the selected interval. Later gestures anchor to
  the fingers, and horizontal scrolling preserves trim. The time ruler provides
  an unambiguous pan surface alongside existing trim-edge/window dragging.
- The cursor follows actual native position without recentering the timeline.
  Regional thumbnails debounce requests, cancel stale native work, retain the
  source lease until native completion, and cache at most six strips. Five
  targeted single-frame seeks avoid decoding a whole long visible interval.
- The refinement radius is now 25% of selected duration capped at 500 ms per
  boundary. Similarity thresholds and original-PTS matching remain unchanged.
- The production native adapter is extracted into a reusable class so the
  Android smoke harness exercises the exact adapter used by the editor.

### FPS preview explicitly deferred

The requester chose to defer source-FPS preview changes and complete the other
changes. The pinned native player lacks the required FPS/timestamp filters;
Android rejected `setpts`. Both upstream prebuilt variants disable general
filters, including the nominal Full variant:
[default build](https://raw.githubusercontent.com/media-kit/libmpv-android-video-build/v1.1.7/buildscripts/flavors/default.sh),
[Full build](https://raw.githubusercontent.com/media-kit/libmpv-android-video-build/v1.1.7/buildscripts/flavors/full.sh).
A custom native build or asynchronously generated preview clips would require
separate scope. Experimental filters were removed. Native dependencies, GIF
encoding/timing and export settings are unchanged; playback-speed preview remains.

### Verification and delivery gate

Focused tests cover autoplay/resume/background state, control visibility and
accessibility, selection-anchored zoom and pan, trim after zoom, native-position
cursor movement, thumbnail cancellation/cache/source ownership, the increased
radius, and real host-FFmpeg regional output. Narrow-width widget checks use 2x
text and keyboard insets where applicable. A headless Android smoke test using
the production adapter passed autoplay, held-position resume, background intent,
and EOF-ending looping. The production Android FFmpeg backend also produced
the expected 480x56 regional strip from five targeted frames. This is native
command/decoder evidence, not visual
continuity acceptance. Maestro discovery did not expose an Android device; no
Maestro UI flow or physical-phone operation was performed, and app data was not
cleared.

After this last documentation edit, rerun affected analysis, focused tests, and
all 16 complete-local-suite checks (application, 12 package/CLI suites and three
repository-tooling suites). Commit locally only after those checks succeed and
the normal Dev APK is rebuilt, replacing the temporary native harness artifact.
The final handoff records observed results, the local commit and APK path.
Keep the work item in progress pending requester assessment of real-video
refinement accuracy, visible loop continuity, and touch interaction on device.
