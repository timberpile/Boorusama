# Pinned searches

Pinned Searches is an app-local, manually refreshed list for the active booru
profile. It is independent of server-owned saved searches. The list and its
navigation badge read cached state; opening the list or changing profiles does
not fetch posts. Cached thumbnail loading uses `BooruImage` with the owning
profile's authentication and image fallback.

The approved requirements are in the [design](superpowers/specs/2026-09-14-pinned-searches-design.md)
and the task-by-task [implementation plan](superpowers/plans/2026-09-14-pinned-searches.md).

## Storage and ownership

`SearchSubscriptionRepository` is the persistence boundary. Each subscription
is one record in the `pinned_search_subscriptions` Hive box, including its
definition, checkpoint, unread count, up to four previews, and recent post
identities. A refresh writes that aggregate once so these fields cannot be
split across separate refresh writes. Repository mutations are serialized;
ordering reads wait for pending mutations.

A subscription belongs to exactly one `BooruConfig.id`. Post IDs are meaningful
only within that ownership. Duplicate detection collapses surrounding and
repeated query whitespace within the profile, without changing case or term
order. The executable query keeps its original content after outer whitespace
is trimmed, and cannot be edited after pinning. Renaming and reordering retain
runtime state. Blank custom names persist as `null`, so the label falls back
to the stored query.

Unread counts are independent of cached previews and recent identity retention.
Dropping an old identity or preview does not reduce unread. The identity window
is bounded by upload time at the next checkpoint's overlap boundary, rather
than by the four-preview presentation limit.

## Baseline, new, and read

Pinning saves and publishes the definition before attempting its initial
snapshot. The first successful snapshot validates the first result page,
caches up to four distinct newest posts, and sets a checkpoint with zero unread.
If this attempt fails, the saved pin remains; its first later successful
explicit refresh still establishes a zero-unread baseline.

A later refresh counts a matching post only when its upload timestamp is
strictly after the previous successful checkpoint and its ID is not already
known in the recent identity window. Posts uploaded at the checkpoint, or old
posts that start matching after metadata edits, do not count. One post matching
several subscriptions contributes once to each subscription; the active-profile
navigation badge sums those counts rather than deduplicating across searches.

Opening a pin awaits an atomic mark-read mutation before passing the unchanged
query to the normal search route. A failed mark-read keeps the user on the
management page. A refresh committing afterward may add newly discovered
unread posts. Refresh commits reload the current aggregate, preserving a rename,
reorder, or mark-read performed while the request was in flight.

## Chronological refresh

`SearchRefreshService` resolves the owning profile's existing `PostRepository`
and the `SearchRefreshQueryAdapter` exposed by `BooruRepository`. The service
records its UTC start time before planning or fetching; only a complete scan
advances the checkpoint to that time.

The current default adapter preserves ordinary queries and rejects `order`,
`order_by`, or `sort` metatags using either `:` or `=`. This includes explicit
chronological ordering tokens: the conservative default does not rewrite or
interpret their engine-specific values. An integration may override the
adapter to safely transform ordering or add a native uploaded-after boundary,
while the stored query remains unchanged. The default does not add such a
boundary or emulate query semantics locally.

`ChronologicalSearchScanner` requests 50 posts per page and uses a five-minute
overlap before the old checkpoint. It validates non-increasing UTC upload
timestamps throughout every fetched page and across page boundaries, allowing
equal timestamps. Explicit `PostResult.hasMore` continuation metadata is
authoritative, including for engines whose fixed server page size differs from
the requested limit. Without it, a later check continues until the overlap
boundary, an empty/short page, or the reported last page. Reaching an access
cap while the reported total proves results remain is a pagination failure,
not successful exhaustion. Duplicate IDs across pages are returned once, and
only timestamps strictly after the actual checkpoint become new-post
candidates.

A nullable upload timestamp or an observed non-chronological response produces
an explicit unsupported result. No timestamp is inferred from the device clock
or post ID. Query, authentication, parsing, network, and pagination failures
record an attempt/error but preserve the last successful checkpoint, previews,
and unread count. A scan never commits its partial discoveries on failure.
Reliable tracking therefore depends on the integration supplying upload times,
newest-first results, and accurate pagination metadata.

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
Previews, recent IDs, unread counts, checkpoints, attempts, errors, and creation
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

## Deferred roadmap

Folders, automatic refresh, and combined feeds are deferred. Their intended
later behavior is recorded only in the design's [Deferred roadmap](superpowers/specs/2026-09-14-pinned-searches-design.md#deferred-roadmap).
