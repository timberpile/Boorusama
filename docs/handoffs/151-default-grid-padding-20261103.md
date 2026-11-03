# Issue #151: Default grid outer padding

Branch: `feature/151-default-grid-padding`, based on local develop `02b0d60e9`.
Implementation: `0c5e55e2a15b293b4edd66cd5820134d48526dcd`.
Local committed delivery only; no push, PR, merge or issue closure.

New global settings and missing `imageGridPadding` values use **4 dp**, matching
existing default spacing. Padding and spacing remain separate settings. Explicit
values, profile overrides, imported settings and unrelated settings edits retain
their values; no stored settings migration or forced rewrite was introduced.

## Verification

- FVM settings tests: 13 passed, including five new default/independent-setting
  and global/profile JSON round-trip cases (0, 4, 16 and 23.5 dp).
- Related layout suites: 61 passed; final manual-Load-More fixture: 1 passed.
- Two existing geometry tests now explicitly request 16 dp: whole-tile keyboard
  visibility and the underfilled manual footer. At 4 dp, larger tiles change the
  scroll geometry and the latter reaches automatic loading instead. Production
  loading behavior was unchanged; other fixtures exercise the new default.
- Complete final candidate: `TEST_CONCURRENCY=4 ./scripts/run_regression_tests.sh`
  **6,037 app tests + 1,655 package/CLI tests across 13 suites + both shell suites
  + 72 Python tests**, `REGRESSION_EXIT=0`. Two pre-existing go_router skips.
- Affected analysis: 0 errors, 0 warnings, 12 infos; nonfatal-infos exit 0.
  FVM formatting and final diff check passed.
- Debug x64 APK build passed. Installed/local SHA-256 matched:
  `ca522631e5429e02fc7f07ca396d041ff244f3094c89c2d1cd3f25e3e92dfef1`.

The first full run exposed the two fixed-geometry fixtures above; it is not counted
as a pass. The complete final run follows those corrections. Existing test
finalizer/native-hook warnings do not replace the explicit final completion.

Leased Android 17 emulator, 360 dp width: Maestro opened Appearance > Image Grid
and verified existing explicit Padding **16.0** and Spacing **4.0** were retained.
No slider was changed. New-install defaults and missing-key behavior are host-test
evidence; no fresh-install/reset device test is claimed. Full import-file UI and
physical-device acceptance remain manual. A changed integration candidate needs
fresh full verification.

Durable logs: `.worktrees/_artifacts/approved-ui-151/`.
