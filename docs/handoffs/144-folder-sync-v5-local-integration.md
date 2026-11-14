# #144 — Folder Sync v5: implementation continuation and final acceptance

Updated 2026-11-14. Issue #144 remains open/in-progress. No integration or closure
is authorized by this handoff.

## Status and starting point

Continue `feature/144-folder-based-collection-sync`, preserving later work.
Current runtime candidate: `1061837f9c2deb9f6344c1a27b6c351667fc11e9`.

**The foundation is implemented; the production Sync feature is not complete.**
This is an implementation continuation followed by local final acceptance, not a
request to approve a finished UI. No import, destructive mirror cleanup or Sync
navigation path has been enabled prematurely. Hosted foundation tests are not
two-device, Android SAF, crash-recovery or full-application acceptance.

Read the approved [v5 specification](../designs/2026-11-03-folder-based-collection-sync.md),
[interactive v5 mockup](../designs/mockups/2026-11-03-folder-sync.html), and
[component/authority README](../../lib/core/backups/folder_sync/README.md).
The separate [#141 acceptance handoff](141-pixiv-bookmark-regression-acceptance.md)
remains relevant to the inherited Pixiv dependency.

## Branch reconciliation and immutable design evidence

The branch retains its original work through
`2207c09753a9008deaf294f40d8d3a709c9d6e17`, the earlier dependency reconciliation
`f11c65ee45aa2d8fec7b81e06ae0f955577b2f43`, and foundation runtime
`a7606bed7b2024d250f31495bb8f45e0056f51e3`.

Merge `259f420eec00e580a3f82f29eda5fdae697a442f` incorporates #141 head
`2fcd7a42de21d68b9ab4a049f940c52cbf2afe29` (runtime/test `64da57f...`) while
retaining the #144 history. Cleanup head:
`ae35297b95e96666ffcc582d26cb80fd8259d803`. The hosted reconciliation checked
both ancestries and unchanged Sync source/tests, pubspec/lock and design files.
It verified the exact approved blobs before pushing:

- Specification: `0f1575ffcf84e0693c233bad53d7837c6af78c1c`.
- Mockup: `fdd399aff10162a26c55da441aadabffbb42b357`.

This feature dependency merge is not develop integration or acceptance of #141.
Check for later #141 fixes before final P9 verification. Its labels and shared
button corrections are now included; there is no outstanding locale patch.
Historical Combined `252e8954dab8c0842f83a2082c67f4841111c34e` is reference only.
Do not merge or wholesale transplant it: its flat UI, automatic enablement on
navigation and receiver-owned name/placement behavior conflict with v5.

## Implemented and inspected boundaries

The implementation lives in `lib/core/backups/folder_sync/`, with focused tests
in `test/core/backups/folder_sync/`.

**Protocol and authenticated observations.** Bounded canonical JSON, Ed25519
identity/signatures, typed publisher/kind/source identity and revision length/hash
checks exist. Private seeds remain local. An immutable identity document excludes
mutable display names. `verifySyncSignature` authenticates bytes only; it does
not approve the key or establish protocol compatibility or mutation authority.

The initial catalog gate had a reproduced rollback defect: a newer signed
catalog with an unsupported protocol or invalid version-specific body failed
before persisting the high-water mark. Older signed catalogs and already prepared
old operations consequently remained usable. Ten new regressions failed before
`4b39b033b77eccd7dab30e1b170c2776e2f7dc08` corrected this ordering.

The gate now verifies the common publisher/protocol/sequence and filename binding,
then durably records highest authenticated OBSERVED sequence/content digest before
compatibility/body checks. Invalid signatures or mismatched common identity do
not advance it. Rejected content yields no usable catalog ticket. Storage failures
propagate; identical retry is allowed, older or equivocating content rejected.
`withCurrentCatalog` rechecks the ticket under the shared mutation coordinator
after asynchronous preparation. OBSERVED is not last APPLIED. Do not advance an
applied marker until the journaled domain mutation succeeds.

**Exact signed revision transport.** `f3a263c7cef0332891c172dfc9f980065cc82bb3`
adds `SyncRevisionTransport`: read only the expected descriptor/payload paths,
authenticate the descriptor with the supplied key, bind every revision field to
the expected advertisement, bound both reads and verify payload length/SHA-256.
The output owns a copied read-only byte view. Missing files are unavailable,
permission/corruption errors propagate; there is no listing, older fallback,
write or deletion. The caller must derive the expected revision and approved key
from current trusted catalog state. **Transport evidence is not validated archive,
supported schema, source/profile permission or an authorized mutation plan.**

**Existing foundations retained.** Mounted-directory storage uses
`v1/devices/...`, bounded reads and immutable no-clobber writes, rejects traversal
and links, and limits retention paths. SAF URIs are deliberately not interpreted
as filesystem paths. `bookmark_scope.dart` computes bounded iterative recursive
union and uncovered-source previews without allocating IDs or deleting data.
`reading_state.dart` provides immutable JSON-ready arrival/read state by publisher,
source Group and portable typed Bookmark identity. None is wired to application
providers, repositories, Viewer events or UI yet.

`pubspec.lock` now includes generated cryptography 2.9.0. Its CI assertion checked
that no unrelated dependency entry changed. Async filesystem checks remain async
to avoid blocking the UI isolate; their lint exception is documented.

## Verification evidence and limits

- [Red checkpoint run 43569871060](https://github.com/timberpile/Boorusama/actions/runs/43569871060):
  candidate `6fa0caba...`, 34 tests passed and all ten newly added regressions
  failed. The follow-up checkpoint fix passed all 44 tests.
- [Transport/cleanup run 43572212520](https://github.com/timberpile/Boorusama/actions/runs/43572212520):
  explicitly tested bot commit `212e0b9ac7c7966ee6f1b89d0776a64d7c568f13`;
  62 tests passed, with 12 analyzer infos still reported.
- [Follow-up run 43572965391](https://github.com/timberpile/Boorusama/actions/runs/43572965391):
  explicitly tested `278870992c9fbe04b0565ca82dd23b9e5aef3687`; all 62 tests
  passed, formatting and dependency-lock checks passed. Two unnecessary_async
  infos remained, so the overall run was not green.
- `1061837...` removes those redundant forwarding wrappers and starts a read-only
  check of the reconciled foundation plus the complete Kurumi suite. That run's
  result is not yet available at this documentation checkpoint. Do not infer
  success from a continue-on-error step conclusion.
- Store recreation tests are not real process/disk crash tests. There is no
  independent review, full final application regression, local build, Android
  SAF, live Pixiv or two-device acceptance from this remote session.

## Remaining implementation, in dependency order

### 1. Complete trusted publication and receive preparation

Define validated canonical catalog collection entries and signed explicit
withdrawal evidence. Reserve revision numbers durably, produce a consistent
source snapshot, write the immutable payload first and signed descriptor last,
then publish a monotonically increasing signed catalog. Preserve recoverability
under interruption at every stage; never reuse or overwrite an immutable winner.
Compare dirty revisions/semantic inputs before rebuilding archives. A display-name
change belongs in a new signed catalog, not a rewritten identity document.

Use the existing bounded `.bsexport` reader in
`lib/core/backups/export_import/package/export_package_reader.dart`, manifest and
source validation, plus `lib/core/backups/sources/bookmark_backup_codec.dart` and
the typed Bookmark codecs. Enforce supported schema and exact advertised
publisher/kind/source scope after transport verification. Preserve v10 Work/Page
identity; do not flatten Works or use thumbnail URLs as identity. Resolve profile
requirements without silently rebinding a different actor.

Prepare outside the shared mutation lock. Immediately before apply, recheck the
current catalog using the same `DataMutationCoordinator`; then execute a journaled
mutation and persist last APPLIED atomically. A future/unsupported catalog,
missing package or read failure must not become an empty authoritative snapshot.

### 2. Add canonical ownership and repository enforcement

Persist `(publisher, kind, source Group)` to fresh local Group ID mapping and
explicit mirror ownership. A source Group has one canonical local mirror even
when several subscribed roots cover it. Imported numeric/local IDs are not source
identity. Source-owned name, member set, hierarchy and sibling order replace the
mirror's prior source-owned values.

Guard mutation entry points in the existing unified Bookmark repository/services,
not just menus: no local rename, move, reorder, mixed local membership edits or
republishing of incoming mirrors. Ordinary local operations must remain unchanged.
All Bookmarks requires at least one local membership and shows mixed local/received
records once. Received-only records must not leak into that local collection.

### 3. Integrate coverage and safe destructive operations

Use complete recursive current/future subtree union, with no exclusions or
future-child toggle. Parent A and explicit child B yield one payload/mirror/read
state; both root entries are virtual links, and B remains under A. Compute the
whole new coverage before any removal, including reparenting and overlapping roots.

Only verified explicit signed withdrawal or confirmed local Unsubscribe/Forget
Device may remove uncovered mirrors. Unsubscribe applies to explicit roots only.
Forget Device must preserve independent copies, other publishers/owners, unrelated
memberships and folders containing unrelated content. Copy creates new writable
local Group IDs with no received ownership. Keep these paths journaled and test
partial failure/restart before enabling them. Permission loss, offline storage,
missing files or unsupported metadata never mean withdrawal.

### 4. Connect reading, arrivals, publication triggers and v5 UI

Persist local state by publisher/source Group/typed Post identity. Acknowledge only
the opened Group's arrivals after its rendered revision is known; opening never
marks Posts or child Groups read. Actual full Viewer display or conditional Mark
Read changes per-Post reading. Preload and neighboring Viewer entries do not count.
A Work display must not mark every Page read. Virtual links share the canonical
state; distinct Groups/devices and the publisher do not.

Implement the approved Local/device sections, source hierarchy and responsive
Kurumi controls from the existing mockup. Publisher display names come from signed
catalogs; local receiver aliases remain local. Keep management available while
offline, with explicit confirmations. Navigation must not enable Sync implicitly.
Separate Following definition changes from Post NEW. Wire debounced publication
signals to genuine local source mutations, never to incoming/read/arrival changes.

### 5. Complete platform and final acceptance

Implement Android SAF through the proper document-provider abstraction, including
persisted grants, revocation, app restart, provider failures and native registration.
Do not emulate SAF with `Directory(contentUri)`. Validate genuine two-device
publication/discovery/subscription, overlap, reparenting, offline recovery,
withdrawal, copy, unsubscribe and Forget Device. Add process-level crash injection
around checkpoint writes, package publication and journaled application, plus
ownership mutation tests and the repository-required complete final regressions.

Record exact final runtime, checks, fault-injection/device evidence and remaining
owner decisions in this handoff and #144. Reconcile any later #141 corrective
commits explicitly before the combined final verification. Do not infer acceptance
from the existence of a large historical Combined implementation.

## Product decisions that remain open

Source `deleted` versus Stop Publishing, changing an active shared directory and
Following auto-update policy still need explicit decisions. Preserve data rather
than inventing destructive behavior. These open choices do not weaken the approved
v5 ownership, recursive-coverage, arrival/read or device-section contracts.
