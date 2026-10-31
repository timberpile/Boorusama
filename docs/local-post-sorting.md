# Local post sorting

Bookmark score sorting uses the score already present in the shared post
snapshot. Both score directions use local bookmark ID as the stable tie-breaker;
list results and group cover previews use the same comparator. Existing upload,
bookmark-date and random modes are unchanged. New enum choices are appended.

The Feed search/filter input is always present and uses “Search Cached...”. Its
independent compact scope badge shows History in the ordinary mode, where older
remote history may load, and Cached while a committed query, source filter or
non-default local sort restricts results to retained snapshots. Draft text alone
changes neither scope nor requests. Newest is the default and does not pause
history; there is no Clear or Feed Order sort mode. Returning to Newest preserves
other active conditions. Clearing every condition restores History.

Feed and Bookmark controls use the same sort labels/icons and measured floating
header behavior: downward scrolling hides the bar and a small upward movement
reveals it. A single available source hides the redundant selector; an unavailable
active source remains explicitly recoverable without broadening results.

Missing or malformed legacy scores use zero; this is a deterministic fallback,
not a claim about the upstream score. Known dates precede missing dates. Cached
Feed score ties use newest known upload date, then descending post ID and full
feed identity, matching the ordinary feed merge. Sorting changes no persisted
snapshot or query and requests no post metadata.

The location of cached-only sort choices is still an open product decision
(#107). The existing selector is retained provisionally; this implementation does
not choose between it and Advanced Search/local conditions. The separate scope
badge and independent accepted corrections do not settle that placement.
