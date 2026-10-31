# Pool and Series Bookmarks

**Status:** Agreed feature design for [Issue #68](https://github.com/timberpile/Boorusama/issues/68). Implemented and verified locally at runtime commit `54b633a9a`; see [acceptance evidence](../handoffs/continuation-2026-10-25-68.md). Develop integration and publication require explicit approval.

## Product model

- A Bookmark Group is one mixed, ordered grid of individually bookmarked Posts and bookmarked Pool references. Never add separate Post/Series tabs, a separate Series browser, or a second bookmark library.
- A Pool or Series bookmark represents the **remote collection**, not its member posts. Store the collection reference and a bounded metadata summary; do **not** persist a member list or snapshots of all its posts.
- Use the existing Danbooru Pool Gallery presentation (`lib/core/posts/pools/pool_grid_item.dart`): cover, title, category/collection treatment and whole-collection member count. Tap opens the full Pool/Series under its originating profile.
- Display a normal **Bookmark** control on Pool and Series detail views. Reuse existing Bookmark Group targeting and group-membership actions. Toggling the reference never silently bookmarks all member posts.
- Users can still select and bookmark loaded posts inside the Pool as they do today. There is no dedicated **Bookmark Posts** action, no hidden full-pool crawl, and Select All keeps its existing loaded-item scope.
- Deleting or moving a Pool reference changes only its own group memberships. Any separately saved member Post bookmarks, files, and other group memberships remain intact.

## Stable identity and persistence

Store a typed reference with sufficient information to reopen the Pool: the source database/verified host identity, profile/source hint, upstream Pool ID, category (Series or Collection), and ordinary local bookmark/group identity. Never assume that independent sites share pool IDs. Preserve auth isolation; never export credentials.

Cache compact display and filter metadata: title, cover, known total member count, aggregate tag set, tag-index coverage (`complete`, `partial`, `unknown`), time observed, and optional oldest/newest member-upload timestamps. An unavailable Pool remains bookmarked with its last safe metadata and an understandable error; offline availability of images must not be implied.

Backups/exports and imports must preserve typed references, local groups, metadata and referential integrity. Existing Post-only libraries remain compatible. An unrecognized future entry type must not be silently lost.

## Bounded member-tag indexing

At initial bookmark creation, inspect available member metadata within a **fixed, bounded request/member budget**; do not fetch member media. Ten members or fewer is a convenient small-Series case, but not a mandatory hard limit. If the entire collection fits the budget and visibility permits, union all member tags and record `complete`.

On large Pools, inspect only an allowed subset and any already available metadata. Never paginate thousands of items to build a tag index. Persist `partial` or `unknown` truthfully. No filtering action performs remote network requests or silently extends the index. An explicit user-requested refresh may recompute the bounded summary and replace stale tags.

### Local filter contract

**A Pool is filtered against the tags currently stored in its own index, even if coverage is incomplete.** Do not keep an otherwise nonmatching Pool visible just because unindexed members might match. Use the same local rule for positive and negative tags as ordinary bookmarks:

- All required tags must appear in the aggregate tag set. An absent required tag excludes the Pool.
- No excluded tag may appear in the aggregate tag set. An indexed forbidden tag excludes the Pool; an absent one does not, even on a partial index.
- Multiple required tags may come from *different* member posts. This is collection-wide union matching, not proof that one post has the whole conjunction.
- With no tag filter, partial and unknown Pools remain browsable as usual.

**Document the limitation in concise user-facing filter help:** “Pool filters use indexed member tags. Large or partially indexed Pools may not reflect every member.” Do not add a blocking dialog or a special always-visible group for partial Pools.

A tag union is not a substitute for individual member rating, blacklist or access restrictions. The visible cover and opened Pool must still enforce the originating profile's normal visibility policy. Stale aggregate tags must be replaceable, not accumulated forever.

## Upload date sorting

- **Newest Uploads:** sort a Pool by its newest member upload timestamp.
- **Oldest Uploads:** sort by its oldest member upload timestamp, when available. A known newest timestamp is an acceptable documented fallback if the older timestamp cannot be obtained cleanly; otherwise mark the value unknown.
- For a small completely indexed Series, calculate both extrema from the same transient member metadata. Do not store the membership list.
- For Danbooru larger Pools, verify bounded single-result requests such as `pool:123 order:created_at` and `pool:123 order:created_at_asc` (`limit=1`) to determine the two extrema without scanning the full Pool.
- Do not treat Pool metadata creation/update time, narrative order, first/last member ID or first/last gallery position as an equivalent upload timestamp.
- Cache timestamps. Sorting or building the Bookmark Grid must not cause an unbounded number of new requests. Handle inaccessible members and failed requests without inventing dates.

## Series-only visual grouping (scope corrected 2026-10-31)

Individual Post bookmarks remain separate. Do not resolve Series memberships or
automatically collapse posts in Bookmarks. Explicit Pool/Series references remain
independent selectable entries alongside individual Posts, with their existing
membership, removal/Undo, backup and import behavior.

Normal Danbooru Search groups adjacent runs of at least two Posts with confirmed
common Series membership under the same source/profile/auth context. Reuse the
Pool Gallery card and authoritative whole-Series count. Do not infer membership
from artists, tags, Collection pools or parent/child links. Preserve raw posts,
pagination and ordering. Entering selection exposes actual constituent Posts.
An explicit Pool/Series search and the Series detail view do not regroup.
Metadata work is bounded and coalesced; deferred metadata changes only unseen
entries so built viewport anchors remain stable.

Related grouping and its interaction remain OPEN. Inline expansion has not been
approved and is not implemented by this correction.

Cover metadata records only the selected static cover's media variants, allowing
existing source-specific listing quality resolution. Older saved references use
a bounded metadata fallback and keep their persisted identity and membership.
Individual Post thumbnails are unchanged.

## Verification and known limits

Check small Series, very large Pools, interrupted indexing, partial/unknown tag sets, positive/negative/multiple-tag queries, filter changes without network, both upload-sort directions, unavailable pools, mixed source profiles, existing and new group membership, backup round trips and migration. Verify the same card design in browsing and selection and the distinction between full remote count and locally selected Post count.

The indexing budget and the exact metadata provider implementation remain engineering details. Do not add a member-snapshot database, automatic synchronization service, arbitrary unbounded searches, a separate Series tab, or a new global Bookmark Posts action to solve them.

Related: [#68](https://github.com/timberpile/Boorusama/issues/68), [Series grouping exploration](https://github.com/timberpile/Boorusama/blob/feature/group-neighboring-series/docs/designs/2026-10-11-neighboring-series.md).
