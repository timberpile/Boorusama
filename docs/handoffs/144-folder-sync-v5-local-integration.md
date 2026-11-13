# #144 Folder Sync v5 — local integration and final acceptance

## Starting point and status

- Continue `feature/144-folder-based-collection-sync`.
- New isolated foundation runtime: `a7606bed7b2024d250f31495bb8f45e0056f51e3`.
- Reconciliation commit: `f11c65ee45aa2d8fec7b81e06ae0f955577b2f43`, with original
  #144 head `2207c09753a9008deaf294f40d8d3a709c9d6e17` as first parent and #141
  handoff head `ca6f951be266ee4d6d98e0bae2959a0c1598fbdd` as second parent.
- #141 runtime inherited here: `56669fa7c2e226473d730cf5a4e9556fc7983b06`.
- Issue #144 remains open / in-progress. This is an implementation continuation,
  **not a ready-to-accept Sync feature or an integration approval**.

The new foundations are deliberately not instantiated by application providers,
settings, lifecycle, Bookmark repositories, import transactions or Viewer code.
There is no new functioning end-to-end Folder Sync UI. No destructive mirror path
has been enabled. Android SAF/native integration has not been ported. The only
existing root file changed by the isolated foundation commit is `pubspec.yaml`,
with one added dependency line; all other changes are in the new folder_sync
implementation/test directories. GitHub compare confirmed that scope.

## Authoritative design and preserved ancestry

The approved v5 files were restored byte-for-byte, not redesigned:

- `docs/designs/2026-11-03-folder-based-collection-sync.md`: blob
  `0f1575ffcf84e0693c233bad53d7837c6af78c1c` from
  `476d6e21bef641ca5e61f5815e57f69254512b6d`.
- `docs/designs/mockups/2026-11-03-folder-sync.html`: blob
  `fdd399aff10162a26c55da441aadabffbb42b357` from
  `cf171fdb3418362c9e53e1ed36a40db11d2e26ef`.

Historical Combined `252e8954dab8c0842f83a2082c67f4841111c34e` is a reference only.
Do not merge it wholesale. Its `lib/core/backups/folder_sync/` and historical
`docs/handoffs/144-folder-sync-production-2026-11-09.md` can inform individual
ports, but that candidate's tests/device claims are not evidence for this branch.
The old #144 branch's two documentation commits and all inherited #141 work remain
in ancestry. No develop merge, PR or issue closure occurred in the remote work.

## What was actually implemented

See [`lib/core/backups/folder_sync/README.md`](../../lib/core/backups/folder_sync/README.md)
for component boundaries.

| Component | Implemented boundary |
| --- | --- |
| `protocol.dart` / `limits.dart` | Bounded canonical metadata, Ed25519 signing and verification, stable typed publisher/kind/source identity, immutable local signing-key inputs, descriptor byte length/SHA-256 checks, explicit unsupported-schema signal. Private seed never enters public identity JSON. |
| `storage.dart` | Mounted-directory storage under `v1/devices/...`, existing no-clobber publication primitive, random temporary names, bounded streaming reads, existing-link/path checks and exact owned-revision retention paths. `content://` is rejected, not treated as a filesystem path. |
| `catalog_gate.dart` | Explicit pinned-key approval, persisted highest verified catalog sequence/digest using `MiscDataStore`, rollback/equivocation rejection, idempotent retry, fail-closed malformed metadata/write failure, deeply immutable verified content. `withCurrentCatalog` rechecks trust and checkpoint under the shared `DataMutationCoordinator` before the caller's final transaction. |
| `bookmark_scope.dart` | Iterative complete-subtree union with overlapping direct/ancestor reasons, canonical source identity, virtual direct-root links, source sibling order, future descendants, and explicit-unsubscribe coverage preview. No duplicate mirror allocation or deletion side effect. |
| `reading_state.dart` | Immutable JSON-ready per-publisher/Group arrival and read state, portable typed Bookmark member keys, accumulated additions minus removals, stale-render acknowledgement rejection, conditional Mark Read and read retention across removal/rearrival. No automatic UI hook or cross-Group propagation. |

The source-owned tree intentionally does not reuse local-editing `FolderTree`:
a directly published child can reference an unpublished parent, and names must
not become identity or discovery validity. Canonical scope keys are not local
Group IDs; allocating and persisting the fresh local mapping remains required.

The gate's checkpoint means **highest verified observed**, not **last applied**.
An unavailable payload leaves current mirrors intact and retries the same signed
catalog. Keep applied markers separate and commit them only with domain state.
A `VerifiedSyncCatalog` does not attest to a payload, schema support, per-source
withdrawal, or correct mirror deletion. Preserve these distinctions when wiring
it into the existing import journal.

## Verification evidence and first local work

**No Dart formatter, analyzer, Flutter test, dependency resolver, Android or live
two-device check ran for this candidate.** Tests are authored, not a green result.
The persisted-checkpoint tests recreate the gate over a fake store; they are not
real disk/process restart or fault-injected journal evidence. Source self-review
and Git ancestry/diff inspection are the remote verification boundary.

First complete the inherited #141 work using
[`141-pixiv-bookmark-regression-acceptance.md`](141-pixiv-bookmark-regression-acceptance.md):
the exact locale patch is still unapplied and the label-based tests require it.
Coordinate that small fix with the #141 branch rather than implementing a second,
divergent workaround here. Do not overwrite later #141 or #144 changes.

`pubspec.yaml` adds the historical `cryptography: ^2.7.0` dependency. Resolve it
with the current project toolchain and regenerate/review the lockfile; no lockfile
or generated build output was fabricated remotely. Format/analyze the changed
files and run the complete `test/core/backups/folder_sync/` directory, including:

- Historical `storage_test.dart` ported by exact blob, plus `storage_v5_test.dart`.
- New `protocol_test.dart`, `catalog_gate_test.dart`,
  `catalog_commit_guard_test.dart`, `bookmark_scope_test.dart`,
  `reading_state_test.dart`.

Add real metadata-store restart/crash tests and randomized/deep-tree oracle tests.
Exercise malformed/deep metadata, unknown source types, payload-size races,
immutable writer conflicts and platform filesystem behavior. Fix any compilation,
formatting or behavioral problems before treating these foundations as accepted.

## Remaining implementation, in dependency order

### 1. Signed publication and validated receive adapter

Adapt the historical protocol/storage/app-port pieces selectively to current
headless v10 `.bsexport` import/export and typed Work/Pool/Post records. Implement
signed catalog entries, sibling order, `active` / `withdrawn` / `deleted` states,
exact publisher/kind/source/revision binding and supported per-entry schemas.
Unknown content types must pause only affected subscriptions as Update Required,
not silently drop entries or erase previous content. No source URL may confer
network-client authority, and no credentials/private seed enter shared files.

Write payload first, signed descriptor last, then publish the increasing signed
catalog. Reserve immutable revision/sequence names durably before publication.
Reconcile partial writes without rewriting an existing immutable name. Validate
length/hash/signature and exact catalog advertisement before import. A missing
or corrupt newer file is not deletion proof. Never fall back past the persisted
accepted high water; an unsupported newer protocol must not resurrect old state.

Use the same application mutation coordinator for trust changes and final
journaled apply. Prepare bytes outside the critical transaction and revalidate
with `withCurrentCatalog` before committing. Preserve source/profile guards and
update last-applied revision, mappings and arrival state with successful domain
state only. Fault injection must prove recovery at each boundary.

### 2. Canonical mirror ownership and data isolation

Persist `(publisher, kind, source UUID) -> fresh local Group UUID`. Parent A and
direct child B subscriptions must share B, membership, revision history and read
state, with root/nested entries as links. Apply source names, source hierarchy and
source sibling order; do not retain local names/placement as the historical port
does. Never merge by display name or collide with the receiver's Default Group.
A published source Default becomes an ordinary received Group.

Enforce read-only ownership in repository/service mutation paths, not merely
hidden menu buttons: rename/move/reorder/delete, child creation, membership edits,
bookmark pickers, Favorites sync, imports and bulk actions. Never republish a
received mirror. Saving its Posts into independent local Groups is allowed.
All Bookmarks must include only records with a local membership, with mixed
local/mirror records deduplicated. Use virtual device sections, not local wrapper
folders. Existing backups, source resolution and profile isolation must remain
compatible.

### 3. Safe removal and independent copies

Compute complete effective coverage before publication/subscription changes.
Stopping one overlapping rule must not transiently withdraw B. Only a current,
verified explicit signed withdrawal can trigger remote cleanup of uncovered
owned mirrors. File absence, offline/permission errors and unsupported data must
retain the last usable mirror. A signed `deleted` tombstone remains a separate,
unsettled policy; do not silently treat it as Stop Publishing.

Explicit-root Unsubscribe uses a confirmation preview and removes only now-
uncovered mirrors. Inherited-only children have no independent Unsubscribe.
Confirmed Forget Device revokes trust/subscriptions and removes that publisher's
owned mirrors transactionally; keep unrelated folders with surviving content,
other publishers, outside memberships and detached copies. It must not be a
standalone trust-row reset. Fresh discovery needs a fresh trust decision.
Create Local Copy uses fresh independent editable Group IDs, preserving original
subscription and deduplicated underlying Posts.

### 4. Publication cost and lifecycle

The historical service calls `capture` for every effective source before testing
its semantic hash. Do not copy that behavior or the unconditional minute timer.
Use committed domain changes/dirty signals, debounce and startup/resume recovery.
Detect unchanged semantic inputs before rebuilding archives. Reuse each covered
source once across overlapping roots. Group title/placement metadata updates
should update the catalog without republishing identical payloads or generating
arrival counts. Device aliases, read state, cache metadata and local IDs must not
become remote content changes. Test capture/write counts for unchanged sync,
one-source edits, metadata-only changes, import no-echo and overlap transitions.

### 5. Arrival/read integration and v5 UI

Persist the reading model with the canonical mirror. Opening a Group acknowledges
its own arrival notice only after its membership revision is rendered, not its
children and not Posts. Mark actual displayed full-Viewer Posts read, never grid
previews/preloads/inactive neighbors. Selection Mark Read appears only when at
least one selected current Post is unread. Keep publisher/Group boundaries and
root/nested link identity. Aggregate +N/dots without duplicate Groups or Posts.
Following post NEW, Following definition changes, Bookmark arrivals and Bookmark
read state remain four separate state machines. Preserve typed Work/Page
identity; do not infer that viewing a Work card reads every Page. Resolve the
actual visible-content mapping before connecting events.

Follow the restored interactive v5 reference: Local plus separate device sections,
existing compact card geometry, sync/lock/upload overlays and +N/dot badges (no
literal NEW). No new top-level Sync navigation or permanent extra toolbar/banner.
Use hierarchical Publish/Receive views and Direct / Via parent / Direct + via
parent indicators; Bookmark subtrees have no exclusions/future switches. Merely
opening a menu must not enable publication. Offline management remains available.
Publisher name is editable in signed metadata; a receiver alias is local only.

### 6. Platform and final acceptance

Port Android SAF and native channel registration deliberately, using persisted
read/write grants and the same `v1` root. Do not assume rename is atomic for every
provider. Validate real file creation/readback, descriptor-last recovery, app
restart and revoked permissions. No general background-delivery guarantee.

Complete current project regression requirements on the final candidate, then
exercise two installations: child B then parent A, duplicate-free root/nested
links, future grandchildren, source rename/reparent/order, stop either overlap,
read isolation and arrivals, offline/missing/partial files, older signed catalog
replay, unsupported payload/schema, name/alias, local copy, unsubscribe and Forget
Device. Include a third owner, same-name/source-ID collisions, mixed local
memberships, Default, read-only mutation entry points, narrow/large-text/keyboard
UI, and real SAF providers. Record exact runtime SHA, commands, results and device
evidence; historical Combined QA is not a substitute.

## Product boundaries still not authorized to guess

Signed source deletion versus withdrawal, changing an active shared directory,
and Following auto-update policy remain separate decisions. Preserve current
data and expose an appropriate pending/unavailable state until their semantics
are settled. They do not justify adding excluded-child controls to Bookmark
subtrees or altering the accepted read-only/device-section design.

## Completion record

Update this handoff and #144 with implemented boundaries, actual verification and
remaining acceptance decisions. The branch is not currently merge-ready. Final
local acceptance and an explicit owner integration decision are still required.
