// Dart imports:
import 'dart:async';

// Package imports:
import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../../../boorus/engine/providers.dart';
import '../../../../configs/manage/providers.dart';
import '../../../../posts/post/providers.dart';
import '../data/providers.dart';
import '../refresh/chronological_search_scanner.dart';
import '../refresh/search_refresh_query_adapter.dart';
import '../services/search_refresh_service.dart';
import '../types/search_refresh.dart';
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
  }) : subscriptions = List.unmodifiable(subscriptions),
       refreshingIds = Set.unmodifiable(refreshingIds);

  final List<SearchSubscription> subscriptions;
  final Set<String> refreshingIds;
  final int batchCompleted;
  final int batchTotal;
  final int? batchProfileId;

  @override
  List<Object?> get props => [
    subscriptions,
    refreshingIds,
    batchCompleted,
    batchTotal,
    batchProfileId,
  ];
}

class SearchSubscriptionsNotifier
    extends AsyncNotifier<SearchSubscriptionsState> {
  SearchSubscriptionsNotifier({SearchRefreshService? refreshService})
    : _refreshService = refreshService;

  final SearchRefreshService? _refreshService;
  final Map<String, Future<SearchRefreshOutcome>> _inFlight = {};
  Future<void> _mutationTail = Future.value();
  Future<void> _batchTail = Future.value();
  var _batchCompleted = 0;
  var _batchTotal = 0;
  int? _batchProfileId;
  var _disposed = false;

  @override
  Future<SearchSubscriptionsState> build() async {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    return _snapshot(await (await _repository).getAll());
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

  Future<({SearchSubscription subscription, SearchRefreshOutcome refresh})>
  pin({
    required int profileId,
    required String query,
    required String? name,
  }) async {
    final subscription = await _mutate((repository) async {
      final existing = await repository.findByQuery(profileId, query);
      return switch (existing) {
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

  Future<SearchRefreshOutcome> refresh(String id) {
    return _inFlight[id] ??= _refresh(id).whenComplete(() {
      _inFlight.remove(id);
      _publishActivity();
    });
  }

  Future<SearchRefreshOutcome> _refresh(String id) async {
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
        refreshingIds: _inFlight.keys.toSet(),
        batchCompleted: _batchCompleted,
        batchTotal: _batchTotal,
        batchProfileId: _batchProfileId,
      );
}
