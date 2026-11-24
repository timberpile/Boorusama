# First-view video autoplay verification

[Issue #189](https://github.com/timberpile/Boorusama/issues/189)

## Host verification

The regression tests started with a settled Realbooru poster and completed its
detail lookup with an MP4. On base `45f3df6c3b`, direct open and first swipe
each recorded zero play calls. With the fix, each recorded one. The tests
also exercised cancellation before resolution or player registration, resume
on the same page after covering the viewer, and manual pause across a metadata
refresh.

The focused Flutter suite passed 595 tests, including Gelbooru v2, viewer and
page-view tests, player tests, and navigation and media-key lifecycle checks.
FVM Dart analysis of the two changed Dart files found no issues.

## Android verification pending

The x86_64 debug dev APK built from the fixed source. Maestro screen inspection
stalled on leased emulators `emulator-5562` and `emulator-5554`. A fresh local
Maestro MCP session and a screenshot request also stalled. No candidate app
was installed and no native playback was observed during this check.

On a leased Android emulator, verify with the engine set to Auto that playback
position advances on direct open and on first swipe for MP4 and WebM. Use a
Realbooru post with poster-only listing metadata when available. Playback on
another source can qualify the engines while live Realbooru remains pending.
