# Issue #157: native nhentai source foundation

Status: **source foundation implemented and package-verified; application engine
and final acceptance remain pending**. The user authorized this independent work
while #156 remediation continues. Nothing here enables a source, integrates into
develop, or completes #157.

Branch: `feature/157-native-nhentai-galleries`.
Worktree: `.worktrees/157-native-nhentai-galleries`.
Base: `5a73ae6233d92abef4e7f062b35114743ed5d5a6` (#156 paused checkpoint).
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

Historical failures are retained. The first complete package attempt had three
load failures because this fresh worktree lacked ignored generated booru config.
`fvm install` linked the already installed SDK and `./gen.sh booru` generated only
required missing output; the complete candidate pass above supersedes that run.
Earlier scoped analysis errors/style findings were corrected. No SDK, dependency,
booru config input, cache identity, backup codec or generated tracked file changed.

## Remaining integration and acceptance

- Independent actual **Sol High** review is still required. Older plan references
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
