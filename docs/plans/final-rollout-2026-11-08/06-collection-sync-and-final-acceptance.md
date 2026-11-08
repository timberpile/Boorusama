# Plan 06: collection sync and final combined acceptance

Read the [lead handoff](../../handoffs/final-rollout-remediation-2026-11-08.md). The final delivery is a coherent user-testable application, not an accumulation of independently reviewed foundations.

## A. Implement the included #144 collection-sync feature

`feature/144-folder-based-collection-sync` currently contains a design and HTML reference only. Its presence in the combined branch does not implement synchronization. Complete the approved behavior in [the existing detailed specification](../../designs/2026-11-03-folder-based-collection-sync.md) and use its mockup for placement, adjusted to the current unified Group hierarchy and corrected Kurumi UI.

This is separate from server Favorites Sync. Do not use the user's request to repair Favorites settings as permission for destructive server Favorites mirroring.

### Adapt the old folder terminology before implementation

Local Bookmark Groups now contain both direct Bookmarks and child Groups. Do not restore a separate BookmarkFolder persistence model for sync. A publication/subscription refers to stable local/source Group identity and its explicit direct/subtree scope. Structure/Unified is a local browsing preference, not a different collection identity or a reason to change mirrored membership.

Retain the old approved source/receiver ownership rules: receiver-local names and placement survive updates, future-child scope is opt-in, direct plus inherited publication/subscription does not duplicate a collection, and the global All view is not publishable. A remotely published reserved Default becomes a regular local Group rather than replacing the receiver's own Default.

### Implementation slices

1. **Scoped export and local metadata.** Use the validated v10 `.bsexport` pipeline and current unified records/hierarchy. Implement durable publisher/subscription identities, explicit source-to-local mappings, scope rules and revision/seen state in the owning feature's local metadata. Do not synchronize credentials, user profiles, app settings, media bytes, cached Following posts or remote Favorite state. Do not export arbitrary full backups into the shared folder.
2. **Folder access.** Add the existing settings-entry flow for a user-selected directory. Android uses a persisted SAF tree permission/storage adapter; `content://` is not a filesystem path. Desktop can use an ordinary mounted directory. Boorusama does not become an SMB/Syncthing client or a new cloud service. Handle revoked permissions and offline storage without deleting collections.
3. **Publication.** Coalesce committed relevant changes. Reuse scoped snapshot/export and a semantic content hash to avoid rewriting unchanged data. Publish immutable payloads and the validated descriptor/commit marker in the order required by the approved protocol. Each publisher owns its namespace. Names/placement-only edits have their prescribed metadata effect, not a fabricated new-member count.
4. **Discovery/receive.** Validate approved publisher trust, identities, versions, hashes/signatures, size/path limits and complete revisions before import. Explicitly subscribe; finding a file does not authorize automatic import. Run bounded reconciliation at startup/resume/while active and manual Sync now. Do not claim OS-background instant delivery when the app is stopped.
5. **Transactional apply.** Reuse the corrected import planning/transaction path without interactive review for already approved compatible subscriptions. Preserve local names/placement and outside memberships. Write last-applied revision only after a confirmed commit, and make replay idempotent after failure/restart. A received change must not publish an echo. Unknown versions, incomplete files and source outages retain last valid local content.
6. **Read-only boundaries.** Guard mirrored memberships/definitions in the service, not only the UI. All picker, bulk, default-group, Favorites Sync target and manual import paths must respect them. View/search/rename/move remain usable. Detach creates/retains an explicit writable copy according to the specification. Unsubscribe normally retains data; an explicit confirmed local subtree deletion must remove subscription bindings so future sync cannot resurrect the deleted local hierarchy. Never delete remote data as a side effect.
7. **UI.** Use Settings -> Export & Import -> Folder Sync, existing compact Publish/Receive/Activity surfaces and contextual actions. No new top-level navigation or permanent status row. Incoming Group additions use the approved numeric `+N`/dot indicator, never 'NEW'. Opening the actual received Group marks its displayed incoming changes seen; merely navigating an ancestor does not clear unseen descendant content. Keep Following's existing post NEW state separate.
8. **Failure/recovery.** Missing files are not deletions. Distinguish withdrawn/deleted publications, permission failure, incompatible schema, invalid payload, conflict and unavailable source access. Respect explicit receiver choices and retained local content. Source deletion and the new local subtree-delete transaction must compose predictably.

### #144 verification

Use two isolated test installations/datasets and an owned shared test directory. Verify initial subscription, direct/subtree overlap, future-child switches at both ends, local rename/move, repeated identical revisions, offline edits/reconnect, truncated/unfinished files, unsupported schema, untrusted publisher, replay, write failure, transaction rollback, restart and deletion/detach/unsubscribe. Assert no credential export or echo loop and no loss of outside memberships.

Exercise real Android SAF permission acquisition/revocation and read/write behavior, not only a fake filesystem. Preserve all original user directories and emulator data. Record actual feature routes and evidence in the owning handoff.

## B. Finish selected design-system deliverables

Family A and labels Structure/Unified are already selected. Keep the production assets, localization, tooltips and semantic names consistent with that decision. Publish editable components named `Bookmark view / Structure` and `Bookmark view / Unified` to Penpot using the available authorized connection. Verify they are actual editable SVG components, not an image of text or a claim based only on repository files.

If the external connection/project is unavailable, retain the editable SVGs and report that precise publication limit separately. Do not use Penpot unavailability as a reason to stop fixing runtime issues, and do not claim publication succeeded.

## C. Final candidate procedure

1. Reconcile the latest local/remote owning branches without resetting any foreign work. Merge each corrected runtime delta once into the isolated combined test branch and record source SHAs. Reject abandoned #163 and superseded offline-cache architecture. No runtime snapshot copying over newer shared logic.
2. Inspect the actual merged diff, generated outputs and consumer wiring. Confirm the new Work/Gallery routes and actions are reachable through ordinary application navigation, not only tests. Re-run generation only when inputs/missing outputs require it; do not upgrade dependencies or SDK as a workaround.
3. Format changed Dart with FVM, analyze affected/full scope as required, run every changed package's complete suite and relevant app consumers, then `./scripts/run_regression_tests.sh` on the exact final runtime/test candidate. Default concurrency comes from `python3 scripts/physical_core_count.py`; keep workload benchmarks serial. Keep complete logs and exit codes in durable workspace artifacts.
4. Build the ordinary `lib/main.dart` Android candidate, recording commit/tree, flavor, mode and APK hash. Use a fresh exclusive emulator lease and the documented complete backup/isolation/restoration procedure. Reusing old screenshots or restoration logs is not evidence for a new build.
5. Run the acceptance matrix below on this combined build. Use controlled fixtures to establish failure semantics; use real services for feature/native transport claims when available. Danbooru downtime prevents that live check, not all fixture tests or all other features. For Szurubooru use the existing credential-file instance and a known accessible Pool: anonymous listing denial is distinct from viewing a known Pool. Record the precise fixture/source limitation when no valid Pool can be found with bounded allowed reads.
6. Obtain an actual independent Sol High final review of the complete combined changes, tests, device/performance evidence and open limits. The reviewer must not have authored the canonical code. Fix actionable findings, rerun affected and final-candidate checks as needed, then obtain re-review of the corrected candidate.
7. Publish only the authorized task/test refs and provide the user with one exact candidate/build and a concise German checklist. Do not merge `develop`, release, open a PR or close issues without the separate authorization required by repository policy.

## D. Acceptance matrix for the user's reported failures

| Area | Minimum final production-path evidence |
| --- | --- |
| Gelbooru profile attachment | Saved record without a live original UUID becomes readable when a unique compatible profile is added; survives restart; ambiguous/wrong-site and queued-action cases stay correct. |
| Cached images | Offline restart decodes actual cached pixels from normal URL/custom-key entries. Sample-only/host-rewritten cache variants work without a hidden metadata/API dependency. No user cache clear. |
| Source badge | Realbooru shows the actual source favicon with and without a saved profile; cached icon works offline; genuinely unavailable icon has an honest fallback. |
| Mosaics | One/two/three members produce no fake icons in unused slots; mixed Post/Pool fallback remains bounded, stable during scroll, and fully clickable. |
| Series/Related | Existing stored cover metadata/bytes can render during source outage; genuine missing data is distinguished. Page 3 at offset zero restores; refresh updates metadata and members coherently. |
| Picker | Old visual reference restored: compact rows, Recent, '+ Group', no vertical dividers, far-trailing chevrons, near-full text width and approximately 20% navigation target. Modal/context/batch, large text, keyboard and Back all pass. |
| Deletion | Confirmed local subtree disappears without promotion; outside memberships survive; Undo/recovery restore correct hierarchy/dates; open navigation normalizes once. |
| Favorites Sync | Save, global target and Save & Fetch survive ordinary token rotation and restart. Actual actor changes, disk failure and missing targets are distinguished; no destructive clearing. |
| Import review | Representative ~3 MB data and realistic local library: acknowledgement does no heavy replanning, rapid category changes stay responsive, preview/apply agree, no freeze/crash, before/after timings and memory recorded. |
| Pixiv existing media | Ordinary Search/Explore/Favorites/Bookmarks images decode on the same valid profile used by the known-good baseline; required media headers survive, credentials do not leak to image hosts. |
| Debug Logs | Newest-first, stable equal-time ordering, functioning category filters/top navigation, useful bounded redacted media/sync/import failures. |
| #140/#141 | Actual native Work listings, Image View/Overview, Page/Work gestures, independent save/reopen/Undo/share, captured downloads, missing Page and Ugoira behavior. |
| #157 | Registered and navigable native Gallery feature, actual Android GET/decode, accurate Page numbering, independent Gallery/Page bookmarks, bounded/resumable tag cache and fixed C3/C4. |
| #160/#161/#162 | Thumbnail and page budgets remain independent, filtered continuation works, inactive routes do not dispatch, no retry storm, local cached feeds stay local. |
| #144 | Real directory/SAF publish/receive on two isolated datasets; idempotent updates, local overrides, seen badges, read-only enforcement and failure/restart recovery. |
| Compatibility | Supported old backups and finalized v10, current user data, profiles, membership timestamps, Classic zoom and existing media modes remain intact. |

A finite test set cannot guarantee every future service or data condition. 'Ready for final user review' nevertheless requires that the reported regressions are reproduced or otherwise causally established and corrected, every promised feature is actually connected, mandatory checks pass, and any unavoidable external limit is explicit. Do not ask the user to discover known broken paths in another foundation-only build.

## E. Final report structure

Keep the normal per-issue handoffs, and add one combined final report containing the exact candidate/build identity, source branch SHAs, each reported symptom's root cause and correction, new feature entry points, automated counts/commands, analysis errors/warnings and separate informational count, device steps/results, performance measurements, reviewer findings/resolutions, and verified original-device restoration. Mark unexecuted checks as unexecuted; do not inherit a pass from an earlier candidate with different runtime code.

Provide the user-facing checklist in German outside English-only repository documentation, or via an explicitly appropriate localized artifact. Keep it short enough for a final review, with concrete actions and expected results rather than asking the user to rerun the entire agent's QA campaign.
