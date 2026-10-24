# Repository Performance and Scalability Audit — Second Pass

## Subsequent execution

This audit preserves preparation-era source findings and untested expectations.
See the [executed local review](performance_scalability_review.md) for actual
fixes, tests, paired work counts/timings and remaining acceptance limits on
`maintenance/scalability-delivery-review`. Deferred audit designs remain outside
the delivered implementation. The user authorized bounded, seed-stable random
group covers during review; historical random cover output is no longer required.

Date: 2026-10-23. Repository: `timberpile/Boorusama`.

## Scope, baseline, and evidence

Original and rechecked `develop`: **4129eae5d6b4d3947c7d2d878b49e7db9830a97c**.
The baseline has not advanced since the first audit. The existing task branch
`maintenance/repository-scalability-optimizations` already contained
**5668a9208d1933614c2ee2dc1cada134f57471dd**, `perf(following): isolate cached previews
from refresh activity`. This work preserves that commit rather than replacing
or claiming authorship of it. New commits are local, not published to GitHub.

This report extends and corrects the first audit. It retains all nine original
finding IDs so a reviewer can compare conclusions. Source inspection covered
shared Post/snapshot models, bookmarks/groups, Following refresh/history,
image cache/preloading, grid filtering, exports, bootstrap, download activity,
server-favorite imports, and selected engine paths, including Nozomi. This is
not a line-by-line certification of every platform or engine. AGENTS, local
implementation/design skills, development/issue workflows, and relevant subsystem
documents were consulted. Issues #58 and #75 are open and remain separate work.

**No application execution, formatter, analyzer, build, functional test, benchmark,
or device profiling was performed.** Python runner syntax was parsed without
executing it. Source blobs/tree hashes and Git diffs were inspected. All added
Dart/Python tests and workloads are **unexecuted**. Static reasoning is not proof
of compilation, runtime equivalence, or a measured performance improvement.

Evidence categories:

- **Confirmed structural inefficiency:** directly visible repeated work or retention.
- **Likely bottleneck:** strong source evidence, user-visible cost still unmeasured.
- **Potential optimization:** needs profiling or additional lifecycle evidence.

File references below identify exact paths and methods. Baseline source links
are pinned to 4129eae; candidate line references apply to the local code commit
7857c4e33ef0593313cba8b49762d551c40a06b7 before documentation. Do not substitute
historical performance numbers from repository handoffs for measurements of this
candidate. Numerical work counts below are derived expectations, not results.

## Executive summary

The largest remaining opportunities are still **avoiding whole-library work after
one source or row changes**, and **avoiding repeated work at pagination/cache
boundaries**. Following's full-feed materialization remains the highest-impact
large-library target. It needs coordinated repository and notifier changes, not
an isolated cache of mutable snapshot objects.

The prepared implementation intentionally takes smaller, reviewable steps:

1. Deterministic bookmark covers now visit indexed group members and keep only
   four candidates, rather than scanning the entire library and sorting the
   complete group. Random mode and malformed/non-indexed fallback stay unchanged.
2. Preload transport failures can reach the scheduling owner. Completion hints
   and failure suppression are bounded and expire; cancellation ownership is
   preserved. This removes permanent false completion and growing URL history.
3. Native cache byte reads validate and pin in one serialized queue entry.
   Payload I/O remains outside that queue; durable journal/checkpoint policy is
   deliberately unchanged.
4. Bookmark state publication exposes privately owned finalized lookup maps
   through read-only views, avoiding their second whole-map copies. It does not
   make a bookmark mutation constant-time.
5. The existing Following preview-isolation commit is retained. An additional
   regression test uses populated decoded image data rather than only empty
   preview state.

Two original proposals were narrowed after deeper review. A metadata-first feed
write alone can accept a durable source update and then encounter unrelated
corruption during the unchanged full publication reload; it is not a coherent
end-to-end fix. Identity-only feed memoization is also unsafe because nested
StoredPostSnapshot maps are mutable. Likewise, background checkpoint encoding
already exists: holding its owner queue is intentional crash-recovery behavior,
not proof that encoding blocks the UI thread.

Newly investigated concerns include Nozomi's repeated multi-tag index algebra,
per-event download history reconstruction, and complete server-favorite import
buffering. The latter preserves intentional reverse-save ordering and must not
be replaced by naïve immediate insertion.

## Revised ranking

Ranking is by expected user-visible benefit, conditioned on the affected
workload. Effort and regression risk are separate. No ranking is a measured
speedup claim. F10–F12 extend the original nine; source breadth/uncertainty lowers
their rank relative to more widely exercised shared paths.

| Rank | ID / finding | Expected impact | Confidence | Effort | Regression risk | Implementation status |
|---|---|---|---|---|---|---|
| 1 | F1 Following whole-library refresh/publication | Very high with many populated feeds | High structure; runtime unmeasured | High | High | Partial: inherited preview isolation retained; broad fix specified/deferred |
| 2 | F2 Cache queue and persistence coupling | High across media-heavy use | High mechanism; medium impact confidence | Medium–high | High for durability redesign | Partial: single-validation reads implemented, untested; journal redesign deferred |
| 3 | F3 History replays cached remote ranges | High when overlap/source count grows | High replay evidence | High | High, engine-dependent | Specified, not implemented; coordinate #58 |
| 4 | F4 Grid append recounts accumulated posts | High in long, blacklisted sessions | High | Medium–high | Medium–high | Specified, not implemented |
| 5 | F5 Bookmark mutation/group and state work | High in large libraries/groups | High structure | Medium–high | High for membership persistence changes | Partial: redundant map copies removed, untested |
| 6 | F6 Four covers require full group selection | Medium–high in large collections | High | Medium | Low–medium for deterministic selector | Partial: bounded selector implemented, untested; invalidation/random/GIF work remains |
| 7 | F7 Preload completion misclassification/retention | Medium broadly; high after errors/eviction | High | Low–medium | Medium, intentional retry policy | Implemented, untested |
| 8 | F8 Whole-directory initialization barrier | Medium–high with many cached files | High structure; medium impact confidence | Medium–high | High if recovery is weakened | Specified, not implemented |
| 9 | F9 Synchronous source encoding and capture retention | High during large exports; less frequent | High structure | Medium–high | High for consistency/security changes | Specified, not implemented |
| 10 | F10 Nozomi repeated full index algebra | Potentially high within that engine | High computation path; narrower coverage | Medium | Medium–high | Newly specified, not implemented |
| 11 | F11 Download progress reconstructs history | Potentially medium during large transfers | High local cost; lifecycle impact not fully established | Medium | Medium | Newly specified; needs event/retention profiling |
| 12 | F12 Server-favorite import buffers full listing | Potentially high memory for huge imports | High retention; intentional semantics | Medium–high | High for order/cancellation changes | Investigated; defer unless heap evidence justifies staging |

## F1 — Following refresh and publication

### Revalidated path and cost

`lib/core/search/following_topics/src/services/search_refresh_service.dart` creates
snapshot payloads and calls `HiveFollowingTopicRepository.commitRefresh` in
`src/data/hive/following_topic_repository_hive.dart`. The repository calls
`_feeds()` before identifying the enabled feeds referencing the changed source.
`_feeds()` materializes every matching stored feed row. In `src/types/topic_feed.dart`,
`TopicFeed.fromJson` reconstructs post snapshots and
`feedPostSnapshotFromJson` validates current-format rows by decoding a Post.
Affected feeds are merged, sorted, serialized, and rewritten as complete rows.

`FollowingTopicsNotifier._refresh` then reaches its `finally` publication path:
`_serialize(() => _reload(repository))`. `_reload` reads all topics, feeds, and
organization. The notifier's serialization uses the shared data mutation
coordinator also used by bookmarks. Thus full publication work can extend an
otherwise unrelated bookmark's queue wait. Hive values can already be in memory;
this is not an assertion of one physical disk read per decoded record.

For R source refreshes and C cached feed records, repeated materialization is
approximately O(R*C), multiplied by snapshot/tag payload size. Per affected feed,
merge/sort and serialized-row write cost remain additional. Empty incoming lists
still enter merge/write, but initialization markers, provenance pruning, or
other feed metadata may legitimately change; an unconditional empty-input return
would be incorrect.

Sources: [repository](https://github.com/timberpile/Boorusama/blob/4129eae5d6b4d3947c7d2d878b49e7db9830a97c/lib/core/search/following_topics/src/data/hive/following_topic_repository_hive.dart),
[notifier](https://github.com/timberpile/Boorusama/blob/4129eae5d6b4d3947c7d2d878b49e7db9830a97c/lib/core/search/following_topics/src/providers/following_topics_notifier.dart),
[feed model](https://github.com/timberpile/Boorusama/blob/4129eae5d6b4d3947c7d2d878b49e7db9830a97c/lib/core/search/following_topics/src/types/topic_feed.dart).

### Existing mitigation and correction

The inherited 5668a920 commit adds `_feedPreviewIndexProvider` and semantic
`.select` inputs to `feedMemberPreviewProvider`. Progress publications retain the
same posts/previews lists, so the derived index and decode future can be reused.
This removes one secondary amplifier, not the repository's full materialization.
The preview path is cache-only; neither the first nor second audit establishes
repeated preview network downloads from progress changes. The current numeric-ID
preview index and same-profile eligibility are preserved, not generalized to
mixed-source identifiers in this patch.

Do not memoize decoded feeds solely by raw map identity: `StoredPostSnapshot`
contains mutable common/custom maps. An external mutation or import can leave
an identity-keyed cached result stale. A reliable mutation revision and immutable
ownership contract are prerequisites.

### Concrete remaining change

Make repository refresh return a committed result containing the accepted topic,
changed feed snapshots, and a publication revision. Inside the existing
serialized repository boundary, read metadata to identify affected feed IDs,
validate/decode those rows, and keep the same rollback order. The notifier applies
that delta under its existing publication boundary; it must not perform an
unrelated full `getFeeds()` afterwards. Keep full authoritative reload for imports,
recovery, replacement, and ambiguous failures. Validate unaffected storage at an
explicit loading/recovery boundary, not accidentally after an accepted write.

Decide and test how unrelated malformed feed data is surfaced. A draft selecting
metadata before decoding was intentionally not committed: it would change the
write's failure semantics while the notifier could still fail on the subsequent
all-feed reload. This requires one coordinated design, not a locally faster
repository method that leaves the user-facing operation inconsistent.

Only then add revision-keyed materialization reuse and no-op feed-write detection.
Compare complete semantic results including initialization/provenance, not just
incoming post count. Reuse the existing metadata API rather than a second store.

### Invariants, risk, and validation

Preserve accepted-source durability, checkpoint/revision guards, cancellation,
per-source NEW state, disabled-feed behavior, mixed-profile identity, ordering,
legacy snapshots, provenance, and rollback across multiple feed writes. Do not
hold the global mutation lock over network/backoff. No intentional storage or
refresh semantics change is included here.

Added `feed_preview_populated_test.dart` asserts a decoded cached PNG survives
progress changes without extra cache reads or requests, and that real preview
publication invalidates it. It is unexecuted. `feed_materialization` provides an
identical baseline/candidate decoder probe; it does not measure a full refresh.
For the future broad fix count decoded feed rows/snapshots per accepted source,
complete-row writes, and mutation-boundary duration. Include no-change refresh,
one affected feed among many unrelated feeds, cancellation before commit,
partial-write failure, corrupt unrelated/affected rows, import while queued,
and source/profile revision change.

**Status:** inherited partial production optimization, one new unexecuted
regression test; storage/publication redesign not implemented.

## F2 — Cache queue coupling and redundant byte-read validation

### Revalidated path and cost

`CacheUsageImageProvider.resolveStreamForKey` submits an unawaited touch before
resolution. `DefaultImageCacheManager._recordUse` journals recency;
`ImageCacheIndex._append` appends with `flush: true`. After 128 journal records,
`checkpoint()` snapshots the complete index and awaits its worker and publication
while the owner queue stays held. E index entries and J journal changes imply
approximately O(floor(J/128)*E) checkpoint input work plus J flush operations.

The worker already removes JSON encoding/writing from the caller isolate.
Queue-wait wall time is not UI-thread CPU time. A decoded RAM image handoff need
not await its touch; subsequent cache-dependent operations can still queue behind
that bookkeeping. The historical repeated full-cache eviction sorts are already
replaced by incremental accounting/LRU and are not a current finding.

Sources: [manager, `_run`, `_recordUse`, byte reads](https://github.com/timberpile/Boorusama/blob/4129eae5d6b4d3947c7d2d878b49e7db9830a97c/packages/cache_manager/lib/src/image_cache_manager.dart#L300-L405),
[index](https://github.com/timberpile/Boorusama/blob/4129eae5d6b4d3947c7d2d878b49e7db9830a97c/packages/cache_manager/lib/src/image_cache_index.dart),
[decoded-hit touch wrapper](https://github.com/timberpile/Boorusama/blob/4129eae5d6b4d3947c7d2d878b49e7db9830a97c/packages/extended_image/lib/src/cache_usage_image_provider.dart).

### Implemented smaller change

Commit **1e312d2de96715ff93d7cf0b36486f9c0460e3b7** changes only the native manager
and adds tests. `getCachedFileBytes` previously validated in its RAM-probe queue
entry, then validated again in `acquireFile`. It now validates once and either
returns RAM bytes or pins the generation through `_pinForRead` in that same queue
entry. The helper is also used by explicit file-lease acquisition. Payload reads,
RAM publication checks, and lease release retain their existing boundaries.

Expected work removal: native disk hit, two validations to one and four queue
entries to three; miss, two lookups/queue entries to one. RAM hits remain one.
No journal flush, checkpoint policy, cache format, recency definition, or quota
change is claimed. Candidate manager lines 331–416 contain the affected path.

### Behavioral comparison

The lookup now linearizes at its first validation/pin. An accepted in-flight read
can finish from a retired pinned generation if clear occurs afterwards; it cannot
repopulate RAM because the current-path check remains. Conversely, a first lookup
that misses no longer waits for a second lookup that might observe a concurrently
committed new file. That is an intentional narrowing of an optional cache probe,
not a loss of durable data. A later request can read the new generation; existing
admission deduplication remains. External file deletion/read failure still yields
a miss and releases the lease. Web's separate manager is unchanged.

The internal byte-read path no longer increments the separate `cacheAcquireFile`
span via the public method. Compare `cacheRead`, lookup, queue and journal counts,
not raw acquisition-span counts as though instrumentation were unchanged.

### Remaining proposal and risk

Separate coalescible recency hints from structural metadata durability. First
update in-memory use immediately, batch repeated recency persistence, and define
explicit crash behavior for unflushed use information. Keep admission/removal
metadata guarantees. Concurrent checkpoint publication would require explicit
revision/journal-generation rotation: simply releasing the existing queue can
lose records or deadlock and is rejected. This high-risk redesign is deferred.

Added tests cover disk/RAM reads, missing/truncated/expired payloads, payload-read
failure, and per-key/all-cache clear while a controlled read lease is active.
All remain unexecuted. The prepared cache workload uses real disposable files,
separate recorder probes, and uninstrumented timings. Local validation must run
all cache-manager and extended-image tests, including checkpoint failures,
restart recovery, pinned eviction, zero/oversized retention and clear epochs.
Paired Android recordings must distinguish queue wait from build/raster timing.

**Status:** smaller structural optimization implemented, untested; main journal
contention recommendation deferred for durability design.

## F3 — Feed history replay

`FeedHistorySession.load` returns cached recent page one without transport, then
starts every source cursor at remote page one when older results are needed.
`_CachedFeedGridState._createHistory` requests 20 items per source page and builds
its query with `after: null`. The session consumes/deduplicates already retained
results and skips posts newer than the oldest cached result before publishing
older results. Its in-memory cursors and loaded-page cache are discarded when
the session ends. This is directly identifiable redundant network work, not
merely a slow sort.

[Session](https://github.com/timberpile/Boorusama/blob/4129eae5d6b4d3947c7d2d878b49e7db9830a97c/lib/core/search/following_topics/src/services/feed_history_session.dart),
[caller](https://github.com/timberpile/Boorusama/blob/4129eae5d6b4d3947c7d2d878b49e7db9830a97c/lib/core/search/following_topics/src/pages/topic_feeds_page.dart),
[query capability](https://github.com/timberpile/Boorusama/blob/4129eae5d6b4d3947c7d2d878b49e7db9830a97c/lib/core/search/following_topics/src/refresh/search_refresh_query_adapter.dart).

Requests grow with the cached overlap per source divided by the actual source
page size. The often-cited example of 1,000 overlapping posts / 20 requested
items = 50 pages is an illustrative operation count, conditional on server
responses/order, not a measured latency. The merge loop additionally sorts S
available source heads for each consumed candidate, roughly O(C*S log S).
Prioritize avoiding replay over that secondary CPU improvement.

Concrete proposal: add a distinct older-history capability at the engine/query
adapter boundary, returning validated keyset/cursor semantics where supported.
Persist per-source resume/exhaustion metadata with query, profile/site and runtime
revision fingerprints. For page-only engines keep an overlap/revalidation
fallback rather than trusting a stale page number. A request failure, filtered
empty page, permission restriction, or API pagination cap is never proof of
history exhaustion. Coordinate [#58](https://github.com/timberpile/Boorusama/issues/58),
which addresses confirmed end markers, without claiming it alone eliminates all
non-exhausted overlap replay.

Preserve chronological merge/ties, origin identity, result completeness, failed
source isolation, and cancellation. A source-head heap is a later O(log S) merge
improvement, not permission to reorder results. No universal `id:<...` or date
metatag is introduced. Existing refresh adapters do not prove such support.

Local verification: instrument physical source-page requests, identities skipped,
first older visible result, and cursor advancement. Use one/many sources, cached
and cold feeds, equal timestamps, overlapping sources, sparse/deleted posts,
reopen, query/profile edits, failures/recovery, and confirmed exhaustion. A local
request fake can establish counts deterministically; live supported engines must
confirm cursor contracts before acceptance. Full persisted cursor migration and
round-trip tests are required if storage changes.

**Status:** specified, not implemented; engine-specific correctness and migration
risk outweigh a speculative static-only cursor change.

## F4 — Grid append revisits historical posts

`PostGridController.fetchMore -> _addAll -> _count(_items, rules) -> _filter`
reprocesses accumulated posts. Duplicate detection is already indexed and only
examines incoming candidates, but count payload extraction, counting and visible
list reconstruction are not append-incremental. Native counting uses
`Isolate.run`; payload construction remains on the caller. Web explicitly counts
inline. No blacklist rules avoids count/isolate work, not all visible-list work.

[Controller](https://github.com/timberpile/Boorusama/blob/4129eae5d6b4d3947c7d2d878b49e7db9830a97c/lib/core/posts/listing/src/widgets/post_grid_controller.dart),
[duplicate tracker](https://github.com/timberpile/Boorusama/blob/4129eae5d6b4d3947c7d2d878b49e7db9830a97c/lib/core/posts/listing/src/widgets/post_duplicate_checker.dart).

For p pages of b accepted posts, total revisits are b*p*(p+1)/2. Multiply by rule
and tag-expression evaluation cost. Immutable visible-list publication may remain
O(N) even after incremental predicates; do not promise fully constant-time append.

Concrete design: retain accepted incoming items as an append delta; tag counts
are accumulated per current rule generation. Compute only the new payload while
rules are unchanged, merge match sets, and append the newly visible suffix.
Full refresh, rule/profile changes, reordered/replaced content and removals must
explicitly reset or rebuild appropriate indexes. Keep source-aware identities.

First introduce/request-test one generation fence shared by refresh, fetch-more,
page-mode changes, and asynchronous filtering. Existing refresh coalescing is not
proof that an in-flight `fetchMore` cannot cross a refresh; the inspected controller
has separate state paths. Caller behavior may mitigate individual cases, but a
new incremental cache must not depend on an unproven race assumption.

A tempting alternative—union every hidden ID on each filter pass—is not universally
better. With dense overlapping rules and early matches, the current short-circuit
loop can inspect less than a full union. It is not committed without workload
comparison. Preserve counts for toggled rules, duplicate modes, errors, empty but
non-final server pages, viewer append/fetch-more futures, and native/Web behavior.

Prepare deterministic controlled-request tests before the change: return old
load-more after a new refresh, change rules while count runs, remove/reorder
posts, and mix duplicate/blacklisted pages. Instrument payload records and rule
evaluations per append at multiple depths. Reuse grid count/filter spans, then
profile UI and allocation separately. The current six-workload harness does not
claim to measure incremental grid counting.

**Status:** specified, not implemented; synchronization/correctness prerequisite
comes before counting optimization.

## F5 — Bookmark mutation and publication costs

The develop tip already has tracked mutation deltas. Normal toggle paths do
**not** reload and decode every stored Post. `BookmarkMutationRepository`,
`_publishCommittedMutation`, retained row identities, hydration batching, and
covered-route refresh suppression are existing improvements and must remain.

Residual work: `_readMutationState` calls `getGroups`; group decoding rebuilds
membership sets. `removeBookmarksFromGroup` unions other memberships for orphan
checks. `BookmarkGroupRepositoryHive._write` sorts and writes a whole membership
list. `applyCommittedChanges` copies row indexes and traverses items when rows
change. A single operation can therefore scale with total memberships M, changed
group size m (including O(m log m) sorting), and library rows N.

[Notifier](https://github.com/timberpile/Boorusama/blob/4129eae5d6b4d3947c7d2d878b49e7db9830a97c/lib/core/bookmarks/src/providers/bookmark_provider.dart),
[service](https://github.com/timberpile/Boorusama/blob/4129eae5d6b4d3947c7d2d878b49e7db9830a97c/lib/core/bookmarks/src/services/bookmark_library_service.dart),
[group persistence](https://github.com/timberpile/Boorusama/blob/4129eae5d6b4d3947c7d2d878b49e7db9830a97c/lib/core/bookmarks/src/data/hive/bookmark_group_repository_hive.dart),
[state](https://github.com/timberpile/Boorusama/blob/4129eae5d6b4d3947c7d2d878b49e7db9830a97c/lib/core/bookmarks/src/types/bookmark_library_state.dart#L65-L280).

### Implemented allocation reduction

Commit **6196af5fe81d9149021258302a3aa02fe054085b** replaces the second
`Map.unmodifiable` copy of two privately constructed lookup maps with
`UnmodifiableMapView` in `applyCommittedChanges` and `withAddedGroupMembers`.
Their first ownership-isolating copies remain. No writer escapes those methods;
a future mutation first constructs fresh maps. This follows the existing
membership-map pattern. The public constructor keeps defensive copies of caller
input. Groups, rows, ordering, identity and persistence are unchanged.

This removes two redundant N-sized map copies for affected row-publication paths;
it does **not** eliminate the first copies, item traversal, group reconstruction,
or sorted group-row writes. It has no claimed percentage or measured heap gain.
Candidate state lines 115–119 and 270–279 are the changed publication sites.

Remaining proposal: track group mutations with returned committed group values
and explicit revisions; update only affected group indexes. Reuse the coherent
reverse-membership index inside the existing mutation boundary to check orphan
status for selected IDs, rather than unioning every other group's IDs. Keep
full repair/reload for external import/replacement and invalidated sessions.
Only consider per-membership storage after profiling remaining whole-group writes;
that migration has a larger compatibility cost than the current safe patch.

Required invariants: last-membership deletion, Default protection, Undo with new
local storage IDs, origin identity, retained earlier snapshots, membership counts,
failed writes/rollback, and import refresh. Added tests assert map immutability,
old/new snapshot independence, replacement, identity exchange/new-ID lookup,
caller-list mutation isolation and no-op/group-only sharing. They are not a
substitute for existing service-level Undo/import tests and are unexecuted.

The publication workload measures one-row replacement over increasing N. Its
output counts are cardinalities, not allocation measurements. Local DevTools
allocation comparison must establish whether removing map copies is worthwhile;
existing bookmark mutation and server-favorite projection benchmarks should also
be rerun with group size and membership overlap varied independently.

**Status:** smaller allocation change implemented, untested; group/repository
incremental redesign remains specified.

## F6 — Bounded bookmark-cover selection

`BookmarkGroupBrowserPage` requests `selectBookmarkPreviews` for built cards;
that function previously called full `selectBookmarks(...).take(4)`. Group
selection traversed all `state.items` and sorted the matching group. Lazy slivers,
per-page preview memoization and covered-route suppression already mitigate the
number/frequency of calls. The first audit's cost applies to built cards/cache
misses, not every group on every toggle.

[Selector](https://github.com/timberpile/Boorusama/blob/4129eae5d6b4d3947c7d2d878b49e7db9830a97c/lib/core/bookmarks/src/providers/bookmark_group_selectors.dart#L16-L121),
[browser](https://github.com/timberpile/Boorusama/blob/4129eae5d6b4d3947c7d2d878b49e7db9830a97c/lib/core/bookmarks/src/pages/bookmark_group_browser_page.dart).

Commit **6d7527105e4ac54ee40f8d801b504daf9185da57** gives deterministic cover
selection its own bounded path. Group member IDs resolve through the existing
`bookmarksById`; All still traverses all items. Each candidate is compared against
at most four retained results. The existing full selector and bounded selector
share the exact comparator. Group work becomes O(m*4), memory O(4), rather than
O(N + m log m) plus full result lists. All becomes O(N*4), still not constant-time.

Local-ID ties break all deterministic comparator ties for ordinary indexed rows,
so group-set iteration order does not change the final four. If local rows are
unindexed or duplicate IDs reduce the index cardinality, use the old full path.
Random sort uses that old path too, preserving the exact seeded shuffle input.
Empty/missing groups and fewer than four entries remain valid. No thumbnail URL,
autoplay, quality, persistence or filter behavior changes are introduced.

The `bookmarkSelect.items` diagnostic reports candidate group size on the fast
path instead of whole-library size. This is a meaningfully narrower input count,
not a measured speedup; interpret comparisons accordingly. Added tests compare
all sort modes/views against the full selector across sizes, deterministic seeds,
equal/missing dates and multiple sites, plus malformed-row fallback and work
bounds. All are unexecuted.

Further opportunity: revision-based cover invalidation can avoid clearing covers
for unrelated library changes, but membership/content/sort dependencies must be
complete. Folder cards requesting one image should eventually use an explicit
limit with the same ordering. Random selection remains a deliberate cost.
[#75](https://github.com/timberpile/Boorusama/issues/75) covers GIF autoplay and
static preview URL selection; it is not implemented here and must remain a
separate issue branch. Do not download a GIF just to pause its first frame, or
silently lower ordinary still-image quality.

**Status:** deterministic selector implemented, untested; other sub-opportunities
remain recommendations. The group/all cover workloads provide exact comparative
results and work counts on both baseline and candidate.

## F7 — Preload completion hints and failed transports

`PreloadManager._preloadSingleUrl` historically classified normal Future
completion as success and retained the URL indefinitely. The production provider
called `ImagePreloader.preloadImage`, which catches transport errors. A failed
preload could therefore suppress future prefetch indefinitely. The provider is
not auto-disposed and URL history grows with distinct completions. Existing
bounded nearby planning, read-only history view, and cancelled-token ownership
checks already address other historical issues and are preserved.

[Manager](https://github.com/timberpile/Boorusama/blob/4129eae5d6b4d3947c7d2d878b49e7db9830a97c/lib/core/posts/media_preload/src/preload_manager.dart),
[production wiring](https://github.com/timberpile/Boorusama/blob/4129eae5d6b4d3947c7d2d878b49e7db9830a97c/lib/core/posts/media_preload/providers.dart),
[image preloader](https://github.com/timberpile/Boorusama/blob/4129eae5d6b4d3947c7d2d878b49e7db9830a97c/packages/extended_image/lib/src/image_preloader.dart).

Commit **2aba98c9ea87f67c392374797b4996dc32b4c011** opts the scheduling owner into
transport-error propagation. Other direct callers retain the best-effort default.
The manager owns two capped histories: 256 completion hints with a 30-second TTL,
and 256 failure hints with a five-second retry delay. Monotonic elapsed time is
injectable for deterministic tests. Expiry/capacity pruning is incremental in
insertion/expiry order, not a full-history scan. A later existing plan, not a new
timer or background loop, initiates retries. Dispose clears hints and disallows
new dispatch.

Intentional behavior changes:

| Previous | New | Benefit | Risk / limit |
|---|---|---|---|
| Swallowed transport failure could become permanent completion | Owner observes failure; five-second suppression then a later plan may retry | Restore useful preloading after failure | Retry policy is new; verify network counts under repeated swipes |
| Success excluded a URL for manager lifetime | Completion expires after 30 seconds or capacity eviction | Bounded retention and eventual cache revalidation | A still-cached image can incur another cache probe/touch |
| Completion set grows with all successful URLs | At most 256 completion entries and 256 failure entries | Bounded URL bookkeeping | More than 256 distinct failures can evict suppression before five seconds |
| Disposed manager could be called again | Further planning is a no-op | Prevent stale-owner dispatch | Existing callers must not rely on reusing disposed managers |

A successful transport is **not** proof of retained disk admission. Optional
cache-write failure, disabled retention or oversized entries still follow
existing best-effort storage behavior. TTL makes the hint temporary; immediate
cache-clear invalidation is not added, so stale suppression can remain up to
30 seconds. This is a bounded compromise, not a claim of exact cache residency.

Cancellation concurrency remains token-owned: old cancelled completion/failure
cannot add a hint, release a replacement's slot, or prevent that replacement.
Existing per-manager concurrency and nearby strategy limits remain. No server
rate limits, media quality rules, profile routing or storage formats change.

Added controlled-time tests cover capacity, expiry via the real directional
strategy, failure cooldown, negative-history eviction, same-URL cancellation
races, duplicate URLs/concurrency, disable/dispose, and real ImagePreloader error
propagation through a fake Dio boundary. They are unexecuted. The synthetic
history workload compares retained cardinality and dispatch overhead; real Android
swipe, eviction/clear and failed-media tests must check requests and perceived
loading. Do not infer memory bytes from URL counts.

**Status:** implemented, untested, with explicit bounded retry/expiry policy.

## F8 — Cache initialization barrier

`DefaultImageCacheManager._initialize` loads metadata, lists payload files,
sequentially checks indexed file existence and length, checks orphans, restores
recency order, cleans scratch files, checkpoints, and trims before first cache
operation completes. Recovery without a valid index performs further metadata
reads. E files imply O(E) filesystem calls and O(E log E) recency sorting.

[Initialization](https://github.com/timberpile/Boorusama/blob/4129eae5d6b4d3947c7d2d878b49e7db9830a97c/packages/cache_manager/lib/src/image_cache_manager.dart#L110-L275),
[bootstrap](https://github.com/timberpile/Boorusama/blob/4129eae5d6b4d3947c7d2d878b49e7db9830a97c/lib/core/bootstrap/production_boorusama_bootstrap.dart).

This is principally first-cache-access latency, not every navigation and not
necessarily the whole app bootstrap. The explicitly enabled clear-on-startup
path is a separate awaited bootstrap operation. The F2 byte-read patch does not
alter this initialization barrier.

Preferred first implementation: gather per-file metadata through a small bounded
worker pool while initialization remains an exclusive barrier; reuse a single
stat result for type/size where semantics match. Apply state mutations and orphan
cleanup deterministically after validation. Do not launch an unbounded Future.wait
for every file, and do not publish partially accounted capacity. Only profile-
justified later work should consider demand validation or background orphan
cleanup, with conservative unknown-byte accounting and no writes admitted early.

Preserve corrupt-index recovery, external deletion/truncation, stale generation
cleanup, scratch ownership, restart LRU, metadata persistence recovery and quota
correctness. Test interrupted initialization, permission failures, repeated retry,
normal and no-index paths, pinned reads after readiness, and multiple requests
joining initialization. Compare equal byte totals at different file counts and
capture first-image readiness externally; manual in-app recording starts too
late for the entire cold-start interval.

**Status:** specified, not implemented because safe initialization scheduling
requires filesystem/recovery validation unavailable in this environment.

## F9 — Export encoding and retained captures

`ExportFlowNotifier.createExport -> ExportService.createPackage ->
LegacyJsonSourceAdapter.capture -> JsonBackupSource.encodeForExport` captures
selected sources into a list before the package writer consumes them. Handler
encoding and converter JSON encoding run synchronously after data retrieval.
`async` does not itself move CPU work off the caller isolate. Serialized source
strings accumulate with total captured payload B; encoding adds source-sized
intermediates alongside domain state.

[Service](https://github.com/timberpile/Boorusama/blob/4129eae5d6b4d3947c7d2d878b49e7db9830a97c/lib/core/backups/export_import/export/export_service.dart),
[JSON source](https://github.com/timberpile/Boorusama/blob/4129eae5d6b4d3947c7d2d878b49e7db9830a97c/lib/core/backups/sources/json_source.dart),
[writer](https://github.com/timberpile/Boorusama/blob/4129eae5d6b4d3947c7d2d878b49e7db9830a97c/lib/core/backups/export_import/package/export_package_writer.dart).

Existing file staging, streaming digest computation and atomic rename are good
mitigations. This is **not** a claim that the complete compressed ZIP is assembled
in memory. Nor does this inspection establish a global point-in-time capture
across all sources: per-source getters have their own coordination. A redesign
must identify that contract explicitly rather than inventing an existing guarantee.

Concrete proposal: capture immutable, source-appropriate data under the required
mutation boundary; encode sufficiently large pure-data payloads in a worker or
stream them to owned staging parts. Return staged-part descriptors/digests rather
than retaining every encoded string. The package writer then operates on those
immutable parts and retains its manifest and atomic-publication path. Do not send
Refs, repositories or callbacks to isolates. An adapter API change must account
for legacy JSON/clipboard/server exports as well as `.bsexport`.

Preserve credentials opt-in/sanitization, source selection, schema versions,
recommended import actions, integrity hashes, temporary cleanup and cancellation.
Worker transfer can itself duplicate memory; benchmark before making it mandatory
for small sources. Tests need semantic round trips, mixed-source selection,
concurrent mutations during capture, write/hash/rename failures, cancellation,
malformed import and credentials-omitted exports. Peak allocation/GC and scheduling
delay are the primary local metrics, alongside total export time.

**Status:** specified, not implemented; cross-source consistency and export/import
compatibility require local functional and memory validation.

## Additional findings

### F10 — Nozomi multi-tag index computation

`packages/booru_clients/lib/src/nozomi/nozomi_post_index.dart` handles single-index
range requests and multi-tag intersections/negative filtering. Multi-tag paging
can reconstruct sets/intersections over cached full indexes before selecting a
small page. `nozomi_memory_cache.dart` already bounds raw index storage (entry and
ID limits), applies expiry and deduplicates in-flight reads. Therefore the repeated
cost is identifiable index computation, **not necessarily another full download**.
The app's Nozomi provider also participates in physical API admission; a page's
Future.wait alone is not evidence of unlimited network transports.

[Index planner](https://github.com/timberpile/Boorusama/blob/4129eae5d6b4d3947c7d2d878b49e7db9830a97c/packages/booru_clients/lib/src/nozomi/nozomi_post_index.dart),
[raw index cache](https://github.com/timberpile/Boorusama/blob/4129eae5d6b4d3947c7d2d878b49e7db9830a97c/packages/booru_clients/lib/src/nozomi/nozomi_memory_cache.dart).

A query-result cache should key normalized positive/negative terms, order and
underlying index generations/expiry, with a bounded total retained-ID budget.
Reuse a result only while every contributing index is current. Independent TTLs
that silently extend stale raw data are unsafe. An alternative with less state
is to improve intersection ordering/representation first while preserving exact
query order. Verify negative-only queries and page continuity separately; this
audit does not claim their result semantics are already broken.

Measure cold and warm multi-tag pages with large indexes, sparse intersections,
negative filters and changing raw-index versions. Counters should separate index
fetches, IDs examined, allocated sets and per-post metadata requests. **Not
implemented**: narrower engine scope and cache invalidation semantics need focused
benchmarks before adding another retained result layer.

### F11 — Download progress aggregation

`DownloadTaskUpdatesNotifier.addOrUpdate` copies and linearly searches the group's
retained task list per event. `downloadActivitiesProvider` rebuilds activity
objects and reparses task metadata, then `DownloadActivityScope` indexes/scans
old/new activities and serializes notification work. Cost can grow approximately
with event count times retained task history. Immediate outcomes are separately
capped; do not describe every activity collection as unbounded.

[Ingress/state](https://github.com/timberpile/Boorusama/blob/4129eae5d6b4d3947c7d2d878b49e7db9830a97c/lib/core/download_manager/src/providers/download_task_updates_notifier.dart),
[projection](https://github.com/timberpile/Boorusama/blob/4129eae5d6b4d3947c7d2d878b49e7db9830a97c/lib/core/download_activity/providers.dart),
[consumer](https://github.com/timberpile/Boorusama/blob/4129eae5d6b4d3947c7d2d878b49e7db9830a97c/lib/core/download_activity/scope.dart).

The full app-wide retention/clearing schedule and actual native event frequency
were not established. Thus this remains a narrower, conditional bottleneck, not
an asserted always-on global regression. Proposed change: key task updates by
stable task ID with a separate ordering sequence, reuse immutable parsed metadata,
and publish per-task/group deltas. Coalesce intermediate progress, never terminal
completion/error/cancel transitions. Keep notification ownership/cancellation,
retry states and durable history semantics; don't silently truncate history.

Local tests should replay controlled high-frequency progress with thousands of
retained completed tasks, event reordering, retry and terminal states. Count copied
entries, metadata decodes and notification calls. **Not implemented** pending
lifecycle verification and evidence that event volume makes this worthwhile.

### F12 — Server-favorite import buffering

`ServerFavoriteFetchRunner.run` keeps fetched pages and a seen-identity set until
the server listing finishes, then saves pages and posts in reverse. This is O(N)
retention of full Post objects, with first-save delay until fetching completes.
It is intentional ordering behavior, not an accidental sequential-loop defect.

[Runner](https://github.com/timberpile/Boorusama/blob/4129eae5d6b4d3947c7d2d878b49e7db9830a97c/lib/core/bookmarks/src/server_favorites/fetch_runner.dart).

A future disk-backed page spool can preserve the same reverse traversal and
accepted-page durability while reducing live Post retention. Keep the seen-key
set or a bounded external identity index; serialize through the shared snapshot
codec, not a reduced model. Validate session/cancellation before each page and
inside the bookmark mutation queue. Delete only owned temporary spool files after
success, failure, cancellation and process recovery.

Test duplicate/overlapping pages, non-advancing pagination, final-page flags,
cancellation during fetch/save, disk exhaustion, profile deletion and exact saved
order. Compare peak heap on very large imports before accepting spool complexity.
**Deferred**: do not trade the existing order/retry contract for naïve immediate
insertion merely to reduce a buffer.

## Cross-cutting review and rejected shortcuts

No dependency, storage schema, backup format, shared Post model, localization,
engine request policy or UI layout changed. Cache and preloader changes interact:
expired completion hints can cause additional cache probes, and the byte-read
path makes reads cheaper but does not make touches/journaling free. Measure this
combination rather than adding hypothetical independent gains.

Bookmark lookup views and indexed covers interact through an immutable public
contract. Current maps are privately owned and finalized; future maintainers must
not mutate them after publication. The added snapshot-isolation tests guard that
contract. This ownership reasoning does not apply to arbitrary externally
supplied mutable snapshot maps, hence rejection of identity-only feed memoization.

Rejected/deferred shortcuts: releasing a checkpoint queue without journal
rotation; treating every empty remote page as exhaustion; inventing engine
cursor syntax; replacing seeded shuffle with unrelated random sampling; disabling
GIFs or reducing quality as a generic performance fix; removing API quotas; and
streaming favorite insertion in a different order. The raw-byte RAM cache is
bounded, so an unbounded-original-image-cache claim remains unsupported.

## Commit and implementation ledger

| Commit | Actual content | Verification status |
|---|---|---|
| 5668a9208d1933614c2ee2dc1cada134f57471dd | Pre-existing remote Following preview isolation | Preserved; not executed/revalidated at runtime here |
| cd658f32e2b20d23256f3744e823211f798248e0 | Six-workload identical-harness comparison infrastructure | New, unexecuted; Python syntax parsed only |
| 6d7527105e4ac54ee40f8d801b504daf9185da57 | Deterministic cover selector and regression tests | New, untested |
| 2aba98c9ea87f67c392374797b4996dc32b4c011 | Bounded/expiring preload hints and transport failure propagation | New, untested |
| 1e312d2de96715ff93d7cf0b36486f9c0460e3b7 | Single-validation cache byte reads and lease regressions | New, untested |
| 6196af5fe81d9149021258302a3aa02fe054085b | Avoid second copies of owned bookmark lookup maps | New, untested |
| 038f5753aab9a5498f436dbf3725d2cf37db404e | Populated preview/progress invalidation regression | New, unexecuted |
| 7857c4e33ef0593313cba8b49762d551c40a06b7 | Static-review follow-up: SDK prerequisite and explicit two-slot test fixture | New, unexecuted |

## Roadmap and validation order

**Highest impact:** measure and then implement coordinated Following deltas; next
address cache recency durability with an explicit crash contract. Work on
engine-specific history resume and generation-safe grid append independently.
Their priority is not reduced merely because they were not safe to implement
without execution in this environment.

**Prepared changes / quicker acceptance:** review cover equivalence and map
ownership, then preload failure/expiry/cancellation, then native byte-read lease
ordering. Run targeted tests and package suites before measuring. #75's static
GIF-cover policy can be pursued in its own issue branch without conflating it
with cover selection.

**Architectural follow-up:** group mutation revisions, bounded cache initialization,
and staged/worker export should follow isolated measurements. Do not introduce a
new database, generated Riverpod system or generic optimization framework.

Benchmark entry point: `benchmark/scalability/compare.py`; protocol and limits:
`benchmark/scalability/README.md`. It copies identical harness bytes into both
prepared worktrees, alternates order, captures structured records and fails closed
on incomplete runs. Its six cases do not automate every proposed architecture or
manual Android workflow. No result files or performance numbers are included.

Local review must execute all added tests, relevant existing consumers and complete
changed-package suites. Before integration, the final combined candidate needs
the complete regression required by AGENTS. Android/Maestro acceptance and profile/
release measurements are separate from automated functional tests. Benchmark
operation counts should establish removed work; repeated frame/latency/allocation
measurements must establish actual user-visible benefit. Any unrun, failed or
skipped checks remain explicit blockers, not assumed passes.

See [local handoff](performance_scalability_handoff.md) for exact setup,
commands, publication status, review priorities and acceptance criteria.
