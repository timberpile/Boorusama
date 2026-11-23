# Neighboring Series and Pool Bookmarks — Current Scope

Issue: [#68](https://github.com/timberpile/Boorusama/issues/68).
Branch: `feature/group-neighboring-series`.
Accepted scope corrected on 2026-10-31; earlier acceptance reports describe
superseded candidates and do not verify the current source.

## Search grouping

Ordinary Danbooru Search and Artist Posts (Newest and Popular) group at least
two confirmed members using a rolling
five-result lookahead in the filtered raw result order. After each match, inspect
the next five raw positions; another match extends the window. Keep the card at
its first member and preserve every intervening unrelated post as a separate tile.
The earliest unclaimed post starts a group. For overlapping memberships, choose
the Series with the most reachable members, then the lowest ID for a tie. Each
raw post belongs to exactly one display entry; window distances always use raw
positions, including already claimed posts. Membership is source/profile/auth
scoped; never infer it from artists, tags, generic Collections or parent links.

Use the existing Pool Gallery card with title and the first grouped post's
thumbnail. The compact badge shows the source logo, white type icon and
`X/total` when this particular group's member count differs from the authoritative
total; otherwise the total. Constrained badges fall back to total, then icon
only. Accessibility retains `Series · X/total` or `Series · total`.
Distinct groups of one Series
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

Metadata admissions contain at most 200 post IDs, independently of the configured
post request size, coalesce overlapping requests and retain a 512-entry
source/account-scoped cache. Search and Artist page delivery await metadata for
the supported loaded page in one request with the existing ten-second timeout.
Danbooru's separate Pool endpoint is requested with its maximum response limit of
1,000 Pool records. A saturated response is treated as unavailable rather than
caching incomplete membership; no additional metadata pages are crawled. This
prevents a partial initial admission from permanently freezing cached tail tiles before their
membership arrives. There is no full-Series or unbounded metadata crawl.

The 1,000-record maximum follows Danbooru's
[Pool controller](https://github.com/danbooru/danbooru/blob/master/app/controllers/pools_controller.rb)
and [default pagination limit](https://github.com/danbooru/danbooru/blob/master/app/models/application_record.rb).
The membership query accepts the supplied IDs as an array; 200 is the app's
supported loaded-page cap, not an asserted API input-ID maximum. Saved-reference
member sampling remains a separate bounded policy.

The wait adds metadata latency to page delivery. Timeout/failure still shows
ordinary Posts and late responses cannot collapse built tiles. Bounded viewport
admissions remain available for cache misses. Moving this work entirely after
delivery would need a separate stable-placeholder design or accept permanently
ungrouped built tiles. Actual live malberrybush ordering and a held tail response
reproduce the old 15-of-18 frozen-card failure; the regression retains all raw
results and resolves the later eighteen-member Series before displaying it.

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

The [2026-11-02 integration review](../handoffs/68-integration-review-20261102.md)
records reconciliation with current develop, final-candidate qualification and
actual Android acceptance limits. Related grouping remains a separate follow-up.
