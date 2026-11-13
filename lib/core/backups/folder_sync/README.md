# Folder Sync v5 foundations (#144)

Status: isolated remote implementation candidate. **Not connected to the app's
settings, lifecycle, import transaction, Bookmark repositories or Viewer. No
usable end-to-end Sync feature or successful runtime check is claimed.**

The approved contract is
[`docs/designs/2026-11-03-folder-based-collection-sync.md`](../../../../docs/designs/2026-11-03-folder-based-collection-sync.md)
and its v5 mockup. Historical Combined `252e8954dab8c0842f83a2082c67f4841111c34e`
is a source reference, not a merge target or current verification result.

## Components

- `protocol.dart`: bounded canonical JSON, Ed25519 identity/signature handling,
  typed publisher/kind/source identity and revision length/hash checks. Private
  seeds are app-local only. Identity.json is immutable; editable publisher names
  belong in increasing signed catalogs. Unknown schemas/types are not permission
  to discard data. `SyncRevision.schema` is validated structurally, not declared
  supported; the import adapter must enforce actual codec capability.
- `storage.dart`: mounted-directory implementation of the immutable storage
  interface under `v1/devices/...`. It uses the repository's no-clobber publication
  helper, bounded streaming reads, random scratch names, path/link checks and
  exact owned-revision retention paths. Android SAF is deliberately not faked as
  a filesystem path. Existing-link checks are not an OS-level sandbox against a
  malicious process concurrently replacing filesystem ancestors.
- `catalog_gate.dart`: explicit pinned-key approval plus app-local persisted
  highest verified sequence/content digest. It rejects rollback, equal-sequence
  equivocation, key changes, malformed local state and failed checkpoint writes.
  Identical retries are accepted for crash recovery. It uses `MiscDataStore` and
  the shared `DataMutationCoordinator`, not a second write-lock architecture.
  `withCurrentCatalog` rechecks trust/checkpoint under that lock after payload
  preparation. **Observed is not applied:** keep last-applied markers separate
  and update them only with successful journaled domain commits. A verified
  catalog is not yet a valid package or an authorized deletion plan.
- `bookmark_scope.dart`: bounded, iterative full-subtree union, canonical source
  identity, direct-root links, source sibling order and overlapping coverage.
  It previews the SOURCE IDs uncovered by an explicit root unsubscribe; it does
  not delete or allocate local IDs. It supports an unpublished external source
  parent without inventing a local folder. Names do not drive scope. It does not
  reuse `FolderTree` because that local-editing model requires every parent and
  unique sibling names, neither of which is appropriate for discovery subsets.
- `reading_state.dart`: immutable JSON-ready receiver-local arrival and reading
  state per canonical publisher/Group. Opening acknowledges only the rendered
  membership revision's arrivals; explicit reading changes only selected current
  identities. Removed/reappearing read identities retain their state. Portable
  member keys reuse `bookmarkContentIdentity` and engine identity with a typed
  JSON tuple, not local IDs or thumbnail URLs. Nothing automatically calls this
  from a grid, preload, neighboring Page or Group opening.

## Wiring and verification gates

Do not transplant the historical service/UI unchanged: it retains receiver-local
Group names/placement, has obsolete exclusions/future-child options, retains
withdrawn mirrors, can fall back to old catalogs, and rebuilds payload archives
before unchanged detection. None of those behaviors is the approved v5 contract.

Still required: descriptor-last publication/catalog construction and recovery,
capability-aware signed entry/package validation, transactional mirror mappings
and ownership guards, safe withdrawal/unsubscribe/Forget Device, local copies,
local-only All Bookmarks, durable reading/arrival integration, dirty-signal
publication, Android SAF/native registration, and the v5 Kurumi UI/device sections.
No missing/offline directory or unsupported catalog may be converted into an
empty authoritative deletion snapshot. Do not fall back past an accepted high
water mark; unsupported newer protocol is an Update Required condition, not an
excuse to resurrect a prior revision.

The direct `cryptography: ^2.7.0` dependency matches the historical implementation;
resolve dependencies and regenerate/review the lockfile locally before checks.
The authored tests in `test/core/backups/folder_sync/` have **not run**. Historical
storage tests were ported by exact blob; new tests cover protocol, checkpoint
restart via store reuse/failures, commit-time revocation, recursive overlap and
separate read/arrival state. Store-reuse tests are not a real disk/process restart
or crash-journal test. Formatting/analyzer, real metadata restart, property/fuzz
checks, complete regressions and actual two-device/SAF acceptance remain required.
