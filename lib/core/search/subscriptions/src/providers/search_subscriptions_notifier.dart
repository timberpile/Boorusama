// Dart imports:
import 'dart:async';

// Package imports:
import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

// Project imports:
import '../../../../boorus/engine/providers.dart';
import '../../../../configs/manage/providers.dart';
import '../../../../configs/config/types.dart';
import '../../../../posts/post/providers.dart';
import '../data/providers.dart';
import '../refresh/chronological_search_scanner.dart';
import '../refresh/search_refresh_query_adapter.dart';
import '../services/search_refresh_service.dart';
import '../services/search_refresh_request_gate.dart';
import '../types/search_refresh.dart';
import '../types/search_following_feed.dart';
import '../types/search_organization.dart';
import '../types/search_subscription.dart';
import '../types/search_subscription_repository.dart';

final searchSubscriptionsProvider =
    AsyncNotifierProvider<
      SearchSubscriptionsNotifier,
      SearchSubscriptionsState
    >(SearchSubscriptionsNotifier.new);

class SearchSubscriptionsState extends Equatable {
  SearchSubscriptionsState({
    required List<SearchSubscription> subscriptions,
    required Set<String> refreshingIds,
    required this.batchCompleted,
    required this.batchTotal,
    this.batchProfileId,
    this.feeds = const [],
    required this.organization,
  }) : subscriptions = List.unmodifiable(subscriptions),
       refreshingIds = Set.unmodifiable(refreshingIds);

  final List<SearchSubscription> subscriptions;
  final Set<String> refreshingIds;
  final int batchCompleted;
  final int batchTotal;
  final int? batchProfileId;
  final List<SearchFollowingFeed> feeds;
  final SearchOrganization organization;

  @override
  List<Object?> get props => [
    subscriptions,
    refreshingIds,
    batchCompleted,
    batchTotal,
    batchProfileId,
    feeds,
    organization,
  ];
}

class SearchSubscriptionsNotifier
    extends AsyncNotifier<SearchSubscriptionsState> {
  SearchSubscriptionsNotifier({SearchRefreshService? refreshService})
    : _refreshService = refreshService;

  final SearchRefreshService? _refreshService;
  final Map<String, Future<SearchRefreshOutcome>> _inFlight = {};
  final _requestGate = SearchRefreshRequestGate();
  Future<void> _mutationTail = Future.value();
  Future<void> _batchTail = Future.value();
  var _batchCompleted = 0;
  var _batchTotal = 0;
  int? _batchProfileId;
  var _disposed = false;
  List<SearchFollowingFeed> _feeds = const [];
  SearchOrganization _organization = SearchOrganization(
    folders: const [],
    homeSearchIds: const [],
  );

  @override
  Future<SearchSubscriptionsState> build() async {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    final repository = await _repository;
    _feeds = await repository.getFeeds();
    _organization = await repository.getOrganization();
    return _snapshot(await repository.getAll());
  }

  Future<SearchSubscriptionRepository> get _repository =>
      ref.read(searchSubscriptionRepositoryProvider.future);

  SearchRefreshService _service(SearchSubscriptionRepository repository) =>
      _refreshService ??
      SearchRefreshService(
        repository: repository,
        resolvePostRepository: (config) => ref.read(postRepoProvider(config)),
        resolveQueryAdapter: (config) =>
            ref
                .read(booruEngineRegistryProvider)
                .getRepository(config.booruType)
                ?.searchRefreshQueryAdapter(config) ??
            const UnsupportedSearchRefreshQueryAdapter(),
        scanner: ChronologicalSearchScanner(),
      );

  Future<SearchFollowingFeed> saveFeed({
    required int profileId,
    required String name,
    required List<String> queries,
    String? id,
  }) => runSerializedMutation((repository) {
    final config = ref
        .read(booruConfigProvider)
        .where((c) => c.id == profileId)
        .firstOrNull;
    if (config == null) throw StateError('Missing feed profile');
    final adapter = ref
        .read(booruRepoProvider(config.auth))
        ?.searchRefreshQueryAdapter(config.auth);
    if (adapter == null ||
        !adapter.isSupported ||
        queries.any(
          (q) =>
              adapter.plan(q, after: null) is UnsupportedSearchRefreshQueryPlan,
        )) {
      throw const FormatException('Unsupported feed query');
    }
    return repository.saveFeed(
      profileId: profileId,
      name: name,
      queries: queries,
      id: id,
    );
  });

  Future<void> deleteFeed(String id) =>
      runSerializedMutation((repository) => repository.deleteFeed(id));

  Future<void> markFeedRead(String id) =>
      runSerializedMutation((repository) async {
        for (final source in (await repository.getAll()).where(
          (s) => s.feedId == id,
        )) {
          await repository.markRead(source.id);
        }
      });

  Future<void> refreshFeed(String id) async {
    await future;
    final sources =
        state.valueOrNull?.subscriptions
            .where((s) => s.feedId == id)
            .toList() ??
        [];
    sources.sort(compareSearchRefreshPriority);
    for (final source in sources.take(10)) {
      await refresh(source.id);
    }
  }

  Future<SharedSearchFolder> createSharedFolder(String name) =>
      _mutate((repository) async {
        final folder = SharedSearchFolder(
          id: const Uuid().v4(),
          name: name,
          searchIds: const [],
        );
        final organization = await repository.getOrganization();
        await repository.replaceOrganization(
          SearchOrganization(
            folders: [...organization.folders, folder],
            homeSearchIds: organization.homeSearchIds,
          ),
        );
        return folder;
      });

  Future<SharedSearchFolder> createSharedFolderAndMovePin(
    String searchId,
    String name,
  ) => _mutate((repository) async {
    await _requireIndependentPin(repository, searchId);
    final folder = SharedSearchFolder(
      id: const Uuid().v4(),
      name: name,
      searchIds: [searchId],
    );
    final organization = _withoutSharedPin(
      await repository.getOrganization(),
      searchId,
    );
    await repository.replaceOrganization(
      SearchOrganization(
        folders: [...organization.folders, folder],
        homeSearchIds: organization.homeSearchIds,
      ),
    );
    return folder;
  });

  Future<void> movePinToSharedFolder(String searchId, String? folderId) =>
      _mutate((repository) async {
        await _requireIndependentPin(repository, searchId);
        final organization = _withoutSharedPin(
          await repository.getOrganization(),
          searchId,
        );
        if (folderId != null &&
            !organization.folders.any((folder) => folder.id == folderId)) {
          throw StateError('Shared folder not found');
        }
        await repository.replaceOrganization(
          SearchOrganization(
            folders: [
              for (final folder in organization.folders)
                if (folder.id == folderId)
                  SharedSearchFolder(
                    id: folder.id,
                    name: folder.name,
                    searchIds: [...folder.searchIds, searchId],
                  )
                else
                  folder,
            ],
            homeSearchIds: [
              ...organization.homeSearchIds,
              if (folderId == null) searchId,
            ],
          ),
        );
      });

  Future<void> reorderSharedPins(
    String? folderId,
    int oldIndex,
    int newIndex,
  ) => _mutate((repository) async {
    final organization = await repository.getOrganization();
    final ids = folderId == null
        ? organization.homeSearchIds.toList()
        : organization.folders
              .singleWhere((folder) => folder.id == folderId)
              .searchIds
              .toList();
    if (oldIndex < 0 ||
        oldIndex >= ids.length ||
        newIndex < 0 ||
        newIndex >= ids.length) {
      return;
    }
    final pin = ids.removeAt(oldIndex);
    ids.insert(newIndex, pin);
    await repository.replaceOrganization(
      SearchOrganization(
        folders: [
          for (final folder in organization.folders)
            if (folder.id == folderId)
              SharedSearchFolder(
                id: folder.id,
                name: folder.name,
                searchIds: ids,
              )
            else
              folder,
        ],
        homeSearchIds: folderId == null ? ids : organization.homeSearchIds,
      ),
    );
  });

  Future<void> renameSharedFolder(String id, String name) =>
      _mutate((repository) async {
        final organization = await repository.getOrganization();
        organization.folders.singleWhere((folder) => folder.id == id);
        await repository.replaceOrganization(
          SearchOrganization(
            folders: [
              for (final folder in organization.folders)
                if (folder.id == id)
                  SharedSearchFolder(
                    id: id,
                    name: name,
                    searchIds: folder.searchIds,
                  )
                else
                  folder,
            ],
            homeSearchIds: organization.homeSearchIds,
          ),
        );
      });

  Future<void> reorderSharedFolders(int oldIndex, int newIndex) =>
      _mutate((repository) async {
        final organization = await repository.getOrganization();
        final folders = organization.folders.toList();
        if (oldIndex < 0 ||
            oldIndex >= folders.length ||
            newIndex < 0 ||
            newIndex >= folders.length) {
          return;
        }
        final folder = folders.removeAt(oldIndex);
        folders.insert(newIndex, folder);
        await repository.replaceOrganization(
          SearchOrganization(
            folders: folders,
            homeSearchIds: organization.homeSearchIds,
          ),
        );
      });

  Future<void> deleteSharedFolderAndPins(String folderId) =>
      _mutate((repository) => repository.deleteSharedFolderAndPins(folderId));

  Future<List<SearchRefreshOutcome>> refreshSharedFolder(
    String folderId,
  ) async {
    await future;
    final current = state.requireValue;
    final ids = current.organization.folders
        .singleWhere((folder) => folder.id == folderId)
        .searchIds
        .toSet();
    final items =
        current.subscriptions
            .where((search) => search.feedId == null && ids.contains(search.id))
            .toList()
          ..sort(compareSearchRefreshPriority);
    return [for (final item in items) await refresh(item.id)];
  }

  Future<({SearchSubscription subscription, SearchRefreshOutcome refresh})>
  pin({
    required int profileId,
    required String query,
    required String? name,
    String? folderId,
  }) async {
    final subscription = await _mutate((repository) async {
      final existing = await repository.findByQuery(profileId, query);
      final subscription = switch (existing) {
        null => await repository.create(
          profileId: profileId,
          query: query,
          name: name,
        ),
        final saved when name != null => await repository.rename(
          saved.id,
          name,
        ),
        final saved => saved,
      };
      if (folderId != null) {
        final organization = _withoutSharedPin(
          await repository.getOrganization(),
          subscription.id,
        );
        if (!organization.folders.any((f) => f.id == folderId)) {
          throw StateError('Folder not found');
        }
        await repository.replaceOrganization(
          SearchOrganization(
            folders: [
              for (final folder in organization.folders)
                if (folder.id == folderId)
                  SharedSearchFolder(
                    id: folder.id,
                    name: folder.name,
                    searchIds: [...folder.searchIds, subscription.id],
                  )
                else
                  folder,
            ],
            homeSearchIds: organization.homeSearchIds,
          ),
        );
      }
      return subscription;
    });
    return (
      subscription: subscription,
      refresh: await refresh(subscription.id),
    );
  }

  Future<void> rename(String id, String? name) async {
    await _mutate((repository) => repository.rename(id, name));
  }

  Future<void> reorder(int profileId, int oldIndex, int newIndex) async {
    await _mutate(
      (repository) => repository.reorder(profileId, oldIndex, newIndex),
    );
  }

  Future<void> markRead(String id) async {
    await _mutate((repository) => repository.markRead(id));
  }

  Future<void> delete(String id) =>
      _mutate((repository) => repository.delete(id));

  Future<SearchRefreshOutcome> refresh(String id, {bool Function()? canStart}) {
    return _inFlight[id] ??= _refresh(id, canStart).whenComplete(() {
      _inFlight.remove(id);
      _publishActivity();
    });
  }

  Future<SearchRefreshOutcome> _refresh(String id, bool Function()? canStart) =>
      _requestGate.run(() async {
        if (!(canStart?.call() ?? true)) return const SearchRefreshDiscarded();
        return _performRefresh(id);
      });

  Future<SearchRefreshOutcome> _performRefresh(String id) async {
    await future;
    if (_disposed) return const SearchRefreshDiscarded();
    _publishActivity();
    final repository = await _repository;
    try {
      final subscription = await repository.getById(id);
      if (_disposed || subscription == null) {
        return const SearchRefreshDiscarded();
      }
      final config = ref
          .read(booruConfigProvider)
          .firstWhereOrNull((config) => config.id == subscription.profileId);
      if (config == null) return const SearchRefreshDiscarded();
      return await _service(repository).refresh(subscription, config);
    } catch (_) {
      return const SearchRefreshFailed(SearchRefreshErrorKind.other);
    } finally {
      if (!_disposed) await _serialize(() => _reload(repository));
    }
  }

  Future<List<SearchRefreshOutcome>> refreshAll(int profileId) {
    final completer = Completer<List<SearchRefreshOutcome>>();
    _batchTail = _batchTail.catchError((_) {}).then((_) async {
      try {
        completer.complete(await _refreshAll(profileId));
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  Future<List<SearchRefreshOutcome>> _refreshAll(int profileId) async {
    await future;
    final subscriptions =
        (await (await _repository).getAll())
            .where((item) => item.profileId == profileId)
            .toList()
          ..sort(compareSearchRefreshPriority);
    _batchCompleted = 0;
    _batchTotal = subscriptions.length;
    _batchProfileId = profileId;
    _publishActivity();
    final outcomes = List<SearchRefreshOutcome>.filled(
      subscriptions.length,
      const SearchRefreshDiscarded(),
    );
    var nextIndex = 0;
    Future<void> worker() async {
      while (nextIndex < subscriptions.length && !_disposed) {
        final index = nextIndex++;
        try {
          outcomes[index] = await refresh(subscriptions[index].id);
        } catch (_) {
          outcomes[index] = const SearchRefreshFailed(
            SearchRefreshErrorKind.other,
          );
        }
        _batchCompleted++;
        _publishActivity();
      }
    }

    await Future.wait(List.generate(3, (_) => worker()));
    return outcomes;
  }

  Future<T> _mutate<T>(
    Future<T> Function(SearchSubscriptionRepository repository) operation,
  ) => runSerializedMutation(operation);

  Future<void> _requireIndependentPin(
    SearchSubscriptionRepository repository,
    String id,
  ) async {
    final search = await repository.getById(id);
    if (search == null || search.feedId != null) {
      throw StateError('Independent pinned search not found');
    }
  }

  SearchOrganization _withoutSharedPin(
    SearchOrganization organization,
    String searchId,
  ) => SearchOrganization(
    folders: [
      for (final folder in organization.folders)
        SharedSearchFolder(
          id: folder.id,
          name: folder.name,
          searchIds: folder.searchIds.where((id) => id != searchId),
        ),
    ],
    homeSearchIds: organization.homeSearchIds.where((id) => id != searchId),
  );

  Future<T> runSerializedMutation<T>(
    Future<T> Function(SearchSubscriptionRepository repository) operation,
  ) => _serialize(() async {
    await future;
    final repository = await _repository;
    try {
      return await operation(repository);
    } finally {
      await _reload(repository);
    }
  });

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

  Future<void> _reload(SearchSubscriptionRepository repository) async {
    final subscriptions = await repository.getAll();
    _feeds = await repository.getFeeds();
    _organization = await repository.getOrganization();
    if (!_disposed) state = AsyncData(_snapshot(subscriptions));
  }

  void _publishActivity() {
    if (_disposed) return;
    if (state.valueOrNull case final current?) {
      state = AsyncData(_snapshot(current.subscriptions));
    }
  }

  SearchSubscriptionsState _snapshot(List<SearchSubscription> subscriptions) =>
      SearchSubscriptionsState(
        subscriptions: subscriptions,
        feeds: List.unmodifiable(_feeds),
        organization: _organization,
        refreshingIds: _inFlight.keys.toSet(),
        batchCompleted: _batchCompleted,
        batchTotal: _batchTotal,
        batchProfileId: _batchProfileId,
      );
}
