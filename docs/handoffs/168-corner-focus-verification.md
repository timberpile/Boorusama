# #168 double-tap corner focus verification

Base: `4542aaa44e5002f7d546fb4ec96bf4cb0523cee5` (origin/develop).
Branch: `feature/168-double-tap-corner-focus`. Refs #168; owner acceptance pending.

The first double tap remaps a 12% inset to the full visible painted-image focal range. Contain-fit geometry accounts for letterboxing; the baseline matrix is applied before remapping. For an already transformed comic, the range is the visible reading region, preserving the current position rather than targeting an offscreen page end. Invalid geometry retains the original tap. Existing scale selection, limit handling, second-tap matrix restoration, pinch and video paths remain unchanged.

Verification: `fvm dart format` on both changed files. `fvm flutter test --no-pub --concurrency=6 packages/kurumi/test/interactive_viewer_test.dart` passed 60 tests, including inset corners/center/continuity on square, portrait, panorama and letterboxed rectangles; actual letterboxed corner focus; original comic restoration, pinch, limits, resizing and media-child lifetime coverage. Scoped `fvm dart analyze` on the two files found no issues. The first run exposed an overly exact floating-point assertion; it was changed to a numerical tolerance and the final file passed. Logs: `.worktrees/_artifacts/pre-release-20261117/168-*`.

Not performed: full Kurumi/application suites, app-wide viewer/swipe integration, live services, Android/emulator/device checks or APK builds. Owner should compare corner taps and comic reading restoration in portrait and landscape on Android. This independent feature is excluded from the bugfix preview; full integration verification remains deferred.
