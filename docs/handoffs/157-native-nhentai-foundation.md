# Native nhentai Galleries (#157)

## Random preview and thumbnail favorites

Android smoke testing on the ordinary dev build used a temporary keyless
profile. The sidebar opened a live Gallery, Back revealed its cover and tags,
and Shuffle replaced the preview in place. The thumbnail heart was hidden for
that profile. Widget tests use simulated account responses to verify the shared
thumbnail and viewer state and confirmed Favorite and Unfavorite actions.
Authenticated Android verification remains pending.

## Following Topics refresh

Each check reads the first Newest search page through the public client and
tracks up to 25 Gallery IDs. The first success establishes a baseline. Later
checks mark the Topic unread when they see higher IDs and show a lower-bound
count when the previous ID falls outside the page. Cover previews use cached
metadata, keeping each check to one request.

The Android dev build followed a live artist search with a temporary keyless
profile and confirmed a successful baseline in Topic Details. The temporary
profile and Topic were removed. Controlled host tests cover new Galleries,
the lower-bound badge state, and marking read. The final card change that
omits the unavailable upload time was verified with a host widget test.

## Gallery review corrections

Browse and Search offer Newest, Popular Today, Popular Week, and Popular All
Time. Choosing an order restarts at page one. The nhentai search endpoint
accepts a wildcard for sorting the full catalog. Anonymous live requests
returned results for all three popularity orders.

Each Gallery tag category and its chips align to the start edge. More Like
This displays all eligible results inline. The viewer toolbar displays the
Gallery-level Favorite heart and enables it when a profile has an API key.
The profile editor accepts pasted keys. The website importer and the profile
settings shortcuts in Favorites were removed.

The widget tests reproduced the previous alignment, four-result limit, and
missing viewer heart. On the corrected tree, 652 affected application tests
passed with one opt-in skip, all 363 client package tests passed, and Flutter
analysis reported `No issues found!`. Gallery favorite writes used a test
fixture. Local evidence is in `.worktrees/_artifacts/157-native-nhentai-polish/`.

## Earlier Gallery details, discovery, and Favorites

Runtime candidate `1c820619f` is based on `origin/develop` at `0ea00c0f7`. Git
range-diff matched all eight replayed commits. This base includes the shared
website Login flow from #159.

Gallery Details group tags with the Danbooru palette and show the source ID and
upload date. Multi-page Galleries can switch between Single and the shared
Timeline. The Timeline preserves manifest slots and returns to its scroll
position after opening a Page. More Like This, Random, and Popular Now
use the public Gallery API through the existing visibility and media policy.

The profile editor can verify a pasted API key or import a key exposed by the
signed-in website's account settings. Login uses the shared preview and Save
flow. The account client sends a profile-scoped key to the account and
Favorites endpoints. Public reads and media use the existing public transport.
Gallery Favorites and local Gallery and Page Bookmarks are independent.

Flutter analysis reported `No issues found!` on the candidate. The ordinary
Android debug APK matched the installed hash on the leased read-only
`emulator-5572`. At 320dp and 150% text, the app displayed Uploaded, ID,
categorized tags, live Popular Now and related Gallery results, and opened a
related Gallery from Show All. Selecting Page 3 and going Back restored the
Timeline. Random opened a live Gallery in the preceding build with equivalent
discovery code. The app opened the site's Login page and rejected a synthetic
invalid API key in the profile editor. The original emulator settings were
restored and the lease released.

Fixture coverage verifies existing-key confirmation, account response
handling, credential isolation, favorite mutations, and pagination. Live
key extraction and real account Favorites remain unverified pending a
signed-in test session with an existing key. Flutter emitted a native-asset
changed-file warning during the successful APK build. Local evidence is in
`.worktrees/_artifacts/157-native-nhentai-review-updates/`.

The first full run found that a Pixiv regression still looked for state on the
old Timeline wrapper. Test commit `bfa0e79c0` targets the shared Timeline state
and preserves the state-retention assertions. The Android runtime is identical
to `1c820619f`.

On `bfa0e79c0`, `fvm flutter analyze --no-pub` reported `No issues found!`.
`./scripts/run_regression_tests.sh` passed with 10,203 Dart and Flutter tests,
three skips, both shell suites, and 148 Python tests. The issue remains open
for review.

## Initial native Android implementation

The branch was rebased onto `develop` at `f4b385fd8`. Git range-diff matched
all three replayed foundation commits. Runtime candidate `0556702f6` enables
the source in the ordinary Android bootstrap. The registry retains decoders on
other platforms so shared Bookmark records can still be read.

Browse and Search use Gallery cards and the shared Single viewer. Gallery and
Page actions capture separate targets. The client shares one manifest for
Details and Pages, retains missing Page positions, and validates CDN
configuration and media paths at the coordinated public transport. A
foreground lookup prioritizes visible tag IDs over a bounded catalog step.
Partial observations preserve known saved tags and the local index. Downloads
use the same guarded transport and publish a completed staged file through the
existing download service.

The public `v4.6.1-timberpile.4` tag resolves to
`45f3df6c3b2e2c977480b5ac3f3aef415765d218`. Its Bookmark writer uses v6 and its
source catalog predates this engine. The app keeps v6 and the existing v4/v5
readers. Tests exercise Gallery and Page roundtrips and local cold reopen.

Device qualification used the read-only `emulator-5572` session. At 320dp,
ordinary routes reached live Browse and Search page two with 25 Galleries.
The app decoded thumbnails and Page media. The viewer saved one Gallery and
one independent Page, downloaded a nonempty Page file, and cancelled a
279-page transfer with 122 WebP files retained. Both records reopened after
restart. The ordinary Android APK built without a QA flag, matched the
installed APK hash, and decoded the saved Gallery after removing the test
profile. Saved metadata stayed visible on an offline restart at 150% text.
The original network and font settings were verified before the read-only
session was shut down and its lease released.

The opt-in host probe also decoded live Page and thumbnail GETs through the
app transport. Flutter reported a native-asset changed-file warning during
the Android build, which completed successfully and produced the matching APK.

On `0556702f6`, `fvm flutter analyze --no-pub` reported `No issues found!`.
`./scripts/run_regression_tests.sh` passed with 10,123 Dart and Flutter tests,
three skips, both shell policy suites, and 148 Python tests. The initial full
run hit an SQLite temp-directory cleanup error. The affected case and the
full suite both passed on the unchanged runtime candidate in the full retry.
Local evidence is in `.worktrees/_artifacts/157-native-nhentai-implementation/`.

`develop` advanced to `0ea00c0f7` during verification. The issue remains open
for review and integration approval.

## Historical foundation handoff

Status: **source foundation implemented, package-verified and independently
reviewed; application engine and final acceptance remain pending**.

## Product UI decisions — 2026-11-14 (for future application integration)

The first native nhentai release **uses the existing Pixiv Work-style Group
media pager** for Galleries, with real ordered Page Posts and shared Group
Details; no nhentai-specific overview-first page or new Viewer is required.
Reuse existing Tag/Search UI without a separate nhentai Tag browser. Source
document: [#157 UI decision](https://github.com/timberpile/Boorusama/issues/157#issuecomment-6877240744).

The broader **cross-engine Gallery/Pool presentation toggle** (media-first
viewer vs. Group overview + Post grid/timeline) is a **future design proposal**,
not approval for a shared Viewer rewrite in #157. Keep source, identities and
member order independent of presentation. Resolve that separately with the owner.
 The user
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
