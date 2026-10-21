# GIF Trim editor

The integrated editor uses the approved overview/detail Trim dialog. Guided
loop refinement, preview-only decoded-frame looping, resume behavior and
background intent are part of the current implementation. The matcher has a
500-ms maximum boundary search radius; preview speed is separate from encoded
GIF speed. Historical development and device acceptance notes remain available
in Git history.

## Interaction

The exporter shows a **Trim** action and selection summary instead of inline
trim/zoom/refinement controls. It opens a full-screen subdialog with an independent
draft controller. **Apply** returns only start/end; Cancel, Close and system Back
discard edits and cancel draft refinement. Export resolution, retained FPS,
playback speed, quality, output-size checks and Save/Share are not changed.

The Trim subdialog has a permanent source overview and a separate detail ruler.
Both are image-free. Overview taps and one-finger drags navigate and scrub; they
never move trim handles. On the detail ruler, empty-track dragging pans, visible
handles trim, and dragging a fully visible selection moves it. When the selection
extends beyond the viewport, dragging its highlight pans rather than moving an
invisible full selection. Tap to scrub, then use **Start here / End here**.
Scrubbing explicitly pauses, while the existing Play action resumes at that point.

**Source / Loop** changes the preview's playback range only. Seeking outside the
selection returns to Source mode, so long-video navigation remains possible.
**Preview speed** offers 25%, 50%, 75% and 100% of source-time playback; these
values never enter `GifEditorSelection.speedPreset` or the final encode plan.

The overview initially exposes an eight-second detail viewport for long sources.
Existing partial selections are initially focused. **To selection**, Apply and
Adjust center the selection in a viewport twice its duration where the source
bounds permit it. Viewport and preview preferences are owned by the exporter
route, so rebuilding/closing the Trim subdialog does not reset them. Pinch is
not required. Plus/minus controls provide explicit zoom. Navigation alone does
not continually auto-fit the selection while a handle is being dragged.

Initial and regional thumbnail requests are removed from this editor path. The
legacy thumbnail backend/data types remain for compatibility; this is not an
unrelated deletion of every thumbnail utility or existing test.

## Guided refinement behavior

**Refine Loop** is available for a shortened source selection and runs only on
request. The service examines source-frame timestamps near the selected start
and end, with a conservative radius (25% of the chosen duration, capped at
500 ms per boundary). It preserves presentation timestamps, rejects static
or visually uninformative matches, distinguishes verified repetitions from
plausible but unverified seams, and leaves the selection untouched when no
reliable candidate exists. Decoding and matching are bounded; cancellation,
source changes and newer trim edits invalidate outstanding results. Applied
refinements adjust only start/end and can be undone without changing export
settings. Native decoding constraints impose no new GIF export limits.

## Preview seam mechanism

An A/B-loop native seek can still pause at every repetition. For small selected
loops this patch adds a preview-only, bounded decoded-frame path:

1. Debounce boundary changes by 350 ms.
2. Decode the local selected interval once with the existing FFmpegKit runner,
   retaining original PTS and all retained frames; no FPS filter or re-encoding.
3. Extract raw RGBA frames and same-session integer `showinfo` PTS. Reject missing,
   changing or inconsistent frame/time-base records instead of inventing timing.
4. Downscale the preview to at most 360 pixels on its longest edge and at most
   24 MiB of raw pixels; reject rather than retain more than 600 frames. Native
   decoder allocations and `ui.Image` copies are additional, not included in the
   24-MiB figure. A smaller preview or native fallback is possible for long/high-
   frame-rate selections. These are analysis limits, never export limits.
5. Schedule decoded images with a PTS-based clock and modulo the selected duration.
   There is no native seek or decoder restart at each buffered loop seam. Fractional
   manual starts display the first retained frame from trim start; subsequent PTS
   and the requested interval duration are preserved. Frame-aligned Refine results
   do not need that leading-frame adjustment.
6. Keep the native player for Source mode, unsupported/large selections and decode
   failures. The UI explicitly labels native fallback as possibly pausing at the
   boundary; it must not be described as a smooth-preview success.

Buffer adoption is serialized through the existing preview controller, alongside
range/seek/pause commands. Stale work cannot publish a buffer for a different
range. Preparation is cancelled on range/mode changes, backgrounding, refinement,
conversion and closing. The runner waits for native completion before temporary
files are deleted. Source leases remain retained until writers are done. Old
images are retired after a rendered frame, not disposed while RawImage may use
them. Closing waits for in-flight decode work before native player disposal.

This removes the per-cycle seek from the buffered path. A synthetic Android
integration probe exercised the production FFmpegKit decoder, actual `ui.Image`
frames in `RawImage`, buffer adoption and repeated playback without native seam
seeks. Device memory, rendering cadence and perceived continuity with the
requester's real videos remain manual acceptance checks.

## Local integration fixes and checks

The latest remote follow-up was fetched and integrated into the existing isolated
task worktree at `f3d2debbea57f405ba90f49cc1c4f2439e39218a`. Local fixes cover:

- Complete adjustable-handle semantics, including the next/previous values
  required by Flutter accessibility assertions.
- Restoring the held playhead when an exporter preview is recreated after Trim;
  Apply clamps an out-of-range playhead to the new start. Paused/playing intent
  survives both Apply and Cancel.
- Explicitly retiring a decoded buffer on switching to Source mode, even when
  the full-source playback bounds are unchanged; native playback resumes at the
  held position with the prior playback intent.
- Updated sharing integration tests for the dedicated dialog, including narrow
  English/German layouts at 2x text, scrolling, draft trim gestures and keyboard
  insets. Old inline-control expectations were removed.
- Formatting and scoped analyzer fixes for the incoming implementation.

Focused regression runs passed for the Trim dialog, sharing flows, held-position
restoration and decoded-buffer lifecycle. The buffer tests use real `ui.Image`
objects and cover seeking, paused/playing Source handoff, modulo looping without
native seeks, stale decode cancellation and image disposal. Affected-scope
analysis reports no issues. The Android synthetic probe additionally checked
held initialization, scrub/pause, foreground playback intent and range replacement.

After the last edit, run all GIF/Share tests, the complete 16-suite local gate
(application, 12 package/CLI suites and three tooling suites) and rebuild the
normal Dev APK. The temporary native probe is not a deliverable. The final
handoff records the observed gate results, local commit and normal APK path.
No remote publication or integration is implicit.

Source-FPS preview remains explicitly deferred. Export FPS, output timing and
native player dependencies are unchanged.

## Preview layout and Source cursor follow-up — 2026-10-13

Both preview surfaces now use the source's display aspect ratio, including
rotation and sample aspect ratio. Their height is a maximum, not a reserved
letterbox. Tight media bounds also prevent the Trim preview from collapsing to
the Play/Pause button width after loading. Portrait videos remain proportional
within the available height.

Trim places Source/Loop and a Kurumi preview-speed menu in one wrapping toolbar.
Zoom/focus share the overview heading; Start/End here share the available width.
The detail track is more compact while its draggable selection and handles keep
48-pixel targets. Longer instructions remain available through tooltips and
semantics. The content can still scroll on smaller screens or with enlarged text.
Regression checks cover 1152×720 in both previews, the main Trim actions without
scrolling at 390×844 in English/German, enlarged text and keyboard insets where
applicable, plus portrait/rotated/anamorphic source dimensions.

The Source playhead interpolates native timestamps on display frames, honoring
preview speed, playback intent, buffering and lifecycle suspension. Authoritative
native samples reset it after seeks and loop wraps. Extrapolation is bounded if
samples stop, and the cursor remains within the active range. Buffered Loop
playback retains its existing frame clock. This changes timeline presentation;
it does not increase source-video FPS or alter export timing. Review a roughly
one-second source in both modes to assess visible cursor continuity on device.

## Boundary controls and single-row size selection — 2026-10-13

Start/End here are available at every cursor position. Setting Start at or beyond
an incompatible current end opens the interval to the source end; setting End
at or before an incompatible current start opens it from zero. The existing
minimum selection duration still applies, including at exact source start/end
and for sources shorter than that minimum. Handle dragging keeps its existing
clamps.

Two labelled Start/End groups each contain previous-frame, next-frame and
set-at-cursor icons. All six controls remain on one row with 48-pixel targets;
only views narrower than their combined minimum width scroll horizontally.
Frame nudges change only the corresponding boundary and stop at source/minimum
window limits. Their interval is one nominal source frame (`1 / source FPS`),
independent of export FPS or either speed setting. Variable-frame-rate sources
therefore use their reported average cadence rather than individual decoded PTS.

Resolution chips, including Original, stay in one horizontal row. The row scrolls
when labels do not fit, including with enlarged text. Selection is still shown by
chip colour and accessibility state. Regression checks cover out-of-window
setting, source extremes, fractional source FPS, six buttons at 320px/2x text in
English/German, and scrolling to Original without a second line.

## Manual review protocol

1. Open GIF export on a long video. Confirm automatic playback, the moving
   playhead and transient Pause overlay. Pause and resume at the held position;
   background/return once playing and once paused.
2. Open Trim. Browse a distant point in the overview, pan the detail ruler, use
   zoom and **To selection**, then move each edge and the selected interval.
   Navigation should preserve the selection and avoid following playback.
3. Scrub inside and outside the current selection, use **Start here / End here**
   and each one-frame arrow, toggle Source/Loop, and try each preview speed. Check that Source resumes native playback and preview speed does not
   change the export speed setting.
4. Cancel a changed draft and confirm the exporter boundaries and held playhead
   survive. Reopen, Apply another draft, and confirm only its boundaries return.
5. Refine a shortened selection and Undo. Check the suggested boundaries and
   loop transition against the source video; repeat with several small loops
   and a selection that shows the explicit native fallback status.
6. Scroll the single-row size selector to Original where needed, then Save and
   Share an export with the usual FPS, speed and resolution controls.
   Compare the resulting GIF and preview, including playback after several loops.

The requester will assess refinement accuracy, touch interaction and displayed
loop continuity with their own videos. No Danbooru corpus, downloads of real
samples or additional manual sample-verification campaign is required here.
This implementation has reached `develop`. The protocol above remains useful
for manual regression checks; newly discovered defects belong in GitHub Issues,
not in a restored local work-item queue.
