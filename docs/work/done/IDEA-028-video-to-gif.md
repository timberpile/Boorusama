# IDEA-028 — Experimental video to GIF

- Priority: Normal
- Feature: Android GIF editor in the unified Share dialog, with configurable trim, frames, playback speed, Save and Share
- Claimed by: `/root/implement_28_gif_experiment`, 2026-10-03
- Source: approved experimental item 28 in `/tmp/ready_ideas_review_checklist.md`

## Problem and expected behavior

The app can save and share videos but has no verified video-to-GIF encoder. The first milestone establishes one reusable, testable conversion contract and evaluates native backends. The original milestone did not expose an action; encoder and Android prototype scope were approved on 2026-10-07 (see below).

## Accepted Android prototype scope

The user approved local integration on 2026-10-08. Later requested behavior supersedes the historical contract-only limits below.

- Android GIF creation appears as a GIF media row below Video with a single Create GIF action, opening the editor after one complete-source preparation.
- The initial trim selects the full video; trim handles and a movable window allow shorter clips. Complete MP4/WebM sources with known duration have no maximum-length gate.
- Resolution presets cap the longest display edge, use 360/480/640/720/Original in ascending order, and default to 480 when it reduces the source. Source FPS and playback speed are independent.
- The approximate size updates immediately; above decimal 20 MB it shows yellow text and a trailing warning icon. Only measured output above 100 MB is rejected.
- The preview stays visible above controls. Results offer Adjust/Save/Share in one row; Save uses the configured download folder, and Share retains the existing owned media handoff.
- Android encoding continues while backgrounded until cancellation, with a cancellable foreground notification and cleanup that waits for native work. Source/output ownership remains safe during cancellation, retry, preview, and pending handoffs.
- Focused Dart/widget, host FFmpeg, and native file-transfer checks establish the implemented prototype behavior. Broader device/codec/resource and release qualification remain explicitly documented; loop detection remains a separate research handoff.

## Historical acceptance criteria for the contract milestone

- A platform-independent contract represents complete MP4/WebM source metadata, trim, independent resolution and frame-rate choices, encoder progress, cancellation, and explicit failure reasons.
- The shared media preparation downloads a source video once; a fake encoder can produce a temporary GIF lease through the same cleanup path. Source and output paths differ, and neither failure nor cancellation leaves an output file or deletes the source cache.
- Exactly 30 seconds is eligible; longer, unknown-duration, or incomplete sources are rejected. Default trim starts at playback position or zero and lasts at most six seconds. Original dimensions account for rotation; Original frame rate requires decoder metadata.
- A result above 25 MB (25,000,000 bytes) is rejected and deleted. The expected 15 MB target is advisory. Save and Share must later call the same conversion service and trim/settings UI.
- Backend evaluation records license, ABI size, MP4/WebM support, cancellation, progress, orientation, cleanup, and failure behavior. No native dependency is added in this milestone.

## Dependencies and boundary

Historical experimental gates are retained below as evidence. The branch is now based on current local develop, which includes the unified Share flow. The user selected `ffmpeg_kit_flutter_new_min` and approved an Android-only prototype in the Share dialog on 2026-10-07. Media downloads are explicitly excluded from item 07 coordination; the previous dependency was incorrect. Configurable Save/Share are implemented; broader device and release qualification remain follow-up work outside the accepted prototype.

## Progress

Worktree: `.worktrees/idea-28-gif-experiment`, branch `feature/28-gif-experiment`.

The experimental milestone provides a pure plan and metadata contract plus an injectable encoder interface. A fake encoder proves that item 29's video preparation, staged progress, a separate GIF output lease, cancellation, failed-encode cleanup, and the decimal 25-MB limit compose without a native dependency. Source metadata governs 30-second eligibility, rotation-adjusted Original resolution, decoder-provided Original FPS, and trim bounds. The current normal Video Save/Share UI is unchanged; no GIF action appears.

RED/GREEN evidence: initial plan and lifecycle tests failed because their implementations did not exist; a cache-reuse probe demonstrated that the generic video share preparation makes a network request. That generic path was deliberately left unchanged because a signature-only cache check could treat an incomplete video as shareable. A 25,000,001-byte boundary test failed under the initial binary-MiB calculation and passed after changing the ceiling to decimal MB.

Verification on 2026-10-03: `./gen.sh` succeeded, 57 Share/GIF tests passed, targeted Dart analysis reported no issues, `git diff --check` passed, and the full `fvm flutter test --no-pub --reporter compact` suite passed 1,794 tests. No visible GIF UI or production encoder exists, so Maestro and real conversion output could not be meaningfully verified. See `docs/gif_conversion_evaluation.md` for the backend comparison and open measurements.

Independent review repair: Output deletion and source release now run best-effort independently, with secondary cleanup failures attached to the original conversion error. Original FPS is available only for finite decoder values from 1 through 100; fixed choices are unaffected. Backend output validation is required before returning a GIF lease, and the plan rejects canvas dimensions beyond 65,535 or a scaled side that would round to zero. RED/GREEN regression tests cover cleanup-error ordering, an extreme 1e9 FPS, a header-only corrupt GIF, and unrepresentable aspect/dimensions. Real backend validation, looping, frame accuracy, and device memory measurements remain blocked.

Review-fix verification on 2026-10-03: 72 Share/GIF tests passed, targeted Dart analysis found no issues, `git diff --check` passed, and the full Flutter suite passed 1,809 tests. This verifies the experimental contract only; the task remains blocked for the native/backend and product decisions below.

Final cancellation-race repair: cancellation is checked immediately after asynchronous output validation, before a failed validation can be reported as corrupt output. It is checked again after source release; cancellation during that cleanup deletes/releases the produced GIF instead of returning its lease. Completer-controlled tests proved both races before the fix and now pass. Verification on 2026-10-03: 74 Share/GIF tests and 1,811 full-suite tests passed; targeted Dart analysis found no issues. The task remains blocked.

Independent review fixes on 2026-10-03: custom trims now stop at six seconds; the plan carries rotation and required sample pixel aspect ratio; oversized source and output frames are rejected against a provisional 3840×2160 area cap and a 160 MB backend working-memory budget. The backend contract requires closed writers and read-only, plan-accurate output validation. The service checks the exact output again after validation and source release, and cancellation wins over a concurrent typed adapter error while retaining its cause. Lifecycle tests use explicit stubbed validation verdicts; the fake does not prove a looping or plan-accurate GIF. Expired temporary GIF cleanup is covered by the shared age-sweep test. No native dependency, backend selection, or visible UI was added.

Verification: 84 Share/GIF tests passed, targeted Dart analysis found no issues, formatting and `git diff --check` passed, and the final full Flutter suite passed 1,821 tests. Two intermediate full runs each had a different isolated test failure (search pin action and unsupported-media Share sheet); their respective test files passed alone, and the final full run passed. The native-hook “File modified during build” message occurred with passing runs as documented in `docs/development_workflow.md`. Device behavior, native memory use, loop/timing validation, and final output handoff remain unmeasured.

Independent re-review repair on 2026-10-03: the backend contract now requires structured whole-file observations instead of a boolean. The service compares full-decode success, canvas and per-frame canvas agreement, frame count, per-frame centisecond delays, total duration, and explicit infinite looping against the export plan before returning a lease. The tolerance and its limits are recorded in `docs/gif_conversion_evaluation.md`; lifecycle tests use declared stubbed evidence and do not prove the bytes match it. RED tests showed twelve mismatched reports escaping as leases before the service check, and a separate low-FPS case exposed an overly broad duration tolerance. Those cases now reject and clean up output.

Verification: 97 Share/GIF tests passed; targeted Dart analysis found no issues; the serial full Flutter suite (`--concurrency=1`) passed 1,834 tests. Two default-concurrency full runs failed in an unrelated bulk-download test whose asynchronous callback read a disposed Riverpod container; that file passed 33 tests in isolation. Native whole-file decoding, frame timing and loop parsing, atomic output handoff, and device measurements remain unverified; the task stays blocked.

Final animation-invariant repair on 2026-10-03: every video-to-GIF output must contain at least two decoded frames, even when a direct plan's expected sample count is one. Plan preflight requires two complete frame periods at the effective FPS, using integer microseconds so a 1-FPS trim of exactly two seconds is accepted and any shorter trim is rejected. RED tests demonstrated both the one-frame lease escape and the short-plan acceptance; the boundary and a two-frame stubbed lifecycle are GREEN. The GIF centisecond delay and capped duration tolerances remain unchanged. This is still only a Dart contract: the eventual backend must decode the complete output and supply observed evidence.

Verification: 102 Share/GIF tests passed; targeted Dart analysis found no issues; formatting and `git diff --check` passed; the serial full Flutter suite (`--concurrency=1`) passed 1,839 tests. The known native-hook “File modified during build” message accompanied the successful full-suite exit. No real GIF output or device behavior was verified.

## Historical blocker after the contract-only milestone

No production encoder has been selected or licensed, and no platform milestone has been approved. Binary/ABI size, actual MP4/WebM codec coverage, orientation, progress, cancellation, decodability, quality, and memory pressure are unmeasured. Safe cached-source reuse, the shared Save/Share trim sheet, item 07 request coordination, and foreground interruption wiring also remain. The visible action must remain unavailable until native output can be measured and validated on real devices and the product decisions in the evaluation are approved.


## Android prototype follow-up (2026-10-07)

User selected `ffmpeg_kit_flutter_new_min`, approved Android-only support, and requested a testable prototype with a GIF creation action in the Share dialog. This supersedes the historical encoder/platform gates above for the prototype. Reused the same isolated worktree/branch and rebased its six contract commits onto current local develop without replaying unrelated Share history.

The Media tab now offers “Create GIF (experimental)” for resolvable videos on Android. It uses the first up to six seconds, 480-pixel longest edge, and 12 FPS, then opens Android sharing. Full source decoding, streaming palette generation, real whole-output decoding/inspection, cancellation, foreground interruption, and independent owned GIF handoff are wired. Failure/Retry preserves the GIF action and normal Video sharing. Narrow width and enlarged text use wrapping Media/Links controls.

The prototype has no configurable trim/settings UI or dedicated durable Save action. Those and broader codec, memory, quality and release/license/ABI qualification remain beyond this request. Keep the overall work item in progress while the user tests this prototype; no integration or publication is authorized.

Final prototype verification: 162 focused Share/GIF tests and 9 Android owned-transfer unit tests passed; affected Dart analysis has no issues, formatting and diff checks passed, and the normal Dev APK built. The native package produced looping, plan-accurate H.264 MP4 and VP9 WebM GIFs on emulator-5558; a rotated source produced 270×480 output after a read-only Android rotation fallback for missing minimal-FFprobe side data. Native progress and cancellation were observed. Maestro exercised GIF creation, a readable Android chooser preview and return to the Share sheet with synthetic local source files. No external recipient was selected. Physical-device/live-site/recipient, broad-codec, memory/thermal/quality and release/license/ABI qualification remain open. See the updated backend evaluation for evidence and prototype boundaries.


## Approved editor implementation, 2026-10-07

The approved mockup is implemented in the existing feature worktree. Create GIF downloads/inspects once and opens a local video preview with a movable trim window and edge handles, read-only times, Original/75%/50%/25% dimensions, 1-to-Original source FPS, and eight snapping playback ratios with whole-FPS rounding and duplicate removal. Original size/FPS are the defaults. The instantaneous estimate uses pixels × selected frames × 0.5 bytes; speed is independent and the estimate never gates conversion. The actual limit is now decimal **100 MB**, superseding the historical 25 MB/15 MB targets above.

Conversion has progress and cancellation; adjustment and retry preserve the prepared source. Results offer GIF preview, measured size, Adjust, Android document-picker Save, and the existing owned native Share handoff. A smaller retry selects 50% dimensions and half the source FPS, preserving trim and speed. Palette/dithering are automatic. High playback FPS reduces retained images to keep representable positive GIF delays without changing requested speed. Source leases remain alive until native work and pending handoffs finish.

Verification: 184 focused Share/GIF tests, the explicitly selected German constrained-layout test, and 17 Java transfer tests passed; scoped analysis, formatting and diff checks passed. The normal Dev APK built at `build/app/outputs/flutter-apk/boorusama-gif-editor-dev.apk`. Timing cases use real host FFmpeg fixtures. The new editor/native save picker has no device UI run in this environment; the user phone was preserved. Details and evidence are in `docs/gif_conversion_evaluation.md`. No integration or publication was requested.

## Requested editor refinements, 2026-10-07

The preview is pinned at the top while settings or conversion status scroll below it. The redundant width/height label is removed. Result actions remain on one row and Share GIF is now Share. Save automatically uses the configured download folder, respecting the profile override and global/default fallback, with MediaStore for Android's public folders and fresh destinations that preserve existing files. Output remains alive through pending saves and image-codec loading. Opening the notification drawer no longer cancels GIF preparation/conversion; actual backgrounding still cancels it.

Verification: 189 focused Share/GIF tests and 22 Java file-transfer/download-location tests passed; scoped analysis, formatting and diff checks passed. English and German widget tests exercise 320×640, 2× text, keyboard insets, the pinned preview, and the single-row actions. Lifecycle tests distinguish inactive from paused, and Save tests cover directory precedence and pending-write retention. The normal Dev debug APK is `build/app/outputs/flutter-apk/boorusama-gif-editor-refined-dev.apk`. Device MediaStore writes and playback/UI checks remain unperformed; no integration or publication is authorized. See `docs/gif_conversion_evaluation.md` for evidence.

## Background conversion and fixed resolutions, 2026-10-07

The user replaced foreground-only conversion with background execution until explicit cancellation. An Android foreground service and temporary CPU wake lock keep encoding/validation running through app backgrounding and screen-off. The ongoing localized notification returns to the editor and provides Cancel; cleanup waits for native writers before stopping the service. Force-stop/process death is not resumable. Initial download/inspection still uses the existing preparation lifecycle.

Resolution choices are now 480/640/720/Original, capping the longest display edge; presets at or above Original are hidden. Default is 640 where available, otherwise Original, without upscaling. Smaller retry selects the next available smaller preset and half the original source FPS. Both sliders have subtle vertical step markers, and the source-FPS helper text is removed. The separate requested loop-detection research handoff is `docs/gif_loop_detection_handoff.md`; no detector is implemented.

Verification: 197 focused Share/GIF tests passed; affected analysis, formatting, and diff checks passed. The existing 22 Java transfer/location tests passed for the save changes. The normal Dev APK is `build/app/outputs/flutter-apk/boorusama-gif-editor-background-dev.apk`. Native foreground-service notification/cancellation, screen-off execution, and MediaStore Save still need device checks; the user phone was preserved. No integration/publication is authorized.

## Icons, 360/480 presets, and duration-cap removal, 2026-10-08

Restored Save/Share icons with wrapping content that preserves the single-row result actions. Added 360 to the longest-edge presets and defaulted to 480 (Original for sources at or below 480). Removed the preview helper sentence and maximum-duration trim hint. The selected clip can extend through the complete source; six seconds remains only the initial selection. Sources have no maximum length, so GIF creation remains available for longer videos. Removed the old output-inspection limit of 601 frames as part of the duration change. The measured 100-MB ceiling, complete-source/whole-output validation, source trim bounds, and other existing metadata/canvas guards remain.

Verification: 203 focused Share/GIF tests passed, scoped analysis reports no issues, and formatting/diff checks pass. Real host FFmpeg converted a 26-second clip from a 32-second source into a validated 624-frame looping GIF. Widget coverage includes a three-minute source, selection beyond 30 seconds, and English/German icon layouts at 320×640 / 2× text with keyboard inset. The normal Dev APK built at `build/app/outputs/flutter-apk/boorusama-gif-editor-unlimited-dev.apk`. No device run, integration, or publication was performed. The loop-research handoff now reflects the removed duration caps.


## Full-video default and Original visibility, 2026-10-08

The initial trim now covers the entire video. Original is the first resolution choice, including for 1280×720 sources; 720 remains a longest-edge cap producing 720×405 for that source. Removed the cancellation helper sentence from the background status in English and German. The separate loop-research handoff reflects the full-video default.

Verification: 207 focused Share/GIF tests passed; scoped analysis reports no issues, and formatting/diff checks pass. Widget tests select Original at narrow width with normal/enlarged text and convert a three-minute video without adjusting its default selection. Existing constrained English/German settings and result actions remain covered. Device checks, integration, and publication were not performed.

Updated Dev APK: `build/app/outputs/flutter-apk/boorusama-gif-editor-full-length-dev.apk`. Build evidence: `/tmp/gif-full-length-build-final.log`.


## Ascending sizes and estimated-size warning, 2026-10-08

Restored ascending resolution choices with Original last. Estimates above decimal 20 MB show yellow text and a trailing yellow warning icon; creation remains enabled. The exact 20-MB boundary stays unhighlighted, and changing settings clears/restores the warning as appropriate.

Verification: 62 targeted selection/conversion-service/widget tests passed, including 1280×720 Original selection and constrained warning layouts at 2× text with keyboard inset. Scoped analysis, formatting, and diff checks pass. Updated Dev APK: `build/app/outputs/flutter-apk/boorusama-gif-editor-size-warning-dev.apk`. No device run, integration, or publication was performed.


## GIF media row in the Share dialog, 2026-10-08

GIF now appears directly below Video using the same media tile, with a leading GIF icon/title and a single trailing wand action. The Create GIF tooltip is localized; the action starts the existing preparation/editor flow. Availability and busy-state restrictions are preserved.

Verification: 210 focused Share/GIF tests passed, including English/German constrained row layouts and editor entry. Scoped analysis, formatting, and diff checks pass. Updated Dev APK: `build/app/outputs/flutter-apk/boorusama-gif-editor-share-row-dev.apk`. No device run, integration, or publication was performed.


## Accepted prototype completion and local integration, 2026-10-08

The user accepted the tested prototype and authorized merging `feature/28-gif-experiment`. The approved feature tip is `9d55a10d3`; integration is prepared as one squash commit on local develop `755bb218d`, preserving newer develop translations and unrelated work. The accepted prototype scope above is complete. Loop detection remains research-only; broader device/resource/codec and release qualification remain documented follow-ups rather than unfinished prototype implementation.

The combined checkout passes **210 Share/GIF tests**, **22 Java transfer/download-location tests**, scoped analysis, generation, and diff checks. A normal Dev debug APK is preserved at `build/agent-artifacts/gif-experiment/boorusama-gif-integrated-dev.apk` outside the completed task worktree. The earlier APKs are retained alongside it with checksums. No new device validation or remote publication is part of this local integration. Evidence: `/tmp/gif-integration-tests.log`, `/tmp/gif-integration-java-tests.log`, `/tmp/gif-integration-analysis.log`, and `/tmp/gif-integration-build.log`.

The first fresh APK build failed with a Dart VM segmentation fault during kernel compilation. Retrying the same source with resolved dependencies succeeded (69.3 seconds). Retry evidence: `/tmp/gif-integration-build-retry.log`. The preserved APK includes the current combined Dart sources and has been checksum-verified. No source or SDK changes were needed for the retry; the underlying compiler-crash cause is not established.
