import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:boorusama/core/posts/favorites/src/data/confirmed_favorite_repository.dart';
import 'package:boorusama/core/posts/favorites/src/types/favorite_interruption.dart';
import 'package:boorusama/core/posts/favorites/types.dart';
import 'package:boorusama/core/posts/post/types.dart';

class _Repository extends FavoriteRepository<Post> {
  Future<AddFavoriteStatus> Function(int) add = (_) async =>
      AddFavoriteStatus.success;
  Future<bool> Function(int) remove = (_) async => true;
  int adds = 0;
  int removals = 0;

  @override
  bool canFavorite() => true;

  @override
  bool isPostFavorited(Post post) => false;

  @override
  Future<List<int>> filterFavoritedPosts(List<int> postIds) async => postIds;

  @override
  Future<AddFavoriteStatus> addToFavorites(int id) {
    adds++;
    return add(id);
  }

  @override
  Future<bool> removeFromFavorites(int id) {
    removals++;
    return remove(id);
  }
}

void main() {
  late _Repository delegate;
  late List<(int, bool)> applied;
  late List<Object> failures;
  late ConfirmedFavoriteRepository<Post> repository;

  setUp(() {
    delegate = _Repository();
    applied = [];
    failures = [];
    repository = ConfirmedFavoriteRepository(
      delegate: delegate,
      prepareProjection: (id, favorited) async => () async {
        applied.add((id, favorited));
      },
      onProjectionError: failures.add,
    );
  });

  test(
    'acknowledged addition and already-existing result project once each',
    () async {
      expect(await repository.addToFavorites(1), AddFavoriteStatus.success);
      delegate.add = (_) async => AddFavoriteStatus.alreadyExists;
      expect(
        await repository.addToFavorites(2),
        AddFavoriteStatus.alreadyExists,
      );
      expect(applied, [(1, true), (2, true)]);
    },
  );

  test('only acknowledged removal projects', () async {
    expect(await repository.removeFromFavorites(1), isTrue);
    delegate.remove = (_) async => false;
    expect(await repository.removeFromFavorites(2), isFalse);
    expect(applied, [(1, false)]);
  });

  test('remote failure and exception never project', () async {
    delegate.add = (_) async => AddFavoriteStatus.failure;
    expect(await repository.addToFavorites(1), AddFavoriteStatus.failure);
    final error = StateError('remote failure');
    delegate.add = (_) async => throw error;
    delegate.remove = (_) async => throw error;
    await expectLater(repository.addToFavorites(1), throwsA(same(error)));
    await expectLater(repository.removeFromFavorites(1), throwsA(same(error)));
    expect(applied, isEmpty);
  });

  test('local preparation failure cannot prevent a server action', () async {
    final error = StateError('local preferences unavailable');
    repository = ConfirmedFavoriteRepository(
      delegate: delegate,
      prepareProjection: (_, _) async => throw error,
      onProjectionError: failures.add,
    );
    expect(await repository.addToFavorites(1), AddFavoriteStatus.success);
    expect(delegate.adds, 1);
    expect(failures, [error]);
    expect(applied, isEmpty);
  });

  test('local write failure preserves the successful remote result', () async {
    final error = StateError('disk write failure');
    repository = ConfirmedFavoriteRepository(
      delegate: delegate,
      prepareProjection: (_, _) async =>
          () async => throw error,
      onProjectionError: failures.add,
    );
    expect(await repository.removeFromFavorites(1), isTrue);
    expect(failures, [error]);
    expect(delegate.removals, 1);
  });

  test('an error in optional feedback cannot change remote success', () async {
    repository = ConfirmedFavoriteRepository(
      delegate: delegate,
      prepareProjection: (_, _) async => throw StateError('local failure'),
      onProjectionError: (_) => throw StateError('disposed feedback'),
    );
    expect(await repository.addToFavorites(1), AddFavoriteStatus.success);
  });

  test('null projection is opt-out, without extra local writes', () async {
    repository = ConfirmedFavoriteRepository(
      delegate: delegate,
      prepareProjection: (_, _) async => null,
      onProjectionError: failures.add,
    );
    expect(await repository.addToFavorites(1), AddFavoriteStatus.success);
    expect(await repository.removeFromFavorites(1), isTrue);
    expect(applied, isEmpty);
    expect(failures, isEmpty);
  });

  test('target is captured before the remote request, not after it', () async {
    final requested = Completer<void>();
    final response = Completer<AddFavoriteStatus>();
    var target = 'original';
    final targets = <String>[];
    repository = ConfirmedFavoriteRepository(
      delegate: delegate,
      prepareProjection: (_, _) async {
        final captured = target;
        return () async => targets.add(captured);
      },
      onProjectionError: failures.add,
    );
    delegate.add = (_) {
      requested.complete();
      return response.future;
    };
    final operation = repository.addToFavorites(1);
    await requested.future;
    target = 'changed';
    response.complete(AddFavoriteStatus.success);
    await operation;
    expect(targets, ['original']);
  });

  test(
    'confirmed cleanup interruption projects, then preserves interruption',
    () async {
      final interruption = FavoriteCompletedWithInterruption(
        DioException(
          requestOptions: RequestOptions(path: '/favorites/1'),
          type: DioExceptionType.cancel,
        ),
        StackTrace.current,
      );
      delegate.remove = (_) async => throw interruption;
      await expectLater(
        repository.removeFromFavorites(1),
        throwsA(same(interruption)),
      );
      expect(applied, [(1, false)]);
    },
  );

  test('status reads never cause a local projection', () async {
    expect(repository.canFavorite(), isTrue);
    expect(await repository.filterFavoritedPosts([1, 2]), [1, 2]);
    expect(applied, isEmpty);
  });
}
