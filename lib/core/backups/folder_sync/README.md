# Folder Sync v5 foundations (#144)

**Not connected to application settings, lifecycle, import transactions,
Bookmark repositories or Viewer events. This is not an end-to-end Sync feature.**
Current verification and remaining acceptance are recorded in the
[local integration handoff](../../../../docs/handoffs/144-folder-sync-v5-local-integration.md).

The approved contract is
[the v5 design](../../../../docs/designs/2026-11-03-folder-based-collection-sync.md)
and its mockup. Historical Combined `252e8954dab8c0842f83a2082c67f4841111c34e`
is a source reference, not a merge target or a current verification result.

## Components and authority boundaries

- `protocol.dart`: bounded canonical JSON, Ed25519 identity/signature handling,
  publisher/kind/source identity and revision length/hash checks. Private seeds
  stay local. Identity JSON is immutable; editable publisher names belong in
  increasing signed catalogs. `verifySyncSignature` authenticates bytes only;
  it does not approve a key, bind a publisher or establish compatibility.
  `SyncRevision.schema` is structurally valid, not necessarily supported.
- `storage.dart`: mounted directories under `v1/devices/...`, bounded streaming
  reads, immutable no-clobber publication, random scratch files, path/link checks
  and exact owned-revision retention paths. Android SAF is not a filesystem path.
  Link checks do not sandbox a hostile process replacing filesystem ancestors.
  Filesystem checks remain asynchronous to avoid blocking the UI isolate.
- `catalog_gate.dart`: explicit pinned-key approval and a durable highest
  authenticated OBSERVED sequence/content digest using `MiscDataStore` and the
  shared `DataMutationCoordinator`. The common signed publisher/protocol/sequence
  is bound before the checkpoint. A valid newer common header advances the
  checkpoint even when its protocol or body cannot be consumed, preventing old
  signed catalogs or prepared old commits from regaining authority. Rejected
  bodies receive no verified ticket. Failed checkpoint writes propagate;
  identical retries are allowed, older/equivocating catalogs are rejected.
  `withCurrentCatalog` rechecks trust/checkpoint under the same lock after async
  preparation. OBSERVED is not APPLIED: applied markers belong to successful
  journaled domain transactions only.
- `revision_transport.dart`: reads only the exact expected descriptor and payload
  paths. It checks the descriptor signature, compares every revision field with
  the caller's expected advertisement, bounds both reads, verifies payload length
  and SHA-256, then exposes a copied read-only byte view. Missing files return
  unavailable; permission/corruption failures propagate. There is no listing,
  older-revision fallback, write or deletion. The caller must obtain `expected`
  from a current verified catalog and use its approved publisher key. The result
  is transport evidence, **not** a validated export archive, supported schema,
  source/profile permission or authorized import/deletion plan.
- `bookmark_scope.dart`: bounded iterative complete-subtree union, canonical
  source identity, virtual direct-root links, source sibling order and overlapping
  coverage. It previews source IDs uncovered by explicit-root unsubscribe but
  neither allocates local IDs nor deletes anything. An unpublished external
  source parent is allowed; names do not determine identity or scope. Local
  editing `FolderTree` assumptions do not fit these discovery subsets.
- `reading_state.dart`: immutable JSON-ready receiver-local arrival and reading
  state per publisher/Group. Opening acknowledges only arrivals for the rendered
  membership revision; reading changes only selected current identities. Removed
  and reappearing read identities retain state. Portable typed Bookmark member
  keys are not local IDs or thumbnail URLs. Nothing automatically hooks this to
  grids, preloads, neighbors, Group opening or all Pages of a Work.

## Production wiring still required

Build signed catalog entries and descriptor-last publication with durable
revision reservations and partial-write recovery. Validate `.bsexport` archives
through the existing bounded package reader, then enforce supported schemas,
typed v10 source content and exact advertised scope. Prepare outside the shared
mutation lock and revalidate the current catalog immediately before journaled
apply. Persist source-to-fresh-local-ID ownership and enforce read-only mirrors
at repository/service entry points, not just hidden menus.

Implement safe explicit withdrawal, confirmed unsubscribe/Forget Device and
independent local copies; local-membership-only All Bookmarks; dirty-signal
publication before archive rebuilding; durable arrival/read integration; Android
SAF grants/native registration; and the approved v5 Kurumi device sections/UI.
An unavailable directory, missing file or unsupported catalog must never become
an empty authoritative deletion snapshot. Unknown deletion policy remains
non-destructive.

Do not port historical flat UI, auto-enable-on-navigation, receiver-owned
name/placement preservation, withdrawn-mirror retention, older-catalog fallback
or unconditional archive rebuilding. These conflict with v5.

## Verification boundaries

The dependency lock is generated, not hand-written. Focused hosted tests cover
protocol, observed checkpoints and rejected prepared commits, signed transport,
recursive overlap, arrival/read separation and mounted-directory operations.
Consult the handoff for exact tested commits and failures; do not infer complete
application acceptance from foundation checks. Store recreation is not a real
process/disk crash test. Journal fault injection, ownership mutation coverage,
complete final regressions and actual two-device/SAF acceptance remain required.
