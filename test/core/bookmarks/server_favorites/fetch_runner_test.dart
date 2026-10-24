import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:boorusama/core/bookmarks/src/server_favorites/fetch_runner.dart';
import 'package:boorusama/core/bookmarks/src/server_favorites/target_settings.dart';

void main() {
  Future<int> addTo(Set<int> members, List<int> posts) async {
    final before = members.length;
    members.addAll(posts);
    return members.length - before;
  }

  test(
    'additive pagination and repeated fetches preserve local-only members',
    () async {
      final members = <int>{99};
      final requested = <int>[];
      final runner = ServerFavoriteFetchRunner<int>(
        fetchPage: (page) async {
          requested.add(page);
          return ServerFavoritePage(switch (page) {
            1 => [1, 1, 2],
            2 => [2, 3],
            _ => [],
          });
        },
        identity: (post) => post,
        validateSession: () async {},
        addPage: (posts, cancellation) => addTo(members, posts),
      );
      final first = await runner.run(
        cancellation: ServerFavoriteCancellation(),
        onProgress: (_) {},
      );
      expect(first.status, ServerFavoriteFetchStatus.completed);
      expect(first.added, 3);
      expect(first.pages, 2);
      expect(requested, [1, 2, 3]);
      final second = await runner.run(
        cancellation: ServerFavoriteCancellation(),
        onProgress: (_) {},
      );
      expect(second.added, 0);
      expect(members, {99, 1, 2, 3});
    },
  );

  test(
    'download failure saves nothing and retry safely starts at page one',
    () async {
      final members = <int>{99};
      var fail = true;
      final runner = ServerFavoriteFetchRunner<int>(
        fetchPage: (page) async {
          if (page == 2 && fail) throw StateError('HTTP 429');
          return ServerFavoritePage([page], hasMore: page < 2);
        },
        identity: (post) => post,
        validateSession: () async {},
        addPage: (posts, cancellation) => addTo(members, posts),
      );
      final first = await runner.run(
        cancellation: ServerFavoriteCancellation(),
        onProgress: (_) {},
      );
      expect(first.status, ServerFavoriteFetchStatus.failed);
      expect(first.problem, ServerFavoriteProblem.remoteFailure);
      expect(first.added, 0);
      expect(first.downloadedPages, 1);
      expect(members, {99});
      fail = false;
      final retry = await runner.run(
        cancellation: ServerFavoriteCancellation(),
        onProgress: (_) {},
      );
      expect(retry.status, ServerFavoriteFetchStatus.completed);
      expect(retry.added, 2);
      expect(members, {99, 1, 2});
    },
  );

  test(
    'cancellation discards a late network response without waiting for it',
    () async {
      final requested = Completer<void>();
      final response = Completer<ServerFavoritePage<int>>();
      final cancellation = ServerFavoriteCancellation();
      final members = <int>{};
      final run = ServerFavoriteFetchRunner<int>(
        fetchPage: (page) {
          requested.complete();
          return response.future;
        },
        identity: (post) => post,
        validateSession: () async {},
        addPage: (posts, token) => addTo(members, posts),
      ).run(cancellation: cancellation, onProgress: (_) {});
      await requested.future;
      cancellation.cancel();
      expect((await run).status, ServerFavoriteFetchStatus.cancelled);
      response.complete(ServerFavoritePage([1], hasMore: false));
      await response.future;
      expect(members, isEmpty);
    },
  );

  test(
    'cancellation waits for an accepted local page and counts its additions',
    () async {
      final committing = Completer<void>();
      final commit = Completer<int>();
      final cancellation = ServerFavoriteCancellation();
      var requests = 0;
      final run = ServerFavoriteFetchRunner<int>(
        fetchPage: (page) async {
          requests++;
          return ServerFavoritePage([page], hasMore: false);
        },
        identity: (post) => post,
        validateSession: () async {},
        addPage: (posts, token) {
          committing.complete();
          return commit.future;
        },
      ).run(cancellation: cancellation, onProgress: (_) {});
      await committing.future;
      cancellation.cancel();
      commit.complete(1);
      final result = await run;
      expect(result.status, ServerFavoriteFetchStatus.cancelled);
      expect(result.added, 1);
      expect(result.pages, 1);
      expect(requests, 1);
    },
  );

  test('changed account or target rejects an in-flight page', () async {
    for (final problem in [
      ServerFavoriteProblem.accountChanged,
      ServerFavoriteProblem.targetChanged,
      ServerFavoriteProblem.targetMissing,
    ]) {
      var valid = true;
      final members = <int>{};
      final result = await ServerFavoriteFetchRunner<int>(
        fetchPage: (page) async {
          valid = false;
          return ServerFavoritePage([1], hasMore: false);
        },
        identity: (post) => post,
        validateSession: () async {
          if (!valid) throw ServerFavoriteException(problem);
        },
        addPage: (posts, token) => addTo(members, posts),
      ).run(cancellation: ServerFavoriteCancellation(), onProgress: (_) {});
      expect(result.problem, problem);
      expect(members, isEmpty);
    }
  });

  test('repeated nonterminal pages stop instead of looping forever', () async {
    var requests = 0;
    final members = <int>{};
    final result = await ServerFavoriteFetchRunner<int>(
      fetchPage: (page) async {
        requests++;
        return ServerFavoritePage([1]);
      },
      identity: (post) => post,
      validateSession: () async {},
      addPage: (posts, token) => addTo(members, posts),
    ).run(cancellation: ServerFavoriteCancellation(), onProgress: (_) {});
    expect(result.problem, ServerFavoriteProblem.paginationStalled);
    expect(result.added, 0);
    expect(requests, 2);
  });

  test('a short page is not assumed to be the last page', () async {
    final members = <int>{};
    final result = await ServerFavoriteFetchRunner<int>(
      fetchPage: (page) async => ServerFavoritePage(
        page < 4 ? [page] : [],
      ),
      identity: (post) => post,
      validateSession: () async {},
      addPage: (posts, token) => addTo(members, posts),
    ).run(cancellation: ServerFavoriteCancellation(), onProgress: (_) {});
    expect(result.status, ServerFavoriteFetchStatus.completed);
    expect(members, {1, 2, 3});
  });

  test(
    'download timeouts leave existing bookmarks intact and hide raw request data',
    () async {
      final members = <int>{};
      final result = await ServerFavoriteFetchRunner<int>(
        fetchPage: (page) async {
          if (page == 2) throw TimeoutException('private request details');
          return ServerFavoritePage([page]);
        },
        identity: (post) => post,
        validateSession: () async {},
        addPage: (posts, token) => addTo(members, posts),
      ).run(cancellation: ServerFavoriteCancellation(), onProgress: (_) {});
      expect(result.problem, ServerFavoriteProblem.timedOut);
      expect(result.added, 0);
      expect(members, isEmpty);
    },
  );

  test(
    'saves the whole listing oldest first across pages and overlaps',
    () async {
      final saved = <int>[];
      final progress = <ServerFavoriteProgress>[];
      final result =
          await ServerFavoriteFetchRunner<int>(
            fetchPage: (page) async => ServerFavoritePage(switch (page) {
              1 => [90, 12, 12],
              2 => [12, 700, 2],
              3 => [4],
              _ => [],
            }),
            identity: (post) => post,
            validateSession: () async {},
            addPage: (posts, token) async {
              saved.addAll(posts);
              return posts.length;
            },
          ).run(
            cancellation: ServerFavoriteCancellation(),
            onProgress: progress.add,
          );
      expect(result.status, ServerFavoriteFetchStatus.completed);
      expect(saved, [4, 2, 700, 12, 90]);
      expect(result.added, 5);
      expect(result.downloadedPages, 3);
      expect(result.pages, 3);
      expect(
        progress
            .where((p) => p.phase == ServerFavoriteFetchPhase.downloading)
            .every((p) => p.added == 0 && p.pages == 0),
        isTrue,
      );
    },
  );

  test('cancellation during downloading saves no buffered pages', () async {
    final waiting = Completer<void>();
    final response = Completer<ServerFavoritePage<int>>();
    final token = ServerFavoriteCancellation();
    final saved = <int>[];
    final run = ServerFavoriteFetchRunner<int>(
      fetchPage: (page) async {
        if (page == 1) return ServerFavoritePage([3, 2]);
        waiting.complete();
        return response.future;
      },
      identity: (post) => post,
      validateSession: () async {},
      addPage: (posts, token) async {
        saved.addAll(posts);
        return posts.length;
      },
    ).run(cancellation: token, onProgress: (_) {});
    await waiting.future;
    token.cancel();
    final result = await run;
    expect(result.status, ServerFavoriteFetchStatus.cancelled);
    expect(result.downloadedPages, 1);
    expect(result.pages, 0);
    expect(saved, isEmpty);
    response.complete(ServerFavoritePage([1], hasMore: false));
  });

  test(
    'save failure preserves the oldest prefix and retry appends in order',
    () async {
      final saved = <int>{};
      var fail = true;
      final runner = ServerFavoriteFetchRunner<int>(
        fetchPage: (page) async =>
            ServerFavoritePage(page == 1 ? [6, 5] : [4, 3], hasMore: page == 1),
        identity: (post) => post,
        validateSession: () async {},
        addPage: (posts, token) async {
          if (posts.contains(6) && fail)
            throw StateError('storage unavailable');
          return addTo(saved, posts);
        },
      );
      final first = await runner.run(
        cancellation: ServerFavoriteCancellation(),
        onProgress: (_) {},
      );
      expect(first.status, ServerFavoriteFetchStatus.failed);
      expect(first.problem, ServerFavoriteProblem.localFailure);
      expect(saved.toList(), [3, 4]);
      fail = false;
      final retry = await runner.run(
        cancellation: ServerFavoriteCancellation(),
        onProgress: (_) {},
      );
      expect(retry.status, ServerFavoriteFetchStatus.completed);
      expect(retry.added, 2);
      expect(saved.toList(), [3, 4, 5, 6]);
    },
  );

  test(
    'empty page with a continuation marker is not false completion',
    () async {
      final result = await ServerFavoriteFetchRunner<int>(
        fetchPage: (_) async => ServerFavoritePage([], hasMore: true),
        identity: (post) => post,
        validateSession: () async {},
        addPage: (_, token) async => 0,
      ).run(cancellation: ServerFavoriteCancellation(), onProgress: (_) {});
      expect(result.problem, ServerFavoriteProblem.paginationStalled);
    },
  );
}
