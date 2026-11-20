# #176 shared Group viewer implementation

This records an earlier #176 revision. See the
[canvas and ordering follow-up](176-canvas-order-verification.md) for ordering and swipe behavior.

For the subsequent control and repeat-entry corrections, see the
[follow-up verification](176-group-viewer-followup-verification.md).

Local implementation on `feature/176-group-viewer-design`. Runtime and tests:
`13c6611be`. Base: `origin/develop@8155acbfa281a983029de53b659e5f760222e5ec`,
reconciled through merge `bcf9bdd99`. No push, PR, integration or issue closure
is authorized by this handoff. #176 remains open for owner acceptance.

## Result

The existing mixed Post viewer supports Single and Timeline for Pixiv Work,
Danbooru Series, Collection and Related occurrences. Work, Series and Related
default to Single; Collection defaults to Timeline. The destination icon uses
the existing header. Related and Collection sorting share the same membership
order in both presentations; Series and Work remain fixed.

Member occurrence keys, captured source access, bounded Single transforms and
Timeline checkpoints survive presentation switches. A Timeline tile drills into
Single inside the same Group. Back from that drill-in returns to Timeline;
explicit mode changes add no Back step. Pool order reuses the existing route-local
PageStorage checkpoint, including restoration after viewer eviction. Live Pool
metadata determines whether a stored Series hint is still accurate.

Single exposes separate member and whole-Group Bookmark buttons with image and
layers markers. Both use the existing folder picker and storage. Group saves
store one reference, without saving all members. Pixiv keeps real Work metadata
and author Page order, with no remote Favorite write. Danbooru retains native
Post actions and Pool links. There is no migration or global mode preference.

The existing Group membership provider supplies both Single and infinite
Timeline grids, including source page boundaries and filtered empty pages.
Native paginated grids retain indexed reads. Active-source observation bridges
the outer page event and widget settlement, preventing an evicted destination's
first read from being discarded and repeated. Missing members reveal chrome,
retain authorized Group actions, and expose membership-load Retry.

## Automated evidence

All commands run in `.worktrees/176-group-viewer-design` with FVM Flutter 3.47.2.
Durable local logs and screenshots are under the ignored
`.worktrees/_artifacts/176-group-viewer/` directory in that worktree.

- `fvm dart format <all 39 changed Dart files>`: formatted; no remaining changes.
- `fvm flutter analyze --no-pub --no-fatal-infos <all 39 changed Dart files>`:
  zero errors, zero warnings, 65 informational findings. See
  `final-candidate-analyze.log`; this is not a zero-lint claim.
- Focused all-kind viewer cases: ten passed, including 320dp / doubled text,
  duplicate Post IDs, exact occurrence restoration, sort identity, Details
  header, tile/Back scroll restoration, independent toolbar slots and failure
  recovery (`final-new-viewer-tests.log`). Later runtime changes are covered by
  the final complete run below.
- Final focused application checks: four passed. They exercise both Single
  Related headers against saved preference/picker state, Group retry, and
  Collection scroll/order restoration after eviction at normal and doubled text
  (`remaining-consumers-final-pass.log`). Command:
  `fvm flutter test --no-pub test/application/pool_bookmark_flow_test.dart --name 'unavailable Pool retries|mixed Bookmark sequence restores gallery|saved Related order is per family' --reporter expanded`.
- `./scripts/run_regression_tests.sh`: exit 0 on the unchanged runtime/test
  state committed as `13c6611be`, using six detected physical cores. Application:
  7,785 passed. All 13 package/CLI suites: 1,722 passed, two skipped. Total:
  **9,507 Flutter/Dart tests passed**. Both shell policy/release checks passed;
  all **76 Python tooling tests passed**. See `full-regression-final.log`.
  Earlier runs with failures are retained as diagnostic evidence and are not
  counted as final verification. The complete run also covers the later
  active-source, live-metadata and Pool checkpoint corrections.
- `git diff --check`: passed. The final report-only commit changes no runtime,
  tests, dependencies or generated runtime inputs after the complete pass.

## Native evidence

Final acceptance build:
`fvm flutter build apk --debug --flavor dev --target-platform android-x64`.
APK SHA-256:
`a951a0afd1c7ea213eb3403c044376205095eaa1cd6cf8ea7d35ad28a0d6aad0`.
The source was subsequently committed unchanged as `13c6611be`.

Installed `com.timberpile.boorusama.dev` on exclusively leased
`emulator-5556` without clearing app data. The installed `base.apk` SHA-256
matches the final local build above. This establishes source-to-build-to-install
correspondence for these checks. Maestro MCP controlled the UI; hierarchy was
inspected before selectors. The streamed installer stalled, so it was stopped
and the completed APK was installed successfully with
`adb -s emulator-5556 install --no-streaming -r build/app/outputs/flutter-apk/app-dev-debug.apk`.

Native checks performed at 320dp logical width and Android font scale 1.5:

- One real three-Page Pixiv Work: default Single,
  B+ in both directions, Page 3 tile drill-in and Android Back to Timeline,
  both local Bookmark targets visible in Immersive and Detailed, actual Work
  metadata, direct Work folder picker, keyboard-open Create Group dialog and
  cancellation without saving. No per-Page remote heart was shown.
- Danbooru Series `Hololive - Dance With Me Kobo (Jasper Xandros)` (six members):
  default Single, both directions of B+, two scoped Bookmark controls, native
  metadata and overflow actions, with no mutable ordering selector.
- Danbooru Collection `Badass`: default Timeline, B+ into Single and back,
  existing Ordered/Latest/Oldest choices in the upper header. Its selected
  first member was unavailable/filtered: the Post Bookmark was disabled while
  the authorized Group Bookmark stayed enabled. Back, sort, B+ and Info were
  visible without overlap in the retained screenshot. Large-Collection sort
  choices were inspected without selecting a new order.

Original Default profile, Series gallery tab, density 320 and font scale 1.0
were restored; density/font values were read back. The exclusive lease was
released. No folder or Bookmark membership was saved by native QA.

Screenshots (all in the durable artifact directory named above):

- `native-final-pixiv-single.png` (original 360dp / normal text).
- `native-final-pixiv-timeline-320-150.png`.
- `native-final-pixiv-detailed-320-150.png`.
- `native-final-pixiv-picker-320-150.png`.
- `native-final-picker-keyboard-320-150.png`.
- `native-final-series-single-320-150.png`.
- `native-final-collection-single-320-150.png`.

An independent read-only UX reviewer found no confirmed blocker in the Pixiv
or Series captures. Optional polish: strengthen the small scope markers and use
an explicit compact style for Pixiv Timeline page-number plaques. The reviewer
could not reliably render the Collection capture; its initial visibility concern
was withdrawn. The primary agent viewed that full capture and exercised its
controls. Static review does not establish navigation or saved-state behavior.

## Acceptance limits

Owner visual acceptance and authorized develop integration remain separate.
Automated tests do not establish authenticated live-service write acceptance or
physical-device responsiveness. Native Danbooru Related sorting/saving, remote
Favorite writes, local save/remove/Undo, profile loss while a picker is open,
landscape/video behavior and Android predictive-Back animation were not exercised
in this device session. Related headers, saved preferences, captured picker
identity, independent Page/Work membership and Undo, revocation, video/gesture
and outer-boundary behavior have automated coverage; this is not a substitute
for those native scenarios. The existing three-second transient counter fades
before the retained static captures, so native counter/header clearance while
visible is not established by those images; constrained widget tests cover it.
The legacy/native Related persistence tests remain unchanged in the complete
suite, while the application regression explicitly exercises saved preferences
from both new Single headers. #176 stays open in `review`, pending owner
acceptance and separately authorized publication/integration.
