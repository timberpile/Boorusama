# Pre-release review remediation — local agent handoff (2026-11-17)

**Task:** Fix the six source-supported review findings across #166, #174, #170 and #172. Follow the repository's AGENTS.md, engineering guidelines, development workflow and verify-change skill. This is an implementation assignment, not permission to integrate into develop.

## Baseline / branches

The reviewed base is develop 4542aaa44e5002f7d546fb4ec96bf4cb0523cee5. Re-fetch origin before changes and preserve other agents' work.

| Issue | Work branch | Reviewed HEAD |
| --- | --- | --- |
| #166 | bug/166-pool-bookmark-covers | 09f0233fe167e4112828eff24057c2f3d9ae7e89 |
| #174 | bug/174-pixiv-work-grouping | 21f06536857a7f1598a92b239155055d2dcd7a62 |
| #170 | feature/170-following-topics-added-sort | aaf50146c859b8a6f1f20c113a40c27f0421585b |
| #172 | bug/172-backup-folder-recovery | f247bf7a92f4e6b754890ff0a9f6eb3a85cc9a53 |
| Combined ten bugfixes | maintenance/pre-release-bugfix-preview-20261117 | 00fad7fcee3cf8865fe924e56a37b9c9e6af40db |

Read [the previous execution inventory](2026-11-17-pre-release-execution-results.md). All findings are static-review hypotheses, not executed regressions: add failing tests and investigate assumptions before making fixes. Use the existing separate worktrees. Commit/push changes on their owning issue branches. Replay new **bugfix** corrections only (#166, #174, #172) into the cumulative preview after issue-branch verification; keep feature #170 separate. Never merge develop, close issues, create PRs or operate emulators/devices without separate approval.

## #166 A — cover-only persistence corrupts native Group index (P2)

Files: lib/core/bookmarks/src/providers/bookmark_provider.dart (fillMissingPoolCover), lib/core/bookmarks/src/data/hive/unified_bookmark_group_repository.dart (writePoolBookmarks), lib/core/bookmarks/src/data/bookmark_collection_projection.dart, lib/core/bookmarks/src/types/content_group_bookmark.dart and stored_group_snapshot.dart.

Cause: fillMissingPoolCover reads and replaces every CollectionBookmark projection. The native sourceGroup GroupBookmarkIndex becomes an empty/unknown memberUnion projection, and collectionRecordForSave reconstructs that changed native record with the wrong basis/tags/coverage. This is not a lossless cover patch.

Fix: In unified mode, read the current native ContentGroupBookmark by integer ID and expected content/source identity under the serialized Bookmark coordinator. Require a missing cover and revalidate the actor and record at commit. Construct a new ContentGroupSummary preserving reference, title, memberCount, displayCategory, previewTags and sourceData, changing only GroupCover. Construct a StoredGroupSnapshot preserving schemaVersion, details and GroupBookmarkIndex's original basis/tags/coverage/date bounds; update coverPolicy only as required. ContentGroupSummary has no copyWith: explicitly preserve every field. Commit just that record via the existing journaled UnifiedBookmarkStore.commitOrganization(records: [changed]), not replacePoolBookmarks(all). Preserve legacy storage through a separate compatible path. Use existing withBookmarkCommitGuard/validateBookmarkCommitGuard where access must be checked at the irreversible boundary.

Red/green test with **real unified Hive**, not overridden fillMissingPoolCover: native coverless Pool with sourceGroup index and nonempty tags, details, membership timestamps, additional unrelated records; fill cover, restart, confirm every non-cover field is identical and IDs unchanged. Also cover a replaced record and preexisting cover.

## #166 B — failed cover lookup stays cached forever (P2)

Files: lib/core/bookmarks/src/services/pool_cover_backfill_queue.dart and lib/core/bookmarks/src/providers/pool_bookmark_provider.dart (missingPoolCoverProvider, scheduleMissingPoolCover).

Cause: PoolCoverBackfillQueue._jobs.putIfAbsent never removes completed futures, including errors; missingPoolCoverProvider unconditionally calls ref.keepAlive. Two immediate failures while offline prevent recovery on later revisit with the same key/policy, and completed entries accumulate.

Fix: Keep _jobs for **in-flight** deduplication only; remove entries after success/error, without leaving unhandled Future errors. Introduce a **bounded TTL/cooldown** for failures/verified negative results so revisits after connectivity recovery can retry, not every widget rebuild. Bound total cache retention; release keep-alive links when work ends. Preserve serialized one-at-a-time lookup, 40-member/page cap, two immediate attempts, and current authorization/policy checks.

Tests with controlled clock and deferred responses: offline failure twice; rebuild before cooldown causes no network activity; reconnect/revisit after cooldown succeeds; multiple concurrent cards deduplicate; many distinct keys do not cause unbounded growth; policy/auth change never exposes an old cover.

## #166 C — received-only Pool backfill attempts forbidden source mutation (P2)

Files: BookmarkPoolCoverImage, BookmarkLibraryNotifier._scheduleNewPoolCovers, missingPoolCoverProvider, unified_bookmark_organization.dart _guardMirrorMutation.

Cause: coverless visible/imported Pool scheduling ignores mirror ownership. A received-only Pool fails ordinary mutation guards at the end of a successful lookup. Tests currently use a fake write and miss this.

Fix: Check canonical current ownership/membership **before scheduling and at commit**. Never weaken BookmarkMirrorReadOnly or modify publisher-owned source payloads/checkpoints. Preferred: receiver-local, policy/access/revision-scoped presentation cover cache for received-only records; invalidate on revocation, withdrawal, Forget and source replacement. If a safe receiver overlay cannot be implemented, fail closed with an explicit documented limitation, not repeated unauthorized writes or a misleading permanent missing-cover result. Respect local+received shared-record ownership rules.

Tests: real Hive mirror with received-only, local-only and shared-membership Pools; source identity replacement, revocation mid-fetch and Forget. Verify canonical source payload/digests, read state and membership timestamps unchanged.

## #174 — native Work route loses page mode and scroll position (P2)

Files: lib/boorus/pixiv/works/search_page.dart; lib/boorus/pixiv/works/work_listing.dart; lib/core/search/search/src/widgets/raw_search_page_scaffold.dart and search_page_scaffold.dart; lib/core/content/widgets/native_content_grid.dart; SearchParams.

Cause: nativeResultBuilder passes (context, query, initialPage, header), but not scrollPosition or effective route pageMode. The Post path forces paginated mode for an explicit page and restores scroll position on PostControllerRefreshCompleted. PixivWorkGrid defaults to global pageMode and NativeContentGrid uses an ordinary ScrollController without the route restoration.

Fix: Extend native result contract with effective pageMode, page and position. Reuse _useRoutePosition and query-reset behavior; an explicit route page overrides global infinite mode. Restore the correct Work occurrence **once**, after the matching authorized data and grid layout are available; reset on new query, access, profile or route. For masonry use a grid-aware index/anchor, not index times fixed tile height. Define mapping for legacy Page-index positions; do not regress one-Work-per-card grouping or use postResultsOnly as a blanket local-search fallback. Ensure back-navigation and previous/next controls work.

Tests: actual SearchPage route with SearchParams.page/scrollPosition, multi-page Work, global infinite preference, standard/masonry, query change and account switch. Verify the combined #169 retained refresh + #175 autohide contract. Investigate whether PixivWorkGrid.onRefresh invalidates cached Work source before successful replacement and leaves visible cards unusable offline; fix only if reproduced.

## #170 — filtered/direct received Topics bypass chosen sort (P2)

Files: lib/core/search/following_topics/src/pages/following_topics_page.dart (_allProfilesBody), types/following_topic_sort.dart and visibleFollowingTopicsProvider.

Cause: filtering replaces sorted visible topics with activity.topics.where(...).toList() without re-sorting. Separately, Home appends directly subscribed received Topics after sorted items.

Fix: Collect the final unique Home/folder/received Topic candidates, apply query/profile filtering, and call sortFollowingTopics(finalTopics, selectedSort) on the final projected Topic list (or within existing publisher sections). Preserve the current manual order, read-only mirror hierarchy, folder order and all persisted positions. Apply the same pipeline to all sort choices rather than special-casing added date. Ensure cached UI inputs include filter/sort state.

Tests: real FollowingTopicsPage at narrow width with reversed saved date/manual order, both date modes, filters, nested folder, directly subscribed Topic, multiple publishers and return to Manual. Check rendered tile order and unchanged stored positions.

## #172 — stale failed directory validation overwrites newer access error (P2)

Files: lib/core/backups/auto/providers.dart (AutoBackupFailureNotifier.report, AutoBackupDirectoryRecovery.selectDirectory); lib/core/backups/zip/backup_notifier.dart; android/app/src/main/kotlin/com/timberpile/boorusama/AutoBackupChannel.kt.

Cause: recovery success uses the captured prior diagnostic identity, but failure replaces *any* current requiresFolderAccess diagnostic. An accepted unversioned report() does not advance _revision, so newer same-category errors can be overwritten by stale validation A.

Fix: Make successful and failed completions obey identical CAS/generation ownership. Preferred: monotonic accepted-diagnostic generation advanced on every accepted report/clear, distinct from selection-request generation; stale async writers cannot overwrite newer errors. A captured-identity check in both outcomes is a valid smaller fix if proven race-safe. Audit BackupNotifier's own transient BackupStatus.error after report(e, revision: stale) declines global publication; do not show a resurrected old warning there. Preserve sanitized stages, cancellation, queueing and existing folder-selection semantics.

Tests: hold validation A, report a newer folder-access failure with another stage, fail A; newer diagnostic survives. Test newer unrelated error, A succeeds, rapid selections, failed writes and older in-flight backup completion. Compare global banner and operation state.

**Kotlin gate:** The #172 native prepare write/delete probe and verify_folder_write stage were NOT compiled in prior verification. Build the actual Kotlin production target, run fresh native JVM tests and build debug APK. Check probe cleanup and zero modification of existing documents. Native compilation does not establish real SAF behavior; do not use an emulator/phone without authorization.

## Verification and delivery

Run affected tests plus new real-storage/widget regressions on each issue branch. Minimum existing files: #166 pool_cover_backfill_test.dart, pool_bookmark_refresh_failure_test.dart, pool_bookmark_source_policy_test.dart and application/pool_bookmark_flow_test.dart; #174 work_listing_entry_points_test.dart, work_mapper_test.dart, native_content_grid_test.dart, work_navigation_autohide_test.dart; #170 following_topic_sort_test.dart, following_topic_sort_persistence_test.dart, following_topic_added_sort_test.dart; #172 auto_backup_directory_recovery_test.dart, auto_backup_failure_test.dart and auto_backup_android_repository_test.dart.

Before publishing the preview, verify its patch inventory still contains all ten existing bugfixes, with #170 and the other three features excluded. Cherry-pick/replay only new #166/#174/#172 corrections; preserve its exact source-to-replay mapping and provide a fresh **final candidate** SHA. Run the complete ./scripts/run_regression_tests.sh (all application/packages/CLI/tooling suites) on that final combined candidate, relevant package suites and changed-file analysis, fvm dart format and git diff --check. Record precise commands, counts, errors/skips and SHA. Reuse no older green results for changed inputs.

The other reviewed changes (#122/#169/#175/#131/#146/#147/#121 and independent features #171/#168/#134) had no additional confirmed static defect; do not refactor speculatively. Include their affected integration cases where the corrected code interacts. #96 and #173 remain blocked; do not pretend they were implemented.

Request an independent local diff review if available, fix confirmed feedback and rerun affected tests. For each of the six findings report: failing-before test, final fix, passing-after test, files changed and pushed commit; identify any disproved premise with evidence. Keep develop, all issues and worktrees untouched except authorized individual branch commits and preview replay. Owner acceptance/integration happens separately.
