# Timeline system-bar preparation (#147)

Base: `4542aaa44e5002f7d546fb4ec96bf4cb0523cee5`.
Branch: `bug/147-timeline-system-bars`.

Danbooru Pool and Related grids explicitly disabled RawPostGrid's SafeArea,
while their outer wrappers also disabled the top inset. Use the normal shared
viewport inset, whose surrounding opaque semantic surface covers the status
region as in Browse. The app bar receives the consumed MediaQuery padding, so
it does not reserve the status inset twice.

The root overlay style now uses the actual Kurumi color scheme for icon contrast
and a semantic surface for three-button navigation. Bottom gesture insets select
the transparent edge-to-edge navigation treatment. Existing nested viewer styles
and immersive route behavior are untouched. Android can enforce edge-to-edge
colors independently; widget values do not establish actual rendered pixels.

Final commands:

- `fvm dart format lib/core/app.dart lib/core/themes/system_ui.dart lib/boorus/danbooru/pools/details/src/widgets/danbooru_infinite_post_id_list.dart lib/boorus/danbooru/posts/related/related_gallery.dart test/core/posts/pools/native_pool_occurrence_ui_test.dart test/core/settings/system_ui_test.dart`: passed.
- `timeout 30s fvm flutter test --no-pub --concurrency=6 test/core/settings/system_ui_test.dart test/core/posts/pools/native_pool_occurrence_ui_test.dart --name 'system bars|danbooru.*Pool repeated'`: 6 passed; light/dark and both navigation contracts, actual Danbooru Pool viewports below a synthetic 24px status inset, occurrence/index navigation preserved.
- `timeout 20s fvm dart analyze lib/core/app.dart lib/core/themes/system_ui.dart lib/boorus/danbooru/pools/details/src/widgets/danbooru_infinite_post_id_list.dart lib/boorus/danbooru/posts/related/related_gallery.dart test/core/posts/pools/native_pool_occurrence_ui_test.dart test/core/settings/system_ui_test.dart`: zero errors/warnings, 6 informational existing-style findings.
- `git diff --check`: passed.

An earlier two-file run passed 9 tests. Analysis then caught an accidentally
removed services import used by keyboard/haptics code; it was restored, analysis
rerun and the six final relevant cases above passed. The earlier run alone is not
used as final-candidate evidence.

Not run: emulator/Maestro, live API/account calls, APK build/install, full suite,
physical Android screenshots, gesture/three-button visual contrast, Related's
rendered inset, or immersive viewer entry/exit restoration. Owner must compare
Browse, Pool and Related while scrolling in light/dark and both Android modes,
then enter/leave the viewer. This is prepared source/widget evidence, not verified
Android visual acceptance or readiness for develop integration.
