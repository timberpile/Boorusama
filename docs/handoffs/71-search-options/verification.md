# Search options: local verification

Date: 2026-10-22 (Europe/Vienna). Issue: #71.

## Source and delivery boundary

- Original implementation: `a8d4d3780755b64654ac538e1501c76a5b1f1b74`.
- Whole-change review base: `fb1a5e3711c81f35a7f308d8f368dcfcfb97a801`.
- Local corrections: `714bdf73a9b8662647396940aabc00ebb5dba0fc`.
- Initial continuation runtime: `908baf04fae2a7438b07bd9722a61d8611e35e34`
  (legacy nullable-response correction), documented in `6c7a5d0ef`.
- Previous UI runtime: `9ff30c41aa1d849a4cb5f83d5a7fa59b3b4bba6f`, recorded
  in the [first UI follow-up](#ui-follow-up-after-user-feedback).
- Previous header/keyboard runtime: `499ee3d4d8012adbe4ba2706def3755a0ffb727f`.
  See the [header and keyboard follow-up](#header-spacing-and-keyboard-follow-up).
- Previous interaction runtime: `953fa730a7aa9a9124c91a6ee0e7eaae0cfeed7c`.
  See the [interaction follow-up](#explicit-options-toggle-and-selection-follow-up).
- Previous raw-suggestion runtime: `10cfb3265`. See the
  [timeline entry and raw suggestion follow-up](#timeline-entry-and-raw-suggestion-follow-up).
- Previous advanced-options runtime: `206b9111f`. See the
  [advanced UI and duration follow-up](#advanced-ui-and-duration-follow-up).
- Latest runtime: `bb15dab78`. See the
  [empty-editor dismissal follow-up](#empty-editor-dismissal-follow-up).
  Earlier sections below retain their historical verification evidence.
- Work continues on `feature/71-search-options` in its isolated task worktree.
  The primary checkout and unrelated worktrees were preserved. No PR, code push,
  develop integration or issue closure was performed.

## Corrections confirmed by review and execution

The en-US/de-DE manifests were applied once to the real locale JSON files
(60 keys each), accessors and missing outputs generated, and all changed Dart
paths formatted. The original constant-set compilation error and missing test
metadata fixtures were corrected.

Completed search changes now replace their post scope. A slow old query cannot
block the new one, obsolete refresh/pagination responses cannot overwrite or
append to new results, and changing a restored page-five query restarts at page
one. Explicit refresh remains available and typing/IME composition does not
commit. This cancels obsolete ownership logically, without promising transport
cancellation. New controlled-response tests exercise the actual search scaffold,
page controller, async API responses, cache enrichment, category changes, clear,
retry and disposal. Existing application network tests retain ordering and
stale-result assertions under the new request ownership.

Options and catalog sheets now use the root navigator, so the main navigation
cannot cover Apply. Sections own a Material surface for their ink effects, and
the scrolling options have a focus traversal group so Tab cannot interleave the
fixed bar with scrolling rows. The landing view is built once; covered results
are excluded from focus and semantics. Empty chip edits reach the controller
through the real search field, with the shared bar retaining its previous default
for other consumers. Keyboard suggestion picking respects active IME composition.
Native multi-condition route queries retain whitespace instead of becoming a
single underscored tag.

The legacy-site device check exposed incomplete Safebooru records with missing
media URLs. Taking `substring(1)` of an empty extension raised a RangeError and
aborted the entire listing. The parser now retains an empty format for missing
media; it does not invent a file type or filter the search locally. A sanitized
nullable DTO regression reproduced the RangeError before the correction.

Application test drivers now use completed additions and the close-editor action
instead of the removed submit-search button. History assertions retain exact
contents and ordering: separately confirmed additions create intermediate complete
queries, and the full multi-tag query remains restorable. Existing desktop raw
confirmation, non-post-search pickers, Topic actions and persistence paths remain
covered by the complete suite.

## Automated checks

The original focused handoff commands were run and their compilation/runtime
findings corrected. Later targeted passes included 40 options tests, 80 search
consumer/application tests, the two previously failing TV/desktop Tab checks,
and 103 legacy/search regressions after the nullable-response fix.

- `git diff --name-only -z <base> -- '*.dart' | xargs -0 fvm dart format`, plus
  formatting of new tests: passed; final formatting changed no files.
- `fvm flutter analyze --no-pub`: 3,008 informational findings, zero warnings and
  errors, all outside the changed paths (exit 1 for repository-wide infos).
  On the final runtime candidate, all 42 changed Dart paths reported
  **No issues found** (exit 0), using:
  `git diff --name-only -z <base> -- '*.dart' | xargs -0 fvm flutter analyze --no-pub`.
- `./scripts/run_regression_tests.sh`, six workers from
  `python3 scripts/physical_core_count.py`: **passed, exit 0** on `908baf04f`.
  4,501 application tests, 1,472 package/CLI tests, both shell suites (PR policy
  and Android release scripts), and 72 Python tooling tests passed.
  An earlier complete pass on `714bdf73a` was superseded by this final rerun.
- `fvm flutter build apk --debug --flavor dev --target-platform android-x64 --no-pub`:
  **passed** on `908baf04f`; its APK was installed and exercised below.
- `git diff --check` against both HEAD and the whole-change base: passed.

The package runner includes every test-bearing package: booru_clients (104),
boorusama_cli (254), cache_manager (59), coreutils (191), dtext (59), extended_image
(47), filename_generator (31), flutter_sqlite3_migration (45), foundation (65),
go_router (436), i18n_cli (32), kurumi (133) and retriable (16).
The two pre-existing `skip: true` go_router cases are “routing config works with
shell route” and “Obsolete branches in StatefulShellRoute are cleaned up after
route configuration change”. No task tests were skipped or assertions disabled.

## Device evidence

Maestro MCP controlled only the exclusively leased `emulator-5554` (Android 17,
API 37, x86_64). Existing app data was retained. The initial development APK and
corrected APKs were built and installed locally. The final `908baf04f` APK matched
its installed APK SHA-1: `58b182f5533ca3bf9a85f0adcdd7c762a7c976dd`.
The preceding `714bdf73a` APK also had a matching installed SHA-1:
`715a9604ee3e71c9d957dac8fdf0629f0a7d5d25`.

| Check | Observed result |
| --- | --- |
| Danbooru family (`safebooru.donmai.us`) | Real autocomplete for `one piece`, touch acceptance, `age:` presets, graphical `age:>=7d` exclusion, `-rating:q`, `score:>=50`, `order:id_desc` and `order:score`; matching live result counts/posts displayed. |
| Gelbooru.com | Local test credentials used only after explicit approval. Its own `rating:general` and `sort:id:desc` / `sort:score:desc` suggestions were applied; live results displayed. No Danbooru age controls were offered. |
| Safebooru.org (legacy) | Rating-only catalog, `rating:safe` loaded 60 posts. Negative rating exposed the nullable-response parser defect described above. Final `908baf04f` live rerun of `-rating:questionable` loaded 60 posts and displayed images instead of failing the listing. Public API probes returned HTTP 200 for both queries and confirmed incomplete nullable records in negative results. Individual records without usable media still show the existing image retry placeholder. |
| 320 logical px, system font scale 2.0 | Catalog, Apply/Cancel, collapsed/reopened Search Options, keyboard open/closed and top/bottom bars exercised. The `714bdf73a` APK verified the full-screen sheet and reachable controls; the only subsequent runtime change is the legacy parser correction. |
| Bottom bar and raw items | Enter confirmed a normal tag and a separate `landscape -rating:e` raw chip. Cancel preserved the original raw chip and other tags. Removing the item being edited did not resurrect it on Enter. The raw control was absent with the editor closed. |
| Profile switch during raw editing | With the profile menu settled after the keyboard transition, switching to Gelbooru preserved the raw draft and normal/raw mode. Cancel restored the unchanged committed raw chip and the other tag. |
| Other sections and saved favorites | On `908baf04f`, at 320 logical px / 2x text, Favorites and Trending collapsed/reopened correctly. Favorite management remained reachable, a temporary `sky` favorite was saved and inserted into the query, and the reopened History section still opened full history management. |
| Share and Topic consumers | On `908baf04f`, search sharing opened the Android sheet with `boorusama-search.bslink` and was cancelled. A temporary `sky` Topic was followed in Home under Safebooru, loaded its live metadata, and retained its original query after editing and cancelling. It was then unfollowed. Application tests also cover structured search sharing, tag pickers, history restoration and Topic persistence. |

Automated attempts during keyboard/menu or density transitions occasionally hit
the wrong control. Inspection and reruns after geometry settled verified the
intended paths. These automation misses did not justify source changes.

The emulator's original physical density 320 and font scale 1.0 were restored;
the temporary bottom-bar preference was returned to Top and the original Default
profile selected. The temporary favorite and Topic were removed. The exclusive
lease was **released** after the final check. Test-only Gelbooru/Safebooru profiles
and normal search history remain; existing data was never reset. Credentials and
temporary private setup flows were not committed or included in evidence.

## Review and limits

The entire base-to-candidate change was reviewed repeatedly, including the
original draft, consumers, capability serialization, edit cancellation,
persistence, request ownership, async ordering, localization and constrained UI.
Confirmed findings were corrected and checks repeated. No additional source
findings remain in the reviewed candidate; this is bounded review evidence, not
a guarantee that all possible site behavior is covered.

The capability catalog remains the approved conservative subset. Pixiv exclusive
user endpoints, separate API sorting, a range/Between builder, and exhaustive
engine-clone coverage are outside this issue. Live checks cover the named sites;
unit tests cover unrecognized-host exclusions and profile-specific definitions.
CI, a production release build and installed-upgrade acceptance were not run.


## UI follow-up after user feedback

The follow-up starts at `6c7a5d0ef` and is committed in
`9ff30c41aa1d849a4cb5f83d5a7fa59b3b4bba6f` on the same isolated branch.

- The post-search input no longer adds a clear X when text is entered. Its separate
  close-editor action uses a dismiss-keyboard icon. Other search-bar consumers
  retain their existing clear control.
- Every available option is shown. Saved pins determine the leading order;
  unpinning never hides an option. The header icon is the sole catalog entry.
  English and German pin labels now describe pinning rather than show/hide;
  `./gen.sh i18n` regenerated the ignored translation accessors.
- Options use rounded filled surfaces with an outline and smaller spacing.
  All quick choices and graphical-editor choice groups are single horizontally
  scrolling rows with compact rounded chips. Text scaling remains enabled.
- The options list scrolls independently within at most half of the editor's
  actual remaining viewport. The measurement precedes the outer landing scroll
  and already reflects keyboard, search-bar and selected-tag displacement.
- Empty suggestion feedback requires a successful empty answer for the exact
  query/profile, followed by 500 ms without replacement. Pending requests,
  failures and obsolete responses cannot show it. Changing input or mode cancels
  the delayed feedback. Keyboard highlighting remains visible over the new fill.

### Verification of the latest runtime

`./scripts/run_regression_tests.sh` completed with exit 0 on the exact runtime,
test and generated-output state committed as `9ff30c41a`, using six workers:
**4,505 application tests, 1,472 package/CLI tests, both shell suites and 72 Python
tests passed**. Package counts and the two existing go_router skips are unchanged
from the initial continuation above. No task assertions or tests were disabled.
The final complete runner log is `/tmp/71-polish-verified-regression.log`.

The first diagnostic runner was interrupted for an additional icon correction
and is not a complete pass. The subsequent full application run exposed two
real nested-scroll Tab traversal regressions on TV and desktop. A dedicated
`FocusTraversalGroup` with widget-order traversal now isolates the options list
from neighboring sections. Both original failing tests passed on a focused
rerun, then passed in the final complete suite. The broad checks therefore found
and corrected a defect beyond the initial 45 passing option tests.

Controlled widget tests cover pending/slow/empty/error/stale autocomplete,
feedback cancellation and cached empty responses; 320-pixel layout at 1x/2x
text with keyboard insets; all-option reachability and pin ordering; horizontal
age-choice selection; and absence of both X icons while preserving editor
closure and other consumers' clear action. Existing tests cover Apply/Cancel,
IME composition, request ownership and non-post-search consumers.

All 47 changed Dart paths against the original whole-change base analyze with
**No issues found** on the committed candidate:

```bash
git diff --name-only -z fb1a5e3711c81f35a7f308d8f368dcfcfb97a801 -- '*.dart' |
  xargs -0 fvm flutter analyze --no-pub
```

Final formatting checked all 12 follow-up Dart paths with zero changes.
`git diff --check` passed against both the preceding commit and the original
base. Repeated review checked the follow-up within the entire issue diff,
including shared-bar consumers, source-specific pins, keyboard focus, delayed
feedback ownership, localization and constrained layout. No further confirmed
findings remain in this follow-up.

The development APK build passed with:
`fvm flutter build apk --debug --flavor dev --target-platform android-x64 --no-pub`.
The final installed APK and local build both have SHA-1
`39ffbe86ff97a46c02066f13385cd41fcb505fe6`.

### Follow-up device evidence

Maestro MCP used only exclusively leased `emulator-5554`, retaining app data.
Normal and 320-logical-pixel / 2x layouts were inspected. The final APK verified
bottom-bar Danbooru search with the keyboard open: Uploaded choices stayed in
one row, horizontal scrolling revealed Last 30 days, and tapping it produced
`age:<30d`. The graphical editor's Exclude/Apply produced `age:>=7d`; closing the
editor displayed 60 live posts. Its controls remained reachable above navigation.
Top-bar enlarged-text layout was also exercised on the preceding APK with the
same layout; the final APK additionally received the traversal correction and
was checked again with the top bar at normal scale.

A native Danbooru option (`disapproved`) was pinned, observed before unpinned
options, then unpinned and observed after the guided options without disappearing.
The original pin selection was restored. Safebooru's rating-only layout and a
real empty autocomplete response were also checked. Timing and stale-response
claims come from the controlled tests, not from human observation of a live
network delay. Profile selection during keyboard transitions required reopening
the menu with the keyboard closed; settled profile selection succeeded.

Screenshots are available locally at `/tmp/71-search-options-final.png` and
`/tmp/71-polish-bottom-danbooru-320-2x.png`. Density was restored to physical 320,
font scale to 1.0, the bar setting to Top and the Default profile selected.
The temporary age condition was removed; normal test search history remains.
The emulator lease was released. No credentials were read or changed during
this follow-up. No PR, push, merge or issue closure was performed.


## Header, spacing and keyboard follow-up

The next user review requested removal of the keyboard-dismiss button, inline
option descriptions, consistent compact spacing, right-aligned section actions
and a full-width section toggle target. The existing isolated branch was reused.
No locale inputs changed; the previously applied manifests and generated
translation accessors remained valid.

The separate dismiss control is removed. System Back and Escape close the active
editor before leaving its page. Review and regression tests caught two ownership
cases: a covered search must not intercept Back intended for full history, and
an inactive navigation branch must not intercept Back for the visible branch.
The handler now checks both current-route and active-subtree state. Consumer
flows use the real system Back path; the navigation regression checks both Back
steps explicitly.

Fresh search opening already focused the input with the existing auto-focus
setting enabled. This was confirmed on the emulator and is now asserted directly
by the six phone-size/search-position cases, without tapping the input again.
The existing setting remains respected rather than silently overridden.

Option descriptions sit beside the title and FREE badge. Six-pixel internal
spacing matches quick-choice gaps. A device review at doubled text size exposed
excessive description wrapping; titles and descriptions now use at most two
lines, with the full description available through a tooltip and the editor.
A layout regression checks inline placement and that an option plus its quick
choices fits inside the bounded list at both normal and doubled text size.
Section actions use their intrinsic width at the right edge, with the remaining
width assigned to the toggle target. Favorites and Trending no longer add an
asymmetric bottom margin outside the collapsible body.

### Verification results

Checked runtime: `499ee3d4d8012adbe4ba2706def3755a0ffb727f`. The following
checks ran on its exact source/test contents before the commit. The report-only
commit after it does not change that candidate.

- `./scripts/run_regression_tests.sh`, detected concurrency 6: exit 0;
  4,506 application tests, 1,472 tests across all 13 packages/CLIs, both repository
  shell suites and 72 Python tooling tests passed. The two existing go_router
  skips remain. Log: `/tmp/71-header-complete-regression-rerun.log`.
- All 48 changed Dart files against the whole-change base were passed to
  `fvm flutter analyze --no-pub`: no issues, exit 0.
  Log: `/tmp/71-header-verified-analysis.log`.
- `fvm dart format --output=none --set-exit-if-changed` on the 13 follow-up Dart
  files: zero changes. Incremental and whole-issue `git diff --check`: clean.
- `fvm flutter build apk --debug --flavor dev --target-platform android-x64 --no-pub`:
  exit 0. Log: `/tmp/71-header-complete-build.log`. Final local and installed APK
  SHA-1: `588dd4050a8854e8b80dee368190921d4690e77a`.

The complete issue diff was checked against
`fb1a5e3711c81f35a7f308d8f368dcfcfb97a801`; final review found no further
in-scope defects after the described corrections. Earlier incomplete runs and a
superseded run with an outdated single-Back navigation assertion were not counted
as passes. One unchanged-candidate run ended with SIGTERM without a test failure;
the subsequent complete rerun above is the accepted gate. No PR, push, develop
merge or issue closure was performed.

### Device evidence

Maestro controlled only exclusively leased `emulator-5554` (Android 17, API 37).
No app data was reset and no credentials were read or changed in this follow-up.
Checks covered first-open keyboard visibility, absence of the dismiss button,
inline descriptions, section collapse/actions, symmetric collapsed spacing,
horizontal upload choices and system Back. Both Top and Bottom positions were
exercised at 320 logical pixels and 2.0 text scale. The Bottom Danbooru check
applied Last 30 days as `age:<30d`; a selector retry accounted for the rendered
chip's spaces. The final APK received the Top enlarged-text check and a normal
Danbooru check. Bottom layout checks used the preceding build with identical UI;
the final build only replaces a deprecated TickerMode lookup with its equivalent
current-SDK API.

Final screenshots: `/tmp/71-search-options-header-final.png` and
`/tmp/71-header-complete-top-320-2x.png`. The enlarged Bottom Danbooru evidence is
`/tmp/71-header-final-bottom-danbooru-320-2x.png`. Device density was restored to
physical 320, font scale to 1.0 and the search-bar setting to Top. Default profile
was selected, temporary selected conditions are absent, and normal QA search
history remains. The lease was released. No physical device was operated on.

## Explicit options toggle and selection follow-up

Verification completed: 2026-10-23 (Europe/Vienna).
Checked runtime: `953fa730a7aa9a9124c91a6ee0e7eaae0cfeed7c`.

The user withdrew the persistent `Searching…` reproduction during this follow-up.
Simple live tag searches completed on the reserved emulator. A separate,
deterministic defect was confirmed: the controller-backed header interpreted a
completed response with an unknown total as perpetual loading. This code also
exists in the local `v4.6.1-timberpile.1` baseline; it is not evidence that issue
#71 introduced the user's transient symptom.

### Corrections and decisions

- Advanced options open only through the down/up arrow inside the search field.
  Initial focus still opens the keyboard according to the existing preference;
  it does not open the advanced menu. Typing continues to show suggestions.
- Raw mode and the menu toggle belong to the text field's tap region. Toggling
  either control preserves the current text and raw flag. Mouse-pointer widget
  coverage and Android touch checks verify that raw mode keeps keyboard focus.
- Confirmed tags, graphical filters, quick choices, favorites and history entries
  close the editor and keyboard while the existing coalescer updates results.
  Suggestion callbacks no longer re-request focus after a completed selection.
  Incomplete option prefixes still focus input for continued editing. Canceling
  a graphical editor restores previous focus; Apply does not.
- The inline options viewport accounts for the bottom navigation/system inset.
  Catalog and graphical sheets explicitly protect their bottom content with
  `SafeArea`; `showModalBottomSheet(useSafeArea: true)` alone excludes that edge.
- Loading, empty and result-count text stays on one line, with ellipsis at
  constrained widths. Header actions take their intrinsic width within a bound;
  the counter receives the remaining space. Accessibility retains the full text.
- The controller-backed counter observes refresh completion as well as count.
  Unknown totals and failed requests stop the spinner without inventing a total
  from the loaded page; known zero and positive totals retain their normal UI.
- Existing application tests now follow explicit menu opening and automatic
  selection closure. The contextual Following navigation test still verifies
  both Back steps by explicitly opening the menu before dismissing it.

### Review and automated evidence

The complete diff against `fb1a5e3711c81f35a7f308d8f368dcfcfb97a801` was reviewed
again, including request ownership, profile/edit snapshots, shared consumers,
suggestion generations, native serializers and UI constraints. Earlier review
results remain recorded above. No further concrete findings remained after the
counter layout correction and the navigation test update.

Focused coverage includes unknown/zero/known/error count completion, raw-mode
and draft retention, explicit menu toggling, keyboard closure, catalog Apply
with an already focused search field, and a 48-logical-pixel system bottom inset.
Application coverage exercises history, browsing, keyboard navigation and both
search-bar positions. The initial unknown-total regression failed before the
fix. The first full application run had one obsolete navigation expectation;
that expectation was updated to the requested explicit-open interaction and its
isolated rerun passed. It was not counted as a complete-suite pass.

Final verification on the unchanged candidate (subsequently committed as the
runtime above):

- `TEST_CONCURRENCY=3 ./scripts/run_regression_tests.sh`: exit 0;
  **4,512 application tests**, **1,472 package/CLI tests across 13 suites**,
  **72 Python tests**, and both repository shell suites passed. The two existing
  `go_router` skips remain. The physical-core detector returned six; the final
  complete run used the supported three-worker override to reduce memory pressure
  while other worktree suites were running. No test group was omitted.
- Full issue Dart diff plus the new regression file passed
  `fvm flutter analyze --no-pub`: **51 items, no issues, exit 0**. Log:
  `/tmp/71-interaction-analysis-verified.log`.
- `fvm dart format --output=none --set-exit-if-changed` checked all 17 Dart files
  changed in this follow-up: zero changes, exit 0. `git diff --check` passed.
- Full runner log: `/tmp/71-interaction-complete-regression-final.log`.
  Earlier failed application-run log:
  `/tmp/71-interaction-complete-regression.log`.
- The documented native-hook cache warning and existing Dart VM finalizer
  diagnostic still appeared. They did not fail the final commands; no SDK or
  dependency changes were made to suppress them. See
  [build troubleshooting](../../build_troubleshooting.md) and the existing
  [migration diagnostic record](../../migrations/upstream-v4.6.1/REGRESSION_FIXES.md).

### Android and live-site evidence

An exclusive lease covered `emulator-5554` (Android API 37, x86_64). Maestro MCP
controlled the UI without clearing app data. The final APK was built from the
runtime source reported above using:

```bash
fvm flutter build apk --debug --flavor dev --target-platform android-x64 --no-pub
```

Build exited 0. Installed and local APK SHA-1 both equal
`df1923015e6ed625bbbd7d43c283fe32c1f9664c`.

- Safebooru: simple `cat` search completed; raw mode remained enabled when tapping
  the input again, with Android reporting `mInputShown=true` during the raw edit.
  Confirming the tag closed the keyboard and showed results.
- Danbooru: catalog and Uploaded/Score sheets were exercised at 320 logical pixels
  and 2x font scale. Horizontal scrolling reached Last 30 days; choosing it hid
  options and applied `age:<30d`. Score editing with the keyboard open allowed
  scrolling to Apply and committed the comparison. Sheet actions remained above
  Android navigation.
- Gelbooru: Rating General and Newest generated native `rating:general` and
  `sort:id:desc` conditions and returned live results. No Danbooru Uploaded
  option was advertised. The final one-line result counter was inspected at 2x.
- Top and bottom search-bar positions were checked, including raw input with
  the keyboard open and the catalog at 320 pixels/2x. A catalog flow during
  animation was inconclusive; the settled flow passed with the keyboard already
  open at both normal and 2x text, verified by the resulting rating chip and
  visible navigation after Apply. A matching widget regression passed too.

Local screenshots include `/tmp/71-raw-keyboard-preserved.png`,
`/tmp/71-danbooru-editor-320-2x.png`, `/tmp/71-score-keyboard-320-2x.png`,
`/tmp/71-final-bottom-raw-320-2x.png`,
`/tmp/71-final-bottom-catalog-320-2x.png` and
`/tmp/71-final-top-counter-320-2x.png`. These are local run artifacts, not
repository fixtures. Existing signed-in profiles sufficed; credentials were not
read or exposed during this follow-up.

Font scale was restored to 1.0, density to the physical 320 setting, and search
bar position to Top. A normal restart discarded temporary search-route state
without resetting application data. The emulator lease was released. Prior
live acceptance cases not changed by this follow-up remain documented above;
this run does not claim exhaustive acceptance for every configured website.


## Timeline entry and raw suggestion follow-up

Date: 2026-10-23 (Europe/Vienna). Runtime: `10cfb3265`.

### Confirmed causes and changes

- The fresh search route drew an opaque empty Material surface before its first
  query. Fresh routes now overlay the source timeline transparently; the source
  remains painted and the modal route prevents interactions with it. Search
  results replace that background only after confirmed input. This preserves
  the existing no-request-on-unconfirmed-input contract.
- Home search entry used the general autofocus setting despite an explicit tap.
  The `fromSearchBar` route flag now requests focus for that deliberate action;
  other entry points retain the existing setting. Headless tests exercise all
  six phone-size/top-bottom combinations with automatic focus disabled.
- Controller-backed repository requests used `originalTag`, so typed `one piece`
  went over the wire with spaces while autocomplete sent `one_piece`. Requests
  now use canonical typed serialization. A direct repository regression checks
  both input paths and verifies that opaque raw queries keep exact whitespace.
- The raw toggle and delayed no-match screen/timer are removed. A final suggestion
  row accepts the exact buffer as raw, with the existing localized RAW badge on
  its right and an accessible raw-query label. Normal matches precede it. It is
  available while autocomplete is pending, empty or failed, and while editing a
  raw chip. Selection uses the existing item-edit, IME and automatic-search
  lifecycle. No localization inputs changed; the already-applied manifests and
  generated accessors were reused.
- Re-reviewed the complete issue diff against
  `fb1a5e3711c81f35a7f308d8f368dcfcfb97a801`, including the preceding implementation,
  request ownership, option serialization, profile restoration, shared consumers,
  layout and tests. No additional runtime defect was established after the fixes.

### Verification

The first full run finished with 4,510 passing tests and three failed UI tests:
one counted the now-retained source timeline as search results, and two attempted
Follow through the new raw suggestion overlay. The tests now target the active
route or dismiss the editor before interacting with its covered result header.
The corrected browsing/repository/suggestion rerun passed all four tests; the
profile-isolation rerun passed both cases. These failed runs are not counted as
a complete-suite pass. The earlier suggestion test also needed to avoid leaving
its synthetic debounce timer pending at teardown.

`./scripts/run_regression_tests.sh` completed with exit 0 on the runtime above:
**4,513 application tests**, **1,472 package/CLI tests across 13 suites**,
**72 Python tests**, and both repository shell suites passed. The two existing
`go_router` skips remain. The physical-core detector returned six, and the
complete runner used its default concurrency of six. No test group was omitted.

- Full runner logs: `/tmp/71-raw-complete-final.log`; earlier failed run:
  `/tmp/71-raw-complete.log`. Focused logs: `/tmp/71-raw-fixed-tests.log` and
  `/tmp/71-raw-profile-tests.log`.
- Full issue diff analysis checked 56 Dart files with
  `fvm flutter analyze --no-pub --no-fatal-infos`: exit 0, no errors or warnings.
  Four pre-existing informational diagnostics remain in unchanged statements of
  `navigation_search_profile_test.dart` (unnecessary async, two unawaited route
  pushes, one missing brace). The default fatal-info invocation returned 1 for
  these infos. The 12-file focused implementation analysis had no issues.
  Logs: `/tmp/71-raw-full-analysis-final.log`, `/tmp/71-raw-analysis-final.log`.
- Formatting checked all 14 follow-up Dart files with
  `fvm dart format --output=none --set-exit-if-changed`: zero changes, exit 0.
  `git diff --check` passed.
- Final Android build: `fvm flutter build apk --debug --flavor dev
  --target-platform android-x64 --no-pub`, exit 0; log:
  `/tmp/71-raw-build-final.log`. The documented native-hook cache warning and
  baseline Dart VM finalizer diagnostic remain; no toolchain changes were made.

### Device and live checks

Maestro MCP controlled the exclusively leased `emulator-5554` (Android API 37,
x86_64), without clearing application data or reading credentials.

- Home to Search retained the source timeline and opened the keyboard, with no
  automatic advanced menu. Reopening the bar after searching retained results.
- Danbooru: manually typed `one piece` and the real autocomplete match both
  returned 28,631 results during this run. Normal API suggestions preceded the
  final raw row. An unmatched input offered only the raw row; selecting it
  created a raw chip, closed the editor/keyboard and refreshed results. Uploaded
  Exclude produced `age:>=7d`.
- At 320 logical pixels and 2x font scale, the raw row and right-hand badge were
  usable with the keyboard open at both top and bottom bar positions. Catalog
  and Rating Apply remained above Android navigation. A fast Gelbooru catalog
  sequence was inconclusive; the settled repeat showed the exact preview,
  applied chip, closed keyboard and live results.
- Gelbooru: Rating General applied `rating:general`; Newest applied
  `sort:id:desc`. Both returned live results. The catalog did not expose Uploaded.
  Safebooru also exercised the raw fallback and selection path. Earlier unchanged
  acceptance cases remain in the historical sections above.

Local screenshots: `/tmp/71-home-search-open.png`,
`/tmp/71-raw-one-piece-suggestions.png`, `/tmp/71-raw-after-matches.png`,
`/tmp/71-typed-one-piece-results.png`,
`/tmp/71-autocomplete-one-piece-results.png`, `/tmp/71-raw-fallback.png`,
`/tmp/71-raw-top-320-2x.png`, `/tmp/71-raw-bottom-320-2x.png`,
`/tmp/71-raw-catalog-320-2x.png`,
`/tmp/71-gelbooru-rating-before-apply.png`,
`/tmp/71-gelbooru-rating-after-apply.png`, and
`/tmp/71-gelbooru-native-sort.png`. These are local evidence, not fixtures.

The final rebuilt APK was installed and a fresh Home-entry/raw-selection smoke
flow passed (`/tmp/71-final-home-entry.png`, `/tmp/71-final-raw-row.png`). Local
and installed APK SHA-1 both equal
`21d66d38ce7d9cb1c1c55d926962f391f7e5c22e`.
Font scale was restored to 1.0, density to physical 320 without an override, and
search-bar position to Top. A normal restart discarded temporary route state
without clearing app data. The exclusive emulator lease was released.

Delivery remains local: no push, PR, merge, issue closure or unrelated worktree
changes.


## Advanced UI and duration follow-up

Date: 2026-10-23 (Europe/Vienna). Runtime: `206b9111f`.

### Changes and review

- Opening advanced options now unfocuses the input and hides the keyboard,
  preserving the pending draft. Closing options does not reopen the keyboard;
  tapping the text input still does. The real-bar regression covers both an
  empty field and a nonempty draft.
- Quick choices now own independent scroll controllers with restoration disabled.
  The shared PageStorage ancestor previously restored another row's horizontal
  offset: a focused reproduction started a fresh row at 480 pixels instead of
  zero before the fix. It now starts at the leading edge. Scrolling within one
  mounted row remains available; reopening the UI starts its rows at the left
  in the tested left-to-right locales.
- The initial section gap and half-divider spacing are six logical pixels.
  Section header padding is smaller and symmetric. The extra option-header
  minimum height is removed, and quick-chip tap-target padding is compact, so
  card padding and choice gaps use the same six-pixel spacing. Options remain
  independently bounded to half the available editor height.
- Score presets are `20+`, `50+`, `100+`, serialized as inclusive comparisons.
- Uploaded accepts native months (`mo`) and years (`y`) as well as hours, days
  and weeks. Parsing existing editor values preserves the selected unit;
  exclusion preserves comparison boundaries for months and years too.
- Uploaded presets now target older posts: over a month, a year and five years
  ago (`age:>1mo`, `age:>1y`, `age:>5y`). These provide a useful older-post cutoff
  beyond the recent posts already presented by newest sorting. The
  [official Danbooru cheatsheet](https://safebooru.donmai.us/wiki_pages/help%3Acheatsheet)
  documents the native units; no approximate day conversion was added.
- Updated the real English/German resources and ran `./gen.sh i18n` successfully.
  Both locales have the same 63 search-option keys. Original handoff manifests
  remain historical records; ignored generated accessors were not committed.
- Rechecked the full issue diff against
  `fb1a5e3711c81f35a7f308d8f368dcfcfb97a801`, with particular attention to shared
  controller focus, scroll ownership/lifecycle, serialization, locale consumers
  and layout. No additional runtime finding remained after correction and
  verification.

### Automated verification

- `fvm flutter test --no-pub --concurrency=6 test/core/search/options`: 58 passed,
  exit 0. New tests cover independent row offsets, month/year restoration and
  Apply at 320 pixels/1x and 2x, native presets and exclusion boundaries.
- `./scripts/run_regression_tests.sh`: exit 0, **4,519 application tests**,
  **1,472 package/CLI tests across 13 suites**, **72 Python tests**, and both
  shell suites passed. The two existing `go_router` skips remain. The runner
  used the detected six physical cores; no groups were omitted.
- The affected search scope initially analyzed without issues. Final full-diff
  analysis checked 57 Dart files with `fvm flutter analyze --no-pub
  --no-fatal-infos`: exit 0, no errors/warnings, the same four existing info
  diagnostics in unchanged statements of `navigation_search_profile_test.dart`.
- Final format check covered all 13 changed/new Dart files: zero changes, exit 0.
  Locale key parity and `git diff --check` passed.
- `fvm flutter build apk --debug --flavor dev --target-platform android-x64
  --no-pub`: exit 0. The baseline native-hook cache warning and SDK XML/Kotlin
  toolchain notices were reported; no dependency or SDK change was made.

Logs: `/tmp/71-polish-focused-pass.log`, `/tmp/71-polish-complete.log`,
`/tmp/71-polish-analysis-final.log`, `/tmp/71-polish-i18n.log`,
`/tmp/71-polish-build.log`. The expected failing pre-fix scroll reproduction is
`/tmp/71-polish-scroll-before.log`. Intermediate focused runs caught a test
finder matching the editable preview as well as the numeric field and missing
API/import setup; those were corrected before the final full pass.

### Device evidence

Maestro MCP controlled the exclusively leased `emulator-5554` (Android API 37,
x86_64), with no data reset or credential access. On the installed runtime:

- Advanced search hid the keyboard (`dumpsys input_method`: `mInputShown=false`),
  exposed the full option viewport, and began the horizontal rows at their first
  choices. Compact section/card spacing was inspected visually.
- Danbooru's three older-upload presets applied the expected chips and returned
  live results. At 320 logical pixels/2x text, the Uploaded sheet accepted Months
  and Years. The months case applied `age:<2mo` with the keyboard open and Apply
  reachable; the years case applied `age:<7y`. Apply closed the keyboard.
- The 2x Score row showed `20+`, `50+`, `100+`; selecting `20+` applied
  `score:>=20` and refreshed results.

The bottom search bar also hid the keyboard on opening advanced options
(`mInputShown=false`). At 320 pixels/2x text, its catalog and Uploaded Apply were
reachable above Android navigation. These additional captures are
`/tmp/71-polish-bottom-320-2x.png` and
`/tmp/71-polish-bottom-uploaded-320-2x.png`.

Installed and local APK SHA-1 both equal
`1ac02a4cc3b44ba1600d70a7dd8235ed4c0f84c2`.
Font scale was restored to 1.0, display density to physical 320 without an
override, and search-bar position to Top. A normal restart cleared only temporary
route state. The exclusive emulator lease was released.

Screenshots include `/tmp/71-polish-advanced-keyboard-hidden.png`,
`/tmp/71-polish-older-month-results.png`,
`/tmp/71-polish-older-five-years-results.png`,
`/tmp/71-polish-options-320-2x.png`,
`/tmp/71-polish-months-keyboard-320-2x.png`,
`/tmp/71-polish-month-results.png`, `/tmp/71-polish-years-results.png`,
`/tmp/71-polish-score-320-2x.png` and `/tmp/71-polish-score-results.png`.
These are local evidence artifacts, not repository fixtures.

No push, PR, develop integration or issue closure was performed.


## Empty-editor dismissal follow-up

Date: 2026-10-23 (Europe/Vienna). Runtime: `bb15dab78`.

The transparent fresh-search route kept its modal barrier after Android hid the
keyboard. Browse stayed painted underneath, but could not receive pointer input.
The scaffold now observes the keyboard-visible to keyboard-hidden transition and
returns to the source route after the frame when the editor is unused and empty.
The callback checks the final keyboard state, mount/current-route ownership,
completed-search state, selected tags, input and chip-edit state. It does not
close active suggestions, advanced options, drafts, applied searches or covered
routes. No extra network request or source-timeline recreation was introduced.

The new application regression failed on both top/bottom bar positions before
the fix. Afterward it dismisses the keyboard, finds an interactive Browse tile
and opens its details directly. Companion tests verify that opening advanced
options hides the keyboard without popping the fresh route. Existing query,
keyboard and rotation tests remain passing.

- Focused application/search-option suite: 71 passed, exit 0. Log:
  `/tmp/71-dismiss-focused.log`. Pre-fix reproduction:
  `/tmp/71-dismiss-before.log`.
- Changed-scope `fvm flutter analyze --no-pub`: no issues, exit 0. Log:
  `/tmp/71-dismiss-analysis-final.log`.
- Final Android build: `fvm flutter build apk --debug --flavor dev
  --target-platform android-x64 --no-pub`, exit 0. Log:
  `/tmp/71-dismiss-build-final.log`. The documented native-hook warning remains.
- Formatting and `git diff --check` passed. Reviewed the fix against its parent
  and the full issue's route, focus and overlay ownership; no further finding
  remained in the affected lifecycle.

The first six-worker full run finished with 4,522 passing application tests and
one failure in the unchanged bookmark cached-image decoding test. Its isolated
rerun passed all 18 tests without changes; the failed assertion follows ten
fixed 60 ms I/O waits in that test. No bookmark/cache code was modified for this
search fix. That failed run is not counted as a complete pass. Logs:
`/tmp/71-dismiss-complete.log`, `/tmp/71-dismiss-cache-rerun.log`.

`TEST_CONCURRENCY=3 ./scripts/run_regression_tests.sh` completed with exit 0 on
the unchanged runtime: **4,523 application tests**, **1,472 package/CLI tests
across 13 suites**, **72 Python tests** and both repository shell suites passed.
The two existing `go_router` skips remain. Six physical cores were detected;
the supported three-worker override was used for this final repeat. The
previously failing bookmark test also passed within this full run. No test was
excluded or weakened. Log: `/tmp/71-dismiss-complete-final.log`.

Maestro MCP exercised the installed APK on exclusively leased `emulator-5554`
without clearing data or reading credentials. Home -> Search -> Android Back
returned to Browse; a swipe moved the original grid and a direct tile tap opened
post details. Advanced options remained open when they hid the keyboard.
Screenshots: `/tmp/71-dismiss-browse-scrolled.png`,
`/tmp/71-dismiss-browse-post-open.png`, `/tmp/71-dismiss-advanced-remains.png`.
No device font, density or search-position settings were changed. A normal
restart discarded transient routes, and the emulator lease was released.
Installed and local APK SHA-1 matched:
`7320f433b04d2f7fa1ca037b025e6e090ea38c8a`.

No push, PR, develop integration or issue closure was performed.
