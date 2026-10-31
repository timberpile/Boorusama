# Neighboring Series and Pool Bookmarks — Current Scope

Issue: [#68](https://github.com/timberpile/Boorusama/issues/68).
Branch: `feature/group-neighboring-series`.
Accepted scope corrected on 2026-10-31; earlier acceptance reports describe
superseded candidates and do not verify the current source.

## Search grouping

Ordinary Danbooru Search groups at least two confirmed members using a rolling
five-result lookahead in the filtered raw result order. After each match, inspect
the next five raw positions; another match extends the window. Keep the card at
its first member and preserve every intervening unrelated post as a separate tile.
The earliest unclaimed post starts a group. For overlapping memberships, choose
the Series with the most reachable members, then the lowest ID for a tie. Each
raw post belongs to exactly one display entry; window distances always use raw
positions, including already claimed posts. Membership is source/profile/auth
scoped; never infer it from artists, tags, generic Collections or parent links.

Use the existing Pool Gallery card with title, the first grouped post's thumbnail
and `Series · X/total` when this particular group's member count differs from the
authoritative total; otherwise `Series · total`. Distinct groups of one Series
have independent X counts. Unknown authoritative totals remain unknown. Tapping
opens the full Series under its source profile. Direct Series views and explicit
`pool:`/`series:` searches stay ungrouped. Selection exposes individual raw Posts;
long press selects the first grouped Post, and Select All uses the raw list.
Related Posts grouping is a separate follow-up, excluded from this change.

Display entries store every member's original index. Built entries retain their
identity, position and members. A frozen Series may extend through unbuilt posts
within its rolling window, including across page boundaries, but cannot consume
another built tile. Late metadata can group unseen entries only. Scroll anchors
map all collapsed member indices to the same card; selection uses original raw
indices. Query/profile/filter replacement invalidates the frozen projection.

Metadata admissions contain at most 40 posts, coalesce overlapping requests and
retain a 512-entry source/account-scoped cache. Initial page delivery still awaits
one bounded admission (ten-second timeout); it does not wait for full coverage.
This adds metadata latency to Search loading, but gives the initial projection
stable geometry. Timeout/failure shows ordinary Posts; late responses cannot
collapse built tiles. Moving this work entirely after delivery would need a
separate stable-placeholder design or accept permanently ungrouped built tiles.
Do not trigger an unbounded metadata scan to avoid this tradeoff.

When grouping underfills an infinite-scroll viewport, request at most three extra
ordinary pages per fill cycle, through the existing controller. Appended results
continue a frozen Series when eligible. Stop on failure, cancellation, refresh,
selection, exhaustion or budget exhaustion. Rebuilds and automatic completions
do not renew the budget. A manual page advance or fresh query/refresh starts a
new cycle; manual Load More remains available. Paginated mode and explicit
collection searches never use this automatic fill.

## Bookmarks and covers

Keep individual bookmarked Posts separate and perform no automatic membership
lookup in Bookmarks. Explicit Pool/Series references remain independent cards in
the same Bookmark Groups. Preserve group memberships, removal/Undo, downloaded
files, individual Posts, and compatible backups/imports. A reference never implies
that its remote members are bookmarked or selected.

Persist compact reference metadata and bounded tag coverage/upload extrema,
never a complete member snapshot database. The existing bounded summary indexer
and cached-tag filtering rules remain applicable; partial tag unions cannot prove
absence in all remote members. Unknown upload extrema remain unknown.

Persist only one selected static cover's thumbnail, sample, original and media
variants. Resolve it with the source's existing listing quality provider and
headers. Existing records lacking variants use the same bounded summary path as
a fallback without rewriting their identity or memberships. Preserve visibility
policy, blacklist/rating restrictions, and missing-profile isolation. Quality
changes do not change ordinary bookmarked Post thumbnail behavior.

## Verification

Verify actual Search routing, confirmed type/count, rolling-window/separated/overlapping
groups, selection, pagination, delayed metadata and stable anchors. Exercise the
live `malberrybush` search and record current data rather than assuming a Pool ID
or count. Keep individually saved Series members separate in Bookmarks. Cover
checks include old records, quality changes after persistence, mixed references
and Posts, source/account isolation, removal/Undo and backup round trips.

The branch is already rebased onto develop `de592828`. This continuation does
not authorize develop integration, PR creation, closure or branch deletion. Record exact commits and current-source
evidence in the branch handoff. Related grouping remains a separate follow-up.
