# Issue #111 final local review

Reviewed the complete implementation at remote input `788c68e7bd9e63066ed124757b98f87492fb3952`, based on develop `422aeae087c1108e655d85d1a3dac25120456cd6`, including downloader/installer consumers and the native validation policy. Foreground checks cover asynchronous download and permission results, denied permission does not reopen Settings in a loop, and retries retain the verified APK. Added an explicit mounted guard at the navigation call so static analysis recognizes the existing lifecycle protection. Formatted all changed Dart files.

Verification on this commit's source/tests:

- Fresh FVM dependency setup and `./gen.sh`: passed, including translation validation and generation of `app_update.download_and_install`. Generated output is ignored under the normal repository workflow. This checkout has no `packages/i18n/test` suite.
- `fvm flutter analyze --no-pub --no-fatal-infos` on all four changed Dart files: no issues after the guard correction.
- `fvm flutter test --no-pub --concurrency=6 --reporter expanded test/app_update`: 51 passed, no failures/skips. Final rerun included lifecycle races, delayed permission return, denial/retry without redownload, cancellation, disposed routes, ABI fallback, labels and existing checker/coordinator/downloader consumers.
- `./android/gradlew -p android testProdDebugUnitTest --tests com.timberpile.boorusama.GitHubApkInstallPolicyTest`: BUILD SUCCESSFUL; XML records 3 tests, zero failures/errors/skips. Checks include package/version/build mismatch, changed/missing/additional signing certificates, canonical private-cache boundaries and symlinks. The fresh checkout needed the ignored same-SDK generated Gradle wrapper/configuration from the already built worktree.
- `git diff --check`: passed.

The repeated libavif native-hook warning is documented in `docs/build_troubleshooting.md`; it did not prevent successful final commands. No native safeguard was relaxed.

Remaining acceptance: actual Android unknown-sources denial/grant/return, installer cancellation and foreground/background behavior with a verified installable APK, plus real Play/browser fallback. Widget method-channel fakes and host JVM policy tests do not prove OS installer behavior. No Android UI acceptance or release-signed upgrade is claimed for this branch. #109/#110 remain independent; they were not merged here. The final combined candidate must pass complete local regression before integration. No integration, PR, release, issue closure or deletion is authorized.

## Permission-return review and debug-signing diagnosis — 2026-10-29

The user exercised the intentionally older `0.0.0+1` production-flavor debug build: Download and Install downloaded successfully, Android's unknown-sources Settings opened successfully, and returning after allowing installs displayed the generic installation-start error. These download/permission observations are user-reported acceptance; successful Android installer launch/replacement is not yet accepted.

The local APK produced for that test reports package `com.timberpile.boorusama`, versionName `0.0.0`, versionCode `1`, and signer Android Debug. Its signing certificate SHA-256 is `671016e734ba672bead2493ba9b6c9e26a5edbcc5d565c32a52228793d2f3d2a`. The actual public release manifest was fetched; its arm64 APK was downloaded, matched to its declared size (100918022 bytes) and SHA-256 (`c8a7929919592ff0d3f089536cb8a58e96ab7cbcac9bafccfb1915fb1503189b`), and verified with Android SDK apksigner. The release certificate SHA-256 is `2121bb6443f3d3fc4a560c62939e7e42f3e25c5c0235e39f0ea23743168b27eb`.

Those certificates differ. Lowering the version makes the release newer but does not change the debug signing key. After permission return, `_install` invokes the native channel; `GitHubApkInstallPolicy.validateIdentity` rejects the mismatched signer before Android's confirmation installer opens, and the dialog presents the observed generic error. This is the expected safe failure for these two APKs. The exact PlatformException from the user's device was not captured, so this diagnosis rests on the test artifacts and verified execution path, not a device error log. No package/signature/version safeguard was relaxed and no runtime correction was warranted.

Current-source rechecks, unchanged runtime at `2c0d46f36f0405f384129239a63a14d18cea66b3`:

- `fvm flutter test --no-pub --concurrency=6 --reporter expanded test/app_update`: **51 passed**, including delayed permission return, denial/retry without another download, foreground/background races and existing consumers.
- `./android/gradlew -p android testProdDebugUnitTest --tests com.timberpile.boorusama.GitHubApkInstallPolicyTest`: **BUILD SUCCESSFUL**, XML **3 tests, zero failures/errors/skips**, including missing/changed/additional signers and package/version/private-cache constraints.
- Documentation diff and `git diff --check`: passed. This follow-up changes only this handoff; no additional application analyzer/full suite is warranted for a report-only update.

Evidence: `/tmp/boorusama-followup-2026-10-29/111-permission-return-check.log`, `111-native-policy-recheck.log`, `111-signing-comparison.log`, and `111-live-update-manifest.json`. No device data, permission or settings was changed during this follow-up. The user's primary checkout and temporary pubspec version change were preserved.

Remaining acceptance: use a lower-version build of this branch signed with the same release certificate as the downloaded target, and prove actual installer launch/cancellation/replacement and foreground/background behavior. A debug-vs-release rejection does not satisfy that gate. The user approved #109/#110 separately; #111 remains open, unmerged and retained, pending its own acceptance/integration approval. The final candidate combining #111 with current develop still needs the complete regression gate.

## Accepted integration and verification exception — 2026-10-29

The user accepted the remaining installation uncertainty, explicitly authorized merging #111, and said the tests can be skipped because they had already run. This supersedes the earlier pending-acceptance/no-authorization statements and waives a new test run for this integration only. Actual same-certificate Android installer/replacement acceptance remains unobserved; it is accepted as an assumption, not recorded as a passed device test.

Integrated the approved remote head `9ac4dd73b4c505c9c300a0e5fe43bf1ba0d06d07` into published develop `84df0c2de6cf8fe0177c49babb3fb0eee880f866` without conflicts. The complete staged patch matched the complete approved branch patch by stable zero-context patch ID before this evidence section was appended. The existing #109 header indicator and #110 UTF-8 byte decoding are retained. No runtime/test correction or dependency change was introduced during integration; the containing commit identifies the final combined state.

Verification reused: this branch's unchanged runtime at `2c0d46f36f0405f384129239a63a14d18cea66b3` passed 51 updater tests and three native install-policy tests; original affected analysis was clean. Develop immediately before #111 passed 5,546 application tests, 1,608 package/CLI tests, both shell suites and 72 Python tests, with two existing router skips. Those are separate checked states: they do not constitute a complete regression pass on the newly combined #111 candidate.

Executed for this integration: latest remote-reference/head checks, complete implementation/test/localization diff review, staged patch-equivalence check, `git diff --check`, combined tree/history review and publication verification. No new Flutter/Dart tests, analyzer run, generation, APK build or device acceptance was performed, following the user's exception. The routine combined regression requirement is explicitly waived for this integration; no new full-suite pass is claimed.

Under the user's merge approval, publish the Conventional Commit including #111 to origin/develop, verify it, close the issue/remove its workflow status and delete only the unchanged completed task branch/worktree using expected-tip protection. Preserve the user's detached checkout and temporary pubspec version 0.0.0+1. No PR, master change, tag or release is authorized. The prior signing diagnosis and test logs remain in `/tmp/boorusama-followup-2026-10-29/`.
