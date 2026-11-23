# Issue #145: Rounded-search dependency and final verification

Branch: `feature/145-bookmark-picker-presentation`. Local delivery only; no push,
PR, merge or issue closure. **Integrate #139 first**, at final base
`b8b233bf19c9fcb305e5ccff0be373293f998e40`.

## Commits and behavior

- Preserves the user-authored #139 correction `6a7d4a533`: the actual search input
  uses the default rounded Kurumi surface, with its opaque shared parent intact.
- `09c414fa5`: replayed typed Kurumi picker implementation.
- `6e27a595c`: original implementation verification documentation.
- `352c45e84`: compact favicon/custom/fallback source-icon coverage.
- `b7d1d2564`: previous dependency verification documentation.
- The following commit contains only this continuation and its historical link.

Picker requests, content, navigation and selection remain independent from their
anchor/dialog surfaces. Immediate opening, deferred metadata, exact-source guards,
closing-animation cancellation and Create Group ownership transfer are unchanged.
The [entry-point inventory](145-bookmark-picker-presentation-20261103.md#final-entry-point-inventory)
remains applicable: Post Viewer, single-selection controls, Pool/Series/Collection
buttons, Related gallery, stored-reference actions, helper/extension dialogs,
context submenus, bulk group selection, Favorites Sync destination selection and
shared group naming. No raw Material dialog/menu surface or obsolete `anchored`
flag remains in these workflows. No broader application migration was performed.

## Automated evidence

- Complete combined candidate: `TEST_CONCURRENCY=3 ./scripts/run_regression_tests.sh`
  passed with **6,111 application tests**, **1,659 package/CLI tests**, both shell
  suites and **72 Python tests**, `REGRESSION_EXIT=0`.
- Final #139 dependency update then removed two obsolete transparent-input
  package tests and added documentation only. Runtime/application-test content
  was unchanged. The complete final Kurumi package rerun passed **184 tests**;
  the final retained total is **1,657 package/CLI tests across 13 suites**.
  Two pre-existing go_router skips remain. This is qualified verification in
  unchanged-source phases, not a newly claimed single runner after the rebase.
- Affected analysis: 0 errors, 0 warnings, 89 infos, nonfatal-infos exit 0.
  Formatting and source-surface audit passed; final `git diff --check` passed.
- Final FVM debug x64 APK build passed. A first successful build reported a
  generated-file modification notice; a repeat passed without that notice.

Controlled automated coverage includes metadata held pending, source changes,
repeated actions, dismissal while closing, group creation handoff, folders,
batch/destination semantics, narrow width, enlarged text, RTL pointer geometry
and focus restoration. This does not establish measured device latency.

## Current Android evidence and limits

Leased Android 17 `emulator-5554`, 360 dp wide, font 1.0, gesture navigation,
without resetting app data. Installed/local SHA-256 matched:
`9292764d9b22cde6b4cee0092cf333acb2293b6151efaaf427d1857e76f0394e`.
Maestro opened All Bookmarks (empty); visual inspection confirmed the distinct
rounded Search field and common opaque Midnight parent. A public safe Post's
Bookmark Groups opened the compact Kurumi anchor. Group transferred to its name
dialog; Save/Cancel were visible and Cancel returned without writing.

This final device rerun covers Post anchor/create-cancel and the actual corrected
search surface. The earlier broader picker device scenarios in the linked
handoffs remain historical evidence, not newly repeated acceptance. Physical
input, device RTL, desktop pointer, live account-removal/offline, backup upgrade
and every picker type on a device remain manual. A changed combined develop
candidate requires fresh full verification. #146/#147/#148 runtime work stays
deferred; #136 records conventions and #105 owns radius changes.

Durable logs: `.worktrees/_artifacts/approved-ui-145/`. Shared final-device cleanup
and preference-restoration limits are recorded with #152, tested afterward.
