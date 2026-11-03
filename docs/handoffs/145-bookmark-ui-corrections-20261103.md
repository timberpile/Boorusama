# Issue #145: Final dependency update

Historical candidate evidence. See the [rounded-search final continuation](145-rounded-search-final-20261103.md) for the current base, commits and verification.

Local branch: `feature/145-bookmark-picker-presentation`.
**Integrate #139 first:** final base `cb995548b79f134a1c3c8e366d54f3ab9758379e`.
No push, PR, develop merge or issue closure. The primary checkout and unrelated
worktrees are preserved.

## Commits and behavior

- `cbb078b24`: original typed Kurumi picker implementation, replayed on final #139.
- `9d69c9ede`: original verification handoff, retained as historical evidence.
- `6268b3639`: favicon/custom/fallback source-icon tests now expect 24 dp.
- The following handoff commit changes documentation only.

Inherited #139's compact 24 dp source/type overlays, 16 dp type icons, 4 dp
geometry, removed help action/dialog and common opaque Bookmark search/toolbar
surface. Related ordering, canonical identity, membership feedback and title-free
Related thumbnails remain intact.

The typed requests, surface-independent content/actions, shared Kurumi anchor,
route-owned Kurumi dialog, group-creation handoff, immediate opening/deferred
metadata, exact-source checks and cancellation/repeated-action guards are
preserved. Bulk and Favorites Sync retain their distinct semantics. AGENTS.md's
binding Kurumi surface rule remains. No generic framework or unrelated dialog
migration was added.

The [original entry-point inventory](145-bookmark-picker-presentation-20261103.md#final-entry-point-inventory)
still applies: Post Viewer buttons; single-selection action; Pool/Series/Collection
buttons; Related gallery; stored-reference card actions; helper/extension dialogs;
Post context submenu; bulk sheet/group picker; Favorites Sync destination picker;
shared group-name/create workflow. Repeated source search found no additional
presenter. All seven shared picker surfaces were explicitly checked: no raw
Material dialog/menu or obsolete `anchored` presentation flag remains.

## Final automated verification

Checked runtime/test content matches `6268b3639`. The dependency replays added
#139's documentation-only handoff updates; runtime/test trees were compared and
remained identical. No functional correction followed the full run.

| Check | Result |
| --- | --- |
| Final FVM formatting of 24 surviving Dart delta paths | Passed, no changes |
| `fvm flutter analyze --no-pub --no-fatal-infos` on the Bookmark subsystem and affected consumers | Exit 0; 0 errors, 0 warnings, 89 infos; broader scope than the original handoff's 48 infos |
| Badge suite including favicon/custom/fallback and RTL | 11 passed |
| `TEST_CONCURRENCY=3 ./scripts/run_regression_tests.sh` | **Complete pass:** 6,111 application tests; 1,659 package/CLI tests across 13 suites; both shell suites; 72 Python tests; `REGRESSION_EXIT=0` |
| Existing skips | Two pre-existing go_router skips; none added |
| Final picker source audit and `git diff --check` | Passed |
| `fvm flutter build apk --debug --flavor dev --target-platform android-x64 --no-pub` | Passed |

The complete application suite includes the controlled async picker lifecycle,
source/profile changes, repeated actions, dismissal during closing animations,
group-creation ownership, folder navigation, destination/batch semantics, narrow
layouts, enlarged text, RTL pointer bounds and focus restoration tests. Existing
Dart finalizer diagnostics and the native-hook build warning appeared; final
completion markers above establish the reported results. No device timing claim.
The initial default fatal-infos analysis returned exit 1 for those informational
findings; the explicit nonfatal-infos rerun above returned 0 without code changes.

## Current Android checks and limits

Installed/local SHA-256 matched:
`0f491cdf0a2f5f5e891615cffbaa911a6c0e07a5dc5244f6183865f00da9c1d5`.
Maestro used exclusively leased Android 17 `emulator-5554`, 360×800 logical pixels,
gesture navigation, without resetting app data. Reopened a saved Related family:
the bookmark icon and selected group were filled. The shared Kurumi anchor opened;
Create Group transferred to the Kurumi name editor with the actual soft keyboard
visible. Save/Cancel fit; cancellation left the original three references intact.

#139's current-source theme/badge/search checks are recorded in
[its correction handoff](139-bookmark-ui-corrections-20261103.md). The original
#145 handoff's Post, Series, Collection, bulk and Favorites Sync device scenarios
remain historical baseline evidence; this continuation reran their automated
coverage and the Related/create-cancel device paths, not every manual scenario.

Deleted only the temporary QA group and its three unique references; All
Bookmarks showed No data available. Restored Browse Danbooru, system font 1.0,
keyboard preference and Midnight appearance/dynamic-color-off, then released
the lease. Favorites was untouched; the updated #145 APK remains installed.
Colors now stores explicit Midnight instead of the earlier “Default” null
override; the editor exposes no null reset. This small representation difference
and ordinary navigation/search history remain.

Physical-device, device RTL, three-button, assistive input, desktop pointer,
live account-removal/offline and backup-upgrade acceptance remain manual. Global
Header/Browse/System Bar runtime work is deferred to #146/#147/#148; #136 specifies
the target and #105 owns radius work. Complete-suite success applies to this
candidate; a changed combined develop candidate requires fresh full verification.

Durable local logs and screenshots:
`.worktrees/_artifacts/bookmark-ui-corrections-145/`.
