# Collection upload-date sorting

Baseline: `22348b2fb20049088705ce38f5b261e191b148af`. The original report asks for triage, not a confirmed device reproduction. Two different ordering surfaces need separate conclusions.

## Collection cards in Bookmark timelines

[BookmarkGridEntry](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/lib/core/bookmarks/src/types/bookmark_grid_entry.dart) correctly separates upload dates from membership-added dates. Ordinary Posts use `post.createdAt`; Collection cards use `newestUpload` or `oldestUpload`. Known dates precede unknown dates in both directions, followed by a deterministic key tie-breaker.

There is a semantic weakness: `BookmarkPoolEntry.uploadDate(oldest: true)` returns `pool.oldestUpload ?? pool.newestUpload`. A known newest member date is not evidence of the oldest member date. A partially indexed Collection can consequently occupy an apparently precise but incorrect position in Oldest Upload order. This is an existing fallback, not proof of the user's exact observed case.

[PoolSummaryIndexer](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/lib/core/bookmarks/src/services/pool_summary_indexer.dart) is intentionally bounded: up to 40 sampled members plus two single-member extrema queries when upload ordering is supported. It only derives extrema from a complete sample when all members have dates. Partial samples without suitable endpoint support retain unknown extrema; failed or inconsistent responses are not authoritative dates. [Unified snapshot projection](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/lib/core/bookmarks/src/data/bookmark_collection_projection.dart) preserves these values through GroupBookmarkIndex rather than replacing them with the Group's creation date.

**Recommendation:** use oldestUpload alone for Oldest Upload; unknown remains unknown and sorts last. Keep newestUpload alone for Newest Upload. Never fall back to the bookmark-added date, remote Pool creation date, observation time or opposite extremum. Reuse the existing bounded summary refresh; sorting itself must remain local and must not crawl every Collection. Preserve #68's sampled-tag semantics and #152's separate membership dates. Document that a saved summary reflects its last observation, not a live continuously updated remote aggregate.

## Members inside an opened Pool/Collection

[PoolGroupMembers](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/lib/core/posts/pools/src/types/pool_group_members.dart), used by [DanbooruGroupSource](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/lib/boorus/danbooru/pools/content_group_source.dart), implements Oldest/Latest by sorting **numeric Post IDs**, then slicing the manifest before loading Posts. It does not compare upload timestamps. Ordered preserves the source manifest.

ID order is deterministic and inexpensive, but is not a universal proof of upload-date order across source engines. If these controls promise upload-date ordering, establish each adapter's guarantee rather than claiming the shared implementation is exact. Prefer an engine-supported ordered member endpoint with correct pagination. Where unavailable, retain explicitly ID-based ordering or offer date sorting only for a complete already-loaded set; never sort individual fetched pages and present that as global chronological order. Do not fetch the entire Pool solely to sort it.

## Verification

Add pure selector tests where a Collection has only newestUpload, only oldestUpload, neither, both, equal dates, and mixed Posts/Collections. Verify imported snapshots and group/subtree/all views preserve added-date versus upload-date semantics. Indexer tests should cover partial responses, missing dates, failed extrema requests and contradictory ranges. For member ordering use IDs deliberately out of timestamp order, multi-page manifests, missing members and stable source positions. Check actual UI labels against the proven order contract.

Conclusion: no blanket 'sorting is broken' verdict. Bookmark-card sorting has a misleading oldest-date fallback, and opened-Pool ordering is ID-based rather than timestamp-based. No runtime changes or tests were executed in this documentation-only investigation.
