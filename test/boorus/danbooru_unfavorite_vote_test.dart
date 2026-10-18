import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:booru_clients/danbooru.dart';
import 'package:boorusama/boorus/danbooru/client_provider.dart';
import 'package:boorusama/boorus/danbooru/posts/favorites/src/data/providers.dart';
import 'package:boorusama/boorus/danbooru/posts/votes/providers.dart';
import 'package:boorusama/boorus/danbooru/users/user/providers.dart';
import 'package:boorusama/boorus/danbooru/users/user/types.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/posts/favorites/providers.dart';
import 'package:boorusama/core/posts/favorites/src/data/providers.dart';
import 'package:boorusama/core/posts/favorites/types.dart';
import 'package:boorusama/core/posts/votes/types.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes/test_post.dart';

void main() {
  final config = BooruConfig.defaultConfig(
    booruType: BooruType.danbooru,
    url: 'https://site.test',
    customDownloadFileNameFormat: null,
  ).auth;

  ProviderContainer containerFor(_DanbooruServer server) {
    final dio = Dio(BaseOptions(baseUrl: config.url))
      ..httpClientAdapter = server;
    final container = ProviderContainer(
      overrides: [
        danbooruClientProvider(config)
            .overrideWithValue(DanbooruClient(baseUrl: config.url, dio: dio)),
        danbooruCurrentUserProvider(config)
            .overrideWith((ref) => Future.value(UserSelf.placeholder())),
        favoriteRepoProvider(config).overrideWith(
          (ref) => ref.watch(danbooruFavoriteRepoProvider(config)),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  VoteState vote(ProviderContainer container) =>
      container.read(danbooruPostVotesProvider(config))[1]?.voteState ??
      VoteState.unvote;

  test('favorite then unfavorite clears the automatic upvote without a second mutation', () async {
    final server = _DanbooruServer();
    final container = containerFor(server);
    final favorites = container.read(favoritesProvider(config).notifier);
    final votes = container.read(danbooruPostVotesProvider(config).notifier);
    expect(await favorites.add(1), AddFavoriteStatus.success);
    expect(vote(container), VoteState.upvoted);
    expect(await favorites.remove(1), isTrue);
    expect(server.score, 0);
    expect(vote(container), VoteState.unvote);
    expect(container.read(favoritesProvider(config))[1], isFalse);
    expect(server.requests, [
      'POST /favorites.json',
      'DELETE /favorites/1.json',
    ]);

    // Ordinary voting/removal still uses the actual server vote ID.
    await votes.upvote(1);
    expect(vote(container), VoteState.upvoted);
    final id = container.read(danbooruPostVotesProvider(config))[1]!.voteId;
    expect(await votes.removeVote(1, id), isTrue);
    expect(vote(container), VoteState.unvote);
    expect(server.score, 0);
    expect(server.requests.last, 'DELETE /post_votes/9.json');
  });

  test('unfavoriting preserves a downvote', () async {
    final server = _DanbooruServer();
    final container = containerFor(server);
    final favorites = container.read(favoritesProvider(config).notifier);
    await favorites.add(1);
    await container
        .read(danbooruPostVotesProvider(config).notifier)
        .downvote(1);
    server.requests.clear();
    expect(await favorites.remove(1), isTrue);
    expect(server.score, -1);
    expect(vote(container), VoteState.downvoted);
    expect(server.requests, ['DELETE /favorites/1.json']);
  });

  test(
    'failed unfavoriting preserves the favorite and automatic upvote',
    () async {
      final server = _DanbooruServer()..failRemoval = true;
      final container = containerFor(server);
      final favorites = container.read(favoritesProvider(config).notifier);
      await favorites.add(1);
      expect(await favorites.remove(1), isFalse);
      expect(container.read(favoritesProvider(config))[1], isTrue);
      expect(vote(container), VoteState.upvoted);
      expect(server.score, 1);
    },
  );

  test(
    'a stale vote preload cannot resurrect the upvote after unfavoriting',
    () async {
      final server = _DanbooruServer()..score = 1;
      final release = Completer<void>();
      server.holdFirstLookup = release.future;
      final container = containerFor(server);
      final votes = container.read(danbooruPostVotesProvider(config).notifier);
      final preload = votes.getVotes([TestPost(id: 1)]);
      await server.lookupStarted.future;
      final favorites = container.read(favoritesProvider(config).notifier);
      await favorites.add(1);
      expect(await favorites.remove(1), isTrue);
      release.complete();
      await preload;
      expect(vote(container), VoteState.unvote);
      expect(server.score, 0);
    },
  );
}

// Danbooru's Favorite.after_destroy removes positive votes on the server.
// Use the real client/repositories to reproduce the empty subsequent vote lookup.
class _DanbooruServer implements HttpClientAdapter {
  var score = 0;
  var failRemoval = false;
  final requests = <String>[];
  final lookupStarted = Completer<void>();
  Future<void>? holdFirstLookup;

  Map<String, Object> get vote => {
    'id': 9,
    'post_id': 1,
    'user_id': 0,
    'score': score,
    'is_deleted': false,
    'created_at': '2026-01-01T00:00:00Z',
    'updated_at': '2026-01-01T00:00:00Z',
  };

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final request = '${options.method} ${options.path}';
    requests.add(request);
    Object data = <String, Object>{};
    var status = 200;
    switch (request) {
      case 'POST /favorites.json':
        score = 1;
      case 'DELETE /favorites/1.json':
        if (failRemoval) {
          status = 500;
        } else if (score > 0) {
          score = 0;
        }
      case 'POST /posts/1/votes.json':
        score = options.queryParameters['score'] as int;
        data = vote;
      case 'GET /post_votes.json':
        data = [if (score != 0) vote];
        if (!lookupStarted.isCompleted) {
          lookupStarted.complete();
          await holdFirstLookup;
        }
      case 'DELETE /post_votes/9.json':
        score = 0;
      default:
        throw StateError('Unexpected request: $request');
    }
    return ResponseBody.fromString(
      jsonEncode(data),
      status,
      headers: {
        'content-type': ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
