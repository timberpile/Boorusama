# Add Following Feeds

## Intent

Following feeds should feel like their own feature: users follow content from
the tag, search, or artist they are viewing, then browse combined chronological
posts. Pinned Searches are an implementation sibling, not part of the feed UI.

## Data and ownership

A feed belongs to one profile and stores ordered IDs of its tracked searches.
Each tracked search stores a query, owner profile, bounded check state and NEW
state, without a feed reference. A visibly pinned query has its own tracked
search even when a feed tracks the same query; its checkpoint and NEW are
independent. Existing `feedId` values in Hive are migration input only.
Deleting a feed deletes orphan internal searches, preserving any search used
elsewhere. The feed recent-post cache is a bounded, deduplicated, chronological
opening snapshot. Individual search refreshes merge their posts into every
referencing feed. A new member begins without NEW; it cannot set the feed NEW
until its later check discovers a new post.

## User flow

The main menu and desktop navigation have a separate Following Feeds entry.
The list includes all profiles and shows an owner caption on each feed. There
is no empty-feed action or raw query editor. The tag menu, search page, and
artist page offer a membership picker: add or remove the current query from
existing feeds of its profile, or create a named feed containing that query.
Artist membership uses exact single-tag query identity. The button shows
Follow or Following plus the number of containing feeds.

The feed management view lists member searches and lets a user open, refresh,
or remove each. Feed NEW is the OR of member NEW states. Opening the feed marks
only those members read; opening a member may clear feed NEW. An independent
visible pin remains unchanged.

## Fetch and history

Opening a feed renders the saved recent snapshot immediately. Foreground
refresh checks member searches in small batches, prioritizing never-checked and
oldest checks. A feed is eventually consistent; it does not imply every source
has finished refreshing. Older browsing is session-local and paginated, with
more work requested when the reader approaches the current end. The UI should
keep rendering while page requests progress and cap concurrent network work.
No OS background worker and no Gelbooru OR adapter are included here.

## Limits

The current cross-engine refresh relies on each integration's chronological
search support. A failed source retains its previous cache and NEW state.
The recent snapshot has a bounded size; older pages are discarded after the
feed view closes. Multiple sources can overlap, so posts are deduplicated by
post ID within the owning profile.
