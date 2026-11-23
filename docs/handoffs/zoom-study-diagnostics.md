# Aspect-Aware Double-Tap Zoom Handoff

Issue: [#153](https://github.com/timberpile/Boorusama/issues/153)
Branch: `feature/153-improve-aspect-aware-double-tap-zoom`
Base: `develop` at `e306ff5338a2255a89731c61bd0672336a933344`.

**Status:** Review complete. The complete local suite passes: 6,175 application tests, 1,676 package/CLI tests across 13 suites, 76 Python tests, and both repository shell suites. Two pre-existing `go_router` cases remain skipped. All four Android export-channel unit tests pass. No emulator or real-device verification was performed during this review.

## Purpose

Support the user's exploration of a more suitable aspect-ratio-aware double-tap zoom. **Aspect-aware Classic is now the only double-tap zoom behavior**. The former Fit Cycle algorithm and Image Viewer behavior selector have been removed. Existing global/per-profile settings and restored backups containing `doubleTapZoomMode` remain readable: the obsolete field is ignored and omitted from new exports. **Snap Zoom to Fit** tolerance is increased from 5% to 10% in Kurumi. Developers can still record their manually selected pinch zoom on real Android images for later analysis.

### Aspect-Aware Classic behavior

- Ordinary images in portrait zoom around **2.25×**, with a gentle **2.45×** peak for squares (not the former fixed 3×). Ordinary landscape images use a constrained other-dimension fit between **1.15× and 2.5×**.
- Extremely tall portrait: fit image to viewport width; extremely tall landscape: a roughly square image column, leaving side gutters.
- Extremely wide portrait: a slightly portrait image band (displayed height ~1.1× viewport width); extremely wide landscape: fit displayed image to the viewport height, **without** an ordinary 2.5× cap.
- The transitions at image aspect ratios **0.30–0.55** and **1.75–2.40** are smoothed to avoid abrupt jumps.
- A first double tap zooms to the target, the next returns. Existing manually zoomed images reset directly.
- When Auto Comic has already fitted a tall image to width, the first portrait double-tap zooms to **2× the reading scale** (previously 1.60×). The next double-tap restores the initial Comic transform and reading position. Landscape behavior is unchanged.
- Known full-post dimensions remain the zoom/pan geometry so cropped previews and Original upgrades cannot shift the reading position. Missing or invalid metadata falls back to **decoded media dimensions** once loaded and, if still unavailable, the safe 3× Classic fallback. Double-tap targets stay at least 1.15× in narrow viewports. Video gesture routing is unchanged.
- No new settings, mode enum, plugin or persistent zoom-algorithm setting is introduced. The legacy zoom choice is removed rather than migrated. Saved Zoom Study observations remain untouched; newly recorded JSON retains `double_tap_mode: classic` for compatibility with earlier exports.

[Algorithm rationale and formula](https://github.com/timberpile/Boorusama/blob/maintenance/content-architecture-design/docs/designs/2026-11-06-aspect-aware-classic-zoom-algorithm.md) is a design source; this task branch contains the actual implementation. In the documentation, the `a >= 2.40` wide-landscape branch is smoothed with a 1.15× floor rather than switching abruptly at a threshold.


## Behavior

1. Use a **dev-flavor build**. Open **Settings → Developer options → Zoom Study**, and enable the switch. It defaults off and is persisted in the existing Hive developer-options box.
2. Open an ordinary still-image Post in the Mixed Viewer. A small, opaque but nonintrusive panel at the lower right displays the live zoom scale relative to initial contain fit (e.g. `2.35×`). It does not appear for video or non-Post group pages.
3. Adjust the zoom with normal pinch/double-tap gestures and press **Record preferred zoom** (bookmark-plus icon). The sample is immediately persisted in Hive under `zoom_study_observations`; it survives reopening the app. When a decoded image representation is available its actual pixel dimensions are recorded; otherwise dimensions come from Post metadata and the report explicitly labels that fallback.
4. Press **Export Zoom Study JSON** (download icon) to produce a fresh `boorusama-zoom-study-YYYYMMDDTHHMMSSmmmZ.json` in the Android public **Downloads** root via MediaStore (API 29+). No directory picker and no storage permission are required.
5. Export includes all saved observations, not only the current image. Export does not delete observations. A new export creates another timestamped file.

Observations include UTC time, engine, numeric Post ID, image width/height and width-to-height ratio (with `image_dimensions_source`), original Post metadata dimensions, actual viewer viewport width/height and ratio, device orientation, chosen relative zoom, fixed double-tap mode label (`classic`), snap setting/tolerance, and auto-comic setting. No image bytes, image URLs, credentials or full account data are exported. Numeric Post IDs can still be sensitive usage context if someone shares the file.

## Implementation

- `packages/kurumi/lib/src/components/interactive_viewer.dart`: only the aspect-aware Classic implementation remains; former Fit Cycle enum/branch/helper logic is removed. Pinch Snap Zoom to Fit remains at ±10%; automatic Classic fit snapping stays **downward-only**. Comic portrait reading-baseline detail zoom is 2×. Manual pinch snapping is unchanged.
- `packages/kurumi/test/interactive_viewer_test.dart`: verify Classic targets in portrait/landscape, square images, wide panorama uncapping, direct reset, no-op prevention, 2× Comic baseline recovery, manual pinch snap and viewport panning. Retired Fit Cycle tests are removed.
- `lib/core/developer_options/{types.dart,providers.dart,widgets.dart,l10n.dart}` and Hive repository: persisted dev switch.
- `lib/core/developer_options/zoom_study.dart`: JSON records in Hive, safe timestamped filename and method-channel client.
- `lib/core/posts/details/src/widgets/zoom_study_overlay.dart` plus `post_details_item.dart`: the active, settled still-image page owns the developer overlay outside the transformed media subtree. The panel reads the existing shared TransformationController and, when ready, the decoded representation from ExtendedImageController. The viewer preserves valid full-post geometry for Classic calculations and zoom-edge constraints, falling back to decoded dimensions when metadata is missing. Diagnostics record decoded dimensions separately. Record/export completions guard disposal before accessing widget context. Video stays on its existing media sizing. The scaffold remains unchanged.
- `android/app/src/main/kotlin/com/timberpile/boorusama/PerformanceDiagnosticsChannel.kt`: add `saveZoomStudy` to the existing, already registered MediaStore JSON exporter. Original performance report method and path are preserved.
- `lib/core/settings/src/types/settings.dart`, Image Viewer settings section, `InteractiveViewerExtended` and the Post viewer: remove the obsolete selection and all wiring. `Settings.fromJson` safely ignores historic `doubleTapZoomMode` values, while `toJson` omits them. No destructive migration is needed.
- `test/settings/double_tap_zoom_mode_test.dart`, its UI counterpart, `test/core/settings/image_viewer_settings_section_test.dart`, and `test/core/widgets/interactive_viewer_extended_test.dart`: verify legacy-key handling, selector removal and Classic-only behavior.
- `lib/core/settings/src/search/settings_search_catalog.dart` and corresponding test: remove the retired selector from Settings Search, too.
- `test/core/developer_options/zoom_study_test.dart`: filename, decoding, settings and method-channel contract tests.

## Review verification

The final runtime candidate `160aa399f` passed `./scripts/run_regression_tests.sh` with the detected six-worker default. Android verification used Gradle 8.14 `:app:testDevDebugUnitTest --tests com.timberpile.boorusama.PerformanceDiagnosticsChannelTest --console=plain`.

Affected-scope Dart analysis has no errors or warnings and one existing informational nullable-cast lint in the mixed-viewer test. Whole-repository analysis reports an unchanged invalid override in `benchmark/bookmark_mutation_latency_test.dart`; opt-in workload benchmarks are outside the complete local suite. Test output also contains non-failing Dart VM finalizer and tap-target diagnostics.

Review fixes preserve known full-post geometry across cropped previews and Original upgrades, retain decoded dimensions as a fallback for missing metadata, prevent narrow-viewport double-taps from zooming out or doing nothing, and guard pending Zoom Study callbacks after disposal. Regression coverage includes narrow width, enlarged text and an open keyboard for the diagnostic controls.

## Verification commands and device follow-up

```bash
fvm dart format lib/core/settings/src/types/settings.dart lib/core/settings/src/pages/appearance/image_viewer_settings_section.dart lib/core/widgets/interactive_viewer_extended.dart lib/core/posts/details/src/widgets/post_details_item.dart lib/core/posts/details/src/widgets/zoom_study_overlay.dart packages/kurumi/lib/src/components/interactive_viewer.dart test/settings/double_tap_zoom_mode_test.dart test/settings/double_tap_zoom_mode_ui_test.dart test/core/widgets/interactive_viewer_extended_test.dart test/core/settings/image_viewer_settings_section_test.dart lib/core/settings/src/search/settings_search_catalog.dart test/core/settings/settings_search_catalog_test.dart packages/kurumi/test/interactive_viewer_test.dart
fvm flutter test test/core/developer_options/zoom_study_test.dart
fvm flutter test test/settings/double_tap_zoom_mode_test.dart test/settings/double_tap_zoom_mode_ui_test.dart test/settings/snap_zoom_to_fit_test.dart test/core/settings/image_viewer_settings_section_test.dart test/core/settings/settings_search_catalog_test.dart test/core/widgets/interactive_viewer_extended_test.dart
(cd packages/kurumi && fvm flutter test)
fvm flutter analyze
```

Perform Android test using the repo's emulator-lease procedure or a real Android 10+ device:
- Confirm that neither Image Viewer settings nor Settings Search contains a zoom behavior selector. If a device previously saved Fit Cycle, verify it now uses aspect-aware Classic automatically. Toggle Zoom Study, open a portrait, a square and a panorama; double-tap and pinch, and confirm that the badge tracks the correct transformed scale.
- Test a portrait normal/near-square image near 2.25–2.45×; a very tall Comic width-fit in portrait and square-ish column in landscape; very wide portrait band and full-height landscape panorama, including values beyond 2.5×. Verify that the second double tap resets appropriately and the Comic reading position is restored.
- Confirm that automatic Classic zoom **does not increase** to a nearby fit but can **decrease** to avoid two-axis panning; manual pinch snapping continues to work normally. Confirm the **2×** portrait Comic detail step.
- Record in portrait; rotate to landscape and record again. Check image/viewport ratios and orientations in JSON.
- Switch Posts and mixed group pages; verify the overlay follows only the active still-image Post.
- Export and inspect a JSON file with multiple observations in Downloads. Restart the app and confirm previous records remain.
- Test export failure and ensure the UI never reports success. Check normal (disabled) viewer behavior and existing performance-report exports.
- Verify on a small screen that the debug panel does not block essential viewer actions.

The full repository regression is required on the final integration candidate by `AGENTS.md` before a merge to `develop`. Integration and publication require explicit merge authorization.

## Deliberately outside scope

- No separate Fit Cycle behavior or user-selectable zoom algorithm remains. Any further zoom tuning should directly adjust the shared Classic implementation after device review.
- No images or media sent to a remote analytics service.
