# Folder collection sync production handoff

This implements plan 06 section A and the approved folder-sync design in the combined maintenance worktree. The final combined commit, complete regression, Android acceptance and independent review are owned by the rollout lead. This author performed no publication or develop integration; the rollout lead follows the user's separate delivery boundaries.

## Production entry points

- Settings > Export / Import > Folder Sync opens the registered settings, Publish, Receive and Activity screens.
- Bookmark Group and Following Topic/folder menus publish or manage the actual selected collection. Received collections open subscription management directly, including when their publisher is unavailable.
- Ordinary startup/resume and active-app periodic reconciliation run through `FolderSyncLifecycle` after import recovery. Mutations coalesce through a short debounce. No operating-system background-service guarantee is claimed.
- Group cards display own/received state and deduplicated ancestor unread counts. Opening a received collection marks only that collection seen. Following definition-change indicators remain separate from post unread counts. Activity entries open the mapped collection.

## Persistence and protocol

- The installation UUID and Ed25519 signing key, trusted publisher keys, publication rules, stable receiver mappings, applied revisions and unread state are durable local metadata. Explicit trust and subscription precede incoming mutation.
- Each immutable payload is one scoped `.bsexport`: Bookmark schema 10 or Following definition schema 2. Profiles, secrets, media caches and feed runtime are excluded. Following definitions resolve only a unique compatible local profile; missing/ambiguous matches pause that subscription.
- Payload and signed descriptor precede the signed catalog commit. Identity, protocol/schema, signature, digest, size and relative path are checked before applying. Receiving never republishes a mirror.
- Import uses the existing durable package transaction, including local preimages, rollback journal, data mutation coordinator and notifier checkpoints. Receiver name, placement, unrelated membership and receiver actor hints remain local. Default received Groups are regular Groups; global All is excluded.
- Direct/subtree/future-child scopes, explicit exclusions and direct-versus-inherited provenance are implemented on both sides. Unsubscribe retains a read-only mirror; Resume reuses its mapping. Detach makes the retained copy writable. Confirmed local subtree deletion forgets/excludes its bindings, preventing resurrection.
- Retention is bounded to recent signed catalogs/revisions while preserving every retained catalog/current reference. Deletion accepts only exact validated immutable revision/catalog paths in the installation's own namespace. Unknown files and received publisher namespaces are preserved. Missing/corrupt own current files cause a fresh immutable revision rather than a false semantic no-op.

## Read-only and recovery boundaries

The synchronous mirror guard loads only from misc metadata, avoiding a bookmark-provider cycle. Bookmark repository writes and Following repository definition/removal/feed operations enforce it; local naming, placement, read status and runtime cache remain writable. Remote Favorites mutations are not used by folder sync. The lead owns the shared Bookmark repository and canonical subtree-deletion integration.

Received application, verified startup rollback and confirmed subtree deletion use separate revocable operation grants. A grant expires in `finally`, so callbacks scheduled inside it cannot retain write access. Startup rollback grants authority only after the private rollback payload digest has verified; ordinary manual imports supply no recovery grant. The real-Hive cold-restart regression reloads persisted Bookmark and Following mirror bindings, runs the actual `ImportRecoveryGate` provider, restores both protected sources and verifies that later ordinary writes remain blocked.

The forwarded review findings are corrected: initial Following creation applies `autoUpdateEnabled=false` durably; Resume invokes resubscribe rather than unsubscribe; startup rollback can restore persisted mirrors; SAF publication stages and verifies bytes before final rename. Cleanup only removes the exact created staging URI while it still bears its staging name. A provider that cannot rename reports storage failure; no unsafe final-name streaming fallback exists.

## Verification and limits

Final focused command:

```sh
fvm flutter test test/core/backups/folder_sync test/core/backups/export_import/import_transaction_test.dart test/core/backups/export_import/import_recovery_test.dart test/core/backups/export_import/import_recovery_gate_test.dart --no-pub --concurrency=6 --reporter expanded
```

Result: **46 passed, exit 0**. Durable log: `.worktrees/_artifacts/final-rollout-2026-11-08/collection-sync-sol-remediation-qualified.log` (relative to the repository's primary checkout).

The final scoped analyzer exited 0 with **0 errors, 0 warnings and 66 informational lint findings** across the module, recovery seam, Following guard and tests. Log: `collection-sync-sol-remediation-analysis.log` in the same artifact directory. Scoped `git diff --check` passed.

Coverage includes actual Hive Bookmark v10 membership/actor-hint preservation, actual signed initial Following subscription with disabled updates, identical-revision stability, persisted-mirror cold restart through the production recovery gate, corrupted-preimage rejection before authority, unsubscribe/resume dialog dispatch, 320dp/2x text publication, signature/schema/path failures, partial publication, retention and unknown-file preservation, future-child/exclusion provenance, deletion suppression and ancestor deduplication. Earlier failed fixture runs remain separate from the qualifying pass.

JVM tests for staged SAF publication and exact retention paths are included under `android/app/src/test/kotlin/com/timberpile/boorusama/`. Their execution, actual Android SAF provider behavior, ordinary-main device acceptance and emulator restoration belong to the lead's remaining Android verification. These are not established by the Dart host tests. The complete combined local suite and exact-candidate independent re-review remain required by the rollout handoff.

## Full-regression remediation qualification

The later combined regression exposed test fixtures that still selected Material popup types after the Following cards switched to Kurumi. Those selectors now target the actual presenter and preserve disabled-action assertions. The profile-deletion fixture supplies the required real Hive misc store, and the standalone card fixture supplies a provider scope. Advanced Backup remains registered; its test now scrolls the destination's lazy list before selecting the initially unbuilt row. Narrow management fixtures retain the actual viewport size when enlarging text.

Two production regressions were also corrected. Following overflow controls retain their prior 48dp target and localized tooltip. Kurumi popup content is scrollable and bounded to the larger available vertical side of its opener, accounting for safe padding and the keyboard; opener bounds are captured when opening, rather than reading an unfinished floating-header transform during overlay construction. The original unbounded Column placed the trailing Unfollow action outside a 320dp/2x viewport.

Cached feeds now disable automatic remote continuation until the explicit history action, which remains reachable for both short and larger cached timelines. Once started, history uses shared continuation. Filtered and locally sorted modes keep automatic continuation disabled. The lead extended the actual viewer route's continuation policy as well, so opening cached posts in the mixed viewer cannot bypass the boundary. The real captured viewer route is covered by a transport counter, `hasMore` and attempted-dispatch checks. Tests exercise active routes; they do not suppress navigation activity.

Final frozen-scope command:

```sh
fvm flutter test test/core/search/following_topics test/core/backups/folder_sync test/application/backup_restore_flow_test.dart test/core/configs/profile_delete_after_media_resolution_test.dart test/core/posts/links/share_saved_search_link_test.dart test/core/posts/listing test/core/bookmarks/bookmark_folder_ux_test.dart --no-pub --concurrency=6 --reporter expanded
```

Result: **1051 passed, exit 0** in `following-sync-cache-viewer-final-qualified.log`. The complete Kurumi package suite passed **206 tests, exit 0**, including new 320x640/2x popup checks with keyboard heights 0 and 180, in `kurumi-popup-viewport-full-suite.log`. The final scoped analyzer exited 0 with **0 errors, 0 warnings and 60 informational findings** in `following-popup-cache-viewer-analysis-final.log`. Scoped diff checks passed. All logs use the durable artifact directory identified above.

The controlled pending Following repository-replacement test also passed without changing the notifier's existing repository read; no speculative dependency-tracking edit was made. The lead separately owns the broader Bookmark dependency/dispatch fixes, AnimeBoxes fixture qualification, complete combined regression, Android build/acceptance and independent exact-candidate re-review.


## Final combined qualification and Android evidence

The rollout lead qualified runtime/test candidate `ca66999c6523d6e3834484d5e0e70c847d4ed6fa`, tree `57e2512c866d71889dc4cf7e245db9edd16f233c`. The complete local suite passed 8,773 Flutter/Dart tests with three opt-in skips, plus 76 Python tests and both shell tooling suites. Full analysis: zero errors, zero warnings, 3,933 infos. The Android staged-publication and retention-path JVM classes passed all five tests. These supersede the earlier scoped/pending statements above; failed earlier attempts remain historical evidence.

Ordinary-main Android acceptance used two isolated installations and actual persisted SAF access to one owned directory. It verified public publisher fingerprints, Bookmark and Following subscriptions, a reverse Gallery-plus-independent-Page receipt, receiver-local name/parent, ancestor versus actual-collection incoming acknowledgement, and identical revision with forty unchanged Bookmark Hive file hashes. Local Following rename survived sync. Mirrored content was disabled in the real picker; unsubscribe retained contents, resume reused the subscription, and explicit detach retained an editable copy. A source withdrawal retained the local collection with its explicit status.

A separate real permission test released only the QA receiver's exact owned persisted tree grant under that application's UID. The grant was checked present, absent after release, and present again after normal Android folder reselection. Sync reported retained-local-content failure while permission was absent and Ready after regrant. No data/cache clearing occurred. The temporary permission probe was removed and its absence verified. These SAF/protocol campaign steps retain their recorded intermediate source identities; the only later runtime difference was Recent's direct scoped-provider dependency. The final successor separately re-exercised all three Sync leaf hardware-Back paths and the underlying Export and Import/Settings chain. Final Following semantic menus and IME/dialog/popup Back precedence also passed.

Before cleanup, both complete QA data/cache roots, device-encrypted roots, installed APKs, owned shared tree and exact diagnostic outputs were preserved and byte/hash-verified. The originally absent apps and task-owned outputs were removed. Fresh verification restored the exact original 259-package inventory, recorded settings/geometry, absence of owned roots/forwards/probe and unchanged immutable original archive; the lease was released only after the repeated successful check at 2026-11-09 07:34:18 UTC.

The actual independent Sol High final audit approves the exact candidate for combined user-review delivery with no unresolved source finding. The external authenticated live-service and Penpot limits, complete commands/counts, build hashes, performance limits and restoration details are in [the combined final report](combined-rollout-production-2026-11-09.md). No develop integration, PR, release or issue closure was performed.
