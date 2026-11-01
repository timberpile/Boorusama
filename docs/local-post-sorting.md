# Local post sorting

Bookmark score sorting uses the score already present in the shared post
snapshot. Both score directions use local bookmark ID as the stable tie-breaker;
list results and group cover previews use the same comparator. Existing upload,
bookmark-date and random modes are unchanged. New enum choices are appended.

The Feed search/filter input is always present and uses “Search Cached...”. A
compact Cached indicator appears only while a committed query, source filter or
nondefault local sort restricts results to retained snapshots. Draft text alone
changes neither scope nor requests. Newest is the default and allows remote
History pagination; there is no Clear or Feed Order sort mode. Returning to
Newest preserves other active conditions; clearing every condition restores
normal History without a separate badge.

Feed and Bookmark controls use the same sort labels/icons and measured floating
header behavior: downward scrolling hides the bar and a small upward movement
reveals it. A single available source hides the redundant selector; an unavailable
active source remains explicitly recoverable without broadening results.

Missing or malformed legacy scores use zero; this is a deterministic fallback,
not a claim about the upstream score. Known dates precede missing dates. Cached
Feed score ties use newest known upload date, then descending post ID and full
feed identity, matching the ordinary feed merge. Sorting changes no persisted
snapshot or query and requests no post metadata.

The accepted Variant A uses two compact rows below the Feed AppBar: cached search
and its committed tags, followed by the direct sort/source/action controls. Only
an active local projection shows Cached. The theme surface keeps these floating
controls readable over thumbnails. The latest successful check appears as a
compact relative AppBar timestamp with full-date tooltip and semantics; no
permanent Last Checked row is reserved.

The cache projection resolves each upload timestamp once before sorting. A local
host diagnostic with 10,000 snapshots, one warm-up and five serial measured runs
found a median of 31.9 ms for tag filtering plus Newest sorting, versus 343.3 ms
for the preserved pre-correction comparator. Score sorting measured 33.8 ms
versus 295.4 ms. These Flutter host test measurements identify synchronous sort
work; they are not Android frame-time or live-service latency measurements.
Production Feed tests separately assert that cached filtering and sorting do not
request remote history and that restoring normal Newest mode allows it again.
