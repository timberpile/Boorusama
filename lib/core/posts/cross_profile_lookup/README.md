# Find on Other Profiles

Tracked by [#49](https://github.com/timberpile/Boorusama/issues/49). The single-post
context menu and viewer action menu open a profile-based result page. Supported
profiles other than the source account search automatically, with at most three
concurrent profile searches. Results always stay visible until the user opens a
thumbnail. Unsupported profiles appear in a compact name/domain list at the bottom.

## Matching and capabilities

Each target tries **Exact File Match** (MD5), then **Pixiv Artwork Match** (artwork
ID), then **Source URL Match**, using only methods supported by its API and source
references available on the post. A successful method stops fallback; source
matches never claim identical file content.

| Target API | MD5 | Pixiv ID | Source URL |
| --- | --- | --- | --- |
| Danbooru | Yes | Yes | Yes |
| Gelbooru | Yes | No | Yes |
| Rule34.xxx | Yes | No | No |

Rule34 uses the existing authenticated Gelbooru V2 JSON API path. Other Gelbooru
V2 sites, including HTML implementations, remain unsupported. Capabilities are
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
- Each profile's name/domain, multiple thumbnail results, and open/load callbacks.
- A completeness flag: incomplete lists show only the number loaded, while a
  complete list can show its visible result count.

The widgets do not issue queries or choose accounts. #49 supplies automatically
searched profile groups. Manually supplied targets and #54's independently updated
source-match groups can use the same interface. Android Share handling and #54
orchestration are not implemented here.

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

The lookup route is pushed above the source route. Matches use the existing mixed
post viewer with the target config and target-bound post origin. The active
browsing profile is never changed. Viewer actions resolve under that target
profile, and Back returns through results to the original navigation stack. No
post-ID shortcut or inferred shared database is used.

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
