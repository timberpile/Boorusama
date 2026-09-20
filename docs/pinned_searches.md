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
definition, checkpoint, NEW state, up to four previews, and at most 50 recent
post identities. A refresh writes that aggregate once so these fields cannot be
split across separate refresh writes. Repository mutations are serialized;
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

A later refresh sets NEW when the fetched snapshot contains a matching post
whose upload timestamp is strictly after the previous successful checkpoint
and whose ID is not already known. Posts uploaded at the checkpoint, or old
posts that start matching after metadata edits, do not trigger NEW. A search
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
advances the checkpoint to that time; it does not claim exhaustive coverage.

`ChronologicalSearchScanner.scanSnapshot` requests only page 1 with a limit of
50 and inspects at most 50 returned posts, even if the server returns more. It
does not follow continuation metadata, access caps, totals, or old checkpoints.
Both the initial baseline and later refreshes use this same budget. Requests,
post processing, and retained identities stay bounded independently of the
number of matching uploads; server/network latency is outside that guarantee.
Raw repository fetches avoid enrichment requests for returned posts.

The scanner validates non-increasing UTC upload timestamps within the bounded
snapshot, allowing equal timestamps and deduplicating IDs. A nullable upload
time or observed non-chronological response produces an unsupported result.
No timestamp is inferred from the device clock or post ID. A successful
snapshot replaces previews with its newest four posts; an empty snapshot clears
previews. Failures preserve the previous checkpoint, previews, and NEW state
while recording an attempt/error. No partial snapshot commits on failure.

This detects new uploads visible in the newest snapshot, rather than counting
or enumerating every upload since the old checkpoint. Uploads that leave the
snapshot before a refresh, delayed indexing with older timestamps, or server
clock differences may escape detection. Tracking relies on actual upload times,
stable identities, and newest-first results from the integration. Validation
can reject observed bad ordering but cannot prove that the server returned the
newest available posts.

The current default query adapter preserves ordinary queries and rejects
`order`, `order_by`, or `sort` metatags using either `:` or `=`. This includes
explicit chronological ordering tokens: the conservative default does not
interpret their engine-specific values. An integration may override the adapter
to safely transform ordering while the stored query remains unchanged. Refresh
planning passes no uploaded-after filter so current previews remain available
when there are no new uploads.

Rule34 and Safebooru.org use site-specific XML post-list endpoints because their
JSON format can omit `created_at`. The Gelbooru v2 parser preserves the XML
upload time, timezone offset, and total result count while retaining JSON
support for other sites. Totals are not used for NEW detection. The `change`
field is not an upload time and must not be used for new-post tracking.

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

The `pinned_searches` backup source runs after profiles. It exports UUIDs,
optional names, immutable queries, relative ordering, and profile references.
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
`(createdAt, id)` order.
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
default is unsupported. Danbooru and Szurubooru add canonical chronological
query terms. Philomena receives created_at descending through raw fetch options.
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

## Shared-folder backup and restore

Backup version 4 stores shared folder definitions and order, folder member
order, and Home order alongside portable profile references and independent
pin definitions. Empty folders survive restore. Imported IDs resolve through
the existing identity rules before memberships are rebuilt. Pin-only backups
append newly created pins to Home and preserve reused pins' destinations.
Old experimental profile-folder backups require no folder migration.

Unmatched pin profiles require confirmation before skipping records.
Standalone restore obtains approval before writing pins or folders.
ZIP and server transfer prepare selected sources and run this preflight before
any source imports, including profiles. Matching uses the selected backup's
profiles when present, otherwise current profiles. Cancel or headless import
with unmatched records aborts before writes. Approval is revalidated against
the actual profiles before pin execution; changed unmatched records abort.
