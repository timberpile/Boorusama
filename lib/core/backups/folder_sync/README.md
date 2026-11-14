# Folder Sync integration (#144)

The current application integration supports **Bookmark Groups**. Following
Topics/folders/Feeds are not connected yet. This is an incomplete feature branch,
not a completed v5 implementation or a qualified two-device Android feature.
See the [handoff](../../../../docs/handoffs/144-folder-sync-v5-local-integration.md)
for exact verification and remaining work. The
[v5 specification](../../../../docs/designs/2026-11-03-folder-based-collection-sync.md)
and [HTML reference](../../../../docs/designs/mockups/2026-11-03-folder-sync.html)
remain authoritative, including the approved source-owned Following UI.

## Application flow

Settings → Export/Import → Folder Sync opens management without enabling scans.
Explicit folder selection enables foreground startup/resume reconciliation,
30-second polling and 500 ms coalescing of Bookmark library changes. A complete
snapshot reconciliation recovers changes missed while offline or terminated.
Changing folders replaces only the transport location: identities, trust,
subscriptions, mirrors, revision counters and checkpoints remain installation-local.

`providers.dart` connects the actual unified Bookmark and Group repositories,
engine codecs, shared domain coordinator, persisted signing identity and library
reload. `service.dart` captures consistent local source snapshots, recursively
publishes selected local Group subtrees, discovers authenticated catalogs, requests
explicit fingerprint approval, and applies only subscribed publishers. Incoming
mirrors cannot be published. Unchanged content reuses verified immutable payloads;
name/hierarchy changes update the catalog. A corrupt own catalog is repaired at a
fresh sequence, preserving the original immutable bytes.

The UI uses existing Kurumi surfaces and Bookmark cards. Bookmark Home separates
Local and publisher-device sections; direct subscribed roots are virtual links to
one canonical received Group, including overlapping root/child subscriptions.
Received structure is read-only. Management includes trust, Publish/Receive,
Sync now, overlap-aware confirmed Unsubscribe/Forget and Create Local Copy.
Offline subscriptions remain manageable. There is no new app-shell destination
or navigation bar.

## Authority and storage

- `protocol.dart`, `catalog.dart`, `revision_transport.dart`: bounded canonical
  JSON, Ed25519 signatures, exact publisher/source identity, typed advertisements,
  descriptor/hash/length verification and compatibility checks.
- `catalog_gate.dart`: explicit pinned keys and highest authenticated OBSERVED
  catalog sequence/digest. Higher unsupported catalogs still prevent rollback.
  Recheck the ticket inside the domain coordinator before apply. Approval,
  identical retries and apply admission repeat the durability barrier, including
  after a failed write that left updated values in Hive's memory cache.
- `durable_preferences.dart`: Sync-specific Hive flush, file sync and parent
  directory sync before keys/reservations/checkpoints become usable authority.
  Provider initialization also barriers cached writes from earlier attempts.
- `publication.dart`: durable monotonic reservations, payload then descriptor
  then complete signed catalog, explicit withdrawal barriers and semantic no-op
  detection. Expensive preparation uses a separate publication queue.
- `bookmark_package.dart`, `receive_preparation.dart`: existing credential-free
  v10 `.bsexport` for one Group's direct memberships. Validate schema, typed
  records, source scope and semantic binding before applying. Bound ZIP expansion
  before staging/JSON parsing, plus an aggregate retained-byte preparation budget.
  This is a resource guard, not an exact process-memory benchmark.
- `bookmark_mirror_engine.dart`, `BookmarkMirrorState`: fresh local UUID mapping,
  complete recursive overlap coverage, receiver reading state and retained
  per-source revision/descriptor history. Signed tombstones retire the source
  revision so a later catalog cannot revive the same withdrawn payload. Subscribe
  is additive; only explicit management or verified inactive advertisements may
  remove uncovered mirrors. Forget revokes trust while retaining anti-replay
  history; reapproval must be explicit.
- The unified Hive journal commits ownership, hierarchy, memberships, local
  reading state and applied revision together. Repository guards reject ordinary
  mirror edits, local/received hierarchy mixing, ownership capture of local
  Groups, changed received-only snapshots, local snapshot replacement by receive,
  and revision-history rollback. Shared records referenced outside removed
  mirrors survive cleanup; no unwanted Default membership is manufactured.
- `storage.dart`: bounded mounted-directory transport with immutable no-clobber
  publication, path/link validation and exact own-namespace retention paths.
- `android_storage.dart` / `FolderSyncChannel.kt`: persisted SAF tree grants,
  bounded worker-thread I/O, no content-URI-to-filesystem conversion and exact
  owned-path cleanup. Native registration and lifecycle cleanup are connected.
  SAF publication creates a new final document and verifies its exact name/URI
  before opening it; it never renames over a possible concurrent winner. Partial
  final documents are retained as immutable evidence and cannot pass signed
  descriptor/hash validation. Ambiguous/renamed provider results fail closed.
  Actual provider crash/concurrency behavior still needs device acceptance.

Missing/offline files, revoked grants, corrupt archives and unsupported versions
never authorize deletion. Source cleanup requires authenticated explicit signed
withdrawal/deletion or confirmed local Unsubscribe/Forget. Cleanup of shared
folder history is not scheduled automatically.

## Bookmark browsing and reading

All Bookmarks and its tag/source/count selectors include only records with a
local membership; a record shared with a local Group appears once. Received Groups
are excluded from ordinary pickers, bulk destinations and Favorites Sync targets,
with repository enforcement behind the UI.

Group opening acknowledges only that canonical Group's arrivals at its rendered
membership revision. Conditional selection Mark Read and an actually decoded,
settled, active full Viewer occurrence update portable member identities. Preloads,
covered routes and neighboring entries do not count. Displaying a saved Work
marks that Work entry, not every separately saved Page. Video-read completion,
parent arrival aggregation and the complete v5 reading presentation remain open.

## Remaining integration

Following package/publication/receive, journaled ownership, repository guards and
approved Local/device UI remain unimplemented. Preserve receiver-controlled
profile binding, automatic/manual Post refresh, scheduling/rate limits, cache,
NEW/read and checkpoints when implementing them. Received definitions must be
fully source-owned and read-only; do not restore obsolete receiver name/placement
overrides or copy Bookmark recursive scope rules into Following.

Also pending: durable mutation dirty signals, filesystem watcher with polling
fallback, complete activity history/deep links, device-alias editing, full status
classification/recovery UX, per-subscription failure isolation within a publisher,
parent arrival aggregates, video reading and broader UI acceptance. No retention
scheduler or incomplete destructive Following path is enabled.

Host tests exercise real Hive repositories, journal interruption/reopen, two
independent library/signing-identity instances, signed directory transport,
offline management, relocation, retry/replay and narrow/enlarged/keyboard UI.
These are not Android provider, real process-kill, Syncthing/SMB or two-physical-device
acceptance results. Do not operate the owner's CPH2769 phone; device acceptance
remains pending.
