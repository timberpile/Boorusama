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
