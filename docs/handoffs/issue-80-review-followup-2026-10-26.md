# Issue 80 review follow-up

Accepted task source: `feature/80-viewer-bookmark-picker` at `2d07d0e5038865c22ad9d5814e1c84c65111e87d`. The user authorized integration, publication, issue closure, and cleanup on 2026-10-26.

## Accepted develop integration

The final combined candidate uses `origin/develop` at `f0f443571c61ffc2f23dd159ce211d277eb7f34c` plus the accepted task source above, prepared as one issue-linked squash commit. The current-folder bulk-action snapshot from #73 and source-aware download services from #62 are preserved. Conflicts were limited to the logger import and keeping `selectedPosts` together with manual Recent tracking. Newer develop tests were adapted to the removed active-group API and nullable disabled-menu callbacks.

- `./gen.sh`: passed after combining localization/runtime inputs.
- Integration-boundary tests for bulk actions, downloads, previews, and bookmark-count persistence: **80 passed**.
- `./scripts/run_regression_tests.sh`: exit 0, **5,151 application tests**, all **13 package/CLI suites**, both shell tooling suites, and **72 Python tests** passed. The existing two go_router skips remain.
- `fvm flutter analyze --no-pub --no-fatal-infos`: exit 0, no errors or warnings, **3,164 informational diagnostics**.
- Runtime/test sources were unchanged after the complete pass; this integration report is documentation only. The final commit retains issue #80 in its subject and closing reference.
- Accepted device evidence is recorded below. No further Astra review was run.

Detailed integration logs are retained locally in ignored `artifacts/issue80-integration-2026-10-26/`. Earlier task logs and worktree configuration are preserved in ignored `artifacts/issue80-accepted-2d07d0e50/` before cleanup. GitHub issue #80 records the final accepted requirements and completion state.

## Menu sizing, Recent metadata, and default preference

- Back now owns the entire area containing its icon and folder path, ending at the Group action. Both header actions use the same Kurumi menu rows, icon inset, and compact height as the list. The busy Group action remains disabled, including accessibility actions.
- Halved plain-divider height (8 to 4) and titled-divider vertical margins (4 to 2), preserving their horizontal insets.
- Removed the fixed 100-pixel Recent folder-path limit. Each inline label uses the row's remaining width to the right inset, shares the group name's alphabetic baseline, and uses the divider color. Longer neighboring Recent group names do not determine its width; full paths remain available through tooltips.
- **Ignore synced groups for bookmark status** now defaults to enabled for new settings and old records missing the field. Explicit persisted true/false choices survive unchanged. Actual-viewer regressions now verify that the default keeps sync-only bookmark highlighting off while heart/upvote still update.

Verification on the current scoped candidate:

- `fvm flutter test --no-pub --concurrency=6 test/core/bookmarks test/danbooru_favorite_group_action_label_test.dart`: **567 passed**, including far-edge Back taps, header/list height and icon alignment, long Recent paths at 1x/2x text, baseline/right-edge/color checks, narrow/keyboard cases, saved default/explicit opt-out, and real-viewer favorite behavior.
- Complete Kurumi package suite: **165 passed**, including disabled popup semantics/dismissal and compact divider regressions.
- Affected source/tests analysis with `--no-fatal-infos`: exit 0, no errors or warnings, 110 informational diagnostics.
- Android debug dev x86_64 build passed. APK SHA-256: `21c43a0b0005caf7b7df3704c432de2a6d73f9d5e6975b3f1a97225d3761a2e4`.
- Maestro on exclusively leased emulator-5554 passed: Back hit area continued to Group, a tap immediately before Group returned to root, header/list/Recent rows all measured 72 physical pixels high, nested creation worked, and Recent displayed the full semantic folder path. Removed the temporary membership/group/two folders, restored Browse, and released the lease. Existing settings choices were preserved; default behavior is established by fresh/legacy-settings and real-viewer tests.
- The complete repository pass below remains historical; a later integration candidate requires a complete pass.

Logs/device notes: ignored `artifacts/issue80-menu-refinement-2026-10-26/`. No further Astra review was run.

## Compact picker navigation follow-up

The user now reports that favorite-button UI updates work again. This resolves the reported symptom through user acceptance; no specific favorite-state root cause is attributed to the picker changes. No further Astra review was requested or run.

- Fixed the titled divider's short rule: the previous loose-flex label reserved unused width. The title now has a bounded natural width and the rule fills the remaining space to the same right inset as a plain divider.
- Shortened the localized creation action to **Group**, retaining the plus icon.
- Replaced the separate breadcrumb section with one row containing the back icon, a small muted folder path, and the right-aligned creation action. Root has no Home/path label. Long paths use ellipsis with the full path in a tooltip.
- Applied the shared row to viewer, context, bulk, and Favorites Sync bookmark pickers. Creation retains the currently browsed folder and its existing busy/error behavior. The separator remains between this row and the groups list.

Verification on the final UI candidate:

- `fvm flutter test --no-pub --concurrency=6 test/core/bookmarks/bookmark_folder_ux_test.dart test/core/bookmarks/bookmark_post_button_layout_test.dart test/core/bookmarks/server_favorites/dialog_test.dart test/danbooru_favorite_group_action_label_test.dart`: **118 passed**. Includes nested paths, actual header alignment, back navigation, current-folder creation, narrow/enlarged-text/keyboard layouts, and actual picker divider edges.
- Full Kurumi package suite: **164 passed**. The new titled/plain divider edge regression failed on the previous implementation and passes after the fix. Shared divider analysis: no issues.
- Affected app/test analysis with `--no-fatal-infos`: exit 0, no errors or warnings, 12 informational diagnostics.
- Android debug x86_64 build passed. APK SHA-256: `58f6a6f532f1fbb9644472ff45375148ba534151ebea8054d6744d7db4c6c1de`.
- Maestro on leased emulator-5554 verified the root row, entering a folder, the aligned Back/path/Group row, returning to root, and creating/selecting a group in the current folder. Temporary membership/group/folder removed, Browse restored, lease released, no app data reset. Header hierarchy bounds confirmed all three controls share their vertical center.
- This scoped UI follow-up uses affected consumer tests and the complete changed-package suite. The complete repository pass below belongs to the preceding candidate; a later integration candidate still needs a complete pass.

Logs and device notes: ignored `artifacts/issue80-compact-header-2026-10-26/`.

## Changes

- Removed the active-group concept throughout Bookmarks: stored preference, library state, selectors, activation APIs, navigation side effects, and localization. Old settings/backups ignore the obsolete key and no longer export it. Manual UI actions choose a destination; APIs without one consistently use Default. Group creation/deletion no longer depend on settings writes. Picker icons indicate actual post membership only.
- Added an optional title to `KurumiContextMenuDivider`. Recent uses the inline, start-aligned title with the divider color. Added the separator after Create new group.
- Raised the anchored picker cap from 65% to 75%, constrained to the actual space above/below its opener, including safe area, keyboard, gap, and popup padding. A strengthened test exposed and now prevents a negative top position for centered openers.
- Anchored popup scroll notifications stop at the popup boundary, preventing the underlying viewer/page from reacting to its overscroll.
- Added the now enabled-by-default Favorites Sync preference **Ignore synced groups for bookmark status**. It excludes every assigned sync group from toolbar highlighting/counts, preserves actual memberships and picker icons, and still highlights membership in another group. It remains a draft until Save and persists locally; version-1 settings missing this field default to true; explicit stored choices are preserved.

## Danbooru favorite-action report

The user confirmed that tapping the heart button on Danbooru saves the favorite remotely, but heart/upvote/bookmark controls only highlight after reopening the post. No production favorite-state fix is claimed without a reproducer.

The combined button tests cover the real Danbooru client, confirmed projection and Hive persistence with both sync-highlight preference settings. Additional actual-viewer composition tests now cover the real toolbar, held HTTP-201 completion, optimistic heart, and acknowledged upvote/bookmark publication without changing the viewer instance. These distinguish provider/rendering behavior from merely rebuilding a handwired button row. All six composition cases passed: mixed/native viewers, collapsed/expanded toolbars, and actual image double-tap. Both earlier combined-button tests also passed. The fixture uses one profile/post and omits unrelated metadata services; it does not establish authenticated live Danbooru behavior. The exact symptom was not reproduced by the controlled tests; the subsequent user report confirms it is gone in the current build.

## Global-removal verification

- FVM Flutter 3.47.2; six test workers. Localization regenerated after removing the obsolete Active label.
- Initial bookmark sweep: 551 passed, two stale tests failed (obsolete settings rollback expectation and benchmark constructor). Both corrected; provider/publication/nested-group rerun: 66 passed.
- Picker suite: 18 passed, including actual-member versus empty-group icons, ignored-sync membership, narrow width and enlarged text.
- `fvm flutter analyze --no-pub --no-fatal-infos`: exit 0, no errors or warnings, 3,108 informational diagnostics. The default analysis command exits 1 on those informational lints. Composition-file analysis: one compatibility-bridge deprecation information.
- Independent Astra High review completed before the user requested no further Astra reviews: no concrete findings in active-group removal, explicit destinations, rollback, import refresh, or the tested actual-viewer update paths. No favorite-state production change was made.
- Final complete regression: `./scripts/run_regression_tests.sh` exited 0: 4,926 application tests, all 13 package/CLI suites, both shell tooling suites, and 72 Python tests passed. The existing two skipped go_router tests remain skipped. The final six-case composition test file was frozen before its full-suite load; its SHA-256 remained `bb3979f3ceb52e10665c6b7ef9f83c6b875c5c5ad7dd7aa9b35d234c5c88cfc3`.
- Android debug x86_64 build passed. APK SHA-256: `fd10a33e79af02d7bbaa42e61fc2430c9d7b3d8e4ea735d8ed8278cf94c75f62`.
- Maestro on exclusively leased emulator-5554 passed creation/opening of a named group, no Active markers in browser/viewer picker, explicit membership add/remove, and Recent. Temporary group and membership removed, Browse restored, no app data reset, lease released. These are current-source checks following APK installation; they do not establish authenticated live Danbooru favorite behavior.

## Earlier verification at `bdb877873`

- FVM Flutter 3.47.2; six test workers.
- 126 affected picker, provider, and folder-UX tests passed, including creation success/failure without any active-target settings write and narrow/enlarged-text layouts.
- 52 earlier picker/settings tests passed; later combined favorite-widget tests and save/reload preference coverage also passed.
- Shared popup scroll isolation and titled-divider regressions passed.
- Application/bookmark analysis: no errors or warnings; 68 informational diagnostics in the broader final scope. Shared Kurumi changed-scope analysis: no issues.
- Final complete regression: `./scripts/run_regression_tests.sh` exited 0: 4,924 application tests, all 13 package/CLI suites, both shell tooling suites, and 72 Python tests passed. The existing two skipped go_router tests remain skipped.
- Final Android debug x86_64 build passed. APK SHA-256: `8626626375398ae89fd0bc33148ff555f2c7507c0fdd913eecd7d8b40d1ebb68`.
- Maestro on leased emulator-5554 verified picker opening, absent Active markers, group creation, Recent, edge drags, and saved/reopened switch state. The final rebuilt APK's picker smoke also passed. Temporary group/bookmark removed, sync preference restored off, Browse restored to Default profile, lease released; no app data reset.
- Independent Astra High follow-up review: no remaining code findings after creation/viewport corrections. The unresolved favorite symptom remains an acceptance gap.

The initial full run passed 4,920 app tests and failed two stale folder-UX expectations. Updating the separator expectation and strengthening the height check exposed the real anchor overflow described above; it was fixed before the final rerun. Test/build logs also emit the previously documented nonfatal native-hook diagnostic `File modified during build. Build must be rerun.` Commands' final exit statuses are reported separately; this diagnostic limits native-hook cache provenance.

Raw logs and device notes are retained in ignored `artifacts/issue80-followup-2026-10-26/` and `artifacts/issue80-global-removal-2026-10-26/`. A combined integration candidate still requires its own complete verification.
