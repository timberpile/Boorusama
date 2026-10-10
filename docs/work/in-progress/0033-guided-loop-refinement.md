# 0033 — Guided Loop Refinement and Seamless GIF Preview

Priority: Normal
Affected feature: Android GIF Editor / Video-to-GIF Export
Dependencies: IDEA-028 (Video-to-GIF, completed)
Status: In progress

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
searchRadius = min(350 milliseconds, selectionDuration * 0.25)
```

Examples:

| Selected duration | Radius per boundary |
| --- | --- |
| 0.5 s | ±125 ms |
| 1.0 s | ±250 ms |
| 1.5 s | ±350 ms |
| 2.0 s | ±350 ms |
| 5.0 s | ±350 ms |

Let `S` and `E` be the currently selected start and end, `D` the source duration, and `R` the derived radius:

```text
startMin = max(0, S - R)
startMax = min(D, S + R)
endMin   = max(0, E - R)
endMax   = min(D, E + R)
```

Requirements:

- Search candidate starts and ends **only** within their respective windows, never beyond ±350 ms of either chosen boundary.
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

### 5.1 Retain Play/Pause with restart-on-Play

Preserve the existing Play/Pause control; do not add another playback control.

- **Pause:** Freeze at the current position and leave the current frame visible.
- **Play:** Always restart at the **selected trim start**, including when the preview was paused in the middle; never resume from the paused position.
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

### 5.3 Finished GIF preview

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
- [ ] Search radius is 25% of selected duration, capped at **±350 ms per boundary**; source bounds and minimum trim validation are enforced.
- [ ] Candidate boundaries use original decoded source frames and PTS, without FPS resampling.
- [ ] The refinement service implements visual similarity, diversity rejection, following-sequence verification, single-cycle seam assessment, and candidate ranking as specified.
- [ ] Verified repetitions and plausible seams remain distinguishable internally.
- [ ] A successful refinement updates only start/end and can be undone.
- [ ] No reliable match, error, cancellation, or stale result leaves the current selection untouched.
- [ ] Longer source videos work with region-limited decoding; normal GIF export duration/size eligibility remains unchanged.
- [ ] Cancellation stops native work where possible and respects source ownership/cleanup.

### Preview

- [ ] Existing Play/Pause control is retained.
- [ ] Pause holds the current frame; pressing Play **always restarts from the selected beginning**.
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
