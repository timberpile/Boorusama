import 'package:foundation/performance.dart';

// Dart imports:
import 'dart:async';
import 'dart:isolate';

// Flutter imports:
import 'package:flutter/foundation.dart';

// Project imports:
import '../../../../../foundation/platform.dart';
import '../../../../../foundation/utils/collection_utils.dart';
import '../../../../errors/types.dart';
import '../../../filter/types.dart';
import '../../../post/types.dart';
import '../types/page_mode.dart';
import 'post_duplicate_checker.dart';

const _kFirstPage = 1;
const _kJumpStep = 1;

typedef ItemFetcher<T extends Post> = Future<PostResult<T>> Function(int page);
typedef ItemRefresher<T extends Post> = Future<PostResult<T>> Function();
typedef HiddenData = ({String name, int count, bool active});
typedef PostGridFetcher<T extends Post> = PostsOrErrorCore<T> Function(
  int page,
);

extension TagCountX<T> on Map<String, Set<T>> {
  int get totalNonDuplicatesPostCount => values.expand((e) => e).toSet().length;
}

class PostGridController<T extends Post> extends ChangeNotifier {
  PostGridController({
    required this.fetcher,
    required this.blacklistedTagsFetcher,
    required this.mountedChecker,
    required PostDuplicateTracker<T> duplicateTracker,
    required this.onError,
    this.debounceDuration = const Duration(milliseconds: 500),
    PageMode pageMode = PageMode.infinite,
    this.blacklistedUrlsFetcher,
    this.forcedPageMode = false,
    this.initialPage,
    this.blacklistCounter,
  }) : _pageMode = pageMode,
       _duplicateTracker = duplicateTracker,
       _eventController = StreamController<PostControllerEvent>.broadcast() {
    if (initialPage != null) {
      _page = initialPage!;
      pageNotifier.value = initialPage!;
    }
  }

  final int? initialPage;
  final PostBlacklistCounter? blacklistCounter;
  var _blacklistGeneration = 0;
  var _rulesRevision = 0;

  final PostGridFetcher<T> fetcher;
  PageMode _pageMode;
  final Future<Set<String>> Function()? blacklistedUrlsFetcher;
  Set<String>? blacklistedTags;
  List<List<TagExpression>> _cachedParsedTags = [];
  final Future<Set<String>> Function() blacklistedTagsFetcher;
  final void Function(String message) onError;
  final bool Function() mountedChecker;
  List<T> _items = [];
  List<T> _filteredItems = [];
  final PostDuplicateTracker<T> _duplicateTracker;

  int _page = _kFirstPage;
  var _hasMore = true;
  var _loading = false;
  Completer<void>? _pendingFetchMore;
  var _refreshing = false;
  var _preserveSelectionOnRefresh = false;
  var _refreshPending = false;
  var _pendingMaintainPage = false;
  var _pendingPreserveSelection = false;
  var _disposed = false;
  final _queuedRefreshWaiters = <Completer<void>>[];
  var _requestGeneration = 0;
  var _hasLoadedPage = false;
  var _total = 0;

  Iterable<T> get items => _filteredItems;
  Iterable<T> get allItems => _items;
  bool get hasMore => _hasMore;
  bool get loading => _loading;
  bool get loadingMore => _loading || (_debounceTimer?.isActive ?? false);
  bool get refreshing => _refreshing;
  bool get preserveSelectionOnRefresh => _preserveSelectionOnRefresh;
  int get page => pageNotifier.value;
  int get total => _total;

  final ValueNotifier<int?> count = ValueNotifier(null);
  final ValueNotifier<int?> maxPage = ValueNotifier(null);
  final ValueNotifier<bool> refreshingNotifier = ValueNotifier(false);
  final ValueNotifier<List<T>> itemsNotifier = ValueNotifier(const []);
  final ValueNotifier<int> pageNotifier = ValueNotifier(_kFirstPage);
  Timer? _debounceTimer;
  final Duration debounceDuration;
  PageMode get pageMode => _pageMode;
  final activeFilters = ValueNotifier<Map<String, bool>>({});
  final tagCounts = ValueNotifier<Map<String, Set<PostBlacklistIdentity>>>({});
  final hasBlacklist = ValueNotifier(false);
  final visibleHiddenTags = ValueNotifier<List<HiddenData>>([]);
  final errors = ValueNotifier<BooruError?>(null);
  final StreamController<PostControllerEvent> _eventController;
  Stream<PostControllerEvent> get events => _eventController.stream;
  final bool forcedPageMode;

  bool _isCurrentRequest(int generation) =>
      !_disposed &&
      mountedChecker() &&
      generation == _requestGeneration &&
      !_refreshPending;

  void _invalidateFetchMore() {
    _requestGeneration++;
    _debounceTimer?.cancel();
    _debounceTimer = null;
    final pending = _pendingFetchMore;
    _pendingFetchMore = null;
    _loading = false;
    if (pending != null && !pending.isCompleted) pending.complete();
  }

  Future<PostResult<T>> _fetchPosts(int page, int generation) async {
    if (_isCurrentRequest(generation)) errors.value = null;
    final result = await fetcher(page).run();
    return result.fold(
      (error) {
        if (_isCurrentRequest(generation)) errors.value = error;
        return <T>[].toResult();
      },
      (value) => value,
    );
  }

  void _setBlacklistRules(Set<String> tags) {
    _cachedParsedTags = tags
        .map(
          (tag) => tag
              .trim()
              .split(RegExp(r'\s+'))
              .where((part) => part.isNotEmpty)
              .map(TagExpression.parse)
              .toList(),
        )
        .where((rule) => rule.isNotEmpty)
        .toList();
    blacklistedTags = _cachedParsedTags.map((rule) => rule.rawString).toSet();
    activeFilters.value = {
      for (final key in blacklistedTags!) key: activeFilters.value[key] ?? true,
    };
    _rulesRevision++;
  }

  Future<void> setBlacklistedTags(Set<String> tags) async {
    if (_disposed || !mountedChecker()) return;
    final normalized = tags
        .map(
          (tag) => tag
              .trim()
              .split(RegExp(r'\s+'))
              .where((part) => part.isNotEmpty)
              .map(TagExpression.parse)
              .rawString,
        )
        .where((rule) => rule.isNotEmpty)
        .toSet();
    if (setEquals(blacklistedTags, normalized)) return;
    _setBlacklistRules(normalized);
    await _filter();
  }

  Future<void> enableTag(String tag) async {
    if (_disposed || !mountedChecker()) return;
    final data = {...activeFilters.value};
    data[tag] = true;
    activeFilters.value = data;
    await _filter();
  }

  Future<void> disableTag(String tag) async {
    if (_disposed || !mountedChecker()) return;
    final data = {...activeFilters.value};
    data[tag] = false;
    activeFilters.value = data;
    await _filter();
  }

  Future<void> enableAllTags() async {
    if (_disposed || !mountedChecker()) return;
    activeFilters.value = activeFilters.value.map(
      (key, value) => MapEntry(key, true),
    );
    await _filter();
  }

  Future<void> disableAllTags() async {
    if (_disposed || !mountedChecker()) return;
    activeFilters.value = activeFilters.value.map(
      (key, value) => MapEntry(key, false),
    );
    await _filter();
  }

  Future<List<List<TagExpression>>> _getBlacklistedTags() async {
    if (blacklistedTags == null) {
      final revision = _rulesRevision;
      try {
        final tags = await blacklistedTagsFetcher();
        if (_disposed || !mountedChecker()) return [];
        // A late initial read cannot replace a live provider update.
        if (revision == _rulesRevision) _setBlacklistRules(tags);
      } on Exception catch (e) {
        if (!_disposed && mountedChecker()) {
          onError('Failed to fetch blacklisted tags: $e');
        }
      }
    }
    return _cachedParsedTags;
  }

  Future<void> _filter({int? requestGeneration}) async {
    if (_disposed || !mountedChecker()) return;
    final generation = ++_blacklistGeneration;
    bool isCurrent() =>
        !_disposed &&
        mountedChecker() &&
        generation == _blacklistGeneration &&
        (requestGeneration == null || _isCurrentRequest(requestGeneration));
    final posts = _items.toList();
    activeFilters.value = {
      for (final rule in _cachedParsedTags)
        rule.rawString: activeFilters.value[rule.rawString] ?? true,
    };
    final counts = await _count(posts, _cachedParsedTags, blacklistCounter);
    if (!isCurrent()) return;
    final blacklistedUrls = blacklistedUrlsFetcher != null
        ? await blacklistedUrlsFetcher!()
        : const <String>{};
    if (!isCurrent()) return;
    tagCounts.value = counts;
    hasBlacklist.value = counts.values.any((matches) => matches.isNotEmpty);
    _setFilteringItems(
      _filterPosts(posts, counts, activeFilters.value, blacklistedUrls),
    );
    _updateVisibleHiddenTags();
    notifyListeners();
  }

  void _updateVisibleHiddenTags() {
    visibleHiddenTags.value = activeFilters.value.keys
        .map(
          (e) => (
            name: e,
            count: tagCounts.value[e]?.length ?? 0,
            active: activeFilters.value[e] ?? false,
          ),
        )
        .where((e) => e.count > 0)
        .toList();
  }

  void setPageMode(PageMode? newPageMode) {
    if (forcedPageMode) return;
    if (newPageMode == null || _pageMode == newPageMode) return;
    _pageMode = newPageMode;
    _hasMore = true;
    if (newPageMode == PageMode.infinite) {
      _clear();
      _setPage(_kFirstPage);
    }
    // Reuse the refresh queue instead of starting a competing page request.
    refresh(maintainPage: newPageMode == PageMode.paginated);
    notifyListeners();
  }

  Future<void> refresh({
    bool maintainPage = false,
    bool preserveSelection = false,
  }) async {
    if (_disposed) return;
    // Cancel a queued load and revoke every older request's publication rights.
    _invalidateFetchMore();
    _hasLoadedPage = false;
    if (_refreshing) {
      final alreadyPending = _refreshPending;
      _refreshPending = true;
      _pendingMaintainPage = alreadyPending
          ? _pendingMaintainPage && maintainPage
          : maintainPage;
      _pendingPreserveSelection =
          _pendingPreserveSelection || preserveSelection;
      final waiter = Completer<void>();
      _queuedRefreshWaiters.add(waiter);
      return waiter.future;
    }
    Object? lastPassError;
    StackTrace? lastPassStackTrace;
    try {
      var nextMaintainPage = maintainPage;
      var nextPreserveSelection = preserveSelection;
      do {
        _refreshPending = false;
        _pendingMaintainPage = false;
        _pendingPreserveSelection = false;
        try {
          await _performRefresh(
            maintainPage: nextMaintainPage,
            preserveSelection: nextPreserveSelection,
          );
          lastPassError = null;
          lastPassStackTrace = null;
        } catch (error, stackTrace) {
          lastPassError = error;
          lastPassStackTrace = stackTrace;
        }
        nextMaintainPage = _pendingMaintainPage;
        nextPreserveSelection = _pendingPreserveSelection;
      } while (_refreshPending && !_disposed);
      for (final waiter in _queuedRefreshWaiters) {
        if (lastPassError == null) {
          waiter.complete();
        } else {
          waiter.completeError(lastPassError, lastPassStackTrace);
        }
      }
      if (lastPassError != null) {
        Error.throwWithStackTrace(lastPassError, lastPassStackTrace!);
      }
    } finally {
      _queuedRefreshWaiters.clear();
      if (_refreshing && !_disposed) {
        _setRefreshing(false);
        notifyListeners();
      } else {
        _refreshing = false;
      }
    }
  }

  Future<void> _performRefresh({
    required bool maintainPage,
    required bool preserveSelection,
  }) async {
    if (_disposed || !mountedChecker()) return;
    final generation = _requestGeneration;
    _preserveSelectionOnRefresh = preserveSelection;
    try {
      _setRefreshing(true);
      _eventController.add(const PostControllerRefreshStarted());
      _setPage(switch (_pageMode) {
        PageMode.infinite => _kFirstPage,
        PageMode.paginated =>
          (maintainPage || forcedPageMode) ? _page : _kFirstPage,
      });
      count.value = null;
      maxPage.value = null;
      notifyListeners();
      final newItems = await _fetchPosts(_page, generation);
      if (!_isCurrentRequest(generation)) return;
      _clear();
      await _addAll(newItems.posts, generation);
      if (!_isCurrentRequest(generation)) return;
      _hasLoadedPage = errors.value == null;
      _hasMore = _canLoadMore(newItems);
      count.value = newItems.total;
      maxPage.value = newItems.maxPage;
      _eventController.add(const PostControllerRefreshCompleted());
      notifyListeners();
    } finally {
      _preserveSelectionOnRefresh = false;
    }
  }

  bool _canLoadMore(PostResult<T> result) {
    if (errors.value != null) return true;
    if (result.hasMore case final more?) return more;
    // A search-depth cap is an upper bound, not proof of more results.
    if (result.total case final knownTotal? when knownTotal >= 0) {
      if (knownTotal == 0 ||
          ((_pageMode == PageMode.infinite || _page == _kFirstPage) &&
              _items.length >= knownTotal)) {
        return false;
      }
    }
    if (result.maxPage case final last? when last >= 0) {
      return _page < last;
    }
    // A later paginated page cannot infer its source stride from retained posts.
    return result.posts.isNotEmpty;
  }

  Future<void> fetchMore({VoidCallback? onNoMoreData}) {
    if (_disposed || _refreshing) return Future.value();
    if (_pendingFetchMore case final pending?) return pending.future;
    if (_loading || !_hasMore) return Future.value();
    // A successful empty filtered page may advance; a failed initial page may not.
    if (!_hasLoadedPage) return refresh(maintainPage: true);

    final generation = _requestGeneration;
    final pending = _pendingFetchMore = Completer<void>();
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounceDuration, () async {
      final previousPage = _page;
      try {
        if (!_isCurrentRequest(generation) || _refreshing) return;
        _loading = true;
        if (_pageMode == PageMode.infinite) _setPage(previousPage + 1);
        notifyListeners();
        final newItems = await _fetchPosts(_page, generation);
        if (!_isCurrentRequest(generation)) return;
        if (errors.value != null) {
          if (_pageMode == PageMode.infinite) _setPage(previousPage);
          return;
        }
        if (newItems.posts.isNotEmpty) {
          await _addAll(newItems.posts, generation);
        }
        if (!_isCurrentRequest(generation)) return;
        _hasMore = _canLoadMore(newItems);
        if (!_hasMore && newItems.posts.isEmpty) onNoMoreData?.call();
        count.value = newItems.total;
        maxPage.value = newItems.maxPage;
      } catch (error) {
        if (_isCurrentRequest(generation)) {
          if (_pageMode == PageMode.infinite) _setPage(previousPage);
          errors.value = UnknownError(error: error, message: error.toString());
        }
      } finally {
        // An obsolete completion must not clear a newer request's latch/state.
        if (identical(_pendingFetchMore, pending)) {
          _loading = false;
          _pendingFetchMore = null;
          _debounceTimer = null;
          if (!_disposed) notifyListeners();
        }
        if (!pending.isCompleted) pending.complete();
      }
    });
    notifyListeners();
    return pending.future;
  }

  Future<void> jumpToPage(int targetPage) async {
    if (_disposed ||
        _pageMode != PageMode.paginated ||
        _loading ||
        _refreshing) {
      return;
    }
    _setPage(targetPage > 0 ? targetPage : _kFirstPage);
    await refresh(maintainPage: true);
  }

  Future<void> goToPreviousPage() async {
    if (hasPreviousPage()) await jumpToPage(_page - _kJumpStep);
  }

  Future<void> goToNextPage() async {
    if (hasNextPage()) await jumpToPage(_page + _kJumpStep);
  }

  bool hasPreviousPage() =>
      _pageMode == PageMode.paginated && _page > _kFirstPage;
  bool hasNextPage() =>
      _pageMode == PageMode.paginated && _hasLoadedPage && _hasMore;

  void moveAndInsert({
    required int fromIndex,
    required int toIndex,
    void Function()? onSuccess,
  }) {
    final data = [..._items]..reorder(fromIndex, toIndex);
    onSuccess?.call();
    _items = data;
    _setFilteringItems(data);
    unawaited(_filter());
    notifyListeners();
  }

  void remove(List<int> postIds, int Function(T item) itemIdExtractor) {
    final data = [..._items]
      ..removeWhere((e) => postIds.contains(itemIdExtractor(e)));
    _duplicateTracker.rebuildFrom(data);
    _items = data;
    _setFilteringItems(data);
    unawaited(_filter());
    notifyListeners();
  }

  Future<void> _addAll(List<T> newItems, int generation) =>
      performanceRecorder.measureAsync(
        PerfOperation.gridIngest,
        () => _ingest(newItems, generation),
        items: newItems.length,
      );

  Future<void> _ingest(List<T> newItems, int generation) async {
    if (!_isCurrentRequest(generation)) return;
    final before = _items.length;
    performanceRecorder.measureSync(PerfOperation.gridDeduplicate, () {
      for (final item in newItems) {
        if (!_duplicateTracker.isDuplicate(item)) {
          _items.add(item);
          _duplicateTracker.trackItem(item);
        }
      }
    }, items: newItems.length);
    performanceRecorder.count(
      PerfCounter.gridIngestCandidates,
      newItems.length,
    );
    performanceRecorder.count(
      PerfCounter.gridIngestAccepted,
      _items.length - before,
    );
    _total = _items.length;

    await _getBlacklistedTags();
    if (!_isCurrentRequest(generation)) return;
    await _filter(requestGeneration: generation);
  }

  void _clear() {
    _blacklistGeneration++;
    _items.clear();
    _filteredItems.clear();
    _total = 0;
    _setFilteringItems([]);
    _duplicateTracker.clear();
    tagCounts.value = {};
    hasBlacklist.value = false;
    activeFilters.value = {};
    visibleHiddenTags.value = [];
    notifyListeners();
  }

  void _setRefreshing(bool value) {
    _refreshing = value;
    refreshingNotifier.value = value;
  }

  void _setPage(int page) {
    _page = page;
    pageNotifier.value = page;
  }

  void _setFilteringItems(List<T> items) {
    performanceRecorder.measureSync(PerfOperation.gridPublish, () {
      _filteredItems = items;
      itemsNotifier.value = items;
    }, items: items.length);
  }

  @override
  void dispose() {
    _disposed = true;
    _blacklistGeneration++;
    _refreshing = false;
    _invalidateFetchMore();
    _eventController.close();
    itemsNotifier.dispose();
    count.dispose();
    maxPage.dispose();
    refreshingNotifier.dispose();
    pageNotifier.dispose();
    activeFilters.dispose();
    tagCounts.dispose();
    hasBlacklist.dispose();
    visibleHiddenTags.dispose();
    errors.dispose();
    super.dispose();
  }
}

List<T> _filterPosts<T extends Post>(
  List<T> items,
  Map<String, Set<PostBlacklistIdentity>> tagCounts,
  Map<String, bool> activeFilters,
  Set<String> blacklistedUrls,
) {
  final performanceSpan = performanceRecorder.begin(
    PerfOperation.gridFilter,
    PerfSpanKind.sync,
    items: items.length,
  );
  var performanceFailed = false;
  try {
    return items.where((e) {
      for (final entry in tagCounts.entries) {
        if ((activeFilters[entry.key] ?? false) &&
            entry.value.contains(_blacklistIdentity(e))) {
          return false;
        }
      }
      if (blacklistedUrls.contains(e.originalImageUrl)) return false;
      return true;
    }).toList();
  } catch (_) {
    performanceFailed = true;
    rethrow;
  } finally {
    performanceSpan.finish(failed: performanceFailed);
  }
}

// Primitive records remain transferable to the native counting isolate.
typedef PostBlacklistIdentity = (int type, String source, int postId);
typedef PostCountData = ({
  TagFilterData filterData,
  PostBlacklistIdentity identity,
});
typedef PostBlacklistCounter =
    Future<Map<String, Set<PostBlacklistIdentity>>> Function(
      List<PostCountData> posts,
      List<List<TagExpression>> rules,
    );

PostBlacklistIdentity _blacklistIdentity(Post post) => (
  post.origin.booruType.id,
  post.origin.sourceHost.isEmpty
      ? 'profile:${post.origin.profileIdHint ?? post.origin.booruId}'
      : post.origin.sourceHost,
  post.id,
);

Future<Map<String, Set<PostBlacklistIdentity>>> _count<T extends Post>(
  Iterable<T> posts,
  List<List<TagExpression>> parsedTags,
  PostBlacklistCounter? counter,
) async {
  if (parsedTags.isEmpty) return {};
  final payload = performanceRecorder.measureSync(
    PerfOperation.gridCountPayload,
    () => posts
        .map(
          (post) => (
            filterData: post.extractTagFilterData(),
            identity: _blacklistIdentity(post),
          ),
        )
        .toList(),
  );
  if (counter != null) return counter(payload, parsedTags);
  return switch (isWeb()) {
    true => countPostBlacklistMatches(payload, parsedTags),
    false => await Isolate.run(
      () => countPostBlacklistMatches(payload, parsedTags),
    ),
  };
}

Map<String, Set<PostBlacklistIdentity>> countPostBlacklistMatches(
  List<PostCountData> postData,
  List<List<TagExpression>> parsedTags,
) {
  final tagCounts = <String, Set<PostBlacklistIdentity>>{};
  for (final data in postData) {
    for (final pattern in parsedTags) {
      if (checkIfTagsContainsTagExpression(data.filterData, pattern)) {
        tagCounts.putIfAbsent(pattern.rawString, () => {}).add(data.identity);
      }
    }
  }
  return tagCounts;
}

abstract class PostControllerEvent {
  const PostControllerEvent();
}

class PostControllerRefreshStarted extends PostControllerEvent {
  const PostControllerRefreshStarted();
}

class PostControllerRefreshCompleted extends PostControllerEvent {
  const PostControllerRefreshCompleted();
}
