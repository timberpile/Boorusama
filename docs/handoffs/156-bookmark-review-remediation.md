# Bookmark remediation: verified candidate and remaining gates

## Current status (2026-11-08)

**Source/tests and exercised Android QA pass independent Sol High review; full
#156 acceptance remains on hold.** The complete final-candidate regression
passed. Original emulator APK, all nine data roots and settings were restored
and independently checked; the exclusive lease is released. No push, PR,
develop integration or issue closure was performed.

Continue `maintenance/156-shared-source-groups` in
`.worktrees/156-shared-source-groups`. Local and fetched remote starting refs
were both `5a73ae6233d92abef4e7f062b35114743ed5d5a6`; that checkpoint was
preserved. Checked runtime/test candidate:
`6af367354ef8c7e09dd939543b1cbf9403f2da35`, tree
`1203be209154993b2f95a2565387afd14d1ebad1`. Subsequent reporting edits are
documentation only and may reuse this candidate's verification.

| Remediation commit | Purpose |
| --- | --- |
| `83c808143d66bb46674ac87d89c0a0b8b2b3247b` | Selective offline integration, cache/policy cleanup, Bookmark behavior and source corrections. |
| `8635be8dbc544d34cd3daa7de8953235b0058d0f` | Preserve card-title hit targets after a full-run selection regression. |
| `6af367354ef8c7e09dd939543b1cbf9403f2da35` | Replace two obsolete salted-cache test expectations and add deferred cached-share revocation coverage; no runtime change. |

The [technical specification](../designs/2026-11-08-bookmark-review-remediation.md)
retains the diagnosis and accepted behavior. The [original architecture
handoff](156-shared-source-groups.md) retains earlier history. Its old approval
covers `2074d452a`, not this remediation. The paused generation architecture,
pending icon selection and prohibition on starting #140 are superseded by the
user's resume instructions. Family A is selected; separate #140/#141/#157
foundations are authorized. Their integration remains gated.

## Selective integration of the offline fix

Inspected the complete delta from base
`363ab86729493e438d12bb4d07c3f5e0afac80a4` to
`bug/156-bookmark-offline-cache` at
`2fbcc64e68fa2eb40e924d2c75d8217191c462e7`. No whole-commit cherry-pick or reset
was used. See also [the offline-cache handoff](156-bookmark-offline-cache.md).

- Integrated the unchanged underlying `ImageCacheManager` through
  `contentMediaCacheManagerProvider`. Ordinary URL/custom keys, distinct rendition
  URLs, quota, eviction, file leases and atomic writes keep their existing owner.
- Integrated Danbooru's reactive read-side AsyncValue projection. Locally known
  global/profile rules are available without successful current-user HTTP;
  available server preferences enrich them on recovery. Explicit replacement
  semantics and server mutation methods remain intact. Unknown remote rules
  are not presented as fetched preferences.
- Imported both formerly unexecuted focused tests. Corrected the blacklist
  fixture to the deployed JSON-list representation and added rendition-miss
  coverage. Consumer tests requiring salted disk keys were adapted while
  retaining actor, cancellation and late-publication assertions.
- Removed rejected `localMediaGeneration` fields/allocator, persistent namespace
  provider/helper and duplicate policy-snapshot store. Bound video retains the
  stable existing `content-media` namespace. No cache-identity database, schema
  or migration was introduced.
- Preserved runtime actor epochs, exact source/account binding, URL restrictions,
  redirects/headers, transport cancellation, file leases and rejection of late
  image/video/share results. Stable storage keys do not grant another actor's
  actions.

Existing URL/custom-key entries are reusable without redownload when the exact
rendition remains present. Thumbnail and sample URLs remain independent. Files
written only under a lost randomized namespace have no recoverable URL mapping;
they were preserved, not reverse-hashed or deleted. Bookmark records,
memberships, dates, profile data and backup version 10 remain compatible.
No user image cache or app data was cleared.

## Findings and implemented behavior

| Reference | Current result and evidence limit |
| --- | --- |
| N1 | Occupied loading/error slots preserve aspect ratio and explicit feedback; an actual mixed-grid outage regression keeps healthy-source media visible. |
| N2 | Normal URL/custom-key disk hits survive container recreation/restart. Host tests require decoded pixels with zero media calls; ordinary-main Android offline process restart also decodes cached pixels. |
| N3 | Bounded cover selection retains at most 12 candidates/four initial failed network attempts; a cached fifth candidate decodes. Sequential remaining-Pool allocation fixes mixed Post/Pool mosaics. One foreground Retry is pointer-tested; empty slots are decorative. |
| N4 | Optimistic mode publication, serialized persistence and guarded rollback are retained. Measurements below do not reproduce/explain the user's 10s/2s observations. No speculative full-library cache was added. |
| N5 | Children-only Structure groups omit empty timeline/search/divider. Genuine/query-empty and unavailable states remain distinct. |
| N6 | Shared anchored/modal pickers use 48dp ordinary rows, 12dp screen gutters and a full-height 80dp parent navigation region. Leaves/Recent have no inactive arrow; repeated self rows and visible root Back are removed. Enlarged text grows rows. Kurumi width changes are opt-in. |
| N7 | Fixed four-slot mosaic has no inner scrolling viewport. Host geometry/exercised Android motion are stable; the original animation was not reproduced or causally attributed. |
| N8 | Plain title at depth 0/1, ancestor popup at depth 2+. Family-A Structure/Unified SVGs use existing renderer/theme/localization. Persisted `allBookmarks` stays unchanged; global All is separate. Penpot publication remains open. |
| N9 | Narrow native Realbooru reads pass deterministic transport and real host/Android GET/decode without a saved profile. DAPI failure remains distinct from successful existing HTML parsing. |
| R1 | Captured selection/action actor is checked across awaited work; another same-site profile cannot be borrowed. Production-path host coverage passes; current Android profile-revocation actions remain unverified. |
| R2 | Deleting the current group normalizes once. Host tests and Android deletion of a disposable QA child pass. |
| R3 | Indexed page-3 checkpoints restore at offset zero with bounded reads. Host/full-suite coverage passes; current Android checkpoint verification remains open. |
| R4 | Actual native ContentGroupPage refresh updates metadata/members coherently and rejects stale seeds. Host/full-suite coverage passes; current Android source refresh remains open. |

N3's initial decode failure needed completion-driven `runAsync` pumping through
the existing helper, not a broader scan or weaker decoded-image assertion.
R4's initial fixture bypassed `OriginAwarePostRepository.fromConfig`. Correcting
that seam retained the actual-page assertions. The corrected test fails against
the original production scope/cache/description implementation and passes on
the candidate: members 1/2 become 2/3, title/description update, and one fresh
metadata request is made. Known native envelope DText is authoritative for
public and saved actors; stale separately cached HTML cannot replace it.
Evidence: `r4-production-baseline-red.log`, `core-corrections-3.log`.

## Automated verification and earlier failures

Durable evidence is in the primary workspace under
`.worktrees/_artifacts/156-resume/`. FVM and six detected physical workers were
used; workload probes remain serial. Final Flutter tests/builds in this worktree
ran sequentially.

**Final command:** `./scripts/run_regression_tests.sh`, unchanged clean
`6af367354`, 14:13:14–14:25:52 UTC, 2026-11-08, **exit 0/PASS**.
`full-regression-6af3673-result.json` records the exact commit/tree/clean state;
`full-regression-6af3673.log` contains:

- Application: **6,743 passed**.
- All 13 package/CLI suites: **1,671 passed**, two go_router skips.
- Shell policy/release checks passed; **76 Python tests passed**.
- Total Flutter/Dart: **8,414 passed**. Completed application coverage includes
  profile write errors, backup rollback, hierarchy, no-poster GIF, preload
  revocation and both picker consumers.

`fvm dart analyze` reports **0 errors, 0 warnings, 3,780 informational findings**,
exit 1. This is not zero-issue analysis (`analysis-6af3673-final.log` and counts
JSON). Changed Dart files were formatted. The unchanged libavif build-hook
message “File modified during build. Build must be rerun.” is documented in
build troubleshooting; runner exit and unchanged tree were verified.

Focused commands/results, also covered by the final complete pass:

```bash
fvm flutter test --no-pub --concurrency=6 \
  test/core/posts/pools/native_pool_occurrence_ui_test.dart \
  test/core/bookmarks/bookmark_cover_fallback_test.dart \
  test/core/content/viewer_access_binding_test.dart
# core-corrections-3.log: 16 passed
fvm flutter test --no-pub --concurrency=6 \
  test/core/content/anonymous_source_policy_test.dart \
  test/core/content/anonymous_public_transport_test.dart
# realbooru-transport-2.log: 23 passed
fvm flutter test --no-pub --concurrency=6 \
  test/application/bookmark_collection_selection_flow_test.dart \
  test/application/bookmark_hierarchy_screen_flow_test.dart \
  test/core/bookmarks/bookmark_cover_fallback_test.dart
# selection-covers-final.log: 18 passed
```

Earlier logs are retained as failures, not acceptance evidence:

- `offline-focused-1.log`: five failures from the imported incompatible local
  blacklist fixture; corrected focused/full runs pass.
- `targeted-matrix-2.log`: 2,584 passes/three failures, obsolete root-popup and
  decorative empty-cover Retry audits. Corrected hierarchy/focus cases pass.
- `full-regression-83c808-result.json`: interrupted/exit 130 after our title
  IgnorePointer broke actual drag selection. Only the gradient now ignores
  pointers; title hit testing is retained and covered.
- `full-regression-8635be8-result.json`: exit 1, 6,740 passes/two obsolete salt
  assertions. Adapted tests/additional cached-share revocation coverage pass;
  only tests differ from that runtime candidate.
- Combined `cover-live-performance-final.log`: exit 1 because its live probe
  omitted the app's normal Referer. Benchmark subcases passed, but the aggregate
  did not. Corrected live and standalone benchmark runs are separate below.

## Controlled before/after performance

| Probe | Before | Final after | Interpretation |
| --- | --- | --- | --- |
| Host, 9,000 generated rows, first tag-index entry | Approximately 750–889ms | 798.641–973.540ms | Tag construction, not Android first frame/decode; no speedup established. |
| Same host probe, repeated entries | 0.28–0.62ms | 0.284–0.793ms | Existing warm reuse remains small; not mode-switch UI timing. |
| Host, 1,000 real Hive rows, write/cold load | Approximately 796/202ms | 892.479/242.833ms | Database probe, not migration/cold process; no improvement claim. |
| Android debug, 9,000 generated Posts | No matched pre-change device capture | Decode-all max 315.158ms; library-load async wall max 676.076ms | Normal import/reload capture, not isolated cold opening. |
| Android debug, four Unified entries/three mode round trips | No matched pre-change device capture | Select max 10.255ms; project 2.129ms; fetch async wall 154.954ms | Scoped spans, not tap-to-decoded-frame duration. |

Before: `.worktrees/_artifacts/156-remediation/geometry-performance-before.log`
(benchmark probes completed within a command whose geometry fixture failed).
Final standalone command, **two tests passed**:

```bash
fvm flutter test --no-pub --concurrency=1 \
  benchmark/bookmark_opening_test.dart \
  benchmark/bookmark_pipeline_performance_test.dart --reporter expanded
```

Evidence: `performance-final-6af3673.log`, `android/performance-import.json`,
`android/performance-warm-modes.json`. Normal-UI import of 9,000 Posts plus four
Group/wrapper records includes a 4.891s frame-latency maximum/4.664s UI delay
across import/settings/navigation; it cannot be assigned to Bookmark opening.
Warm Bookmark-group routes recorded 279 frames, 60 over budget, max frame
latency 414.390ms/UI delay 153.347ms. Four route-owned background tag
builds/cancellations reach 5.991s async wall time, with one finished vocabulary;
this is not mode-switch blocking time. Cache stayed at 83 entries/13,023,184
bytes under the unchanged 1GB quota; warm capture did not reopen/decode the
library. Background rebuild cost and debug-emulator jank remain limits.
Migration, first-frame, image lookup/decode and physical/profile/release timings
are not inferred from those spans.

## Ordinary-main Android/Maestro and restoration

Used an exclusive exact `emulator-5554` lease, fresh nine-root backup, parked
originals and an isolated working clone. Ordinary `lib/main.dart` dev-debug APK
was built at `8635be8dbc544d34cd3daa7de8953235b0058d0f`; only two test files
changed through `6af367354`. `android/candidate-runtime-equivalence.json`
proves runtime correspondence. Installed/build APK SHA-256:
`3fc9c45232ba9faf10931e4e5edac979233dd23f4c5d50e5b87c9a98ec0b1320`.
No test-only entry point or app/cache clear was used.

- Normal UI import/cache seeding used public-only QA fixtures. All 69 existing
  image-cache files retained identical hashes; 14 exact URL renditions were
  added with no replacement/quota reset. Synthetic strips and actual cached
  Safebooru media decoded offline in the mixed grid/parent mosaic.
- `offline-restart-persistence` passed eight Maestro commands. Force-stop
  changed PID 7087 to 2821 with airplane mode on/Wi-Fi off. Unified persisted
  and four cached strips decoded (`offline-restart-unified-decoded.jpg`). Host
  tests establish zero media transport calls; Android establishes decoded
  offline pixels/no recorded ImageFetcher failure, **not** a global device
  zero-HTTP-attempt counter.
- Mode/hierarchy passed 13 commands. Anchored trailing navigation/direct leaf
  membership worked at 320dp. Naming cancellation/keyboard at 2x font passed
  11 commands; actual modal nested navigation/Cancel at 320dp/2x passed 13.
  Cancel retained selection. Root Back stayed hidden; leaves had no arrows;
  enlarged rows grew with text.
- Deleting disposable QA Empty passed ten commands, normalizing once to its
  parent and staying there across scroll/rebuild. No original group was deleted.
- Four-swipe mosaic flow passed. Thirty sampled video frames keep lower tile
  tops aligned at zero pixels and card-bottom offsets at 4–5px. Upper-row
  toolbar clipping is not evidence of independent motion.
- Exploratory anchored-count/name-Back flows failed due to stale selectors or
  incorrect expected dialog ownership. Corrected continuation/cancel flows
  passed; naming deliberately closes the picker before its dialog. Failed
  result files remain failures.

`android/restoration.json` and `android/final-system-check.json`: **PASS**.
Restored and post-cleanup archives match all **448 original members**, zero
missing/extra/changed entries (type/mode/size/content SHA/links/device numbers).
Independent Sol repeated both comparisons. Original APK SHA-256:
`a6c31bf518d151fec6d8100b4623ee24d6845d5953540425a3e2b1e275e559ce`.
All nine original roots, permissions, settings, radio, size and density were
restored; original app resumed because it had been running. Archive equivalence
was checked before normal resume, which can write runtime data. Only owned
external QA exports/video and the owned VM forward were removed; QA archives
remain durable. `android/lease-release-result.txt` confirms release. This
workstream has no active emulator lease.

## Source-specific live results

**Realbooru:** DAPI still returns HTTP 200 XML `success=false`/API offline.
Existing native HTML listing/detail parsing and exact-source public transport
succeed without credentials or a saved profile. Host decoded a 100x150 thumbnail
and 2334x3500 sample. Android fetched the previously absent sample, 1,116,703
bytes, MD5 matching its source filename. Read-only VM inspection (getters only,
no evaluation/UI mutation) confirmed a live undisposed ExtendedRawImage at
2334x3500 labelled as that sample. Evidence: `realbooru-live-probe-3.log`,
`android/realbooru-android-sample-evidence.json`,
`android/realbooru-decoded-live-images.json`. The allowlist is limited to exact
native source/API shapes and first-party safe media; unknown sources,
credentials and unsafe query/redirect targets remain rejected.

**Szurubooru:** inspected necessary ignored URL/profile metadata only; no matching
saved app profile exists. `/api/info` returns 200 and advertises
`pools:view:anonymous`, `pools:list:regular`. Anonymous listing 403 is a listing
authorization boundary, not proof public viewing is unsupported. Pool 1 is 404;
a bounded 100-Post permitted read found no Pool IDs. The user was asked for a
known existing Pool ID/link. No answer/usable fixture was available. No broader
crawl or permission bypass was attempted; actual Android Pool acceptance
remains open. Redacted capability/discovery JSON is retained locally.

## Independent review and separate issue foundations

An independent `gpt-6.1-sol` reviewer at **high** effort authored no canonical
implementation/tests. Report:
`.worktrees/_artifacts/156-independent-sol-review.md`. Its P2 mixed Post/Pool
cover-index finding was fixed with cached 1+1/2+2 regressions and re-reviewed.
It inspected final complete-run/source evidence and actual Maestro/provenance,
then independently repeated archive comparisons/APK hashes. Verdict:
**PASS source/tests/exercised QA/restoration at `6af367354`; HOLD full #156
acceptance**. Its earlier 98-test run applies to an intermediate head and
coincided with an APK build, not the final sequential regression.

The later user instruction permits these separate branches. They remain
incomplete and need prerequisite reconciliation, production integration,
complete combined regression and Android acceptance:

| Issue / owning branch | Latest committed checkpoint | Reviewed runtime/test source | Status / owning handoff |
| --- | --- | --- | --- |
| #140 `feature/140-pixiv-work-viewer` | `d7298c5a06883977966421aec0d11ecf4d2564e4` | `308463b1dcedf252ae260a361e13f6300244b9f5` | Work/Page source foundation; 61 focused + 240 package passed. `docs/handoffs/140-pixiv-work-viewer.md` in its worktree. |
| #141 `feature/141-pixiv-work-page-bookmarks` | `01fa085840f8442246505b1ad1d883e01a4fecdb` | `1167f6dbf398be58879cf2967bd0c2a084cbe8f4` | Independent Work/Page drafts, real Hive memberships/removal/Undo/restart; 37 focused passed. `docs/handoffs/141-pixiv-work-page-bookmarks.md` in its worktree. |
| #157 `feature/157-native-nhentai-galleries` | `cf71fb22e142564d96a1f25cce85a48898ec52fc` | `7a621b3049fe61622082e7bf7e7218e0d37493b0` | Native API/models/bounded incremental tag cache; full package 276 passed. `docs/handoffs/157-native-nhentai-foundation.md` in its worktree. Engine remains unregistered. |

All received independent Sol High foundation review/re-review. One P2 Pixiv
omitted-tag response incorrectly published complete empty tags. Reproduced and
fixed in #140, propagated/tested in #141: unknown/unusable observations preserve
cached tags, usable partial subsets retain partial coverage, and explicit empty
remains authoritative. No actionable source-foundation finding remains.
Reviewer independently ran 61/37/38 focused cases; complete package
counts above are implementer evidence. Final checkpoint commits change handoffs
only. Report: `.worktrees/_artifacts/architecture-foundations-sol-review.md`.
No common viewer/access/cache/storage files were concurrently edited by these
workstreams. Their paused-base cache design must be reconciled with #156 before
combined verification. Foundation approval is not final issue acceptance.

## Remaining acceptance gates

1. Obtain a known valid Szurubooru Pool fixture/authorized reader and perform
   the retained ordinary-main Android Pool check within its listing policy.
2. Separately exercise current Android R3 page-3 restoration, R4 coherent source
   refresh and local-blacklist/profile-revocation actions. Host/full-suite passes
   do not substitute for these checks. Danbooru service failures/missing Szuru
   Pool limited this campaign.
3. Reproduce/attribute the original mosaic and 10s/2s latency symptoms with a
   matching workload/device. Debug-emulator spans do not prove release/physical
   responsiveness or measured before/after improvement.
4. Publish/verify the approved editable SVGs as Penpot components
   `Bookmark view / Structure` and `Bookmark view / Unified` when connected.
   Selection is final; publication remains open.
5. Re-review relevant runtime changes/new gate evidence before full acceptance;
   rerun complete regression if runtime/tests change. Further Android work needs
   a fresh exact lease/restoration campaign. No PR, push, develop integration or
   issue closure is authorized by this handoff.
