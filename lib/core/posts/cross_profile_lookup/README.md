# Find on Other Profiles

Tracked by [#49](https://github.com/timberpile/Boorusama/issues/49). The single-post
context menu and viewer action menu open a profile-based result page. Supported
profiles other than the source account search automatically, with at most three
concurrent profile searches. Results always stay visible until the user opens a
thumbnail. Unsupported profiles appear with their icons and names at the bottom.

## Post-context matching and capabilities (#49)

Each target tries **Exact File Match** (MD5), then **Pixiv Artwork Match** (artwork
ID), then **Source URL Match**, using only methods supported by its API and source
references available on the post. A successful method stops fallback; source
matches never claim identical file content.

| Target API | MD5 | Pixiv ID | Source URL |
| --- | --- | --- | --- |
| Danbooru | Yes | Yes | Yes |
| Gelbooru | Yes | No | Yes |
| Rule34.xxx | Yes | No | No |
| Safebooru.org | Yes | No | No |

Rule34 uses the existing authenticated Gelbooru V2 JSON API path. Safebooru.org
uses its registered XML API. Other Gelbooru V2 sites, including HTML
implementations, remain unsupported. Capabilities are
explicit rather than inferred from general search support. Relevant references:
[Rule34 MD5](https://rule34.xxx/index.php?page=help&topic=cheatsheet),
[Gelbooru source search](https://gelbooru.com/index.php?id=25921&page=wiki&s=view),
[Danbooru query implementation](https://github.com/danbooru/danbooru/blob/master/app/logical/post_query_builder.rb).

Only a completed empty search advances to the next method. Request errors,
cancellation, invalid responses, and incomplete pages never trigger silent
fallback. Once a method has returned visible matches, a later empty page does
not change the matching method.

## Lookup and account boundaries

`ExactPostLookup` retains the original typed result and cancellation contract.
It validates the source MD5, sends `md5:<hash>` with cascading disabled, and
validates every returned hash and origin, including the target profile identity.
It rejects mismatched/redacted hashes rather than labeling ordinary feed posts as
exact matches. It filters and deduplicates visible results without retaining
hidden post objects. Typed request failures are preserved internally and never
rendered verbatim, since transport diagnostics can contain credentials.

`exactPostLookupProvider(target)` and `sourcePostLookupProvider(target)` use `originAwarePostRepoProvider(target)` and
the target's blacklist configuration. The engine repository composes the target's
configured search restrictions, including rating/deleted-item filters, without
reading the browsing query. Local visibility checks also enforce rating,
deleted/banned visibility, blacklist rules, and unsupported Flash filtering.
Target credentials and endpoint are selected by the existing engine providers.

`CrossProfileLookupSession` performs at most one source metadata refresh per results
session when the original MD5 is absent or invalid. It uses the source's genuine
site ID and resolved originating profile, validates the response identity, and
bounds the refresh to 15 seconds. An explicitly identified but removed source
account never falls back to another account on the same site. Missing or
ambiguous origins cannot refresh. The original image is never downloaded to
compute a hash. A failed refresh remains cached for the session; reopening the
page permits a new attempt. An available source reference remains usable if the
refresh fails or returns metadata without a source URL.

Dismissing the page logically cancels queued and active work.
Late results are discarded; cancellation does not abort an already running HTTP
request. Edited or removed target profiles invalidate their displayed results and
prevent stale completions or opens from using changed credentials. Edited
supported profiles automatically start a new search.

## Shared results presentation

`CrossProfileResults` and `CrossProfileResultSection` in `results.dart` are
presentation components shared with the intended #54 workflow. They accept:

- An arbitrary source reference widget (post preview or shared artwork reference).
- A per-profile `PostLookupMatchKind`: exact file, Pixiv artwork, or source URL.
- Per-profile idle/loading/success/no-match/unsupported/missing-hash/error states.
- Each profile's icon and name, multiple thumbnail results, and open/load callbacks.
- Completeness and continuation flags determine whether Find More is available.
  Headers omit profile URLs and result-count lines; loading, failure and access
  warnings remain visible. Custom profile icons use the existing logo component.

The widgets do not issue queries or choose accounts. #49 supplies automatically
searched profile groups. Manually supplied targets and #54's independently updated
source-match groups can use the same interface. #54 accepts a `PixivArtworkReference` in the same route and page. Its separate
session searches every verified compatible account, including the currently
browsed profile. Shared artwork lookup has its own verified host-specific
capabilities; general URL/hash support does not establish artwork-ID compatibility.
The existing single Android text-share listener dispatches recognized captioned
artwork links before the legacy upload prompt and deduplicates overlapping
initial/warm deliveries while that artwork's page remains open. No Pixiv account,
source-post refresh, synthetic post or active-profile switch is required for
source matching.

## Shared Pixiv artwork lookup (#54)

| Target | Artwork-specific source query | Exact-file fallback |
| --- | --- | --- |
| Danbooru | `pixiv_id:<id>` | `md5:<hash>` |
| Gelbooru.com | Three verified `source:` patterns below | `md5:<hash>` |
| Rule34.xxx | Three verified `source:` patterns below | `md5:<hash>` |
| Safebooru.org | Disabled: known stored sources returned no matches | `md5:<hash>` |
| Sankaku and other hosts | Disabled: unverified | Disabled |

Gelbooru.com and Rule34.xxx try `source:*pixiv.net/*artworks/<id>*`,
`source:*pixiv.net/*illust_id=<id>*`, then `source:*pximg.net/*/<id>_p*`.
These find candidates only. Returned metadata must independently identify the
same numeric artwork ID, including HTML-escaped legacy URLs and multiple source
URLs that all refer to that artwork. Prefix IDs are filtered; missing or ambiguous
identity is an invalid response. Each variant retains its own page cursor.
Raw continuation is preserved when rows are hidden or duplicated, and the
existing **Load more** action continues the search. Source matches keep their
Pixiv provenance and never claim byte identity.

Only completed empty source searches advance to original-file hashing. Any
visible or filtered source match stops MD5 fallback for that target. Downloads
are therefore optional and on demand, shared across targets for one results
session. A configured authenticated Pixiv profile supplies metadata through the
existing `PixivClient.getIllustDetail`; that source profile's visibility policy
is applied before downloading. Source edits/removal cancel and invalidate the
session. Target searches continue using each target's own credentials and filters.

Each static artwork page uses its original bytes, streamed into MD5 without
retaining a file or fabricating a Post. Limits are 20 pages, 32 MiB per file,
128 MiB per artwork, 10 seconds for metadata, 60 seconds per transfer and
90 seconds per artwork. Metadata exceeding 20 pages is rejected before parsing
source Posts. Pages run serially, with at most two CDN transfers application-wide
and at most three target lookups per results page. The dedicated strict-TLS CDN
client accepts only HTTPS `pximg.net` original-image URLs for the exact artwork
and page, sends the Pixiv Referer, follows no redirects and inherits no API
tokens or cookies. Closing the route cancels active/queued media transfers;
ordinary target API cancellation remains logical.

Missing authentication, inaccessible/oversized originals, partial page coverage
and unsupported Ugoira are shown as incomplete coverage rather than definitive
no-match. Pixiv visibility/mute decisions and the source profile's local filters
have a separate access-restriction message; the resolver never hashes a restricted
placeholder. Source matching remains usable without Pixiv authentication. Re-encoded
media cannot be matched by original MD5. No image similarity search is performed.

Live controls, Android checks and remaining verification limits are recorded in
the [#54 handoff](../../../../docs/handoffs/independent-issues-2026-10-25/54-pixiv-share-lookup.md).

`SourcePostLookup` validates returned artwork IDs or source URLs and target origins,
then applies the same mandatory visibility checks as exact lookup. URL matching
ignores fragments but preserves paths and query parameters. Unsafe search tokens
are rejected. Pixiv artwork, legacy illustration, and image URLs can supply IDs.
The generic typed `PostLookupPage` carries match provenance and pagination state.

Pagination uses the repository's explicit continuation flag, then total count,
then the unfiltered page size. Hidden or duplicate rows do not imply completion.
Additional pages require an explicit **Load more** action. Every result, including a unique complete match, stays in the results interface
until explicitly opened. Results across pages are deduplicated.

## Navigation

Android chooser text shares enter through `IncomingTextShareActivity`, a
transient activity with no UI. It removes document/multiple-task flags and
forwards the unchanged share payload to the existing Flutter host with
`NEW_TASK`, `SINGLE_TOP` and `REORDER_TO_FRONT`. This reuses the app's task and
receiver without clearing native activities above the host. MainActivity keeps
the `singleTop` mode required by
[background purchase verification](https://production-docs.revenuecat.com/docs/getting-started/installation/flutter).
File/link
entry points, `share_handler` and the native startup-delivery queue are unchanged.

The lookup route is pushed above the source route. Matches use the existing mixed
post viewer with the target config and target-bound post origin. The active
browsing profile is never changed. Viewer actions resolve under that target
profile, and Back returns through results to the original navigation stack. No
post-ID shortcut or inferred shared database is used.

Both artwork-share and post-based lookup show each profile's matches in a
three-column thumbnail grid. Each thumbnail opens that specific post under the
target profile; its post ID remains available to accessibility and as a tooltip.
Profile status, match provenance and pagination remain outside the grid.

## Verification

The original 32 lookup tests passed with FVM before integration work. Targeted
provider, repository, widget, and application-flow tests cover credentials and
endpoint selection, restrictions, source refresh, cancellation, automatic search,
ordered fallback, bounded fan-out, profile edits,
loading/error/missing-hash states, multiple/partial results, enlarged narrow
layouts, viewer scope, and Back navigation. Repository boundary tests use
controlled HTTP responses; they do not establish live server availability.

Run the focused checks with:

```sh
fvm dart format lib/core/posts/cross_profile_lookup test/cross_profile_lookup
fvm flutter test --no-pub --concurrency="$(python3 scripts/physical_core_count.py)" \
  test/cross_profile_lookup test/application/cross_profile_lookup_flow_test.dart
fvm flutter analyze --no-pub lib/core/posts/cross_profile_lookup test/cross_profile_lookup
```

Run `./scripts/run_regression_tests.sh` on the final candidate before proposing
integration. Live authenticated server/device testing is not part of the
controlled test evidence. Publication and develop integration require separate
authorization.
