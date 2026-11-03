# Issue #152: Per-group Bookmark added dates

Historical initial candidate. The [All-order/backup-v9 follow-up](152-all-membership-order-20261103.md) supersedes global All-date sorting and version 8 output. The [responsiveness fix](152-related-bookmark-responsiveness-20261103.md) removes repeated date decoding.

Branch: `feature/152-bookmark-group-added-dates`.
Implementation: `de83d29446a5c49aa963b32867a43d87db940d38`.
**Depends on final #139 `b8b233bf1`; integrate #139 first.** This branch does not
include #145's picker cleanup. Local committed delivery only: no push, PR, merge
or issue closure. The following commit records verification only.

## Behavior and representation

Each Post membership stores UTC `addedAt` in `BookmarkGroup`. Stored
Pool/Series/Collection/Related references carry dates keyed by group. Group
Bookmark Newest/Oldest and previews use these dates; All retains global
`createdAt`. Upload/score sorting and canonical source identity are unchanged.

Repeat adds and metadata refresh retain dates. Remove/re-add creates a new date;
Undo restores the original, including recreated local Post IDs. Duplication keeps
original dates. Snapshot equality/refresh detects date-only changes without extra
network work or a full-library rebuild per mutation.

Hive appends optional field 5 to the existing group adapter/type ID. UTC ISO
strings preserve microseconds, which native Hive DateTime truncates. Legacy or
missing dates use the saved item's `createdAt`, never migration time. Post dates
are initialized once at library load. Malformed local values are ignored and
repaired from that fallback. Collection JSON/backup parsing rejects malformed
dates or absent-membership references before writes.

Bookmark backup **version 8** carries dates; readers accept **versions 4–8**.
File-local Post IDs and target group IDs are remapped with dates. Replace, update,
merge, copy, target merge and rollback preserve their intended timestamps;
merge retains existing local membership dates. Import preview detects date-only
changes and projects deterministic Pool dates. Older apps are not promised the
ability to read version 8. No new per-item requests or generic framework.

## Automated verification

Checked runtime/tests: `de83d2944`; subsequent change is this handoff only.
Required adapter/registry/i18n outputs were present for the final run. A filtered
adapter generation initially removed the ignored booru registry; `./gen.sh`
restored it before final builds/regression.

| Check | Result |
| --- | --- |
| New controlled membership-date suite | **18 passed** |
| Earlier import-preview/membership focused run | **61 passed** |
| FVM formatting | Passed, no changes |
| Bookmark/backup/Hive analysis, nonfatal infos | 0 errors, 0 warnings, 154 infos; exit 0 |
| `TEST_CONCURRENCY=2 ./scripts/run_regression_tests.sh` | **6,092 app + 1,657 package/CLI across 13 suites + both shell suites + 72 Python; REGRESSION_EXIT=0** |
| Existing skips | Two pre-existing go_router skips; none added |
| Final diff review and diff check | Passed |
| Final sequential FVM dev debug x64 APK build | BUILD_EXIT=0 |

Controlled tests cover independent dates, repeats, refresh, both sort directions,
All/group mixed Post/Pool/Related order and previews, remove/re-add, Undo,
duplication, legacy Hive reopen/exact microseconds, export/restore/remapping,
merge/copy/update/target merge, legacy merge before normal migration, rollback
after forced write failure, malformed values and timestamp-only import preview.

Initial focused failures exposed Hive precision truncation, an unsuitable
failure-injection fixture and the old version-8 rejection assertion. Corrected
before the final focused/full runs. Interrupted/failed runs remain diagnostics,
not passes. Existing finalizer, unclickable test-target and native-hook diagnostics
appeared; explicit completion establishes the result. First successful APK builds
emitted a native-asset modification notice; the final sequential build did not.

## Actual Android checks

Exclusively leased Android 17 `emulator-5554`, 360 dp width, font 1.0, gesture
navigation, no reset. Installed/local SHA-256 for the full membership scenario:
`9ca86c2d1079702d271e5523df971f78e57c45591a2534f831dfcba61d9089f2`.

Two public safe Posts were added through the real picker into temporary A152/B152
groups. The globally older Post, added later to B, opened first in B Newest;
All Newest opened the other Post first. Removing a B member and Undo kept its
original position. Removing/re-adding moved it to the front. Oldest reversed the
order; Newest survived a cold restart. Viewer semantics identified both Posts.

Deleted only the two QA groups/unique Posts; All showed No data available.
Restored Browse Danbooru, Newest, font1.0 and keyboard preference0. Midnight and
explicit Padding16/Spacing4 were not edited. No Favorites/Blacklist/account
mutation. Ordinary navigation/search history and clipboard `cat` remain. Older
isolated UI builds predate RelatedPostsOrder; a profile change on #149 may have
rewritten Settings without that future key. Modern fallback is Oldest (also the
last observed value); byte-identical restoration is not established because the
key was not snapshotted before downgrade.

Final repeated build used unchanged tracked runtime/adapter content. Installed
hash matched `417bcc18093ed3885e6052766ae5b5deec2334aa93d4bafafdedb9ad8ed50237`;
cold restart/empty-library smoke passed. Lease released; final #152 APK remains
installed. No measured latency claim.

Device Pool/Series/Collection/Related timestamp scenarios, physical/assistive
input, RTL, offline/profile changes and full backup-upgrade/import UI remain
manual; their persistence contracts have host coverage. A changed combined
develop candidate needs fresh complete verification before integration.

Durable logs: `.worktrees/_artifacts/approved-ui-152/`.
