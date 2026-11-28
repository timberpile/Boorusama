# Incremental Bookmark publication for MiteMite (#193)

Implement Option A on `feature/193-stream-bookmark-transfer`. The comparison baseline is `826e30c6ecbfa4b6642085f17170a5e44793e8c8`. It publishes one streamed v7 archive per changed group. The primary fixture is one publisher sharing 10 groups of 10,000 bookmarks and 100 groups of 100 bookmarks, for 110 groups and 110,000 distinct posts. Measure portable record edits across these groups and keep a separate membership-removal control. Both devices should do work proportional to the affected buckets. A fresh subscriber must still be able to subscribe using only the latest publication.

Keep the current folder picker, trust model, explicit subscription roots, signed catalogs and publisher ownership. SQLite is private to each installation. Standalone Bookmark backups, Following payloads, and unrelated grid/search behavior retain their current contracts. This document describes proposed implementation and tests. The baseline measurements below describe existing behavior.

## Start with the reproducible comparison

Your first implementation deliverable is a reusable benchmark in `benchmark/mitemite_group_updates_test.dart`. Use the existing [two-independent-Hive-libraries test](../../test/core/backups/mitemite/bookmark_mirror_engine_test.dart) as the setup example and [scalabilityBookmark](../../benchmark/scalability/fixtures.dart) for synthetic records. Use two real Bookmark repositories, separate identities/preferences, production MiteMite services and a temporary shared directory. Commit the benchmark separately while the application tree is identical to the baseline. Run the benchmark on that commit before implementing Option A. The following command applies once you have created the file.

```bash
fvm flutter test --no-pub --concurrency=1 --reporter=expanded benchmark/mitemite_group_updates_test.dart
```

**Fixture.** Exactly 110 published groups with disjoint memberships. The first big group is the directly offered root and the other 109 are its children, so one subscription covers the whole dataset in one connected receive unit. This exercises the cost of traversing unchanged sibling groups. Flat independent subscriptions and overlapping membership have different transaction costs; cover them with focused tests separately. All fixture data are synthetic. Seed 193 selects distinct members without replacement within each case. Each scenario changes a source date inside the portable post snapshot in one committed batch, then calls publish once and receive once. An incidental local observation clock would be the wrong edit for this test.

| Scenario | Distinct record edits | Groups with changed payload |
| --- | ---: | ---: |
| One edit in a large group | 1 | 1 of 10 large groups |
| Concentrated random batch | 100 | 1 large group |
| Spread random batch | 100 | 10 large groups, 10 records per group |
| Small-group fan-out | 100 | 50 randomly selected small groups, 2 records per group |
| Clean resume and unchanged receiver poll | 0 | 0 |

The equal-sized 100-edit batches isolate the cost of touching more groups. With 64 roughly balanced buckets in a large group, 100 random edits in that group will touch about 51 buckets on average. Ten random edits in each of ten such groups will touch about 93 buckets in total. With one bucket per small group, two edits in each of 50 groups will rewrite 50 small chunks, containing 5,000 rows altogether. These are design expectations. Log the actual distinct buckets, rows and file opens for the fixed seed; do not assert those averages. Keep the scenario order, selection and edited fields identical across A/B. Each case checks that the peer receives the new source date for every edited record and that precisely the affected group revisions advance. The separate 4,000-member control removes a membership while the peer owns a copy in Favorites; it checks IDs, surviving dates and the unchanged-poll epoch. If adding a size override for that control, keep the mixed fixture fixed.

Use the benchmark-only commit for A and the implementation tip for B. Alternatively put the identical benchmark file in a disposable detached worktree at the exact baseline above. Record both SHAs, the harness blob hash, SDK, fixture count and transport. Confirm that A has the same application tree as the pinned commit. Run serially on the same host/storage with fresh data for each trial. Alternate A/B order and keep every sample. Use at least three paired trials for the primary matrix and report medians and ranges, with initial publish/subscribe broken out. Have the harness emit elapsed service-call time and bytes of newly present files. A zero-file result says nothing about reads, rereads or temporary writes. For the paired host benchmark, call sync directly. In-memory preferences suffice for timings. Test actual poll latency, visible UI refresh and durable restart separately.

### Building the harness

1. Seed outside the timer. Reserve local IDs in batches per group, then call `commitOrganization(records: ..., groups: [group])`. Use deterministic group UUIDs, positions, fixed UTC membership dates and unique portable source IDs (`upstreamId: localId + 1` works with the existing fixture). Configure both services on the same temporary directory, publish the root, discover and approve the publisher, and subscribe once. Confirm the peer owns 110 mirror groups with the requested cardinalities.
2. Use a single `Random(193)`. In fixture order, draw one member from large group 4, 100 distinct members of large group 6, ten distinct members of each of the ten large groups, and two distinct members of each of 50 shuffled small groups. To reproduce the exploratory selection, shuffle the list of small groups first, then draw each case by shuffling a copy of each selected group's ordered member IDs. Record the selection digest for both binaries.
3. Capture the peer's group revisions, change the portable post field with one batch `upsertAll`, then call `sender.synchronize(trigger: SyncTrigger.localChange)` followed by `peer.synchronize()`. For example, use `scalabilityBookmark(id, upstreamId: id + 1, uploadedAt: DateTime.utc(2025, 1, caseNumber))`. Compare the peer's source post date by portable content identity after apply. Assert every changed key arrived, the same records still belong to each group, dates survived, and the set of advanced group revisions equals exactly the touched source IDs. Check both services for errors after every phase. Add a no-op poll and the single-group removal control.
4. Time local commit, publish and receive independently. Take file inventories outside those intervals. Emit JSON per phase with group count, edit count, touched groups/buckets, elapsed time, shared bytes and file operations. Add instrumented work counters as described below. Do correctness scans outside timed regions.

## Trace the baseline before editing

| Concern | Start here |
| --- | --- |
| Local change signal and lifecycle | [Provider debounce, poll and watcher](../../lib/core/backups/mitemite/providers.dart), [state comparison](../../lib/core/backups/mitemite/local_change_detection.dart), [service](../../lib/core/backups/mitemite/service.dart), especially `synchronize`, `_sync` and `_publish` |
| Publish | [Streamed staging](../../lib/core/backups/mitemite/streamed_bookmark_publication.dart), [revision reservation and catalog-last publication](../../lib/core/backups/mitemite/publication.dart). Today staging consumes every covered member before semantic equality is checked. A new catalog verifies every active revision. |
| Identity and portable records | [Member keys](../../lib/core/backups/mitemite/seen_state.dart), [publication sanitization and semantic comparison](../../lib/core/backups/mitemite/bookmark_package.dart). Membership dates are emitted separately from the old semantic hash. |
| Apply and visibility | [Receive preparation](../../lib/core/backups/mitemite/receive_preparation.dart), [transaction units](../../lib/core/backups/mitemite/receive_units.dart), [mirror engine](../../lib/core/backups/mitemite/bookmark_mirror_engine.dart), [library projection](../../lib/core/bookmarks/src/providers/bookmark_provider.dart). Existing apply can preserve an old membership date over an incoming date. |
| Persistence | [Bookmark mutation journal](../../lib/core/bookmarks/src/data/hive/unified_bookmark_repository.dart), [group storage](../../lib/core/bookmarks/src/data/hive/unified_bookmark_organization.dart). Current group IDs/dates and mirror reading sets can still cost a whole group per edit. |
| Shared storage and maintenance | [Directory adapter](../../lib/core/backups/mitemite/storage.dart), [SAF adapter](../../lib/core/backups/mitemite/android_storage.dart), [native channel](../../android/app/src/main/kotlin/com/timberpile/boorusama/MiteMiteChannel.kt), [retention](../../lib/core/backups/mitemite/retention.dart) and [audit/repair](../../lib/core/backups/mitemite/service_maintenance.dart) |

## 1. Specify a versioned snapshot on disk

Use the existing `v1/devices/<publisher UUID>/` namespace, key and monotonic catalog sequence. Below is a proposed layout for the new representation. Resolve paths locally from validated identifiers. Each group remains an independent subscription source.

```text
devices/<publisher>/
  identity.json
  catalog/411.json
  collections/bookmarks/<source>/
    manifests/23.json
    chunks/19/0b-<sha256>.ndjson.gz
    chunks/23/03-<sha256>.ndjson.gz
```

Here `411` is the publisher-wide catalog sequence and `23` is a reserved group revision. The chunk path carries its creation revision. Later manifests may refer to the same immutable object. This also gives repair a fresh path if a provider retained a truncated file at its original path. Keep existing reservations, withdrawal barriers, label, parent, ordering, roots and complete-catalog semantics. A group rename can reuse its manifest. A change in which groups are covered can introduce or retire collections.

Use a recognized version gate in the signed catalog. For example, extend `publicationScopeVersion` with generation 3 for these complete catalogs and add an explicit versioned Bookmark representation to revision parsing. Both the .4 released reader and the pinned branch check scope versions. Confirm with pinned-reader fixtures that they reach the update-required path before consuming new entries. A mixed Bookmark/Following catalog may require an upgraded reader while its Following payload stays compatible. Following-only publishers can keep their current catalog format. The new reader must handle old signed JSON, the branch's signed v7 table archives, and new manifests. Keep previously received mirrors visible during the switch. Preserve peer approvals, subscriptions, applied revisions and observed replay high-water marks across restart. Refer to [release compatibility](../release_compatibility.md) and [released upgrade checks](../testing/released_upgrade_verification.md). The prior handoff identifies public .4 at `45f3df6c3b2e2c977480b5ac3f3aef415765d218`; verify the applicable public release before shipping.

**Manifest.** Bind publisher, source UUID, group revision, format version and bucket algorithm. The signed catalog authenticates the manifest's SHA-256 and byte length. List every occupied bucket. For each object record its bucket, creation revision, SHA-256 of exact compressed bytes, compressed length, expanded length and row count. Keep this list outside the 256 KiB signed catalog. An empty group has an empty list. A missing object named in a manifest makes that revision unavailable. Only absence from a fully verified manifest means the bucket is empty.

**Rows.** Persist a power-of-two bucket count in each manifest. For the first prototype choose the smallest of 1, 16, 64 and 256 that targets at most 256 rows per bucket on first publish, capped at 256. That gives one bucket per 100-member group and 64 per 10,000-member group, at most 740 occupied buckets before oversized objects are split. Assigning 256 buckets even to every small group could create thousands of tiny SAF files. Use the high log2(bucket count) bits of SHA-256 over UTF-8 of the exact canonical `syncBookmarkMemberKey` string, and bucket zero for a single-bucket group. Keep bucket numbering stable across routine edits. A future explicit full rebuild may change the count; in that case replace the entire old partition atomically. Measure the proposed counts before freezing this version. Write rows ordered by that key, as deterministic gzipped UTF-8 NDJSON. Each row carries the portable member key, UTC group membership date and the existing sanitized typed record. File-local record IDs have no cross-device authority. Normalize incidental IDs, timestamps used solely for observations, unordered tag fields and compressor headers consistently with the existing equality/transfer rules. Preserve source facts and original portable values required for restore. Keep semantic equality separate from exact byte authentication. Include dates in membership equality. Re-encoding identical state or changing only publisher-local hints must not churn revisions. Add tiny golden fixtures for exact bucket assignment, determinism, empty group and date-only change before wiring service code.

Use existing stream/row/staging protections and explicitly bound manifest size, object count and total group/connected-unit budget. Count actual expanded bytes while decoding. If a bucket exceeds the chosen object size, split only that bucket on row boundaries into ordered, size-bounded pieces and bind their ordinals in the manifest and derived paths. Reject duplicate keys/buckets/pieces, key-to-record or key-to-bucket mismatches, invalid dates, invalid locators, inconsistent counts, cross-collection references and oversized inputs. Check limits before writing shared state. Files from the folder are untrusted even after authenticating their publisher. Use the same typed path allowlists and streaming validation in Dart and Kotlin.

### Worked deletion for a fixture

Use short labels only in this example. On disk use full canonical publisher/source IDs, full digests and the portable typed member keys. Suppose Desktop’s group revision 22 references bucket 03 containing posts 101 and 205, and bucket 0b containing post 309. Phone has already mapped these to local IDs 51, 82 and 94. Local Favorites also contains 82. Desktop removes 205. The form of the new manifest’s object list is:

```json
[
  {"bucket":"03","createdRevision":23,"part":0,"sha256":"<digest of new 03>","compressedBytes":214,"expandedBytes":487,"rows":1},
  {"bucket":"0b","createdRevision":19,"part":0,"sha256":"<previous digest of 0b>","compressedBytes":239,"expandedBytes":512,"rows":1}
]
```

Lengths and bucket assignments above illustrate the fields. Generate actual bytes and compute expected values for tests. The new 03 object decompresses to one line with the key, `addedAt` and portable record for 101. There is no delete operation to find or replay. Phone verifies manifest 23, reads bucket 03, and compares it with the two local rows previously applied for 03. In its transaction it removes the mirror membership for 82, stores the replacement 03 reference and advances the group head to 23. Its Favorites membership for 82, bookmark row 82, and the applied rows for 0b survive. A second sync at the same head reads zero chunks. Cover both this case and a delayed 03 file.

## 2. Build a recoverable local index, then make publication selective

Use the existing Bookmark repository as the authority during introduction. A practical private SQLite layout is below. Reuse an existing durable equivalent when available. Indexes must support the actual queries with a bounded number of rows visited.

| Local rows | Key and use |
| --- | --- |
| Outgoing membership | `(generation, source, bucket, member_key) → local_record_id, added_at`. Add a reverse index on generation and local record ID for edits shared by several groups. |
| Outgoing dirty work | `(generation, source, bucket) → latest_edit_revision`. Keep catalog/topology changes separately. Remember both the old and new keys/buckets on identity changes. |
| Published manifest and bucket references | Key by publisher, shared-folder configuration, source and bucket. Record the exact last committed manifest and verified objects. Scope proof of a shared write to its destination. |
| Applied manifest/buckets and members | Key by trusted publisher, source, bucket and member key. Store local ID and source membership date. Keep applied state and pending/recovery state distinct. Store subscriptions/ownership under their existing authority. |

1. Bootstrap from one consistent committed revision. For ordinary writes, capture the changed record IDs, old/new group memberships and dates in the existing recoverable mutation path, before clearing the source journal. Update the SQLite index/dirty rows idempotently and checkpoint the processed source revision. Hive and SQLite have independent transactions. Make the handoff between them replayable. A crash between commits, a replaced storage generation, a bulk restore or an unexplained revision gap must reconcile before declaring the publisher clean. Test reopening at each boundary. A missing index can be rebuilt from authoritative data. A failed rebuild leaves the previous publication usable.
2. On local add/remove/date edit mark the direct group's bucket. A portable record update dirties all covered local groups containing it. Removing a record requires its **previous** memberships. A move dirties both sides. Refresh coverage for root/ancestor edits and scope changes. Read acknowledgements and received-only material must never be re-advertised. Receiver state can change alongside an unrelated legitimate outgoing edit.
3. Snapshot dirty bucket revisions. Read just their indexed members, stream portable rows, and reuse references for unaffected buckets. Write and verify new objects, then the complete manifest, then the signed catalog. A trusted object already committed at this destination can be reused on the ordinary path. Explicit audit, destination change, incomplete publication or reported corruption requires verification/repair. Preserve the existing failure guard for newly advertised dependencies. Use fresh immutable paths to repair a corrupt object. If the baseline reserves an extra descriptor for a legacy representation, keep the old validation path for legacy reads.
4. After catalog visibility, acknowledge only the captured dirty revisions. A concurrent edit survives for the next pass. If the process dies after writing the catalog, recover by checking the signed file against the persisted intent. A staged intent alone cannot mark the pass complete. Clean startup/resume can check small metadata and recovery watermarks. They should perform zero bookmark payload reads. Keep expensive preparation outside the application mutation lock.

## 3. Apply only the changed part on the receiver

1. Discover the latest signed catalog through the existing approval and replay gate. Skip payload planning only if the applied manifest, subscription coverage, storage generation and recovery status still match. Observing a catalog is distinct from applying it. A failed apply must retry the same catalog. A changed label or subscription can still require work when the group payload is identical.
2. Compare the verified manifest with locally applied bucket references. Fetch only new or changed buckets, and plan removals for buckets omitted from the new manifest. For a never-seen group, fetch all occupied buckets. An offline peer can jump directly to the latest manifest. Stream, authenticate and stage bounded rows before live mutation. If any required file is delayed, corrupt or unsupported, preserve the last valid connected mirror and retry. A newer observed catalog, changed subscription, revoked trust or replaced storage invalidates the pending apply.
3. Diff by portable member key inside each affected bucket. Resolve receiver IDs with the existing content identity and ownership rules. Removing a mirror membership leaves local Favorites and other publishers' memberships intact. Apply an authoritative date change to that publisher's membership only. Preserve read flags for retained keys, arrivals/unseen semantics, and the existing treatment of foreign or locally owned record conflicts. A shared record or subtree move can couple groups; use the old and new scopes and indexed reverse memberships to assemble the connected transaction. Unrelated units keep their current independent failure handling.
4. Commit the data, membership/date changes, reading-state updates and applied heads as one recoverable unit. Revalidate the active catalog ticket just before commit. If Hive remains involved, use the existing journal with idempotent replay or a durable coordinated intent; two independent successful writes are insufficient. Apply the UI projection once after durable success, and retry a failed projection without replaying arrivals or durable writes. Measure actual ID/date rows touched. A parallel SQLite cache beside a full Hive group rewrite does not satisfy incremental apply. If profiling confirms that rewrite, introduce indexed authoritative membership/date reads and writes behind the repository API, with released-data upgrade, restart, export and rollback fixtures. Also address whole-group reading-state rewrites on the hot path. Keep existing callers consistent with the new authority.

## 4. Retention, recovery and device work

Extend owned retention to mark objects reachable from retained verified manifests, cached committed revisions and protected in-flight reservations. Preserve the existing withdrawal/privacy rules when choosing retained catalogs. Shared chunks survive until the last retained reference is gone. Recheck current intent/reservations before deleting. Incomplete reachability or provider I/O errors defer collection. Restrict deletion to recognized files in the current publisher's namespace and keep it outside the edit path. Test relocation to an empty folder, interrupted first write, a poisoned immutable object, crash after manifest/before catalog, crash after catalog/before local acknowledgment, and cleanup racing a newer reservation.

Keep the existing foreground scheduling for the first A/B comparison. Android SAF currently polls while foregrounded at about one-minute intervals. Log folder arrival → discovery, discovery → durable apply, and apply → refreshed UI separately. A triggered host sync measures a different interval from waiting for an Android poll. Follow [Android emulator coordination](../android_emulator.md), lease the device, use Maestro MCP, and use a temporary selected folder. Exercise real SAF with an initial share and a warm edit. Report SDK, build mode, storage provider, file opens and whether an external folder synchronizer actually participated.

## Acceptance and reporting

| Scenario | Required observable result |
| --- | --- |
| Clean resume, unrelated edit, unchanged poll | Zero covered bookmark rows encoded/decoded, zero new payload files, and zero receiver library refreshes. Metadata and repair checks are separately counted. |
| Membership removal, including local Favorites | One dirty logical bucket per affected group. Only that bucket's objects are read/written plus manifest/catalog metadata. Correct local post survives. Verify empty-last-bucket deletion and cold reopen. |
| Mixed-size matrix above | Verify exactly 1, 1, 10 and 50 changed group heads respectively. Count changed buckets and provider calls, including unaffected groups. Same-bucket edits coalesce. Edits across buckets, shared records and overlapping roots touch the required distinct buckets. Record bytes and rows per side. |
| Metadata and correctness | Rename and reorder without rewriting members. Test moves into/out of scope, date-only changes, same numeric IDs on different sites, typed Work/Page identities, Local Media privacy, mark-read and receiver-only edits. |
| Catch-up, failure and compatibility | Fresh 100k subscribe, offline jump, missing dependency followed by delivery, failed apply at each durable boundary, replay/fork, legacy JSON, v7 table archive and mixed Following. Existing mirrors stay usable and recover without duplicate arrivals. Exercise the prior signed 22-group fixture when available. |
| Initial publication cost | Record first publish/subscribe, peak scratch/RSS, object count and file opens. Compare large and small groups separately on actual SAF. If first subscribe regresses materially, quantify the tradeoff and test a different bucket count before freezing the wire format. |

Instrument counts at the production adapters/repository as well as timing the service. Separate manifest/catalog traffic, payload reads/writes/verification, distinct objects, member rows encoded/decoded, Hive group rewrites, private staging, durable commit and UI refresh count. Run counter-heavy probes separately from clean timing trials. Report median and range for A and B plus denominators. Use measured subsecond performance only for the interval, device and provider actually tested. Pass functional equivalence and bounded-work assertions even when the host appears fast. Report a remaining full scan or slow receiver phase explicitly.

Run the publication, catalog gate, transport, mirror engine, retention, lifecycle, legacy fixture and native DocumentsProvider tests, the complete local suite for the cross-cutting change, schema audit against the verified released tag, and final Flutter analysis. Keep independent evidence for host, Android SAF, release compatibility and external peer propagation. Record final candidate SHA and any outstanding qualification.

Run the existing focused baseline suites from the worktree root:

```bash
fvm flutter test --no-pub --concurrency=1 --reporter=expanded \
  test/core/backups/mitemite/publication_pipeline_test.dart \
  test/core/backups/mitemite/bookmark_mirror_engine_test.dart \
  test/core/backups/mitemite/retention_test.dart
fvm flutter analyze --no-pub
```

## Baseline evidence

Exploratory host runs used Flutter 3.47.2, the baseline application tree above and the directory transport. The publication pipeline, Bookmark mirror engine and retention suites together passed 96 tests. The auxiliary 4,000-member test verified one removal and preserved the receiver's local Favorites membership and surviving dates. In the same benchmark invocation initial publication took 1,448 ms and added 90,163 bytes, while removal publication took 1,059 ms and added 90,145 bytes. Receiving the removal took 2,950 ms. This host sample illustrates the cost of whole-group republication.

The earlier [#193 qualification](193-stream-bookmark-transfer.md#large-mitemite-publications) measured 84.6 s to first publish and 242.8 s to subscribe a **single** 100,000-post group under different host load. Its Android debug run used a separate SAF receiver. Keep those historical figures out of the paired mixed-group comparison.

### Partial mixed-fixture measurements

These are single samples from an exploratory run using the fixture above. The run was stopped during the spread-out large-group case at the owner's request. The two rows below completed their receiver assertions. The mixed suite as a whole is unqualified. Run all scenarios with the same committed harness on both variants.

| Completed case | Local commit | Publish | Receive | New shared files | New shared bytes |
| --- | ---: | ---: | ---: | ---: | ---: |
| One record in one large group | 46 ms | 37,652 ms | 35,141 ms | 3 | 280,183 |
| 100 records in one large group | 44 ms | 31,086 ms | 38,309 ms | 3 | 280,952 |

First publish took 40,395 ms (221 new files, 2,704,323 bytes), first subscribe took 144,061 ms, and clean publisher resume took 49,134 ms with zero new files. These observations establish the baseline's order of magnitude. They provide no speedup estimate or timing evidence for edits distributed across large or small groups. All candidate runs, paired repetitions, Android SAF timings and external propagation tests belong to the implementer.

## Implementation evidence

The publisher stores a replayable membership and dirty-bucket index in its private SQLite database. The shared directory contains signed catalogs, immutable Bookmark manifests and immutable gzip NDJSON chunks. A small edit writes its dirty chunks and the associated manifest and catalog. A subscriber verifies the new references, reuses the unchanged ones, and journals membership, reading state and head changes before refreshing the view. The earlier signed JSON and v7 archive representations remain readable. An older client needs an upgrade to subscribe to a manifest-based publication.

The comparison uses the benchmark-only baseline `3024a57b4`, with an application tree identical to `826e30c6e`, and candidate `7d06dac49`. Both variants use harness blob `c51ab8d36932f742c9ff6b19f7ec202c6dd7529b`, Flutter 3.47.2 on Linux x86-64, an ext4 directory transport, fresh Hive repositories and the same 110-group, 110,000-distinct-post fixture per trial. The selection digest is `e806589504ff3083d8ee94129cde24aac150e383bae41fb785e5abd85ce6c513`. Timings cover direct service calls through the host test. Android poll delay and UI projection are measured separately.

### Three paired host trials

The trial order was baseline/candidate, candidate/baseline, baseline/candidate. Each timing shows median seconds and the observed range. Byte columns count newly present shared files.

| Scenario | Before publish | After publish | Before receive | After receive | New chunks | Before bytes | After bytes |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Initial transfer | 36.967 (35.911–37.279) | 32.691 (32.635–32.780) | 88.808 (87.759–90.994) | 85.075 (84.802–86.406) | 740 | 2,705,319–2,705,334 | 3,144,221 |
| Clean resume / unchanged poll | 29.970 (29.325–30.709) | 0.120 (0.120–0.128) | 16.393 (15.945–16.896) | 0.024 (0.024–0.028) | 0 | 0 | 0 |
| One post edited | 30.478 (30.181–31.084) | 0.203 (0.201–0.205) | 31.683 (31.610–31.818) | 1.307 (1.302–1.361) | 1 | 280,195 | 78,756 |
| 100 edits in one large group | 31.222 (30.219–31.543) | 2.213 (2.197–2.247) | 31.834 (31.626–31.977) | 7.269 (7.213–7.344) | 46 | 280,955 | 266,199 |
| 100 edits across ten large groups | 33.390 (32.874–33.800) | 4.362 (4.109–4.363) | 76.286 (75.407–76.442) | 12.902 (12.900–13.104) | 92 | 2,275,391–2,275,395 | 606,997 |
| 100 edits across fifty small groups | 32.277 (31.689–32.692) | 2.072 (2.037–2.077) | 32.105 (31.973–32.339) | 6.252 (6.181–6.345) | 50 | 275,244–275,252 | 205,090 |

The mixed run's median peak RSS was 2,394 MiB before and 1,971 MiB after, with ranges of 2,354–2,394 MiB and 1,970–1,976 MiB. The benchmark did not measure peak scratch space. In the separate 4,000-member removal control, median publish time was 1.103 → 0.108 seconds and receive time was 3.079 → 0.401 seconds.

### Work performed per edit

The separate instrumented host matrix ran before the byte-boundary correction on candidate `17b3cd4fc`. It produced one new chunk, one manifest and one catalog for a one-record edit. The publisher point-read 142 rows and the receiver opened one payload chunk. The 100-edit batches point-read 7,233, 14,474 and 5,000 publisher rows and fetched 46, 92 and 50 chunks respectively. A clean publisher resume encoded zero Bookmark rows and produced zero shared files. Its concurrent maintenance verification read shared objects. The unchanged receiver poll opened zero payloads and issued zero projection callbacks. The 4,000-member control preserved the receiver's local Favorites copy and the surviving dates after publishing and fetching one changed chunk.

First publication in the mixed fixture created 740 Bookmark chunks, 110 manifests and one catalog, compared with 110 archives, 110 signed descriptors and one catalog on the pinned baseline. The increased object count matters on providers with costly file opens.

### Compatibility and devices

- The host authenticated and subscribed to the supplied signed legacy archive. Its Hive cold reopen preserved 22 groups, 22,462 dated memberships and 4,312 distinct records.
- A fresh host subscriber on `7d06dac49` applied a complete signed 100,000-post group in 229.5 seconds while the regression suite ran. It checked an unchanged retry and reopened the exact 100,000 dated memberships after restart. This was a separate fixture from the paired timing trials.
- The pinned old reader refused a catalog with the new manifest representation. The registered schema audit passed against published tag `v4.6.1-timberpile.4`.
- The Android x86-64 profile build subscribed to a 4,000-post fixture through DocumentsUI. The next foreground poll found a membership removal after its chunk, manifest and catalog were copied into the selected folder. The group displayed 3,999 unseen posts about 47 seconds after catalog arrival, including poll delay and UI observation. The profile build with `164398b04` reopened the same subscription with 3,999 posts after a cold restart. Discovery, durable apply and UI refresh were observed together on the device. No external folder synchronizer participated.
- All 13 native MiteMite DocumentsProvider tests passed on Android. Maestro lost its device connection after native instrumentation, so the 100,000-post Android subscription is unverified. The temporary app packages and selected synthetic folder were cleaned up.
- The full regression script passed on `7d06dac49`, including 8,652 application tests, package tests and repository checks. Two application tests were skipped. Flutter analysis reported zero issues. The focused MiteMite suite passed all 407 tests.

## Bookmark import progress and Mark Seen follow-up

Implementation commit `dfaf06f35` shows one operation on the subscription row and as a placeholder in Bookmark Groups. Cancel remains available through verification and preparation. The repository's durable journal boundary switches the operation to Saving and disables cancellation. MiteMite now has a top-level Settings entry.

Bulk Mark Seen resolves each owner and subtree scope once and commits the selected identities together. Its normal presentation update reuses the loaded Bookmark indexes and preserves the publisher manifest for the next incoming update.

- On emulator-5572, the baseline profile build from `164398b04` still had no committed seen-state change about three minutes after Mark Read on 7,000 selected posts. The candidate profile build reopened the same 7,000 unseen posts and returned to the grid with Seen labels within the 10-second UI wait. After a cold restart, selecting all 7,000 posts again offered no Mark Seen action.
- Real Android SAF verification showed progress on the subscription row and the Bookmark Groups placeholder. Cancel removed the pending group while the other 7,000-post subscription stayed visible. The automated widget test additionally verified a successful retry and the non-cancellable saving phase.
- Separate host probes with other checks running measured 443.67 seconds on the exact baseline `a5cc93eb8` and 0.624 seconds on the candidate for 7,000 targets. The candidate committed once, updated the library projection once, and performed no full reload for Mark Seen. A subsequent membership update fetched one changed payload chunk.
- The complete regression suite passed, including 8,654 application tests with two skipped. Flutter analysis reported zero issues.
