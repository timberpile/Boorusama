# Issue #139: Bookmark UI corrections

Superseded input styling: [the later rounded-search correction](139-rounded-search-20261103.md)
preserves the user's default Kurumi field surface. The opaque parent remains.

Local branch: `feature/139-related-families`. Implementation commit:
`eb315fd6955666260ff183dabc0d7964e768a7dc`. This continues the
[earlier Related handoff](139-related-followup-20261103.md); its 28 dp overlay
description is historical and superseded here. No push, PR, develop merge or
issue closure was performed. #145 must incorporate this branch first.

## Changed behavior

- Collection/Series/Related source icons and type badges now share **24 dp**
  footprints, **16 dp** type icons, **4 dp** insets and a **4 dp** gap. Counts
  retain their full accessibility label and fall back when enlarged text cannot
  fit. Ordinary Post overlay sizing is unchanged.
- Removed the Bookmark Search Bar info action and its Material help dialog.
- One opaque active-theme `surface` now owns the Bookmark Search Bar and Timeline
  Toolbar. Both children are transparent. Search suggestions retain their own
  surface. Optional component overrides preserve other callers' existing defaults.
- Related ordering, canonical identity, membership feedback, title-free Related
  cards and the narrow Kurumi picker changes from the earlier delivery remain.

The global Header/System Bar/scroll changes are deliberately deferred to
#146/#147/#148 and specified on the #136 documentation branch. No global toolbar
refactor, API rename or radius migration was included; #105 owns radius work.

## Automated verification

Checked runtime/tests: `eb315fd69`. Later handoff edits are documentation only.

| Check | Final result |
| --- | --- |
| Changed Dart formatting and `git diff --check` | Passed |
| Scoped `fvm flutter analyze --no-pub --no-fatal-infos` on nine affected application/test files | 0 errors, 0 warnings, 22 infos |
| Kurumi `fvm dart analyze lib/src/components/search_bar.dart test/search_bar_surface_test.dart` | No issues |
| Complete Kurumi suite | 186 passed, including four new light/dark parent-paint/default pixel tests |
| Narrow Bookmark scroll/keyboard application tests | 2 passed, at 1x/2x text; assert shared opaque owner and removed help action |
| Focused mixed Post/Series keyboard-selection regression | 1 passed after replacing the removed info icon as its focus target |
| `./scripts/run_regression_tests.sh`, detected physical concurrency 6 | **Complete pass:** 6,073 application tests; 1,659 package/CLI tests across 13 suites; both shell suites; 72 Python tests; `REGRESSION_EXIT=0` |
| Existing skips | Two pre-existing go_router skips; no new skips |
| `fvm flutter build apk --debug --flavor dev --target-platform android-x64 --no-pub` | Passed |

The first full run found the existing keyboard test's obsolete info-icon lookup.
The corrected test passed independently, then the complete suite was rerun on
the final candidate above. Earlier failures are not counted as passes. The build
emitted existing AGP/Kotlin notices and the documented native-hook “File modified
during build” diagnostic. No generated runtime source change was needed.

## Android verification and limits

Maestro controlled exclusively leased `emulator-5554`, Android 17, 720×1600 at
320 dpi (360×800 logical), gesture navigation. Installed/local APK SHA-256 matched:
`4a4d1dd54ab5f352304693da8b7a3c8e1af5eb2272063a84707a23e7330e298f`.
The APK was built from the runtime files subsequently committed as `eb315fd69`;
later pre-commit edits affected tests/docs only.

Created one temporary group with safe public Related, Series and Collection
references. Visually checked aligned compact badges, counts and the title-free
Related card, the removed help action and the shared search/toolbar surface.
Applied actual Light, Dark and Midnight (AMOLED) presets; also enabled dynamic
color on Dark, then restored it. Checked 2x Android text and actual soft-keyboard
search suggestions. Navigated Collection top/down/reveal states; their existing
translucent toolbar/status-bar drift is evidence for deferred #147/#148, not a
completed fix. Ten reviewed captures with hashes and exact limits are retained
on #136 in `docs/designs/136-timeline-evidence/`.

The original global Midnight preset, dynamic-color-off state, font scale 1.0,
soft-keyboard/hardware-keyboard preference and Browse Danbooru profile were
restored. During subsequent #145 verification, deleted only the temporary group
and its three unique references; All Bookmarks showed No data available. No app
reset or account change occurred. Favorites' profile was untouched. The lease
was released; the updated #145 APK remains installed. Navigation/search may leave
normal transient/history state.

Theme restoration is visual, not representation-identical: Appearance initially
showed Colors “Default”; the editor now saves an explicit Midnight selection.
It exposes no action to restore the earlier null color override. This small
preference difference remains; no settings reset or private-data edit was used.

Favicon/custom/fallback geometry is additionally exercised by #145's three
existing tests updated to 24 dp. Device RTL, three-button navigation, physical
devices, assistive input and every global capture-matrix cell remain unverified.
The two-member Related family is too short to establish long-gallery scrolling;
host tests cover ordering, pagination/stale results and restoration. This is
neither a latency benchmark nor global Header/System Bar acceptance.

Durable local logs: `.worktrees/_artifacts/bookmark-ui-corrections-139/`.
A changed combined develop candidate needs a fresh complete suite before any
separately authorized integration.
