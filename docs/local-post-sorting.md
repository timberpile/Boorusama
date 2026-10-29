# Local post sorting

Bookmark score sorting uses the score already present in the shared post
snapshot. Both score directions use local bookmark ID as the stable tie-breaker;
list results and group cover previews use the same comparator. Existing upload,
bookmark-date and random modes are unchanged. New enum choices are appended.

Cached Feed sorting is available only inside Feed Search. Choosing score or
upload-date ordering activates the existing local filter projection even with an
empty tag query, so history loading and feed initialization remain paused. It
sorts only the feed's retained snapshots, not previously paged remote history.
Closing Search resets the projection. Clearing the sort leaves any tag/source
filter intact; clearing all search conditions restores stored/history mode.
No sort operation requests post metadata, rewrites snapshots or changes the
persisted feed order.

Missing or malformed legacy scores use zero, consistent with the existing
shared-post legacy conversion. This is a deterministic fallback, not a claim
that the upstream score is actually zero. Known upload dates precede unknown
ones in either date direction. Feed score ties use newest known upload date,
then source host, engine, post ID and profile hint. These fallback identities do
not imply that IDs or scores are comparable across different sites.
