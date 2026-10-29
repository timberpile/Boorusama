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
