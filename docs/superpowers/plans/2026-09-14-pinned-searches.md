# Pinned Searches MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add profile-scoped pinned searches with optional names, manual chronological refresh, cached four-post previews, and unread badges.

**Architecture:** Persist each pinned search and its bounded runtime data as one Hive aggregate behind `SearchSubscriptionRepository`, then expose it through a manually declared Riverpod `AsyncNotifier`. A reusable `SearchRefreshService` obtains a chronological query plan from the active booru repository, scans existing post pages through `PostRepository`, and commits baseline or unread changes atomically; UI and backup code consume only the repository/notifier contracts.

**Tech Stack:** Flutter, Dart, Riverpod `Notifier`/`AsyncNotifier`, Hive CE generated adapters, `fpdart` `TaskEither`, GoRouter, Equatable, UUID, existing i18n generator.

**Spec:** `docs/superpowers/specs/2026-09-14-pinned-searches-design.md`

## Global Constraints

- The MVP is fully manual: no periodic, launch-time, resume-time, or operating-system background refresh.
- The Pinned Searches page is a flat list; folders and folder fields are deferred.
- Searches belong to one `BooruConfig.id`, and deleting that profile deletes all of its pinned-search data.
- A blank custom name is stored as `null`; `displayName` falls back to the exact query.
- Opening a search marks all currently known results read before opening the unchanged query.
- Existing posts in the first successful baseline never count as unread.
- A successful later check counts only previously unknown posts with `createdAt` strictly after the prior successful checkpoint.
- Failed, incomplete, unordered, or timestamp-less scans do not advance the checkpoint or replace previews.
- Search queries are immutable in the MVP.
- All user-facing text must be added to i18n resources and accessed through `context.t`.
- Providers must be manually declared and use `Notifier` or `AsyncNotifier`; do not introduce provider code generation.
- Use `Equatable` for persisted/domain value equality.
- Treat every external value, especially post timestamps and backup JSON, as nullable and validate it explicitly.
- Use `fvm` for every Flutter and Dart command.
- In a fresh worktree, run `fvm dart pub get` from `packages/boorusama_cli` before the first `./gen.sh`.
- Do not implement any item from the spec's Deferred roadmap in this plan.

---

## File Structure

Create a new core feature at `lib/core/search/subscriptions/`:

- `types.dart`, `providers.dart`, `routes.dart`, `widgets.dart`: public barrels.
- `src/types/search_subscription.dart`: immutable subscription aggregate and display-name behavior.
- `src/types/search_post_preview.dart`: portable preview and recent-identity values.
- `src/types/search_refresh.dart`: refresh plans, outcomes, error kinds, and atomic commit input.
- `src/types/search_subscription_repository.dart`: persistence contract.
- `src/data/hive/search_subscription_hive_object.dart`: Hive persistence objects.
- `src/data/hive/search_subscription_repository_hive.dart`: serialized aggregate repository.
- `src/data/providers.dart`: Hive box/repository provider.
- `src/refresh/search_refresh_query_adapter.dart`: booru-facing query-plan contract and conservative default.
- `src/refresh/chronological_search_scanner.dart`: page traversal and chronological validation.
- `src/services/search_refresh_service.dart`: baseline/check orchestration and error mapping.
- `src/providers/search_subscriptions_notifier.dart`: application commands, in-flight coalescing, and batch refresh.
- `src/providers/search_subscription_selectors.dart`: active-profile list and unread totals.
- `src/pages/pinned_searches_page.dart`: flat management page.
- `src/widgets/pin_search_dialog.dart`: optional-name confirmation dialog.
- `src/widgets/pinned_search_card.dart`: preview, badge, status, and menu presentation.
- `src/widgets/pinned_search_navigation_icon.dart`: reusable badged navigation icon.
- `src/routes/routes.dart`, `src/routes/route_utils.dart`: `/pinned-searches` navigation.

Keep chronological query planning under the search feature, but expose it from
`BooruRepository` so integrations can override the conservative default later.
Keep preview rows embedded in each Hive aggregate: a successful refresh becomes
one `box.put`, and a crash cannot split the checkpoint from its unread count.

---

### Task 1: Domain model and repository contract

**Files:**
- Create: `lib/core/search/subscriptions/types.dart`
- Create: `lib/core/search/subscriptions/src/types/search_subscription.dart`
- Create: `lib/core/search/subscriptions/src/types/search_post_preview.dart`
- Create: `lib/core/search/subscriptions/src/types/search_refresh.dart`
- Create: `lib/core/search/subscriptions/src/types/search_subscription_repository.dart`
- Test: `test/core/search/subscriptions/search_subscription_test.dart`

**Interfaces:**
- Consumes: `BooruConfig.id`, generic integer `Post.id`, `Equatable`.
- Produces: `SearchSubscription`, `SearchPostPreview`,
  `RecentSearchPostIdentity`, `SearchRefreshErrorKind`,
  `SearchRefreshOutcome`, `SearchRefreshCommit`, and
  `SearchSubscriptionRepository` for every later task.

- [x] **Step 1: Write the failing value-behavior tests**

Cover nullable-name normalization, exact-query fallback, immutable collections,
oldest-refresh ordering, and query identity normalization without semantic term
reordering:

```dart
final unnamed = SearchSubscription.create(
  id: subscriptionId,
  profileId: 7,
  query: 'cat_girl order:id',
  name: '   ',
  position: 0,
  createdAt: now,
);
expect(unnamed.name, isNull);
expect(unnamed.displayName, 'cat_girl order:id');
expect(normalizeSearchIdentity('  A   B  '), 'A B');

final ordered = [recent, neverChecked, oldest]
  ..sort(compareSearchRefreshPriority);
expect(ordered.map((item) => item.id), [neverId, oldestId, recentId]);
```

- [x] **Step 2: Run the domain test and verify it fails**

Run: `fvm flutter test test/core/search/subscriptions/search_subscription_test.dart`

Expected: FAIL because the subscription types do not exist.

- [x] **Step 3: Define the immutable values**

Implement `SearchSubscription` with these exact fields:

```dart
class SearchSubscription extends Equatable {
  const SearchSubscription({
    required this.id,
    required this.profileId,
    required this.query,
    required this.position,
    required this.createdAt,
    required this.previews,
    required this.recentPostIdentities,
    required this.unreadCount,
    this.name,
    this.lastAttemptAt,
    this.lastSuccessfulCheckAt,
    this.lastErrorKind,
  });

  factory SearchSubscription.create({
    required String id,
    required int profileId,
    required String query,
    required String? name,
    required int position,
    required DateTime createdAt,
  });

  String get displayName => name ?? query;
  bool get hasBaseline => lastSuccessfulCheckAt != null;
}
```

Normalize only surrounding and repeated whitespace for identity comparison.
Preserve the executable `query` supplied by the search controller after
trimming its outer whitespace. Do not lowercase or reorder terms.

Define `SearchPostPreview` and `RecentSearchPostIdentity` as Equatable values.
Both contain `postId`; the preview additionally contains nullable
`postCreatedAt`, `thumbnailUrl`, nullable `sampleUrl`, and `discoveredAt`. The
recent identity contains non-null `postCreatedAt`, which prevents ambiguous
deduplication data from entering successful refresh state.

- [x] **Step 4: Define atomic refresh input and repository operations**

Use these contracts so concurrency decisions do not leak into widgets:

```dart
enum SearchRefreshErrorKind {
  network,
  authentication,
  query,
  pagination,
  parsing,
  unsupported,
  other,
}

class SearchRefreshCommit extends Equatable {
  const SearchRefreshCommit({
    required this.subscriptionId,
    required this.expectedCheckpoint,
    required this.startedAt,
    required this.identityRetentionBoundary,
    required this.baseline,
    required this.discoveredPosts,
  });
  final String subscriptionId;
  final DateTime? expectedCheckpoint;
  final DateTime startedAt;
  final DateTime identityRetentionBoundary;
  final bool baseline;
  final List<SearchPostPreview> discoveredPosts;
}

sealed class SearchRefreshOutcome extends Equatable {
  const SearchRefreshOutcome();
}

final class SearchRefreshSucceeded extends SearchRefreshOutcome {
  const SearchRefreshSucceeded({
    required this.subscription,
    required this.discoveredCount,
    required this.baseline,
  });
  final SearchSubscription subscription;
  final int discoveredCount;
  final bool baseline;
}

final class SearchRefreshFailed extends SearchRefreshOutcome {
  const SearchRefreshFailed(this.kind);
  final SearchRefreshErrorKind kind;
}

final class SearchRefreshDiscarded extends SearchRefreshOutcome {
  const SearchRefreshDiscarded();
}

abstract interface class SearchSubscriptionRepository {
  Future<List<SearchSubscription>> getAll();
  Future<SearchSubscription?> getById(String id);
  Future<SearchSubscription?> findByQuery(int profileId, String query);
  Future<SearchSubscription> create({
    required int profileId,
    required String query,
    required String? name,
    String? id,
    DateTime? createdAt,
  });
  Future<SearchSubscription> rename(String id, String? name);
  Future<List<SearchSubscription>> reorder(int profileId, int oldIndex, int newIndex);
  Future<SearchSubscription?> markRead(String id);
  Future<SearchSubscription?> commitRefresh(SearchRefreshCommit commit);
  Future<SearchSubscription?> recordRefreshFailure(
    String id, {
    required DateTime attemptedAt,
    required SearchRefreshErrorKind kind,
  });
  Future<void> delete(String id);
  Future<void> deleteForProfile(int profileId);
  Future<void> restoreForProfile(
    int profileId,
    List<SearchSubscription> subscriptions,
  );
}
```

`commitRefresh` must return `null` if the subscription was deleted or its
checkpoint no longer equals `expectedCheckpoint`. This is the stale-result
guard used by the service. `identityRetentionBoundary` tells the repository
which older deduplication identities can be pruned. `restoreForProfile` is
reserved for compensating a failed profile deletion; it restores exact captured
aggregates and is not the backup-import API.

- [x] **Step 5: Export the types, format, and run the test**

Run:

```bash
fvm dart format lib/core/search/subscriptions test/core/search/subscriptions/search_subscription_test.dart
fvm flutter test test/core/search/subscriptions/search_subscription_test.dart
```

Expected: PASS.

- [x] **Step 6: Commit the domain boundary**

```bash
git add lib/core/search/subscriptions/types.dart lib/core/search/subscriptions/src/types test/core/search/subscriptions/search_subscription_test.dart
git commit -m "feat(search): define pinned search domain"
```

---

### Task 2: Hive persistence and atomic mutations

**Files:**
- Create: `lib/core/search/subscriptions/src/data/hive/search_subscription_hive_object.dart`
- Create: `lib/core/search/subscriptions/src/data/hive/search_post_preview_hive_object.dart`
- Create: `lib/core/search/subscriptions/src/data/hive/recent_search_post_hive_object.dart`
- Create: `lib/core/search/subscriptions/src/data/hive/search_subscription_repository_hive.dart`
- Create: `lib/core/search/subscriptions/src/data/providers.dart`
- Create: `lib/core/search/subscriptions/providers.dart`
- Modify: `lib/core/hive/hive_adapters.dart`
- Modify (generated): `lib/core/hive/hive_adapters.g.dart`
- Modify (generated): `lib/core/hive/hive_adapters.g.yaml`
- Modify (generated): `lib/core/hive/hive_registrar.g.dart`
- Test: `test/core/search/subscriptions/search_subscription_repository_test.dart`

**Interfaces:**
- Consumes: all Task 1 values and `SearchSubscriptionRepository`.
- Produces: `HiveSearchSubscriptionRepository` and `searchSubscriptionRepositoryProvider`.

- [x] **Step 1: Write failing repository contract tests**

Use a temporary Hive directory and a real typed box. Register only the new
adapters when their type IDs are not already registered. Cover:

```dart
test('stores a blank name as null and finds the same normalized query', () async {
  final created = await repository.create(
    profileId: 4,
    query: '  cat   rating:safe  ',
    name: ' ',
    createdAt: DateTime.utc(2026),
  );
  expect(created.name, isNull);
  expect((await repository.findByQuery(4, 'cat rating:safe'))?.id, created.id);
});

test('commits new discoveries without overwriting a concurrent mark read', () async {
  await repository.markRead(id);
  final committed = await repository.commitRefresh(commit);
  expect(committed?.unreadCount, discoveredPosts.length);
});
```

Also cover duplicate prevention per profile, same query allowed in another
profile, contiguous reorder positions, top-four preview sorting, overlap ID
deduplication, baseline commits with zero unread, stale checkpoint rejection,
failure preservation, deletion, `deleteForProfile` isolation, and exact
`restoreForProfile` compensation.

- [x] **Step 2: Run the repository test and verify it fails**

Run: `fvm flutter test test/core/search/subscriptions/search_subscription_repository_test.dart`

Expected: FAIL because the Hive objects and repository do not exist.

- [x] **Step 3: Add compact Hive aggregate objects**

Store one `SearchSubscriptionHiveObject` per subscription in the
`pinned_search_subscriptions` box. Its fields mirror `SearchSubscription`, with
embedded `List<SearchPostPreviewHiveObject>` and
`List<RecentSearchPostHiveObject>`. Store `lastErrorKind` as its enum name so
unknown future values can map to `other` instead of failing deserialization.

Register all three object types in `@GenerateAdapters`. Do not choose type IDs
manually; let the existing Hive CE generator allocate from `nextTypeId`.

- [x] **Step 4: Implement serialized repository mutations**

Use a private future tail so reads participating in a mutation cannot observe
half-written ordering:

```dart
Future<void> _mutationTail = Future.value();

Future<T> _serialize<T>(Future<T> Function() operation) {
  final completer = Completer<T>();
  _mutationTail = _mutationTail.catchError((_) {}).then((_) async {
    try {
      completer.complete(await operation());
    } catch (error, stackTrace) {
      completer.completeError(error, stackTrace);
    }
  });
  return completer.future;
}
```

For `commitRefresh`, reload the current object inside `_serialize`, verify its
checkpoint, discard candidate IDs already in its recent identity window, merge
and sort previews newest-first, keep four previews, and:

```dart
final unreadCount = commit.baseline
    ? 0
    : current.unreadCount + newlyDiscovered.length;
```

Set both `lastAttemptAt` and `lastSuccessfulCheckAt` to `startedAt`, clear the
error, and prune recent identities older than
`commit.identityRetentionBoundary`.
`recordRefreshFailure` updates only attempt/error fields. `markRead` sets only
`unreadCount` to zero. All mutations rebuild from the latest stored object so a
rename or mark-read racing a refresh is retained.

- [x] **Step 5: Add the repository provider and public exports**

Declare:

```dart
final searchSubscriptionRepositoryProvider = AsyncNotifierProvider<
  SearchSubscriptionRepositoryNotifier,
  SearchSubscriptionRepository
>(SearchSubscriptionRepositoryNotifier.new);

class SearchSubscriptionRepositoryNotifier
    extends AsyncNotifier<SearchSubscriptionRepository> {
  @override
  Future<SearchSubscriptionRepository> build() async {
    final box = await Hive.openBox<SearchSubscriptionHiveObject>(
      'pinned_search_subscriptions',
    );
    ref.onDispose(() async => box.close());
    return HiveSearchSubscriptionRepository(box: box);
  }
}
```

Export only the repository provider from the feature's public `providers.dart`;
keep Hive objects internal except where generator imports require them.

- [x] **Step 6: Generate adapters and format immediately**

Run:

```bash
cd packages/boorusama_cli
fvm dart pub get
cd ../..
./gen.sh
fvm dart format lib/core/search/subscriptions lib/core/hive test/core/search/subscriptions/search_subscription_repository_test.dart
```

Expected: generation succeeds and registers all three new Hive adapters.

- [x] **Step 7: Run persistence tests**

Run:

```bash
fvm flutter test test/core/search/subscriptions/search_subscription_test.dart
fvm flutter test test/core/search/subscriptions/search_subscription_repository_test.dart
```

Expected: PASS.

- [x] **Step 8: Commit persistence**

```bash
git add lib/core/search/subscriptions lib/core/hive test/core/search/subscriptions
git commit -m "feat(search): persist pinned searches"
```

---

### Task 3: Chronological query capability and scanner

**Files:**
- Create: `lib/core/search/subscriptions/src/refresh/search_refresh_query_adapter.dart`
- Create: `lib/core/search/subscriptions/src/refresh/chronological_search_scanner.dart`
- Modify: `lib/core/boorus/engine/src/booru_repository.dart`
- Modify: `lib/core/boorus/defaults/src/booru_repository_default.dart`
- Test: `test/core/search/subscriptions/chronological_search_scanner_test.dart`
- Test: `test/core/search/subscriptions/search_refresh_query_adapter_test.dart`

**Interfaces:**
- Consumes: `PostRepository<Post>`, `PostResult<Post>`, and Task 1 refresh errors.
- Produces: `SearchRefreshQueryAdapter`, `SearchRefreshQueryPlan`,
  `DefaultSearchRefreshQueryAdapter`, `ChronologicalSearchScanner`, and
  `SearchScanResult` for Task 4.

- [x] **Step 1: Write failing query-plan tests**

The conservative default accepts ordinary queries unchanged and rejects query
tokens that request non-chronological ordering:

```dart
final adapter = DefaultSearchRefreshQueryAdapter();
expect(adapter.plan('cat rating:safe', after: checkpoint),
    isA<SupportedSearchRefreshQueryPlan>());

for (final query in ['cat order:score', 'cat sort:favorites', 'order_by=random']) {
  test('rejects non chronological query $query', () {
    expect(adapter.plan(query, after: checkpoint),
        isA<UnsupportedSearchRefreshQueryPlan>());
  });
}
```

Tokenize on query whitespace and inspect metatag keys ending in `:` or `=`;
do not reject a normal tag merely because its text contains “order”. A future
booru override may replace or remove an ordering token and may add a native
uploaded-after constraint.

- [x] **Step 2: Write failing scanner behavior tests**

Use `SimplePost` records and a page fetch callback. Cover:

- baseline reads page one only and returns four distinct previews;
- checks continue page-by-page until the oldest post reaches the overlap
  boundary;
- only posts strictly newer than the checkpoint are candidates;
- equal timestamps are not new;
- duplicate IDs across pages are returned once;
- empty and short pages complete successfully;
- `maxPage` is honored;
- a null timestamp returns `SearchRefreshErrorKind.unsupported`;
- ascending or otherwise non-monotonic timestamps return `unsupported`;
- a fetch/pagination failure is returned without a partial success.

Use explicit page records rather than mocking scanner internals:

```dart
final result = await scanner.scanForNewPosts(
  query: 'cat',
  checkpoint: DateTime.utc(2026, 9, 1),
  fetchPage: (page, limit) async => Either.of(pages[page]!),
);
expect(result, isA<CompletedSearchScan>());
expect((result as CompletedSearchScan).posts.map((post) => post.id), [3, 2]);
```

- [x] **Step 3: Run both tests and verify they fail**

Run:

```bash
fvm flutter test test/core/search/subscriptions/search_refresh_query_adapter_test.dart
fvm flutter test test/core/search/subscriptions/chronological_search_scanner_test.dart
```

Expected: FAIL because adapters and scanner do not exist.

- [x] **Step 4: Implement the query-plan contract**

Use sealed results rather than nullable strings:

```dart
sealed class SearchRefreshQueryPlan extends Equatable {
  const SearchRefreshQueryPlan();
}

final class SupportedSearchRefreshQueryPlan extends SearchRefreshQueryPlan {
  const SupportedSearchRefreshQueryPlan({
    required this.query,
  });
  final String query;
}

final class UnsupportedSearchRefreshQueryPlan extends SearchRefreshQueryPlan {
  const UnsupportedSearchRefreshQueryPlan();
}

abstract interface class SearchRefreshQueryAdapter {
  SearchRefreshQueryPlan plan(String query, {required DateTime? after});
}
```

Add `SearchRefreshQueryAdapter searchRefreshQueryAdapter(BooruConfigAuth
config)` to `BooruRepository`. Implement it once in `BooruRepositoryDefault`
with `const DefaultSearchRefreshQueryAdapter()`, so every current engine remains
source-compatible and can override it later.

- [x] **Step 5: Implement the scanner**

Inject `pageSize` and `overlap` through the constructor, defaulting to 50 posts
and five minutes. `scanBaseline` fetches one page. `scanForNewPosts` validates
descending UTC creation times across page boundaries and stops only after the
overlap boundary, an empty/short page, or `maxPage`.

Return a sealed `SearchScanResult`:

```dart
typedef SearchRefreshPageFetcher = Future<Either<
    SearchRefreshErrorKind, PostResult<Post>>> Function(int page, int limit);

sealed class SearchScanResult { const SearchScanResult(); }
final class CompletedSearchScan extends SearchScanResult {
  const CompletedSearchScan(this.posts);
  final List<Post> posts;
}
final class FailedSearchScan extends SearchScanResult {
  const FailedSearchScan(this.kind);
  final SearchRefreshErrorKind kind;
}
```

Do not commit or mutate subscription state in the scanner.

- [x] **Step 6: Format and run the focused tests**

Run:

```bash
fvm dart format lib/core/search/subscriptions/src/refresh lib/core/boorus/engine/src/booru_repository.dart lib/core/boorus/defaults/src/booru_repository_default.dart test/core/search/subscriptions
fvm flutter test test/core/search/subscriptions/search_refresh_query_adapter_test.dart
fvm flutter test test/core/search/subscriptions/chronological_search_scanner_test.dart
```

Expected: PASS.

- [x] **Step 7: Commit the refresh capability**

```bash
git add lib/core/search/subscriptions/src/refresh lib/core/boorus/engine/src/booru_repository.dart lib/core/boorus/defaults/src/booru_repository_default.dart test/core/search/subscriptions
git commit -m "feat(search): scan pinned searches chronologically"
```

---

### Task 4: Refresh service and subscription notifier

**Files:**
- Create: `lib/core/search/subscriptions/src/services/search_refresh_service.dart`
- Create: `lib/core/search/subscriptions/src/providers/search_subscriptions_notifier.dart`
- Create: `lib/core/search/subscriptions/src/providers/search_subscription_selectors.dart`
- Modify: `lib/core/search/subscriptions/providers.dart`
- Test: `test/core/search/subscriptions/search_refresh_service_test.dart`
- Test: `test/core/search/subscriptions/search_subscriptions_notifier_test.dart`

**Interfaces:**
- Consumes: Tasks 1–3 repository, query plan, scanner, `postRepoProvider`,
  `booruEngineRegistryProvider`, and `booruConfigProvider`.
- Produces: `SearchRefreshService`, `SearchSubscriptionsState`,
  `SearchSubscriptionsNotifier`, `searchSubscriptionsProvider`, active-profile
  selectors, `refresh`, `refreshAll`, `pin`, `rename`, `reorder`, `markRead`,
  and `delete` commands.

- [x] **Step 1: Write failing refresh-service tests**

Use fake external boundaries only: an in-memory repository, fake post-page
fetcher, fake query adapter, and fixed `Clock`. Verify:

```dart
test('first successful refresh establishes a read baseline', () async {
  final outcome = await service.refresh(subscriptionWithoutCheckpoint, config);
  expect(outcome, isA<SearchRefreshSucceeded>());
  expect((await repository.getById(id))?.unreadCount, 0);
  expect((await repository.getById(id))?.lastSuccessfulCheckAt, startedAt);
});

test('later refresh commits only new posts', () async {
  final outcome = await service.refresh(subscriptionWithCheckpoint, config);
  expect((outcome as SearchRefreshSucceeded).discoveredCount, 2);
  expect((await repository.getById(id))?.unreadCount, 2);
});
```

Also verify unsupported plan, post-repository failure, null timestamp, stale
commit, and deletion during fetch. Failure records `lastAttemptAt` and error
kind but preserves checkpoint/previews/unread.

- [x] **Step 2: Run the service test and verify it fails**

Run: `fvm flutter test test/core/search/subscriptions/search_refresh_service_test.dart`

Expected: FAIL because `SearchRefreshService` does not exist.

- [x] **Step 3: Implement `SearchRefreshService`**

Inject all side effects:

```dart
class SearchRefreshService {
  SearchRefreshService({
    required this.repository,
    required this.resolvePostRepository,
    required this.resolveQueryAdapter,
    required this.scanner,
    Clock clock = const Clock(),
  });

  Future<SearchRefreshOutcome> refresh(
    SearchSubscription subscription,
    BooruConfig config,
  );
}
```

The injected resolvers have these signatures:

```dart
typedef SearchPostRepositoryResolver = PostRepository<Post> Function(
  BooruConfigSearch config,
);
typedef SearchRefreshQueryAdapterResolver = SearchRefreshQueryAdapter Function(
  BooruConfigAuth config,
);
```

Capture `startedAt = clock.now().toUtc()` before planning/fetching. Pattern
match on the query plan and scanner result. Convert successful `Post` objects
to preview/identity values only after explicitly validating `createdAt`. Pass
the subscription's original checkpoint as `expectedCheckpoint` in the atomic
commit. Map external `BooruError` categories to the closest
`SearchRefreshErrorKind`; never expose raw exception text as UI copy.

- [x] **Step 4: Write failing notifier tests**

Cover serialized state publication, active-profile selectors, initial snapshot
after pin, duplicate-query reuse, optional rename, mark-read, reorder/delete,
same-subscription refresh coalescing, and Refresh All start order/concurrency.

Record fake service starts to assert:

```dart
expect(startedIds.take(3), [neverCheckedId, oldestId, nextOldestId]);
expect(maxConcurrentRefreshes, lessThanOrEqualTo(3));
```

Verify an independent failure does not prevent later searches from starting.

- [x] **Step 5: Run the notifier test and verify it fails**

Run: `fvm flutter test test/core/search/subscriptions/search_subscriptions_notifier_test.dart`

Expected: FAIL because provider state and commands do not exist.

- [x] **Step 6: Implement notifier state and commands**

Use immutable state with all subscriptions plus transient activity:

```dart
class SearchSubscriptionsState extends Equatable {
  const SearchSubscriptionsState({
    required this.subscriptions,
    required this.refreshingIds,
    required this.batchCompleted,
    required this.batchTotal,
  });
}
```

The notifier owns `Map<String, Future<SearchRefreshOutcome>> _inFlight`.
`refresh(id)` returns the existing future when present and removes it in
`whenComplete`. `refreshAll(profileId)` sorts by
`compareSearchRefreshPriority` and runs a three-worker queue; it updates batch
progress after each outcome and reloads committed state.

`pin` must save first, publish state, then call `refresh` to establish the
baseline. Return both the saved subscription and refresh outcome so the dialog
can close after persistence without pretending the snapshot succeeded.

Expose these exact command signatures:

```dart
Future<({SearchSubscription subscription, SearchRefreshOutcome refresh})> pin({
  required int profileId,
  required String query,
  required String? name,
});
Future<SearchRefreshOutcome> refresh(String id);
Future<List<SearchRefreshOutcome>> refreshAll(int profileId);
Future<void> rename(String id, String? name);
Future<void> reorder(int profileId, int oldIndex, int newIndex);
Future<void> markRead(String id);
Future<void> delete(String id);
```

Declare selectors as `Provider.family`, including:

```dart
final profilePinnedSearchesProvider = Provider.family<
    AsyncValue<List<SearchSubscription>>, int>((ref, profileId) {
  return ref.watch(searchSubscriptionsProvider).whenData((state) {
    final items = state.subscriptions
        .where((item) => item.profileId == profileId)
        .toList()
      ..sort((a, b) => a.position.compareTo(b.position));
    return items;
  });
});

final profilePinnedSearchUnreadCountProvider =
    Provider.family<int, int>((ref, profileId) {
  return ref
          .watch(profilePinnedSearchesProvider(profileId))
          .valueOrNull
          ?.fold(0, (total, item) => total + item.unreadCount) ??
      0;
});
```

- [x] **Step 7: Format and run service/notifier tests**

Run:

```bash
fvm dart format lib/core/search/subscriptions test/core/search/subscriptions
fvm flutter test test/core/search/subscriptions/search_refresh_service_test.dart
fvm flutter test test/core/search/subscriptions/search_subscriptions_notifier_test.dart
```

Expected: PASS.

- [x] **Step 8: Commit application behavior**

```bash
git add lib/core/search/subscriptions test/core/search/subscriptions
git commit -m "feat(search): refresh pinned searches manually"
```

---

### Task 5: Profile-deletion cascade

**Files:**
- Modify: `lib/core/configs/manage/src/providers/booru_config_provider.dart`
- Test: `test/booru_config_notifier_test.dart`

**Interfaces:**
- Consumes: `searchSubscriptionRepositoryProvider` from Task 2.
- Produces: profile deletion that removes the owning subscription aggregates
  and prevents late refresh commits from recreating them.

- [x] **Step 1: Extend deletion tests with pinned-search cleanup**

Override `searchSubscriptionRepositoryProvider` with a recording repository.
Add cases for deleting the current profile, another profile, and the final
profile:

```dart
await notifier.delete(config);
expect(searchRepository.deletedProfileIds, [config.id]);
expect(searchRepository.remaining.every((s) => s.profileId != config.id), isTrue);
```

Also verify both failure directions: a search-repository deletion failure does
not remove the profile, while a profile-repository deletion failure restores
the exact captured subscriptions.

- [x] **Step 2: Run the focused config test and verify it fails**

Run: `fvm flutter test test/booru_config_notifier_test.dart`

Expected: FAIL because profile deletion does not call the search repository.

- [x] **Step 3: Add cascade cleanup before config removal**

Before entering the existing last/current/ordinary branches, capture the
profile's subscriptions and run `deleteForProfile(config.id)`. Extract one
private cascade helper to avoid duplicating this around each
`booruConfigRepoProvider.remove(config)` call. If config removal fails, call
`restoreForProfile(config.id, captured)` before routing the original error
through `onFailure`. If compensation also fails, log both errors and report the
operation as failed.

Do not change the existing confirmation dialog or add recovery UI. Because
refresh commits reload the aggregate by ID, in-flight work receives `null`
during the cascade and cannot recreate a deleted search.

- [x] **Step 4: Format and run deletion tests**

Run:

```bash
fvm dart format lib/core/configs/manage/src/providers/booru_config_provider.dart test/booru_config_notifier_test.dart
fvm flutter test test/booru_config_notifier_test.dart
```

Expected: PASS.

- [x] **Step 5: Commit profile lifecycle integration**

```bash
git add lib/core/configs/manage/src/providers/booru_config_provider.dart test/booru_config_notifier_test.dart
git commit -m "feat(search): delete pins with profiles"
```

---

### Task 6: Pin dialog and normal-search integration

**Files:**
- Create: `lib/core/search/subscriptions/src/widgets/pin_search_dialog.dart`
- Create: `lib/core/search/subscriptions/widgets.dart`
- Modify: `lib/core/search/search/src/widgets/search_page_scaffold.dart`
- Modify: `packages/i18n/translations/en-US.json`
- Test: `test/core/search/subscriptions/pin_search_dialog_test.dart`
- Test: `test/core/search/subscriptions/search_page_pin_action_test.dart`

**Interfaces:**
- Consumes: `SearchPageController.tagString`, current `BooruConfig`, and Task 4
  notifier commands.
- Produces: `showPinSearchDialog`, `PinSearchDialog`, and a Pin/Manage Search
  result-header action for every normal booru search using
  `SearchPageScaffold`.

- [x] **Step 1: Write failing pin-dialog widget tests**

Pump localized app scaffolding and verify:

- the query is displayed read-only;
- the optional name starts empty for a new pin;
- whitespace submits as `null`;
- a custom name is trimmed;
- Cancel returns `null`;
- an existing pin pre-fills its custom name and uses Save copy.

Use the public return value:

```dart
final Future<String?> result = showPinSearchDialog(
  context,
  query: 'cat rating:safe',
);
```

- [x] **Step 2: Run the dialog test and verify it fails**

Run: `fvm flutter test test/core/search/subscriptions/pin_search_dialog_test.dart`

Expected: FAIL because the dialog does not exist.

- [x] **Step 3: Implement the optional-name dialog**

Use `KurumiDialog`/Material controls consistent with existing name dialogs.
The query is context, not an editable field. Return `null` on cancellation and
return the trimmed name, using an empty string as the dialog's explicit “no
custom name” value; the notifier converts it to stored `null`.

Add i18n keys under a new `pinned_searches` namespace for title, optional name,
name hint, query label, Pin, Save, and persistence/snapshot feedback. Do not run
generation until Step 7 so both UI files can be formatted together.

- [x] **Step 4: Write failing search-page action tests**

Pump `SearchPageScaffold` with a fake repository/notifier. Assert the action is
absent before a non-empty search has loaded, appears after `tagString` becomes
non-empty, opens the dialog, and calls:

```dart
notifier.pin(
  profileId: currentConfig.id,
  query: controller.tagString.value,
  name: submittedName,
);
```

For an already pinned query, assert the same action opens the dialog with its
current name and calls `rename` rather than creating a duplicate.

- [x] **Step 5: Run the action test and verify it fails**

Run: `fvm flutter test test/core/search/subscriptions/search_page_pin_action_test.dart`

Expected: FAIL because the result header has no pin action.

- [x] **Step 6: Add the action to `SearchPageScaffold`**

In the existing result-header row, add a small consumer widget that listens to
`SearchPageController.tagString`, resolves exact pin state for the current
profile, and shows either Pin Search or Manage Pinned Search. Keep the generic
booru-specific `extraHeaders` untouched.

Persist before waiting for the initial snapshot. Show a localized success for
the saved pin and a separate non-destructive warning if its baseline fetch
fails. Never close or replace the current search result page.

- [x] **Step 7: Generate localization, format, and run widget tests**

Run:

```bash
./gen.sh
fvm dart format lib/core/search/subscriptions lib/core/search/search/src/widgets/search_page_scaffold.dart test/core/search/subscriptions
fvm flutter test test/core/search/subscriptions/pin_search_dialog_test.dart
fvm flutter test test/core/search/subscriptions/search_page_pin_action_test.dart
```

Expected: generation succeeds and both tests PASS.

- [x] **Step 8: Commit pin creation UI**

```bash
git add lib/core/search/subscriptions lib/core/search/search/src/widgets/search_page_scaffold.dart packages/i18n
git add test/core/search/subscriptions
git commit -m "feat(search): pin searches from results"
```

---

### Task 7: Pinned Searches page, routes, previews, and badges

**Files:**
- Create: `lib/core/search/subscriptions/routes.dart`
- Create: `lib/core/search/subscriptions/src/routes/routes.dart`
- Create: `lib/core/search/subscriptions/src/routes/route_utils.dart`
- Create: `lib/core/search/subscriptions/src/pages/pinned_searches_page.dart`
- Create: `lib/core/search/subscriptions/src/widgets/pinned_search_card.dart`
- Create: `lib/core/search/subscriptions/src/widgets/pinned_search_navigation_icon.dart`
- Modify: `lib/core/routers/routes.dart`
- Modify: `lib/core/home/src/widgets/side_bar_menu.dart`
- Modify: `lib/core/home/src/widgets/home_navigation_tile.dart`
- Modify: `lib/core/home/src/pages/home_page_scaffold.dart`
- Modify: `packages/i18n/translations/en-US.json`
- Test: `test/core/search/subscriptions/pinned_searches_page_test.dart`
- Test: `test/core/search/subscriptions/pinned_search_navigation_test.dart`

**Interfaces:**
- Consumes: Task 4 providers and commands, `BooruImage`, existing search route,
  current `BooruConfig`, `HomeNavigationTile`, and `SideMenuTile`.
- Produces: `/pinned-searches`, the flat management UI, manual Refresh All,
  mark-read/open behavior, and active-profile unread badges on mobile and
  desktop navigation.

- [ ] **Step 1: Write failing page behavior tests**

Cover loading/error/empty states and a populated active-profile list. For a
card verify effective name, optional query subtitle, four-preview limit,
numeric unread badge, last-refresh/error presentation, and menu actions.

Verify observable commands:

```dart
await tester.tap(find.text('Cats'));
await tester.pumpAndSettle();
expect(fakeRepository.markedReadIds, [catsId]);
expect(router.location, contains('query=cat'));
```

Also assert Refresh All forwards only the active profile ID, progress is shown,
rename/reorder/delete update the list, a broken preview uses the existing image
fallback, and opening the page itself makes no post request.

- [ ] **Step 2: Write failing navigation badge tests**

Provide searches for two profiles. Assert mobile and desktop navigation show
only the selected profile's summed unread count, update after `markRead`, and
hide the badge at zero.

- [ ] **Step 3: Run both widget tests and verify they fail**

Run:

```bash
fvm flutter test test/core/search/subscriptions/pinned_searches_page_test.dart
fvm flutter test test/core/search/subscriptions/pinned_search_navigation_test.dart
```

Expected: FAIL because the page and route are absent.

- [ ] **Step 4: Implement routes and flat page**

Register a `pinnedSearchRoutes` child of `Routes.home` at
`/pinned-searches`. `goToPinnedSearchesPage(ref)` pushes that route.

Build `PinnedSearchesPage` from `profilePinnedSearchesProvider(current.id)`.
The app bar contains Refresh All, disabled while the active profile's batch is
running. Use a reorderable flat list; map visible indices back to the active
profile's ordered subscriptions before calling `reorder`.

Opening a card must await `markRead(id)` and then call:

```dart
goToSearchPage(
  ref,
  tag: subscription.query,
  queryType: QueryType.simple,
);
```

If mark-read fails, keep the user on the page and show a localized error rather
than opening with a badge that was not cleared.

- [ ] **Step 5: Implement cards and cached previews**

Use up to four square `BooruImage` children with the owning profile's auth
context and existing loading/error fallback. Do not fetch posts from the card
or page. Add overflow actions for refresh, rename, move up/down, and delete;
boundary move actions remain visible but disabled. Deletion is immediate after
the existing destructive confirmation pattern.

- [ ] **Step 6: Add mobile and desktop navigation badges**

Add a Pinned Searches tile beside other search/bookmark navigation. Extend
`HomeNavigationTile` with optional `badgeCount` and wrap both selected and
unselected icons with `Badge.count` only when the value is positive. On mobile,
use `PinnedSearchNavigationIcon` as the `SideMenuTile.icon`.

Insert `PinnedSearchesPage` into `coreDesktopViewBuilder` and its matching tile
into `coreDesktopTabBuilder`, shifting the following `_v(...)` values together
so page and tile indices remain aligned. Add a focused test protecting that
mapping.

- [ ] **Step 7: Add i18n copy and generate**

Add keys for Pinned Searches navigation/title, empty state, Refresh, Refresh
All, refreshing progress, unread count, last checked, never checked, rename,
move, delete confirmation, unsupported tracking, and each stable error kind.
Then run:

```bash
./gen.sh
fvm dart format lib/core/search/subscriptions lib/core/routers/routes.dart lib/core/home test/core/search/subscriptions
```

- [ ] **Step 8: Run page and navigation tests**

Run:

```bash
fvm flutter test test/core/search/subscriptions/pinned_searches_page_test.dart
fvm flutter test test/core/search/subscriptions/pinned_search_navigation_test.dart
```

Expected: PASS.

- [ ] **Step 9: Commit browsing UI**

```bash
git add lib/core/search/subscriptions lib/core/routers/routes.dart lib/core/home packages/i18n test/core/search/subscriptions
git commit -m "feat(search): browse pinned searches"
```

---

### Task 8: Backup and idempotent restore

**Files:**
- Create: `lib/core/backups/sources/pinned_search_backup_data.dart`
- Create: `lib/core/backups/sources/pinned_search_backup_codec.dart`
- Create: `lib/core/backups/sources/pinned_search_import_service.dart`
- Create: `lib/core/backups/sources/pinned_searches_source.dart`
- Modify: `lib/core/backups/sources/providers.dart`
- Modify: `lib/core/backups/types/types.dart`
- Modify: `packages/i18n/translations/en-US.json`
- Test: `test/core/backups/pinned_search_backup_codec_test.dart`
- Test: `test/core/backups/pinned_search_import_service_test.dart`
- Test: `test/core/backups/pinned_searches_source_test.dart`

**Interfaces:**
- Consumes: Task 2 repository, configured profiles, `JsonBackupSource`, and
  `BackupRegistry`.
- Produces: backup source ID `pinned_searches`, portable profile mapping,
  validated JSON codec, idempotent append restore, and localized backup tile.

- [ ] **Step 1: Write failing codec tests**

Define backup records containing only stable definition data:

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "name": "Cats",
  "query": "cat rating:safe",
  "position": 0,
  "profile": {
    "id": 4,
    "booruType": "danbooru",
    "url": "https://example.test/",
    "name": "Example"
  }
}
```

Verify valid round trip and reject non-object rows, malformed UUIDs, blank
queries, invalid positions, duplicate IDs, and missing/invalid profile fields.
Verify runtime fields such as preview URLs, unread counts, checkpoints, and
errors are absent from encoded JSON.

- [ ] **Step 2: Run the codec test and verify it fails**

Run: `fvm flutter test test/core/backups/pinned_search_backup_codec_test.dart`

Expected: FAIL because the backup codec does not exist.

- [ ] **Step 3: Implement validated backup values and codec**

Use `PinnedSearchBackupData`, `PinnedSearchBackupRecord`, and
`PinnedSearchProfileReference` Equatable values. Normalize profile URLs by
lowercasing the host, removing a trailing slash, and retaining scheme/path.
JSON parsing must pattern-match nullable/external values and throw
`InvalidBackupFormatException` with the offending row/field.

- [ ] **Step 4: Write failing import-service tests**

Cover profile resolution in this order:

1. same ID plus matching booru type and normalized URL;
2. unique matching booru type and normalized URL;
3. otherwise skip with an explicit count.

Verify imported pins append after existing positions, preserve their imported
relative order, reuse an existing normalized query for that profile, remain
idempotent on repeated import, and never create a pin for an unmapped profile.

- [ ] **Step 5: Run the import test and verify it fails**

Run: `fvm flutter test test/core/backups/pinned_search_import_service_test.dart`

Expected: FAIL because the import service does not exist.

- [ ] **Step 6: Implement import planning and application**

Keep mapping and mutation outside widgets. Return:

```dart
class PinnedSearchImportResult extends Equatable {
  const PinnedSearchImportResult({
    required this.importedCount,
    required this.alreadyExistedCount,
    required this.skippedProfileCount,
  });
}
```

Create restored subscriptions without previews, recent IDs, checkpoints,
attempts, errors, or unread counts. Do not issue network requests during
restore; the next explicit refresh establishes a baseline.

- [ ] **Step 7: Register the backup source after profiles**

Create `PinnedSearchesBackupSource` as a `JsonBackupSource` with ID
`pinned_searches` and priority `100000`, one greater than the existing profiles
source. This ensures full ZIP/server restore has installed profile IDs before
mapping pins. Register/watch it in `backupRegistryProvider` and
`allBackupSourcesProvider`.

Extend `BackupOperationResult` with optional pinned-search and skipped-profile
counts without changing existing bookmark defaults. Build a localized tile
showing the number of definitions; import messaging must mention skipped pins
when their profile was absent. A backup/manifest without `pinned_searches`
continues through the existing missing-source behavior unchanged.

- [ ] **Step 8: Generate, format, and run backup tests**

Run:

```bash
./gen.sh
fvm dart format lib/core/backups lib/core/search/subscriptions test/core/backups
fvm flutter test test/core/backups/pinned_search_backup_codec_test.dart
fvm flutter test test/core/backups/pinned_search_import_service_test.dart
fvm flutter test test/core/backups/pinned_searches_source_test.dart
```

Expected: PASS.

- [ ] **Step 9: Commit backup support**

```bash
git add lib/core/backups lib/core/search/subscriptions packages/i18n test/core/backups
git commit -m "feat(search): back up pinned searches"
```

---

### Task 9: Cross-feature verification and durable documentation

**Files:**
- Create: `docs/pinned_searches.md`
- Modify only if verification exposes a defect: files introduced or listed in Tasks 1–8.

**Interfaces:**
- Consumes: the complete feature.
- Produces: verified behavior and durable project documentation for later folder,
  automatic-refresh, and feed phases.

- [ ] **Step 1: Add subsystem documentation**

Write `docs/pinned_searches.md` with the implemented boundaries only:

- persisted aggregate and profile ownership;
- exact definition of baseline/new/read;
- chronological scanner invariants and unsupported-query behavior;
- manual Refresh All priority/concurrency;
- profile deletion and backup lifecycle;
- links to the design and implementation plan;
- a short “Deferred roadmap” pointer to the design spec rather than duplicating
  its future requirements.

Do not describe unimplemented folders, schedulers, or feeds as current behavior.

- [ ] **Step 2: Format all changed Dart files**

Run:

```bash
fvm dart format lib test
```

Expected: exits 0.

- [ ] **Step 3: Run static analysis**

Run: `fvm flutter analyze`

Expected: exits 0 with no errors or warnings introduced by the feature.

- [ ] **Step 4: Run the complete focused test group**

Run: `fvm flutter test test/core/search/subscriptions test/core/backups/pinned_search_backup_codec_test.dart test/core/backups/pinned_search_import_service_test.dart test/core/backups/pinned_searches_source_test.dart test/booru_config_notifier_test.dart`

Expected: PASS.

- [ ] **Step 5: Run the full test suite**

Run: `fvm flutter test`

Expected: PASS. If an unrelated pre-existing failure occurs, record its exact
test name and verify the focused suite still passes; do not weaken tests.

- [ ] **Step 6: Verify generated and repository state**

Run:

```bash
git diff --check
git status --short
```

Expected: no whitespace errors; only intended feature, generated, translation,
test, and documentation files remain uncommitted.

- [ ] **Step 7: Manually exercise the observable flow where supported**

Verify in a development build:

1. Search for a non-empty query and pin it with no custom name.
2. Confirm its card uses the query as its label, has four or fewer previews,
   and has zero unread.
3. Pin another query with a custom name.
4. Refresh one search after a known new upload and confirm its badge increases.
5. Open that search and confirm the badge and navigation total clear before the
   exact original query opens.
6. Refresh All and confirm progress continues if one search fails.
7. Switch profiles and confirm the list/badge changes without refreshing.
8. Delete a profile and confirm its pins disappear.
9. Export/import pins and confirm definitions return without runtime badges or
   previews.

- [ ] **Step 8: Commit verification documentation and any verified fixes**

```bash
git add docs/pinned_searches.md
git add lib test packages/i18n
git commit -m "docs(search): document pinned searches"
```

- [ ] **Step 9: Confirm branch readiness**

Run:

```bash
git status --short --branch
git log --oneline --decorate -12
```

Expected: clean `feature/pinned-search-subscriptions` branch containing the
design, plan, focused conventional commits, and no changes from the abandoned
older `feature/pinned-searches` branch.
