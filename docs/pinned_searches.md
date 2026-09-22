# Pinned searches

Pinned Searches is an app-local collection of independent searches from all
existing booru profiles. It is independent of server-owned saved searches. The list and its
navigation badge read cached state; opening the list or changing profiles does
not fetch posts. Cached thumbnail loading uses `BooruImage` with the owning
profile's authentication and image fallback.

The approved requirements are in the [design](superpowers/specs/2026-09-14-pinned-searches-design.md)
and the task-by-task [implementation plan](superpowers/plans/2026-09-14-pinned-searches.md).
The later [bounded-refresh decision](work/done/PS-001-bounded-newest-post-refresh.md)
supersedes their exhaustive scanning and numeric unread-count requirements.

## Storage and ownership

`SearchSubscriptionRepository` is the persistence boundary. Each subscription
is one record in the `pinned_search_subscriptions` Hive box, including its
definition, refresh time, highest observed post ID, NEW state, up to four
previews, and at most 50 recent post identities. A refresh writes that
aggregate once so these fields cannot be split across separate refresh writes.
Repository mutations are serialized;
ordering reads wait for pending mutations.

A subscription belongs to exactly one `BooruConfig.id`. Post IDs are meaningful
only within that ownership. Duplicate detection collapses surrounding and
repeated query whitespace within the profile, without changing case or term
order. The executable query keeps its original content after outer whitespace
is trimmed, and cannot be edited after pinning. Renaming and reordering retain
runtime state. Blank custom names persist as `null`, so the label falls back
to the stored query.

The legacy Hive `unreadCount` field is retained for compatibility, but positive
values load as 1 and are displayed as NEW. No exact count is computed. NEW is
independent of preview and identity retention: dropping cached posts does not
clear it. Recent identities are limited to the newest 50 within a five-minute
upload-time window before the next checkpoint.

## Baseline, new, and read

Pinning saves and publishes the definition before attempting its initial
snapshot. The first successful snapshot caches up to four distinct newest
posts and sets a checkpoint without NEW. If this attempt fails, the saved pin
remains; its first later successful explicit refresh establishes that baseline.

A later refresh sets NEW when the fetched snapshot contains a post ID higher
than the highest ID observed by that search in earlier successful refreshes.
Upload timestamps do not affect NEW. The highest ID never decreases, including
after an empty snapshot. Existing searches without a stored ID boundary use
their next successful refresh to establish one without creating NEW. A search
card shows NEW; the navigation entry shows a dot if any independent pin owned
by an existing profile has NEW. Neither reports a total.

Opening a pin awaits an atomic mark-read mutation before passing the unchanged
query to the normal search route. A failed mark-read keeps the user on the
management page. A refresh committing afterward may set NEW again. Refresh
commits reload the current aggregate, preserving a rename, reorder, or mark-read
performed while the request was in flight.

## Bounded chronological snapshots

`SearchRefreshService` resolves the owning profile's existing `PostRepository`
and the `SearchRefreshQueryAdapter` exposed by `BooruRepository`. It records its
UTC start time before planning or fetching. A successful validated snapshot
updates the last-check time and highest observed post ID; it does not claim
exhaustive coverage.

`ChronologicalSearchScanner.scanSnapshot` requests only page 1 with a limit of
50 and inspects at most 50 returned posts, even if the server returns more. It
does not follow continuation metadata, access caps, totals, or old checkpoints.
Both the initial baseline and later refreshes use this same budget. Requests,
post processing, and retained identities stay bounded independently of the
number of matching uploads; server/network latency is outside that guarantee.
Raw repository fetches avoid enrichment requests for returned posts.

The scanner requires an upload timestamp on each post and deduplicates IDs.
It accepts the site's default post order, including small differences between
ID order and upload timestamps. A missing upload time produces an unsupported
result.
No timestamp is inferred from the device clock or post ID. A successful
snapshot replaces previews with its newest four posts; an empty snapshot clears
previews. Failures preserve the previous ID boundary, last-check time,
previews, and NEW state while recording an attempt/error. No partial snapshot
commits on failure.

This detects higher post IDs visible in the newest snapshot, rather than counting
or enumerating every upload since the previous refresh. If more than 50 matching
posts arrive between checks, NEW still appears when a higher ID is visible,
but the feed cache may miss some intermediate posts. Tracking assumes IDs rise
approximately with the site's default newest-first order. The scanner cannot
prove that the server returned every newest available post.

The current default query adapter preserves ordinary queries and rejects
`order`, `order_by`, or `sort` metatags using either `:` or `=`. This includes
explicit chronological ordering tokens: the conservative default does not
interpret their engine-specific values. An integration may override the adapter
to safely transform ordering while the stored query remains unchanged. Refresh
planning passes no uploaded-after filter so current previews remain available
when there are no new uploads.

Rule34 and Safebooru.org use site-specific XML post-list endpoints because their
JSON format can omit `created_at`, which previews and feed caches still need.
The Gelbooru v2 parser preserves the XML upload time, timezone offset, and total
result count while retaining JSON support for other sites. Totals and upload
times are not used for NEW detection.

Engine capability adapters and unsupported-profile explanations are tracked
separately in [PS-005](work/done/PS-005-engine-refresh-adapters.md).

## Manual batch and concurrent operations

The manually declared `SearchSubscriptionsNotifier` publishes immutable state,
serializes application mutations, and coalesces concurrent refresh requests for
one subscription. The network and chronological behavior remain in the refresh
service. Refresh All selects only the requested profile, starts never-checked
subscriptions first, then oldest successful checkpoints, with subscription ID
as the stable tie-breaker. A three-worker queue continues after individual
failures and publishes per-search outcomes and batch progress. Batch calls are
serialized; transient progress records its owning profile.

The repository rejects a successful refresh if the subscription was deleted,
its captured `createdAt` changed, or its expected checkpoint no longer matches.
Failure recording also checks existence and `createdAt`. This prevents an old
request from mutating a newly imported definition that reuses the same UUID.
Runtime deletion compensation preserves the original aggregate and creation
timestamp; backup import creates a new timestamp.

## Profile deletion and backup

Deleting a profile removes its complete subscription aggregates before removing
the profile. A failed profile operation compensates by restoring the captured
subscriptions. Both outcomes reload the subscriptions notifier immediately, so
lists and badges publish the final deleted or compensated state. Profile
replacement during restore also removes subscriptions for missing profile IDs
or IDs reassigned to a different booru type/portable URL; equivalent same-ID
profiles retain their pins. These cross-repository operations use compensation,
not a crash-atomic transaction across profile and subscription storage.

The `pinned_searches` and `following_feeds` backup sources run after profiles.
Each exports a separate JSON format with source-specific `source` and `version: 1`
headers. Pinned Searches exports independent pins, shared folders, Home order,
UUIDs, optional names, immutable queries, relative ordering, and profile
references. Following Feeds exports feed UUIDs, names, order, exact query lists,
and profile references. Internal searches used by feeds never appear in the
Pinned Searches export.
Previews, recent IDs, NEW state, checkpoints, attempts, errors, and creation
timestamps are excluded. Portable profile URLs retain scheme, host, port, and
path, lowercase the host, remove all terminal slashes, and strip user info,
query, and fragment to exclude embedded credentials. Export, parsing, mapping,
and profile replacement share this idempotent identity.

Restore first seeks the same profile ID with matching booru type and portable
URL, then a unique match by type and URL. Unmapped or ambiguous references are
skipped and counted. New definitions append after existing pins in imported
relative order; matching IDs or normalized queries reuse existing definitions,
making repeated import idempotent. Newly created definitions have no runtime
state and establish a baseline only on the next explicit refresh. Reused pins
retain their existing runtime state. Legacy backups without this source remain
valid.

ZIP restore defers profile-triggered restart until ordered sources and cleanup
finish. Device transfer retains its final restart prompt. A standalone profile
import keeps its restart behavior. Restarting inside the profiles source would
dispose the state needed to map the following pinned-search source.

## Organization and navigation

The [shared-folder design](superpowers/specs/2026-09-19-shared-pinned-search-folders-design.md)
supersedes the original profile-owned folders and profile-grouped list.
Named folders appear in manual order above Home's cards. Home has no heading;
`[Home]` identifies that destination in pin and move dialogs. Folder rows show
`N items`. Each card, including folder members, has an owning-profile footnote:
name when unique, URL when unnamed, and name plus URL when names are ambiguous.
Cached browsing does not activate another profile or fetch posts. Opening a
pin activates its owner before running the stored query and marks only that
pin read. Unsupported pins retain their per-search explanation.

Each card shows `Last post` on the same metadata row as its owner. The value is
the upload time of the newest cached preview from the last successful check;
rendering and sorting never fetch posts. A pin without a successful baseline
shows `Not checked`, while a successful empty snapshot shows `No posts`.
Refresh errors keep the prior cached value and remain visible.

The collection has session-only Manual order, Last post: newest first, and Last
post: oldest first views. The selected view is shared by Home and named folders
until the app restarts. Date views keep searches without an upload time last,
use manual order to break ties, leave folder rows in manual order, and disable
Move Up and Move Down. Switching back to Manual order restores the persisted
organization order unchanged.

Manage folders provides creation, renaming, manual ordering, and deletion.
Folder names are unique case-insensitively across the collection. Move to folder
lists Home and all named folders; Create folder creates the destination and
moves the selected pin only when the operation succeeds. Deleting a folder
requires confirmation and unpins every member, across profiles. Cancel leaves
both folder and pins intact. Empty folders also require confirmation.

One JSON Hive value, `search:organization`, stores ordered folders, each
folder's ordered independent pin IDs, and ordered Home IDs. Subscription
aggregates still own profile IDs, queries, and refresh state. Missing IDs are
pruned on read; independent pins absent from organization append to Home in
`(createdAt, id)` order. Hidden feed sources cannot join Home or folders.
Old experimental profile-folder rows are ignored; no migration is required.
Mutations are serialized. Folder deletion and profile compensation restore
captured organization and pins after ordinary storage failures; cross-box
operations are not crash-atomic. Removing a profile removes only its pins and
memberships, preserving shared folders and other owners' pins.

Folder NEW aggregates member pins. Refresh Folder resolves each member's owner
and query adapter, uses existing refresh priority and the shared request gate,
and does not change the active profile. Root Refresh All visits supported
profiles sequentially. Results remain separate per search.

Supported engines explicitly opt in to timestamp tracking; the repository
default is unsupported. Refreshes use each engine's default post order without
adding sorting terms or fetch options. The scanner requires upload timestamps
but tolerates small ordering differences between IDs and timestamps.
Nozomi remains unsupported because complete index intersection and per-post
fetches are not a bounded newest-page query. Unsupported profiles keep the tab
and pin action visible with a localized explanation. Routine check times are
available through Info; successful pinning is silent and errors remain inline
in their originating search view.


Widget tests that seed an AsyncNotifier before mounting the first frame should
use `tester.runAsync`; directly awaiting its future in the fake async zone can
wait for scheduled Riverpod work that has not yet been pumped. Text controllers
belong to dialog State so they survive the route's closing animation.

Automatic refresh defaults to enabled every five minutes. A search is eligible
only when its last successful check is strictly older than the interval. The
foreground coordinator checks eligibility on launch/resume, network recovery,
and every minute; it stops scheduling when inactive or paused. It accepts Wi-Fi
or Ethernet, and pauses on mobile-only, offline, or unknown connectivity. The
existing mobile-data preference controls downloads rather than general network
refresh, so it is not reused. Manual refresh remains available.

Each automatic run starts at most ten newest-page checks, sequentially with
one-second spacing, and starts no further checks after twenty seconds. An
already-started request may finish after that deadline or after pausing. The
budget counts search checks, not a universal HTTP count: engines may first
resolve tags. Never-checked searches precede the oldest successful checks;
failed checks back off for five, ten, twenty, then thirty minutes. Checkpoints
and cached results survive errors. No OS background worker is registered.

Following Feeds is a separate navigation feature. A feed belongs to one profile
and stores the IDs of the tracked searches that supply it. Search records have
no feed ownership in the domain model. Hive field 12, the former `feedId`, is
read only to migrate older feed records to `sourceIds`. An independent pin for
the same query has its own record and NEW state. One internal search may serve
more than one feed. Folder membership, pin lists, and pin badges exclude all
internal searches by looking at feed membership.

A user follows an existing tag, artist, or current search into one or more
feeds, or creates a named feed from that starting point. There is no empty-feed
creation or raw query editor. The all-profile feed list shows each owner's
profile caption. Artist Follow/Following shows how many feeds contain the exact
artist tag. Feed management lists its member searches for direct opening and
manual refresh.

Feeds use the same chronological scanner and foreground refresh scheduler as
independent pins. A feed has NEW if any member search has NEW. Opening it marks
only its members read; opening a member may also clear its feed's NEW. Adding a
new member checks that source directly and does not create NEW before that
search discovers new posts. Pinned Searches' Refresh All checks independent
pins only.

Changing a profile's engine or normalized site URL retains its feed definitions
and search queries but clears post caches, previews, NEW/error state, and refresh
checkpoints and highest observed IDs. The persisted runtime revision rejects
results from refreshes
started against the previous site without changing each search's creation time
or its position in Home. New refreshes for that profile pause while the cache
is reset and the profile update is saved. The reset is written first, so an
interrupted update cannot pair the new site with old cached posts. Display-name
edits and equivalent URLs keep the existing cache. If saving the new profile
fails, the previous cache is restored only after verifying that the persisted
site is still the old one. An interrupted update can leave that cache empty;
the feed rebuilds it through later source refreshes.

Each feed persists a chronological, deduplicated recent snapshot of at most 500
posts. Successful source snapshots merge into it; failures preserve the cache
and source status. Opening the feed renders this snapshot without a source
scan. Approaching the end starts a session-only chronological merge of older
pages from the member sources. Source pagination buffers and older post IDs are
discarded when the feed view closes. History loading starts after actual
scrolling; very short cached lists expose a Load older posts button. An empty
recent snapshot waits for foreground source refreshes. Older browsing may
require many network requests for a large feed, while opening its recent cache
remains immediate. The feed grid uses infinite scrolling regardless of the
global page mode. When new posts arrive during history browsing, the current
session stays in place until the user chooses Show updated posts. Failed page
loads keep their source cursor and offer Retry. Gelbooru OR batching and an OS
background service are
separate future work.

Each cached feed row stores the same versioned post snapshot used by bookmarks,
including common media data, origin identity, and engine-specific data. The
grid decodes those snapshots into the shared post renderer, and clicking a row
opens the ordered mixed-post viewer without fetching the posts again or
changing the globally active profile. Native engine cards and details remain
available offline when the snapshot and matching engine codec are available;
unsupported engine data stays in the sequence with cached media and generic
presentation. Near the end of the loaded posts, the viewer asks the grid to
load more history. Removing a source clears the recent
snapshot so posts exclusive to that source do not remain visible. Unchanged
source checkpoints persist. All refresh entry points share a three-request
concurrency gate; automatic work remains sequential.

Backup version 3 stores feed names and source query definitions, excluding
runtime cache and checkpoints. Restore creates internal source searches and
maps owners through the existing profile identity rules. Profile removal also
removes its feeds; failure compensation restores feeds, searches, and shared
organization. These cross-box writes are compensated on ordinary failures but
are not crash-atomic. Run `./gen.sh` after Hive adapter generation to restore
the engine registry and i18n output.

## Shared-folder backup and restore

Backup version 4 stores shared folder definitions and order, folder member
order, and Home order alongside portable profile references and independent
pin definitions. Empty folders survive restore. Imported IDs resolve through
the existing identity rules before memberships are rebuilt. Pin-only backups
append newly created pins to Home and preserve reused pins' destinations.
Old experimental profile-folder backups require no folder migration.

Unmatched pin or feed profiles require confirmation before skipping records.
Standalone restore obtains approval before writing pins, feeds, or folders.
ZIP and server transfer prepare selected sources and run this preflight before
any source imports, including profiles. Matching uses the selected backup's
profiles when present, otherwise current profiles. Cancel or headless import
with unmatched records aborts before writes. Approval is revalidated against
the actual profiles before pin execution; changed unmatched records abort.
