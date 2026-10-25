# Issue #77 source metadata implementation and acceptance

Branch: `feature/77-engine-metadata-audit`. Current user-feedback runtime/test
candidate `6b5d91f7119c382b4cd091e37fcb4afc0adbdd44`, based on published develop
`88536ed64` and the corrected #57 dependency `1b20a8547`. Earlier metadata
candidate `2bfecc609`, initial implementation `e76dd675c` and layout tests
`591ea45d9` retain their evidence below.
No #68 changes are included. No branch push or develop publication is authorized.

## Implemented contract

Approved Option B keeps operational Post getters and geometry non-null while
adding `PostDetailFacts` to common Post data. Converters populate it directly
from nullable raw source evidence. Zero counts and byte sizes remain known zero;
negative counts/bytes, invalid/nonintegral dimensions, absent formats and blank
descriptions remain unknown. Signed scores are valid. Details display the genuine
site ID, never Pixiv/Sankaku synthetic app IDs. Existing IDs and rating enums
remain stable; absent or fabricated ratings become Unknown.

Common snapshot schema 2 reads schema 1. Legacy ambiguous zeros do not become
known facts; operational geometry/media values and unknown engine payloads
survive. Existing fake General ratings in legacy Philomena/Hydrus/e-shuushuu/
Zerochan snapshots decode as Unknown. No engine payload schema was changed.

Expanded file rows, collapsed summaries, statistics, Related Posts metadata and
Original share descriptions consume verified facts. Unknown values and empty
sections disappear without stray separators. Known zero remains visible. Default
source descriptions reuse the existing safe commentary renderer; no extra
metadata categories are introduced. The file-row layout preserves existing
colors and value treatment, with a stacked arrangement at narrow width and
large text to avoid the reproduced ListTile leading-width assertion.

## Engine coverage

All 17 registered families have raw-absence and snapshot contracts:

| Family | Verified facts and semantic decisions |
| --- | --- |
| Danbooru | Original bytes/dimensions/extension, score, favorites; existing uploader and comment providers retained |
| Gelbooru | Original dimensions/URL format, score and supplied comment total; missing/extensionless URL no longer throws |
| Gelbooru v1 | Only supplied score; thumbnail-derived Original facts remain unknown |
| Gelbooru v2 | Original file size/dimensions/URL format, score, comments, JSON/XML file-size presence; reuse #76 Realbooru parser |
| Moebooru | Original bytes/dimensions/file_ext, score; nullable score parsing repaired |
| e621 | Original file facts, score.total, favorites, comments and description; video alternatives cannot supply Original facts |
| Philomena | Original facts and supplied stats/description; content rating remains unknown without authoritative mapping |
| Sankaku | Genuine string ID, Original facts, source score/favorites/comments and uploader name; no fake numeric uploader ID |
| Szurubooru | Original canvas/bytes/MIME, supplied stats; missing safety remains unknown |
| Shimmie2 | Original facts, supplied score/numeric_score and favorites; embedded comment list is not a total |
| Pixiv | Genuine work ID/caption, single unrestricted page geometry; multipage/restricted dimensions unknown; bookmarks are not favorites |
| Anime Pictures | Listing stats; resolved Original facts and uploader only from real opened-post resolution, not filename/preview inference |
| e-shuushuu | Original facts, favorites and caption; favorites are not score, posts are not comments, no fabricated General rating |
| HyBooru | Summary facts only when supplied; full Original/rating enrichment on opening the post |
| Hydrus | File Original facts; no fabricated community metrics/rating/date from import time |
| Nozomi | Selected media geometry; converted static WebP does not establish original JPEG/PNG format |
| Zerochan | Only explicit full-media fields establish Original facts; rewritten thumbnail fallback does not |

Explicit legacy `safe` strings retain the existing sensitive/S classification.
Danbooru's distinct General category remains distinct.

## Bounded enrichment

Only opened Anime Pictures and HyBooru posts use the new engine-owned wrapper.
It admits one request plus the latest queued post, caches positive/negative
results for 30 seconds and discards stale post/profile/deleted-profile results.
A controlled 100-post controller test opens only the current post; rapid 1/2/3
navigation requests 1 and 3, and offline failure preserves listing media.

Anime Pictures reuses its detail response and existing five-minute, ten-entry
Original resolver cache, coalescing concurrent requests. Its redirect-issued
cookie is attached only to the exact resolved media URL through a source-scoped
media Dio; other URLs/profiles/cache-cleared entries receive no ticket. Cookies
never enter Posts or snapshots. A live HEAD check established that the cookie
is required and that source size equals Original Content-Length (1,471,977 bytes
for post 933209), without downloading the media body.

Danbooru previously counted one comments page as a total. The existing provider
now requests at most 100 visible IDs plus one continuation ID. It displays a
count only when the set is complete and ordered; partial/unsupported/malformed
responses remain unknown. This is not a full comment crawl. Live post 5080442
returned six IDs and an empty continuation; another post confirmed zero with
one request. This provider cache is presentation state, not a persisted comment
snapshot.

Realbooru's post-owned Posted-at label now establishes its actual upload day,
with valid month/calendar parsing and an uploader restricted to the same post
container. Generic API change timestamps are not promoted to upload time.
Original URL/size parsing continues to use #76's shared parser.

## Verification and live evidence

- Complete regression on `e76dd675c`: 5,079 application tests, 1,581 tests across
  all 13 package/CLI suites, both shell tooling suites and 72 Python tests passed;
  two existing go_router skips. `/tmp/boorusama-77-regression-final.log`.
- The additional actual description-renderer tests pass at 320 px and 1x/2x text;
  expanded/unknown file details and known-zero stats are also covered.
  `/tmp/boorusama-77-description-layout.log` (7 passed).
- Final complete regression with those tests: see the complete verification sections
  below; no interrupted run is counted as passing.
- Final analysis of all 63 changed Dart files: exit 0, 36 informational
  diagnostics, no warnings/errors (`/tmp/boorusama-77-analysis-host-final.log`).
  Changed Dart formatted
  and `git diff --check` passed. Focused consumers passed 708 tests before the
  final two description cases; the complete run covers the combined candidate.
- Source fixtures preserve small allowlisted actual JSON/XML/HTML responses and
  per-capture provenance, with URLs/names/free-form content anonymized and no
  credentials/headers/cookies. See the fixture README for exact exclusions.
- Successful live metadata covers Danbooru variants, authenticated Gelbooru,
  Gelbooru V2 variants, all four Moebooru hosts, e621/e926, both Philomena hosts,
  both Sankaku Channel/Idol APIs through all seven registered aliases, Shimmie XML,
  Anime Pictures, HyBooru, e-shuushuu and Nozomi image/video metadata.
- The earlier debug x86_64 APK used for the presentation runs below built and
  then passed an unchanged repeat in 8.2 s.
  SHA-256 `fc406dbd29d63b940a4ee05c4d1bb8151f0de829dcc2317444cfe5f81e0ce066`.
  `/tmp/boorusama-77-android-build-checked.log`. Existing Kotlin/SDK support
  warnings remain. Android presentation evidence is recorded in the addendum.

## Remaining acceptance and delivery gates

- donmai.moe/illusioncards returned 403; Zerochan/Asiachan returned 503.
  Rule34 did not yield a real Post record; an authenticated retry requires
  explicit approval after automatic approval review rejected credential use.
- No configured Szurubooru/Hydrus instance or usable Pixiv authentication was
  available. Their controlled tests do not establish live host or permission
  variation acceptance. Current Sankaku Idol clients do not implement a separate
  single-post detail endpoint; listing metadata is the supported source here.
- #53/#76/#57 dependencies retain their documented live/profile limitations,
  including checked Realbooru distinct Originals returning 404. #77 does not
  waive those gates or establish a successful live Original decode there.
- #68 combination is not tested. If either feature is approved for develop,
  reconcile the actual combined candidate and rerun the complete suite.
- Explicit issue-specific approval is required before #77 develop publication;
  architecture approval alone does not authorize integration. Preserve the branch
  and open issue until required acceptance and publication are complete.

## Earlier complete verification before the host correction

Exact test candidate `591ea45d9` passed `./scripts/run_regression_tests.sh`, exit 0:
5,081 application tests, 1,581 package/CLI tests across all 13 suites, both shell
tooling suites and 72 Python tests. Two existing go_router skips remain.
`/tmp/boorusama-77-regression-checked.log`. Documentation-only changes after this
pass do not change that runtime/test candidate.

## Android presentation before the host timestamp correction

Installed the checked APK above on API 37 `emulator-5554`, retaining app data.
Maestro MCP controlled all user actions.

- Existing Default profile (`safebooru.donmai.us`), post 12435337: the actual
  Details drawer showed genuine ID, 1080x2400 Original geometry, GIF, 6.7 MB,
  upload date and resolved uploader. Source description, favorites/score and a
  confirmed `0 Comments` rendered. Collapsed and expanded file details agreed.
  Screenshot: `/tmp/boorusama-acceptance-evidence/77-file-details.jpg`.
- Created only anonymous `Issue77-Anime-QA`, opened actual listing post 933235,
  and observed resolved 2894x4093 JPG Original facts, 1.9 MB, uploader and upload
  date. Confirmed `0 Points` appeared; unavailable favorites/comments did not.
  This exercises the real opened-post wrapper and source service, not only a
  mocked Details object.
- Temporarily selected Original viewer quality and opened that Anime Pictures
  post again. The visible image loaded; sanitized HTTP profiling recorded one
  `oimages.anime-pictures.net` response, HTTP 200, `image/jpeg`. No credential,
  cookie value or signed URL was emitted. The profiled reopen reused existing
  metadata; it does not establish first-open request counts. Source/profile
  isolation and 100-post admission counts are controlled-test evidence.
  `/tmp/boorusama-77-anime-http.log`.
- Restored High viewer quality, deleted exactly `Issue77-Anime-QA`, verified the
  original three profiles remained, selected Default profile and returned to
  Browse. HTTP profiling disabled; VM port forward 8189 removed; exact lease
  released. Other settings and real saved data were retained.
- Exploratory flows encountered retained Settings routes, combined profile labels
  and an old Maestro connection after native testing. Inspection/reconnection
  resolved these setup/navigation issues; failed selector flows were not counted
  as passing acceptance.

This adds real Android presentation/source-resolution evidence, without claiming
live coverage for the unavailable host/account matrix above or the separate
#68 combined candidate.

## Final registered-host correction

The final live/controlled host audit found that Sankaku Idol's ISO upload time
was dropped by its conversion to the common Sankaku DTO. Tests failed for all
three Idol aliases before the fix (`/tmp/boorusama-77-idol-red.log`). Candidate
`2bfecc609` preserves that source timestamp and its subsecond precision; missing,
blank and malformed timestamps remain unknown. The shared app converter now
retains valid source subsecond data. No field is inferred from modification time.

All seven registered aliases were then exercised through actual anonymous
production clients with bounded timeouts/concurrency: four Channel configurations
resolve to sankakuapi.com and successfully read listing/detail metadata, while
three Idol configurations resolve to iapi.sankakucomplex.com and successfully
read listing metadata. Sanitized results are retained in fixture provenance and
`/tmp/boorusama-77-alias-live.json`. This closes the earlier unprobed-alias gap;
it does not establish signed-in permission variations or implement an unavailable
Idol detail endpoint. A captured Idol fixture passes through the actual DTO and
application converter, including timestamp, genuine ID, counts and uploader.

A four-byte range from the Nozomi video index and one metadata JSON capture
also establish actual WebM geometry/format, with byte size still unknown. No
video body was fetched. Both static-converted and video source fixtures pass.
The final source/codec sweep passed 77 app tests; the complete client suite
passed 195 tests before the final full gate. Analysis and full-gate evidence for
the current candidate supersede earlier candidate totals where stated below.

The unavailable public hosts were retried with an identified app client:
donmai.moe/illusioncards still returned 403 and Zerochan/Asiachan still 503.
Their unavailable source matrices remain open, rather than being called passed.

The final `2bfecc609` APK built and passed an unchanged repeat in 9.5 seconds.
SHA-256 `0e9097b207bec9927ecc894ecae6db38b5687978cab42af0a0bac83e0f520c7b`.
`/tmp/boorusama-77-final-host-android-build-repeat.log`. The broader Anime Pictures
presentation/media check above predates only this Sankaku timestamp correction;
its exact APK correspondence is preserved separately.

## Earlier metadata candidate verification and cleanup

`./scripts/run_regression_tests.sh` on exact runtime/test candidate `2bfecc609`
passed, exit 0: 5,083 application tests, 1,591 package/CLI tests across all 13
suites, both repository shell suites and 72 Python tests. Two existing go_router
tests skipped. `/tmp/boorusama-77-regression-host-final.log`.

The native hook repeatedly reports File modified during build. The current
[build troubleshooting](../build_troubleshooting.md#repeated-native-build-warning)
explains the dependency-directory URI classification; no task source changed
during the run. A serial complete extended_image rerun
passed all 47 tests. Linux and Android libavif shared-library SHA-256 values and
generated i18n Dart were byte-identical before/after that rerun, despite the
same dependency-directory warning. This is not a new generated runtime candidate.
Evidence: `/tmp/boorusama-77-extended-image-repeat.log` and matching
`/tmp/boorusama-77-native-{before,after}.json`. Final APK integrity and the
unchanged repeat build are independently recorded above.

Installed that final `2bfecc609` APK (SHA-256 `0e9097b207bec9927ecc894ecae6db38b5687978cab42af0a0bac83e0f520c7b`)
and repeated the real Default-profile search/viewer Details flow: verified its
1080x2400 GIF summary and genuine ID 12435337. Returned to Browse and released
the exact emulator lease. The earlier broader Anime Pictures run is explicitly
source-correspondent to its earlier APK; the final date conversion has actual
live client, fixture, full-suite, build and this fresh Android smoke evidence.
No settings or QA profiles remain changed; profiling/forwarding remain off.

All task code/tests and this report are committed on the existing branch. The
remaining live/account and publication gates above remain open; no develop
integration or branch publication has occurred.

## User feedback: consistent cross-engine Details placement

The user reported Gelbooru points and Rule34 points/comments appearing at the
bottom of Details rather than in Danbooru's position. Commit `db6bdace5` fixes
the shared default layout: information/toolbar, description, statistics,
source/tags/file details, then related content. Unsupported sections/values
remain absent. Saved custom layouts retain their explicit user-selected order.
No data interpretation, source fetch policy, metric labels or native callbacks
were changed by this layout correction.

The regression reproduced 19 failures before repair. All 17 actual registered
engine builders are checked against Danbooru's native `full.keys` order, avoiding
a reference derived from the code under test. Actual expanded-sheet tests at
320px and 1x/2x text verify Gelbooru and Gelbooru V2 statistics before tags/file
details, known-zero points/comments, hidden unknown favorites, and custom-order
precedence. Other sections use marker slivers to avoid starting unrelated API
requests; the statistics widget and section registration are production code.

The layout/source-facts/custom-layout focused command passed 40 tests, and
analysis of the changed runtime/test files reported no issues. Independent
GPT-6.1 Sol XHigh review found no confirmed defect, including the strengthened
reference and the final merge intersection. The combined candidate includes
#57's Original-control correction `715f72ede` and published #84/#81/#62 fixes;
the reviewed files are unchanged by reconciliation. #68 is not included.

An ARM64 Dev APK built successfully, then built unchanged successfully again:
`build/qa/issue77-consistent-details-arm64-debug.apk`.
SHA-256: `682bb15f1bb3bfd528a2f00a31aa8b6a10e7c36ab4c920658615ca3e475e33ee`.
Existing SDK/AGP/Kotlin and documented native-hook dependency-directory warnings
remain; tracked runtime/generated inputs were unchanged. No fresh device or
live authenticated API check is claimed for this layout correction. The user's
Rule34 display report is not a comprehensive account/metadata-matrix pass.
Final complete verification on exact runtime/test candidate
`6b5d91f7119c382b4cd091e37fcb4afc0adbdd44`:

`./scripts/run_regression_tests.sh` passed with exit 0: 5,127 application tests,
all 1,591 tests across 13 package/CLI suites, both repository shell suites and
72 Python tests. Two existing go_router skips were retained. Log:
`/tmp/boorusama-77-layout-current-develop-full.log`. Only this report changed
after the checked runtime state; no repeat application run is required for it.

The branch remains local and open for the user's retest and remaining
source/account acceptance. Publication requires explicit #77 approval. The
prior all-fourteen QA snapshot predates these user-feedback corrections and
is not reused as qualification of this candidate.
