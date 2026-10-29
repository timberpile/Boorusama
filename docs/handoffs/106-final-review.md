# Issue #106 final local review — 2026-10-29

Reviewed the full implementation at e9daef989e17ed439b7ef942a65ce90b245c5710 against develop 422aeae087c1108e655d85d1a3dac25120456cd6, production root-navigator Undo producers, live shell feedback anchor, Kurumi/OKToast host and viewer ownership/disposal. The containing commit identifies the final verified source state, including this record.

## Corrections and review

- Fixed analyzer-rejected BuildContext parameter reassignment with a mounted local feedbackContext, including Undo failure feedback.
- Confirmed that the original live inset bridge treated every covered viewer as zero obstruction. Without the previous fixed toast margin this overlapped the real bottom preview/toolbar. Measure the existing preview widget, publish its visible animated extent through the existing viewer controller and owned navigation-chrome path, and clear it on disposal. Root feedback now follows measured viewer obstruction and restored navigation. No guessed toolbar height or separate shell layout framework was introduced.
- Added animated/nonanimated measurement regressions for hide/show/resize/disposal and viewer-owner transitions in the real notifier presentation tests.
- Repaired faulty action selectors and Kurumi assertions: ordinary toast Container dimensions included its old vertical margin; action toasts require a 48px accessible target, so exact equal height was invalid. Styling, decoration, action invocation and expiry remain asserted.
- OKToast reads native ui.window instead of TestFlutterView. KeyboardToastHost explicitly models that external host displacement for widget tests; these cases are not represented as native keyboard acceptance. The bookmark viewer fixture now supplies its actual declared 80px obstruction. Five-second expiry is drained on the virtual clock.

The complete correction diff was re-reviewed, including lifecycle/listener cleanup, ownership and safe-area accounting. `git diff --check` passed.

## Automated verification

FVM formatting on all affected Dart files passed. Affected `fvm flutter analyze --no-pub --no-fatal-infos` returned 0 with 19 informational style diagnostics, no warnings/errors. Focused root/live Undo, bookmark notifier and viewer tests passed all 88 cases.

The complete regression components passed on the unchanged final runtime/test state:

| Component | Passed | Skipped |
| --- | ---: | ---: |
| Application | 5486 | 0 |
| booru_clients | 206 | 0 |
| boorusama_cli | 254 | 0 |
| cache_manager | 59 | 0 |
| coreutils | 191 | 0 |
| dtext | 59 | 0 |
| extended_image | 47 | 0 |
| filename_generator | 31 | 0 |
| flutter_sqlite3_migration | 45 | 0 |
| foundation | 65 | 0 |
| go_router | 436 | 2 |
| i18n_cli | 32 | 0 |
| Kurumi | 167 | 0 |
| retriable | 16 | 0 |

Commands: `./scripts/run_regression_tests.sh` initially completed the application and booru_clients suites, then stopped because the unchanged CLI timezone subprocess test exceeded its 30s hang guard during competing FVM work. A complete `fvm dart test --concurrency=6 --reporter expanded` in boorusama_cli passed all 254, without changing the test or relaxing its timeout. The remaining packages then ran sequentially with the runner's Flutter/Dart selection and concurrency 6. Both `.github/scripts/test-pull-request-policy.sh` and `.github/scripts/test-android-release-scripts.sh` passed; `python3 -m unittest discover -s scripts/tests` passed 72 tests. This is a recovered complete component pass, not a claim that the initial runner exited successfully. Two upstream router cases were skipped by that package.

One cache_manager run emitted a Dart VM callback/finalizer diagnostic despite exit 0 and 59 passes. Its complete suite was rerun: 59 passed with the same callback diagnostic. This native diagnostic remains unresolved; passing assertions/exit codes are not described as clean native runtime logs. No cache/FFI changes were made for this navigation task. The documented libavif native-hook warning also appeared; successful commands completed after it.

`fvm flutter build apk --debug --flavor prod --target-platform android-x64 --no-pub` passed. Existing Gradle/Kotlin future-support warnings remain.

## Android acceptance actually performed

Exclusively leased emulator-5554; renewed before every operation; Maestro discovery, hierarchy inspection and real UI actions. Installed into this session's disposable production package with -r, preserving the signed-in dev package. Local and installed APK SHA-256 both: `7e2ede3b8c358e7bf8565e015a70ea6ce4d52af169ac03b02127c29ee7e78519`.

Konachan (Safe) provided decoded media and a working viewer after Safebooru CAPTCHA/media failures. Used the real viewer Bookmark Groups → Default add/remove path. The action toast was clear of the measured toolbar (106-viewer-undo.png); a repeat asserted Undo visible and tapped it successfully. Removing again and closing the viewer kept the live toast above restored Browse navigation (106-viewer-to-browse-undo.png).

Keyboard-transition capture attempts reached Search/the native IME after presentation timing delays, but did not establish a full-keyboard toast frame. They are not passes. No shared/personal data was reset. The lease was released; no device setting was changed.

Remaining device acceptance: live toast during a fully open native keyboard, enlarged system text, immersive/rotation/background/expiry and batch-removal transitions. Coordinate additional Undo producers from #55 and viewer changes from #89/#104/#112 during eventual authorized integration. Those branches were not modified or combined. The complete regression must run again on the eventual combined candidate. No merge, PR, closure or branch deletion occurred.

Evidence: /tmp/boorusama-review-2026-10-29/106-{analysis,focused-tests,regression,cli-retry,regression-resumed,cache-retry,build}.log and 106-*.png.

## Selection Manager correction after user review — 2026-10-29

The user rejected the timeline removal case: selection hides navigation, but the toast did not account for the still-visible Selection Manager. Reproduced with the real timeline and bookmark-removal dialog; toast bottom was 552 logical pixels while the expected upper bound above the controls was 446. The earlier viewer acceptance did not cover this case.

Measure the constrained visible selection panel (controls, footer, safe-area/spacer) and publish its height through the existing active-destination selection owner. Root overlay insets now observe that obstruction while selection remains active, including panel resizes and keyboard placement. Releasing the owner restores normal navigation/system insets. Viewer/keyboard behavior retains its existing priority. The real removal dialog also needed the established `scrollable: true` policy: at 320x568 and 2x text its title/content otherwise overflowed by 92 pixels. The journey now scrolls the group row into view before tapping.

Verification on the final runtime/test state in this handoff's containing commit:

- Observed the production timeline geometry assertion fail before the correction. Added real timeline removal/Undo journeys at 1x and 2x text, plus an already-visible root toast following selection-panel resize, dismissal and keyboard insets.
- `fvm dart format` on all 19 affected/new Dart files: zero further changes. `fvm flutter analyze --no-pub --no-fatal-infos` on the same scope: exit 0, no errors/warnings, 23 informational diagnostics.
- `fvm flutter test --no-pub --concurrency=6 --reporter expanded test/application/timeline_selection_undo_insets_test.dart test/core/navigation`: **74 passed**.
- **`./scripts/run_regression_tests.sh`: exit 0**, **5,488 application tests** and **1,608 package/CLI tests passed**; two existing upstream go_router skips. Both shell suites and all **72 Python tests passed**. Unlike the earlier recovered pass, this final complete runner finished successfully. No timeouts, tests or assertions were relaxed.
- Android production debug x64 APK build: passed. Installed on exclusively leased emulator-5554 into com.timberpile.boorusama, preserving the signed-in dev app. APK SHA-256: `0b5b6adc931cf38179794d6abbe029e420146a4de923a80ea696538e6e35765f`.
- Maestro exercised Konachan (Safe) Browse -> real post -> Bookmark Groups -> Default, returned to Browse, selected the same post, then Bookmark -> Remove From -> Default. Undo was visible and tapped successfully while `1 item selected` remained visible. A timed screenshot captured the toast entirely above Selection Manager: `/tmp/boorusama-followup-2026-10-29/106-timeline-undo.png` (preserved capture frame 15). Restored the disposable bookmark state, closed selection, and released the lease. No device settings or personal data were reset.
- Independently reviewed the complete correction and `git diff --check`: passed.

Logs: `/tmp/boorusama-followup-2026-10-29/106-{reproduction,format,analysis,tests,regression-final,build}.log`. Existing native Dart-VM callback/finalizer and libavif hook messages persisted in successful test/build runs; native logs are not clean.

User acceptance of this correction remains pending. Native keyboard-open toast frames, enlarged Android system text, immersive/rotation/background/expiry and additional #55 Undo producers remain manual checks. Widget tests cover enlarged text and changing keyboard/selection obstructions, not every native transition. #89 has since been accepted and integrated separately into develop; it was not pulled into this branch. Coordinate #55/#104/#108/#112 before any later authorized integration, and run the complete suite on that final combined candidate. Keep #106 open and retain this branch; no merge, PR, closure or deletion is authorized here.
