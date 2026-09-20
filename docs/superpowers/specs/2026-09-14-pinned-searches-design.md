# Pinned Searches MVP Design

## Summary

Pinned Searches lets a user save a normal post search for one configured booru
profile, refresh it manually, and see whether matching posts were uploaded
since the previous successful refresh. Search cards show compact previews of
the latest posts. Unread badges appear on searches and the Pinned Searches
navigation entry.

The MVP performs no periodic, launch-time, resume-time, or operating-system
background refresh. All network work starts from an explicit pin or refresh
action. A later automatic scheduler will call the same refresh service.

This is an app-local feature and remains separate from server-owned features
such as Danbooru Saved Searches.

## Goals

- Save arbitrary non-empty searches for the active profile.
- Let the user provide an optional name while pinning.
- Establish a read baseline when a search is first pinned.
- Refresh one search or all searches for the active profile on demand.
- Count matching posts uploaded after the last successful check.
- Show cached previews and aggregate unread badges without network access.
- Reopen a pin through the existing normal-search flow.
- Leave a reusable search abstraction for later feed composition.

## Deferred roadmap

The following features are intentionally outside the MVP but are documented as
future phases so the MVP does not block them.

### Search folders

- Add profile-scoped, single-level folders; nested folders remain unnecessary.
- Extend the pin dialog with an optional folder selector, an Unfiled choice,
  and a create-folder action.
- Allow creating, renaming, ordering, and deleting folders and moving searches
  between them.
- Deleting a folder moves its searches to Unfiled, preserving their relative
  order, instead of deleting them.
- Show a folder badge equal to the sum of its searches' unread counts. A post
  matching multiple searches may contribute more than once.
- Add Refresh Folder. Its searches use the same oldest-successful-refresh-first
  ordering and bounded concurrency as Refresh All.
- Include folder definitions, ownership, membership, and ordering in backup;
  keep runtime preview and unread data disposable.

### Automatic refresh

- Add one global refresh interval rather than per-search intervals initially.
- Check subscriptions belonging to every configured profile, while the
  navigation badge continues to show only the active profile's total.
- Use the same `SearchRefreshService` as manual refresh; do not create a second
  execution path.
- Rank eligible work by oldest `lastSuccessfulCheckAt`, with never-refreshed
  searches first and stable subscription ID as the tie-breaker.
- Apply a global concurrency limit and a per-run request/time budget.
- Give failed searches retry backoff without changing their last-success time,
  preventing a failing search from starving the queue.
- Run overdue checks on application launch/resume and through best-effort
  platform background execution. The UI must not promise exact execution
  times, especially on mobile platforms.
- Report new posts only through in-app search, folder, and navigation badges;
  device notifications are not part of the planned behavior.

### Combined following feeds

- Keep each feed scoped to one profile.
- Let a feed reference existing user-pinned searches and own additional hidden
  search sources that do not appear in the Pinned Searches list.
- Extend the underlying subscription model with a purpose such as `pinned` or
  `feedSource` and an optional owning feed ID when this phase is implemented.
- Deleting a feed deletes sources it owns but never deletes independent pinned
  searches that it merely references.
- Merge cached source discoveries chronologically and deduplicate posts by
  profile-local post ID.
- Materialize and cache feed results so a feed with hundreds or thousands of
  sources opens immediately and refreshes incrementally.
- Shard compatible source checks where a booru supports safe OR queries, while
  retaining independent checkpoints and errors. Do not require a local
  reimplementation of booru query semantics.
- Expose freshness and partial-refresh state because large feeds will be
  eventually consistent rather than synchronously exact.

## Explicit exclusions

- Nested folders.
- Cross-profile folders, feeds, or result aggregation.
- Device notifications and notification permissions.
- Detecting old posts that begin matching because their tags, score, status, or
  other mutable metadata changed.
- Reimplementing booru query semantics locally.
- Synchronizing with server-owned saved searches.

## User experience

### Pinning a search

A loaded, non-empty normal search exposes a Pin Search action. Activating it
opens a dialog containing:

- an optional name field;
- Pin and Cancel actions.

The name is stored as nullable data. Blank or whitespace-only input becomes
null. The effective display label is the trimmed custom name when present and
the exact stored query otherwise. The query shown beneath a card is omitted
when it is already the display label.

Confirming the dialog saves the subscription immediately and starts its initial
snapshot. The search remains saved if that request fails.

### Initial snapshot

The initial snapshot is part of the user-initiated pin action. It fetches the
newest results needed for the compact preview, records a successful baseline,
and treats every result then known as read. Existing posts never produce an
unread badge.

If the snapshot fails, the subscription retains an error state and has no
successful checkpoint. Its first later successful manual refresh is another
baseline operation and also produces no unread count.

### Browsing and opening

The Pinned Searches page shows a flat list containing only the active profile's
searches. Opening the page never refreshes a search.

Each search card shows:

- its effective name;
- its query when a custom name is present;
- up to four newest cached thumbnail previews;
- its unread badge;
- its last successful refresh time and any current error state;
- actions to refresh, rename, reorder, and delete.

The navigation entry shows the sum of unread counts for the active profile
only. A post matching multiple searches contributes once to each matching
search and can therefore contribute more than once to that sum.

Opening a search atomically marks all results known at that moment as read,
then opens its unchanged stored query through the existing search page. A
refresh that discovers posts after the mark-read mutation completes may create
new unread results.

### Manual refresh

The user can refresh one search or every search in the active profile. Refresh
All starts searches in ascending order of `lastSuccessfulCheckAt`; searches
without a successful checkpoint start first. Stable subscription ID is the
tie-breaker. A small concurrency bound prevents request bursts. One search
failing does not stop the batch.

The UI exposes overall batch progress and attaches failures to their individual
searches. A second refresh request for an already-running subscription joins or
reuses the in-flight operation rather than starting duplicate network work.

## Meaning of new and read

A new result is a previously unknown post that:

1. matches the stored search on its owning booru; and
2. was uploaded strictly after the subscription's previous successful-check
   timestamp.

Old posts that later match because of edits or mutable metadata do not count as
new. Fixed historical searches may therefore never accumulate unread results.

The refresh service records its start time before network work. After a
complete successful scan, that start time becomes `lastSuccessfulCheckAt`.
The next scan uses a small overlap before the checkpoint to tolerate timestamp
precision and indexing behavior, while the actual newness comparison remains
strictly against the checkpoint. Persistent recent post identities prevent the
overlap from double-counting results.

A refresh advances its checkpoint only after it has completely scanned the
server result range newer than the old checkpoint. Network errors, parse
errors, authentication failures, unsupported queries, and pagination-limit
failures preserve the old checkpoint and existing preview data. Partial results
must not be committed as a successful refresh.

If a booru cannot supply or reliably constrain results by upload time, the
search remains pinnable but its refresh state reports that new-post tracking is
unsupported. Missing nullable post timestamps must be handled explicitly and
must never be guessed from the device clock.

## Data model

### `SearchSubscription`

```text
id: UUID
profileId: BooruConfig.id
name: String?
query: String
position: integer within the profile's flat list
createdAt: timestamp
lastAttemptAt: timestamp?
lastSuccessfulCheckAt: timestamp?
unreadCount: integer
lastErrorKind: network | authentication | query | pagination | parsing | other?
```

Every MVP subscription is user-pinned. Feed ownership and hidden-source fields
are added by the later feed migration, after their lifecycle is specified.
The `refreshing` state is transient provider state rather than persisted data;
after a process restart a search returns to idle while retaining its last
successful checkpoint and error.

The executable query is preserved. Identity normalization may trim surrounding
whitespace for duplicate detection, but must not reorder terms, change case,
or infer semantic equivalence. A profile cannot have two pinned subscriptions
with the same normalized query. Pinning an existing query edits or opens its
existing pin instead of creating a duplicate.

Queries are immutable in the MVP. A user changes a query by deleting the old
pin and pinning the desired search. Renaming or reordering a subscription
preserves its refresh and read state.

### `SearchPostPreview`

```text
subscriptionId: UUID
postId: integer
postCreatedAt: timestamp?
thumbnailUrl: String
sampleUrl: String?
discoveredAt: timestamp
```

Only a small bounded list, initially four items, is retained for presentation.
Preview records are disposable and are not sufficient for unread accounting.

### Recent identity window

The repository retains a bounded set of recent `(subscriptionId, postId)`
identities covering at least the configured checkpoint-overlap horizon. It is
used only to deduplicate overlapping refreshes. `unreadCount` is stored
separately so pruning preview and deduplication records never lowers a badge.

Post identity is profile-local. IDs from different profiles are never treated
as the same post.

## Architecture

### Repository

`SearchSubscriptionRepository` owns persistent subscriptions, previews, recent
identities, ordering, and aggregate mutations. Its interface is independent of
the concrete local database so supported platforms can use their established
storage backend.

Operations that change multiple records are logically atomic. This includes
pin creation, mark-read, refresh commit, reordering, and profile deletion. The
repository enforces profile ownership rather than trusting widgets.

### State

Manually declared Riverpod `Notifier` and `AsyncNotifier` providers expose
immutable application state and commands. Business rules remain in state
classes or services. Selectors provide search and active-profile badge totals
without making network requests.

### Refresh service

`SearchRefreshService` performs both initial snapshots and subsequent manual
checks. It resolves the current owning profile, asks a booru-specific refresh
capability for a chronological query, uses the existing post repository/client,
and commits one refresh result atomically.

The service accepts an explicit operation type:

- `establishBaseline`, which updates previews and the checkpoint with zero
  unread results;
- `checkForNewPosts`, which updates previews, recent identities, unread count,
  and checkpoint only after a complete scan.

### Booru capability

Chronological checking is a capability exposed by each booru integration, not
generic string concatenation in UI or state code. It is responsible for:

- retaining the original search constraints;
- overriding incompatible order or random operators when safe, or reporting
  the query as unsupported for refresh;
- expressing an uploaded-after boundary when supported;
- paginating newest-first until the old boundary is reached;
- preserving explicit server continuation metadata when page size alone cannot
  prove exhaustion;
- reporting unsupported cases explicitly.

The stored query is never rewritten. Opening a pin always uses the original
query and its original ordering.

## Persistence lifecycle and backup

Deleting a profile deletes all of its subscriptions, their preview and recent
identity data. There is no disabled or orphaned recovery state.

Backup includes pinned subscription definitions, names, queries, ownership
mapping, and relative ordering. It excludes previews, recent post IDs, unread
counts, checkpoints, attempts, and errors. Restore processes profiles first,
skips searches whose profile was not restored, and establishes a fresh baseline
only when the user next refreshes them. Legacy backups without Pinned Searches
remain valid.

Portable profile URLs omit user info, query, and fragment to exclude embedded
credentials. Their identity retains scheme/host/port/path, lowercases the host,
and removes all trailing path slashes idempotently. Use the same identity when
exporting, parsing, mapping restored pins, and comparing replacement profiles.

## Error handling

- Saving a pin and performing its initial snapshot are separate outcomes. A
  failed snapshot never removes the saved pin.
- Existing previews and checkpoints survive failed checks.
- Batch refresh returns per-search outcomes and continues after failures.
- Unsupported chronological tracking is distinct from temporary failure.
- Profile deletion wins over an in-flight refresh; a late result cannot
  recreate deleted data.
- Deletion invalidates in-flight work because refresh successes and failures
  recheck subscription existence and the captured immutable `createdAt` before
  writing. Successes additionally recheck the expected checkpoint. This prevents
  old work from contaminating a backup-restored pin that reuses the same UUID.
- Broken cached image URLs use the existing image fallback and never block
  opening or managing a search.

All user-facing labels and error messages use the existing i18n resources and
`context.t`.

## Testing

Tests focus on observable behavior and external integration boundaries:

- Pin dialog stores nullable names.
- Blank names fall back to the exact query for display.
- Initial snapshots populate previews and establish zero unread results.
- A first successful refresh after a failed baseline also produces zero unread.
- Later refreshes count only previously unknown posts uploaded after the prior
  successful checkpoint.
- Overlap windows and repeated responses do not double-count post IDs.
- Failed and incomplete scans preserve checkpoint, unread count, and previews.
- Opening resets known unread results without swallowing a refresh committed
  afterward.
- Queries are immutable; rename and reorder operations preserve refresh state.
- Navigation badge sums update after refresh, read, and delete.
- Batch refresh starts never-refreshed searches first and then oldest successful
  refresh first, while continuing past independent failures.
- Concurrent requests for one subscription share a single refresh operation.
- Profile deletion cascades and rejects late in-flight refresh commits.
- Backup round trips definitions and ordering but not disposable runtime state;
  repeated import is idempotent and legacy backup remains supported.
- Nullable timestamps and unsupported booru capabilities surface explicit
  states rather than false unread results.

Repository contract tests run against each supported storage implementation.
Booru-specific capability tests cover query transformation and chronological
pagination without mocking internal domain logic.

## Delivery phases

1. Domain values, repository contract, persistence, ordering, and
   profile-deletion cascade.
2. Refresh capability contract and manual refresh service with baseline,
   checkpoint, preview, and unread behavior.
3. Providers, derived badge state, routes, navigation, pin dialog, management
   page, and existing search-page integration.
4. Backup and restore, localization generation, focused tests, analysis, and
   full-suite verification.

Folders, automatic refresh, and combined feeds require separate approved
designs after the MVP is working and measured. Their intended behavior is
captured in the deferred roadmap above.
