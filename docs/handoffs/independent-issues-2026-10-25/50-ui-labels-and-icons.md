# Issue #50 — UI labels and action icons

## Reviewed source

- Branch: `maintenance/50-ui-labels-and-icons`.
- Original base: `2e5ca00d7bca6881cfddd19125c72d5f80d9593d`.
- Review combined the local regression fixes at `57bfe816f` with remote UI follow-ups at `7b78a9fd5`, preserving both histories.
- Final runtime candidate: `919fd6f27bff4ab30507b8e806fecd1a04f2d23b`, including `develop` at `8040071defbccb9c024785bd7c59d6f0f5fa5e29`.
- The user requested review, repairs and integration once verification passes. No PR or Astra review is involved.

## Resulting behavior

English short labels and official feature names use consistent capitalization; ordinary prose and other locales retain their grammar. English labels were shortened where icons and context preserve their meaning. Localization keys and interpolation tokens remain unchanged.

History clearing and selected-tag confirmation use accessible icon buttons. Clearing still confirms and Cancel preserves history. Context menus, Selection Manager and Viewer overflow actions share their existing action icons. Viewer customization reads **Customize UI**, and **View Tags** uses the same tag icon as Selection Manager.

Following, feed and Bookmark menus pair localized text with action icons. Profile selectors show site/custom icons and names; URL context remains available to accessibility and tooltips. Topic-card metadata is unchanged. Bookmark source selectors show site favicons with a globe for All. Bookmark Group overflow omits Select while long press retains selection.

Integration preserves the accepted #80 picker: the compact **Group** action, inline folder navigation, removed Active Group state and synced-group bookmark-status option. It also preserves #66's selection-only search action and wrapped caption.

## Confirmed problems repaired

- Reconciled diverged local and remote #50 histories and resolved integration conflicts without dropping current Bookmark/Viewer regression coverage.
- Added the favicon cache, deterministic Dio and developer-options overrides required by isolated Bookmark control fixtures.
- Scoped a Follow button finder to its dialog after the empty-state button acquired the same short caption.
- Updated remaining obsolete Record/Load Original test expectations. Retained completion-based cache-settings synchronization and Viewer Original-quality assertions.
- Fixed a real layout regression: long icon-bearing adaptive overflow menus exceeded short viewports. Their content now scrolls within the anchor's available height. A package regression checks the last action remains reachable and invokes its callback.
- Disposed semantics handles before Flutter's end-of-test checks and supplied a real short viewport for the new package test.
- Formatted affected Dart files using FVM. JSON review confirmed unchanged English keys/interpolation tokens and no non-English changes relative to develop.

## Verification

Pinned FVM setup and regeneration completed through `./init.sh`. The final combined-candidate regression completed successfully. Verification applies to `919fd6f27`; subsequent edits to this handoff only report results.

Focused checks passed after repair: Bookmark controls at narrow/enlarged sizes and with keyboard; Following dialog behavior; Viewer Original actions; developer tools; Kurumi overflow accessibility, bounds, scrolling and callback behavior.

`fvm flutter analyze --no-pub --no-fatal-infos`: exit 0, **0 errors, 0 warnings, 3,166 informational diagnostics**. `git diff --check` passes for the task diff against develop.

## Android evidence and limits

- Built with `fvm flutter build apk --debug --flavor dev --target-platform android-x64` and installed without clearing data on leased `emulator-5554`.
- Local and installed APK SHA-256 both equal `18915be148689ce7616001f5ca964e212ed6a04078f2fa3051784ae27ddb9f24`. This build includes the final runtime menu fix; later changes were test/report-only.
- Final-APK Maestro smoke passed: Following navigation, Sort By with Manual Order/Updates First, More/Bulk Follow, Search trigger and search field (13 commands). Opening the Browse search and its keyboard also passed (4 commands).
- The additional return-navigation script did not complete because its Following selector was unavailable after Back; it is not counted as a passed navigation check. No product defect is inferred from that selector failure. Narrow/enlarged/keyboard behavior is covered by widget tests and the full application's keyboard navigation tests.
- No screenshots or data reset were used. The test app was stopped and the emulator lease released. TalkBack speech output and German device layout were not manually exercised.

## Final integration gate — 2026-10-27

`./scripts/run_regression_tests.sh` completed with exit 0 at default concurrency **6** on the final runtime candidate:

- **5,173 application tests passed**.
- **1,597 package/CLI tests passed** across all 13 package suites, including the complete Kurumi suite (**167 passed**).
- Two pre-existing disabled `go_router` tests were skipped (`routing_config_test.dart:142`, `go_router_test.dart:4743`); no suite was omitted.
- Both repository shell suites and **72 Python tests passed**.

The earlier focused and full-run failures were repaired and do not reproduce in this final pass. Only this English report changed afterward; the checked runtime, tests, dependencies and generated outputs remain unchanged. The final squash commit preserves issue #50, publishes to `origin/develop` and completes the authorized issue/branch cleanup. Full logs and the final APK are retained in the primary checkout's ignored `artifacts/issue50-review-2026-10-27/` directory.
