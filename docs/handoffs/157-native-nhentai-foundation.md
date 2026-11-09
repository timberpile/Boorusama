# Issue #157: native nhentai source foundation

Status: **source foundation implemented, package-verified and independently
reviewed; application engine and final acceptance remain pending**. The user
authorized this independent work
while #156 remediation continues. Nothing here enables a source, integrates into
develop, or completes #157.

Branch: `feature/157-native-nhentai-galleries`.
Worktree: `.worktrees/157-native-nhentai-galleries`.
Base: `5a73ae6233d92abef4e7f062b35114743ed5d5a6` (#156 paused checkpoint).
Verified runtime source: `7a621b3049fe61622082e7bf7e7218e0d37493b0`.
The subsequent handoff update changes documentation only; runtime source and tests
remain identical to that reviewed candidate.
The upstream #156 cache corrections must be reconciled before a combined candidate
is tested. This branch changes only new source-specific package files and this
handoff, not shared content/access/cache/Bookmark storage, engine registration,
configuration inputs, UI or persisted user data.

## Implemented foundation

Public entry point: `packages/booru_clients/lib/nhentai.dart`.

- A read-only Dio client for exact built-in HTTPS v2 config, Gallery listing,
  search, details, tag-ID lookup and tag-category endpoints. Requests are bodyless
  GETs, carry cancellation, and disable automatic redirects. Inject the existing
  coordinated **anonymous** source transport when wiring the application; the
  package wrapper is not a substitute for its final header/redirect boundary.
- Source DTOs keep Gallery ID separate from `media_id`, retain nullable Summary
  metadata, unknown tag categories, unknown versus explicitly empty manifests,
  original Page numbers and manifest order. Missing media keeps its Page slot;
  duplicate Page numbers fail explicitly. Raw listing length, server `per_page`,
  total and `num_pages` are distinct from visible/deduplicated projections.
- Durable keys are `gallery:<GalleryID>` and
  `gallery-page:<GalleryID>:<sourcePageNumber>`. Pages remain 1-based and
  `sourcePosition = pageNumber - 1`. A bounded Cantor pairing supplies a numeric
  bridge without an assumed maximum pages-per-Gallery multiplier. Its supported
  exact-integer bound is `galleryId + pageNumber <= 134217728`; out-of-range
  values fail instead of colliding/truncating. The source string is the durable
  identity. No synthetic Gallery Post was created.
- CDN configuration may select only HTTPS roots in the service-owned `iN`/`tN`
  `.nhentai.net` host families; the configured roots become the exact permitted
  subset. Image and thumbnail families remain distinct. Media paths must match
  the supplied `media_id` directory and approved image suffixes; source paths
  (including `.webp.webp`) are retained. Credentials, unsafe schemes, host suffix
  tricks, encoded/traversal paths, queries and fragments are rejected by the
  media policy. It neither probes every server nor guesses media URLs.
- A source-scoped tag-cache service starts no work on construction. Visible
  unknown IDs use deduplicated batches of at most 100 with shared in-flight reads.
  One caller leaving cannot cancel another's shared read; source disposal revokes
  all shared work and late publications. Bounded catalog operations yield between
  pages to visible lookup and never block it behind an active sweep.
- The tag persistence seam is deliberately unbound to a new database. It upserts
  a fetched batch **before** writing its category/sort checkpoint. Batch or
  checkpoint failure repeats the same page safely after recreation. Actual
  server continuation drives progress; repeated, empty-continuing, unknown or
  contradictory pages stop instead of advancing. Counts may change; ranked
  sweeps always retain partial coverage. Explicit bounded rechecks preserve old
  known tags and update canonical names without deleting unseen entries.

## Current source evidence (2026-11-08)

These are fresh bounded **WSL/host** reads, not Android acceptance or a service
stability guarantee. No credentials, private titles/tag names or raw media were
committed. Durable private local evidence is under
`.worktrees/_artifacts/157-native-nhentai/` in the primary workspace.

- Public `/api/v2/config`, a small Gallery listing, Gallery 694482 details and
  tag-ID lookup all returned HTTP 200 JSON. The detail manifest supplied 41
  Pages with source numbers 1-41 and a separate `media_id`.
- The actual new Dart/Dio client plus Flutter host decoder completed a live probe.
  Source-provided thumbnail GET: HTTP 200, 26,226 bytes, decoded 500x706.
  Source-provided first Page GET: HTTP 200, 148,402 bytes, decoded 1280x1807.
  Source-provided duplicate-extension cover GET: HTTP 200, 28,608 bytes, decoded
  700x988. The path was not rewritten. Reported thumbnail/cover dimensions can
  differ from decoded rendition dimensions; do not infer original geometry
  from a thumbnail or silently replace source metadata.
- Two tag pages requested `per_page=5` and each returned 120 items, with reported
  `per_page=120`, `num_pages=40` and total 4,774. Their ID sets had zero overlap.
  This does not prove a gap-free or complete catalog. A separate small search
  requested two items and returned 25 with reported `per_page=25`; the client
  preserves actual response facts rather than treating the requested size as
  an exhaustion proof.
- Exact successful hosts were `t1.nhentai.net` and `i1.nhentai.net`. Configuration
  also reported i2-i4/t2-t4; their GET/decode behavior was not exercised.

Raw response and media content are retained only in ignored local evidence, not
shared fixtures. Tests use synthetic symbolic Gallery/title/tag values.

## Verification

Pinned FVM Flutter 3.47.2, Dart 3.13.2, six detected physical test workers.

- `fvm dart format` on the new source/tests: completed.
- `fvm dart analyze packages/booru_clients/lib/src/nhentai packages/booru_clients/test/nhentai`:
  **0 errors, 0 warnings, 0 informational findings**.
- From `packages/booru_clients`:
  `fvm flutter test --no-pub --concurrency=6`: **276 tests passed**, including
  all 38 new source-foundation cases. Final evidence:
  `package-suite-candidate.log`.
- The host-only live probe passed one Flutter test; redacted transport/decode
  results are in `host-live-summary.json`. This probe is intentionally not part
  of routine tests and does not turn network availability into a unit-test gate.
- `git diff --check`: passed.

## Independent foundation review (2026-11-08)

An actual independent **Sol High** review inspected source candidate
`7a621b3049fe61622082e7bf7e7218e0d37493b0` against the base above, the current
contracts and this handoff. It identified **no actionable correctness findings**
in the #157 foundation. The reviewer independently ran, from
`packages/booru_clients`,
`fvm flutter test --no-pub --concurrency=6 test/nhentai`: **38 tests passed**.
Its diff check against the supplied base also passed.

The durable ignored local
[review report](../../../_artifacts/architecture-foundations-sol-review.md) and
adjacent `sol-review-157-tests.log` record the independent evidence and limits.
The **276-test complete package pass**, clean scoped analysis and live host
GET/decode results above are author verification; the reviewer read them but
did not independently repeat those checks. Its independent 38-test run is not
a full-package or complete-project regression. No Android, live service, decoder,
timing or restoration validation was performed by that review.

This closes the independent review gate for this source foundation only. It does
not approve a later application cutover or complete #157. Fresh final runtime
review remains required when the gated application adapters are implemented.

Historical failures are retained. The first complete package attempt had three
load failures because this fresh worktree lacked ignored generated booru config.
`fvm install` linked the already installed SDK and `./gen.sh booru` generated only
required missing output; the complete candidate pass above supersedes that run.
Earlier scoped analysis errors/style findings were corrected. No SDK, dependency,
booru config input, cache identity, backup codec or generated tracked file changed.

## Remaining integration and acceptance

- The independent actual **Sol High** foundation review is complete as recorded
  above. Final application/runtime review remains open; older plan references
  to Astra do not supersede the user's newer reviewer instruction.
- The engine remains absent from production registration/configuration. Complete
  the native Android/Dio GET/decode/cancellation/pagination gate under an exclusive
  emulator lease, normal entry point and verified full original-state restoration.
  No emulator was touched by this workstream.
- Bind the client and media policy to the established coordinated anonymous final
  transport, including approved redirects/header isolation and platform gating.
  No cookies/account proxy or anti-bot bypass is authorized.
- Provide the app's Group Summary/Details/member source and engine-owned Page
  Post payload/codec after #140's shared Work/Page composition and #141's explicit
  Group/Page Bookmark contracts are stable. Reuse shared envelopes; do not
  refetch Gallery details once per Page or create a synthetic Gallery Post.
- Bind the tag-store seam to the existing source-local persistence lifecycle and
  validate stored checkpoints. No production persistence adapter, foreground
  lifecycle binding or OS background scheduler is introduced by this foundation.
- Gallery/Page independent v10 backup/import, local membership/Undo, shared UI,
  downloads, orientation and actual source removal remain untested/unimplemented
  application acceptance. No CORS/Web claim is made.
- Reconcile the completed #156/#140/#141 candidates, run relevant app consumer
  tests and the complete final combined project regression before any proposed
  integration. No PR, push, develop integration or issue closure is authorized.


## Combined production continuation (2026-11-09)

The sections above describe the historical foundation candidate. The combined
rollout now registers nhentai as engine 38 and implements ordinary Browse/Search,
anonymous transport, exact source-provided media paths, native Gallery summaries,
shared detail/member envelopes and a durable tag store using the existing cache.
No HTML, cookie/account proxy or challenge bypass is introduced.

Gallery cards use the shared native timeline and its existing bounded pagination
policy. Pages retain actual Gallery/Page locators and missing manifest positions.
Gallery and Page bookmarks are independent canonical records. Saved native groups
participate in local library display, strict filtering, tag suggestions, membership
ordering, bulk operations, mixed viewer navigation and local group cover mosaics.
Cover probes prefer existing cached renditions and never fetch members to render
a card. Stored metadata is available during a failed live member read only under
valid current source access.

C3 persistence now shares mutation serialization across replacement coordinators
and store wrappers. A canceled started durable write remains serialized until it
settles. C4 retains unknown tags, unions partial observations by identity and
allows an explicit complete-empty observation to clear metadata and index. The
application regression uses the real Hive unified store and verifies restart,
independent Gallery/Page removal and Undo, plus matching metadata/index updates.

The complete `booru_clients` package suite passed **286 tests**. The log is
`.worktrees/_artifacts/final-rollout-2026-11-08/nhentai-package-suite-final.log`.
Targeted serialization analysis reported no issues. The qualified native/Pixiv
application batch passed **56 tests with one opt-in live test skipped**; see
`native-and-pixiv-production-tests-final.log`. It covers actual registered Pixiv
Search/Favorites and mixed Work/Ugoira navigation, Favorites privacy cancellation,
source envelope reuse, missing Page positions, known-zero manifests, saved Hive
records, tag observation merges, native mosaics and shared pagination consumers.
The production-route test found and fixed a Ugoira card requiring an absent
selection ancestor; native Post cards now explicitly disable selectable wrappers.
The existing prefetch harness now waits for completed ingestion and uses known
content height: its old lazy delegate retained stale geometry despite a changed
item count, which did not establish the claimed continuation threshold. Policy
expectations and production prefetch behavior were preserved.

Final targeted application analysis reported **zero errors, zero warnings and 15
informational findings**. Earlier interrupted or failed application runs remain
non-qualifying. The final combined handoff owns complete-suite candidate evidence.

The bounded host check used anonymous GETs for config, listing, search, one detail
and one tag-ID lookup. Exact returned Page and thumbnail resources returned HTTP
200 and decoded with ffmpeg (1280x1807 and 500x706). Those two tested paths had no
duplicate extension. Search returned 25 items despite a requested limit of two;
continuation therefore uses the raw source result rather than assumed requested
page size. The redacted evidence is `nhentai-host-read-check.log` in the same
artifact directory. This is host transport/decoder evidence; it does not establish
Android acceptance, source-restoration success or final independent approval.

The opt-in `test/boorus/nhentai/native_live_read_test.dart` passed **one live test**
through the guarded production Dio stack and Flutter decoder. Both exact returned
resources decoded at the dimensions above. Its redacted log is
`nhentai-native-live-read.log`; ordinary regression skips live-service access.
This remains host Flutter evidence. Android ordinary-main acceptance, emulator
restoration, the complete final
combined suite and an independent Sol High review of that exact candidate remain
separate rollout gates owned by the combined handoff. This continuation does not
authorize a PR, push, develop integration, release or issue closure.
