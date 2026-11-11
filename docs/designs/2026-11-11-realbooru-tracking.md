# Why Realbooru new-Post tracking is unsupported

Baseline: `22348b2fb20049088705ce38f5b261e191b148af`.

## Confirmed current constraints

[GelbooruV2Repository.searchRefreshQueryAdapter](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/lib/boorus/gelbooru_v2/gelbooru_v2_repository.dart) returns UnsupportedSearchRefreshQueryAdapter for thumbnail-only sites. Realbooru's [listing parser](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/packages/booru_clients/lib/src/gelbooru_v2/parsers/rb_parsers.dart) builds PostV2Dto records without `createdAt`; it extracts IDs, thumbnail/media hints, tags, rating and score. Its detail parser extracts only a calendar upload day from the Posted-at label, explicitly not an exact timestamp.

[ChronologicalSearchScanner](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/lib/core/search/following_topics/src/refresh/chronological_search_scanner.dart) rejects a scanned Post with a missing creation date. [SearchRefreshCommit](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/lib/core/search/following_topics/src/types/search_refresh.dart) and existing tracking state use timestamp checkpoints/retention boundaries. Merely removing the thumbnailOnly gate will therefore still fail and could encourage incorrect timestamp assumptions.

This is an application-contract limitation, not proof that Realbooru can never support new-Post tracking. Four preview images do not establish the chronological/checkpoint guarantees required for NEW tracking; #65 intentionally separates these features.

## Recommended route

Keep the current unsupported status until a trustworthy strategy has fixtures and live read-only evidence. Do not fetch a detail page for every listing item just to enable ordinary refresh, and never fill missing upload times with now or fabricated ID-derived dates.

First inspect representative current listing responses for a genuine upload timestamp and verify newest-first ordering and pagination. If reliable timestamps are available, populate them in the site parser and enable a site-specific chronological capability rather than equating tracking with thumbnailOnly globally.

If timestamps remain unavailable, the practical alternative is an explicit identity-based refresh strategy for sites with verified stable newest-first, increasing Post IDs. It should use the same scheduler/repository/commit boundary, but its own typed checkpoint: high-water ID plus a bounded recent seen-ID overlap. Seed a baseline without reporting every existing item as new; count only identities above the established watermark for new-upload semantics. An older Post newly matching changed tags must not masquerade as a new upload. Preserve unknown upload dates in the shared Post model and display rather than inventing dates to satisfy feed sorting.

Advance a checkpoint only after a successful bounded scan reaches a trusted overlap/boundary or exhaustion. If the page budget is reached before that, retain a resumable boundary and a lower-bound/truncated result; do not jump the watermark past an unscanned interval. Offset-page movement needs overlap/deduplication and explicit handling of deletions. If ordering is unstable or the source reuses IDs, leave tracking unavailable.

This requires a small but real extension of timestamp-only refresh contracts and persistence/backup compatibility. It should be its own feature after evidence, not a one-line bug fix or a general new tracking framework. Reject explicit incompatible sort queries through the query adapter.

## Verification

Fixtures for missing timestamps, increasing IDs, reordered/sticky entries, gaps, deletions, duplicate pages, old retagged matches, more new entries than the page budget, profile/query changes and cancellation. Test restart/backup of the new typed checkpoint and ensure an interrupted scan never loses an interval or marks failed work successful. Existing timestamp-based sources must retain their behavior.

No authenticated/live Realbooru tracking experiment, runtime change or device verification was performed. The independent [folder preview correction](2026-11-11-following-folder-previews.md) does not depend on this feature.
