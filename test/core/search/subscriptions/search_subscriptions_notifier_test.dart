import 'dart:async';
import 'package:dio/dio.dart';
import 'package:boorusama/core/http/client/coordination.dart';
import 'package:boorusama/core/http/client/providers.dart';
import 'dart:typed_data';

import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/errors/types.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/search/subscriptions/providers.dart';
import 'package:boorusama/core/search/subscriptions/src/data/providers.dart';
import 'package:boorusama/core/search/subscriptions/src/refresh/chronological_search_scanner.dart';
import 'package:boorusama/core/search/subscriptions/src/refresh/search_refresh_query_adapter.dart';
import 'package:boorusama/core/search/subscriptions/src/services/search_refresh_service.dart';
import 'package:boorusama/core/search/subscriptions/types.dart';
import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';

import 'subscription_test_utils.dart';
import 'package:boorusama/core/search/subscriptions/src/data/hive/search_subscription_repository_hive.dart';

void main() {
  final config = BooruConfig.fromJson({
    ...BooruConfig.empty.toJson(),
    'id': '00000000-0000-4000-8000-00000000000c',
  });
  final checkpoint = DateTime.utc(2026, 9, 14, 8);
  final startedAt = DateTime.utc(2026, 9, 14, 9);
  late SearchSubscriptionRepository repository;
  late ProviderContainer container;
  late TestSearchPostRepository posts;
  late List<BooruConfig> configs;

  SearchSubscriptionsNotifier notifier() =>
      container.read(searchSubscriptionsProvider.notifier);
  SearchSubscriptionsState snapshot() =>
      container.read(searchSubscriptionsProvider).requireValue;

  Future<SearchSubscription> seed(
    String id, {
    String? profileId,
    DateTime? checkedAt,
    int unread = 0,
  }) async {
    final item = SearchSubscription(
      id: id,
      profileId: profileId ?? config.id,
      query: id,
      position: (await repository.getAll())
          .where((item) => item.profileId == (profileId ?? config.id))
          .length,
      createdAt: checkpoint,
      previews: const [],
      recentPostIdentities: const [],
      unreadCount: unread,
      lastSuccessfulCheckAt: checkedAt,
      highestSeenPostId: checkedAt == null ? null : -1,
    );
    final existing = (await repository.getAll())
        .where((other) => other.profileId == item.profileId)
        .toList();
    await repository.restoreForProfile(item.profileId, [...existing, item]);
    return item;
  }

  setUp(() {
    configs = [config];
    repository = memorySubscriptionRepository();
    posts = TestSearchPostRepository(
      (_, _, _) async => Either.of(
        PostResult(
          posts: [
            testSearchPost(1, checkpoint.add(const Duration(minutes: 1))),
          ],
          total: 1,
        ),
      ),
    );
    container = ProviderContainer(
      overrides: [
        searchSubscriptionRepositoryProvider.overrideWith(
          () => _RepositoryNotifier(repository),
        ),
        booruConfigProvider.overrideWith(
          () => BooruConfigNotifier(initialConfigs: configs),
        ),
        searchSubscriptionsProvider.overrideWith(
          () => SearchSubscriptionsNotifier(
            refreshService: SearchRefreshService(
              repository: repository,
              resolvePostRepository: (_) => posts,
              resolveQueryAdapter: (_) =>
                  const DefaultSearchRefreshQueryAdapter(),
              scanner: ChronologicalSearchScanner(),
              clock: Clock.fixed(startedAt),
            ),
          ),
        ),
      ],
    );
  });
  tearDown(() => container.dispose());

  test(
    'manual arrival interrupts a source brief cooldown wait without an attempt write or replay',
    () async {
      await seed('cat', checkedAt: checkpoint);
      final c = container.read(apiRequestCoordinatorProvider);
      final key = ApiQuotaKey.fromUri(Uri.parse('https://brief-source.test'));
      var starts = 0;
      final dio = Dio(BaseOptions(baseUrl: 'https://brief-source.test'))
        ..httpClientAdapter = _SourceAdapter((_) async {
          starts++;
          return ResponseBody.fromString(
            '',
            429,
            headers: {
              'retry-after': ['1'],
            },
          );
        });
      coordinateApiDio(dio, c);
      posts = TestSearchPostRepository((_, _, _) async {
        try {
          await dio.get('/posts');
          return Either.of(const PostResult(posts: <Post>[], total: 0));
        } on DioException catch (error) {
          final cooldown = error.error! as ApiCooldownException;
          return Either.left(RateLimitedError(cooldown.retryAt));
        }
      });
      final automatic = notifier().refresh(
        'cat',
        requestClass: ApiRequestClass.automatic,
      );
      while (c.snapshot(key).retryAt == null) {
        await Future<void>.delayed(Duration.zero);
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final manual = await notifier()
          .refresh('cat')
          .timeout(const Duration(milliseconds: 250));
      expect(manual, isA<SearchRefreshDeferred>());
      expect(
        await automatic.timeout(const Duration(milliseconds: 250)),
        isA<SearchRefreshDeferred>(),
      );
      expect(starts, 1);
      expect(snapshot().subscriptions.single.lastAttemptAt, isNull);
      expect(
        snapshot().subscriptions.single.adaptiveState.interval,
        const Duration(hours: 24),
      );
      dio.close();
    },
  );

  test(
    'started authentication does not authorize a new data admission after the deadline',
    () async {
      await seed('cat', checkedAt: checkpoint);
      final c = container.read(apiRequestCoordinatorProvider);
      final registry = ApiAuthRefreshRegistry();
      var open = true;
      var rotations = 0;
      var dataStarts = 0;
      final dio = Dio(BaseOptions(baseUrl: 'https://auth-budget.test'))
        ..httpClientAdapter = _SourceAdapter((options) async {
          if (options.path == '/auth') {
            rotations++;
            open = false;
          } else {
            dataStarts++;
          }
          return ResponseBody.fromString('', 200);
        });
      coordinateApiDio(dio, c);
      posts = TestSearchPostRepository((_, _, _) async {
        await registry.run('account', () => dio.post('/auth'));
        try {
          await dio.get('/posts');
          return Either.of(const PostResult(posts: <Post>[], total: 0));
        } on DioException catch (error) {
          expect(error.error, isA<ApiAdmissionExpired>());
          return Either.left(
            AppError(
              type: AppErrorType.cannotReachServer,
              message: 'expired admission',
            ),
          );
        }
      });
      expect(
        await notifier().refresh(
          'cat',
          requestClass: ApiRequestClass.automatic,
          canAdmit: () => open,
        ),
        isA<SearchRefreshFailed>(),
      );
      expect(rotations, 1);
      expect(dataStarts, 0);
      dio.close();
    },
  );

  test(
    'ordinary failure records one attempt when its optional retry crosses the admission deadline',
    () async {
      await seed('cat', checkedAt: checkpoint);
      final c = container.read(apiRequestCoordinatorProvider);
      var admissionOpen = true;
      var starts = 0;
      final dio = Dio(BaseOptions(baseUrl: 'https://retry-budget.test'))
        ..httpClientAdapter = _SourceAdapter((options) {
          starts++;
          admissionOpen = false;
          throw DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
          );
        });
      coordinateApiDio(dio, c);
      posts = TestSearchPostRepository((_, _, _) async {
        try {
          await dio.get('/posts');
          return Either.of(const PostResult(posts: <Post>[], total: 0));
        } on DioException catch (error) {
          expect(error.type, DioExceptionType.connectionError);
          return Either.left(
            AppError(
              type: AppErrorType.cannotReachServer,
              message: 'test connection failure',
            ),
          );
        }
      });
      final result = await notifier().refresh(
        'cat',
        requestClass: ApiRequestClass.automatic,
        canAdmit: () => admissionOpen,
      );
      expect(result, const SearchRefreshFailed(SearchRefreshErrorKind.network));
      expect(starts, 1);
      final source = snapshot().subscriptions.single;
      expect(source.lastAttemptAt, startedAt);
      expect(source.lastSuccessfulCheckAt, checkpoint);
      expect(source.adaptiveState.interval, const Duration(hours: 24));
      expect(source.adaptiveState.consecutiveEmptyAutomatic, 0);
      dio.close();
    },
  );

  for (final sameOrigin in [true, false]) {
    test(
      'manual joining a running source ${sameOrigin ? 'returns actual-origin cooldown immediately' : 'ignores unrelated cooldown and shares success'}',
      () async {
        await seed('cat', checkedAt: checkpoint);
        final c = container.read(apiRequestCoordinatorProvider);
        final entered = Completer<void>();
        final release = Completer<void>();
        var scans = 0;
        final dio = Dio(BaseOptions(baseUrl: 'https://actual-data.test'))
          ..httpClientAdapter = _SourceAdapter((options) async {
            if (options.path == '/other') {
              return ResponseBody.fromString(
                '',
                429,
                headers: {
                  'retry-after': ['60'],
                },
              );
            }
            scans++;
            entered.complete();
            await release.future;
            return ResponseBody.fromString('', 200);
          });
        coordinateApiDio(dio, c);
        posts = TestSearchPostRepository((_, _, _) async {
          await dio.get('/posts');
          return Either.of(
            PostResult(posts: [testSearchPost(2, checkpoint)], total: 1),
          );
        });
        final automatic = notifier().refresh(
          'cat',
          requestClass: ApiRequestClass.automatic,
        );
        await entered.future;
        if (sameOrigin) {
          await expectLater(dio.get('/other'), throwsA(isA<DioException>()));
        } else {
          c.recordRateLimit(
            ApiQuotaKey.fromUri(Uri.parse('https://unrelated.test')),
            retryAfter: '60',
          );
        }
        final manual = notifier().refresh('cat');
        if (sameOrigin) {
          try {
            expect(
              await manual.timeout(const Duration(milliseconds: 250)),
              isA<SearchRefreshDeferred>(),
            );
          } finally {
            release.complete();
          }
        } else {
          release.complete();
          expect(await manual, isA<SearchRefreshSucceeded>());
        }
        expect(await automatic, isA<SearchRefreshSucceeded>());
        expect(scans, 1);
        expect(
          snapshot().subscriptions.single.adaptiveState.interval,
          sameOrigin ? const Duration(hours: 12) : const Duration(hours: 24),
        );
        dio.close();
      },
    );
  }

  test(
    'manual owner survives automatic cancellation while sharing one scan',
    () async {
      await seed('cat', checkedAt: checkpoint);
      final fetched = Completer<void>();
      final release = Completer<void>();
      var requests = 0;
      posts = TestSearchPostRepository((_, _, _) async {
        requests++;
        fetched.complete();
        await release.future;
        return Either.of(
          PostResult(posts: [testSearchPost(2, checkpoint)], total: 1),
        );
      });
      final token = CancelToken();
      final automatic = notifier().refresh(
        'cat',
        requestClass: ApiRequestClass.automatic,
        cancelToken: token,
      );
      await fetched.future;
      final manual = notifier().refresh('cat');
      token.cancel();
      release.complete();
      expect(await manual, isA<SearchRefreshSucceeded>());
      await automatic;
      expect(requests, 1);
      expect(
        snapshot().subscriptions.single.adaptiveState.interval,
        const Duration(hours: 24),
      );
    },
  );

  test(
    'manual join promotes a queued automatic scan without starting a second scan',
    () async {
      await seed('cat', checkedAt: checkpoint);
      final c = ApiRequestCoordinator();
      addTearDown(c.dispose);
      final key = ApiQuotaKey.fromUri(Uri.parse('https://site.test'));
      final active = await c.acquire(key);
      final passive = [
        for (var i = 0; i < 2; i++)
          await c.acquire(
            key,
            context: const ApiRequestContext(
              requestClass: ApiRequestClass.automatic,
            ),
          ),
      ];
      final queued = Completer<void>();
      var scans = 0;
      ApiRequestClass? dispatchedClass;
      posts = TestSearchPostRepository((_, _, _) async {
        queued.complete();
        final context = ApiRequestContext.current();
        final permit = await c.acquire(key, context: context);
        context.onStarted?.call();
        scans++;
        dispatchedClass = context.requestClass;
        permit.release();
        return Either.of(
          PostResult(posts: [testSearchPost(2, checkpoint)], total: 1),
        );
      });
      final automatic = notifier().refresh(
        'cat',
        requestClass: ApiRequestClass.automatic,
      );
      await queued.future;
      expect(c.snapshot(key).queued, 1);
      final manual = notifier().refresh('cat');
      expect(await manual, isA<SearchRefreshSucceeded>());
      await automatic;
      expect(scans, 1);
      expect(dispatchedClass, ApiRequestClass.userInitiated);
      expect(
        snapshot().subscriptions.single.adaptiveState.interval,
        const Duration(hours: 24),
      );
      active.release();
      for (final permit in passive) {
        permit.release();
      }
    },
  );

  test(
    'publishes the saved pin before its initial snapshot completes',
    () async {
      final fetched = Completer<void>();
      final release = Completer<void>();
      posts = TestSearchPostRepository((_, _, _) async {
        fetched.complete();
        await release.future;
        return Either.of(
          PostResult(posts: [testSearchPost(1, checkpoint)], total: 1),
        );
      });
      final pinning = notifier().pin(
        profileId: config.id,
        query: 'cat',
        name: null,
      );
      await fetched.future;
      expect(snapshot().subscriptions.single.query, 'cat');
      expect(snapshot().subscriptions.single.lastSuccessfulCheckAt, isNull);
      expect(snapshot().refreshingIds, {snapshot().subscriptions.single.id});
      release.complete();
      final result = await pinning;
      expect(result.subscription.query, 'cat');
      expect(result.refresh, isA<SearchRefreshSucceeded>());
      expect(snapshot().subscriptions.single.lastSuccessfulCheckAt, startedAt);
      expect(snapshot().subscriptions.single.unreadCount, 0);
      expect(snapshot().refreshingIds, isEmpty);
    },
  );

  test(
    'keeps a pin saved when the initial snapshot fails and retries as a baseline',
    () async {
      posts = TestSearchPostRepository(
        (_, _, _) async =>
            Either.left(ServerError(httpStatusCode: 503, message: 'private')),
      );
      final result = await notifier().pin(
        profileId: config.id,
        query: 'cat',
        name: 'Cats',
      );
      expect(
        result.refresh,
        const SearchRefreshFailed(SearchRefreshErrorKind.network),
      );
      expect(snapshot().subscriptions.single.name, 'Cats');
      expect(snapshot().subscriptions.single.lastSuccessfulCheckAt, isNull);
      posts = TestSearchPostRepository(
        (_, _, _) async => Either.of(
          PostResult(posts: [testSearchPost(1, checkpoint)], total: 1),
        ),
      );
      final retried = await notifier().refresh(result.subscription.id);
      expect((retried as SearchRefreshSucceeded).baseline, isTrue);
      expect(snapshot().subscriptions.single.unreadCount, 0);
    },
  );

  test(
    'an edit starts a new baseline while the previous refresh is in flight',
    () async {
      await seed('old');
      await container.read(searchSubscriptionsProvider.future);
      final oldStarted = Completer<void>();
      final oldRelease = Completer<void>();
      posts = TestSearchPostRepository((query, _, _) async {
        if (query == 'old') {
          oldStarted.complete();
          await oldRelease.future;
          return Either.of(
            PostResult(posts: [testSearchPost(1, checkpoint)], total: 1),
          );
        }
        return Either.of(
          PostResult(posts: [testSearchPost(2, checkpoint)], total: 1),
        );
      });

      final previous = notifier().refresh('old');
      await oldStarted.future;
      final editing = (notifier() as dynamic).edit(
        'old',
        profileId: config.id,
        query: 'new',
        name: null,
      );
      final result = await editing.timeout(const Duration(seconds: 5));
      expect(result.refresh, isA<SearchRefreshSucceeded>());
      expect((result.refresh as SearchRefreshSucceeded).baseline, isTrue);
      oldRelease.complete();
      expect(await previous, const SearchRefreshDiscarded());
      final saved = (await repository.getById('old'))!;
      expect(saved.query, 'new');
      expect(saved.previews.single.postId, 2);
      expect(saved.hasNewPosts, isFalse);
    },
  );

  test('a missing profile blocks the edit before any write', () async {
    final original = await seed('old', checkedAt: checkpoint, unread: 1);
    await container.read(searchSubscriptionsProvider.future);
    await expectLater(
      notifier().edit(
        original.id,
        profileId: '00000000-0000-4000-8000-0000000003e7',
        query: 'new',
        name: 'New',
      ),
      throwsA(isA<MissingPinnedSearchProfileException>()),
    );
    expect(await repository.getById(original.id), original);
  });

  test('name-only edits do not start a baseline request', () async {
    final original = await seed('old', checkedAt: checkpoint, unread: 1);
    await container.read(searchSubscriptionsProvider.future);
    var requested = false;
    posts = TestSearchPostRepository((_, _, _) async {
      requested = true;
      return Either.of(const PostResult(posts: [], total: 0));
    });
    final result = await notifier().edit(
      original.id,
      profileId: config.id,
      query: original.query,
      name: 'New name',
    );
    expect(result.refresh, isNull);
    expect(requested, isFalse);
    expect(snapshot().subscriptions.single.name, 'New name');
    expect(snapshot().subscriptions.single.hasNewPosts, isTrue);
    expect(snapshot().subscriptions.single.lastSuccessfulCheckAt, checkpoint);
  });

  test(
    'a failed edit baseline leaves the new query saved and not checked',
    () async {
      final original = await seed('old', checkedAt: checkpoint, unread: 1);
      await container.read(searchSubscriptionsProvider.future);
      posts = TestSearchPostRepository(
        (_, _, _) async =>
            Either.left(ServerError(httpStatusCode: 503, message: 'offline')),
      );
      final result = await notifier().edit(
        original.id,
        profileId: config.id,
        query: 'new',
        name: null,
      );
      expect(
        result.refresh,
        const SearchRefreshFailed(SearchRefreshErrorKind.network),
      );
      final saved = (await repository.getById(original.id))!;
      expect(saved.query, 'new');
      expect(saved.lastSuccessfulCheckAt, isNull);
      expect(saved.lastErrorKind, SearchRefreshErrorKind.network);
      expect(saved.hasNewPosts, isFalse);
    },
  );

  test(
    'reuses duplicate queries and applies an optional replacement name',
    () async {
      await Future.wait([
        notifier().pin(profileId: config.id, query: ' cat   dog ', name: null),
        notifier().pin(profileId: config.id, query: 'cat dog', name: 'Pets'),
      ]);
      expect(snapshot().subscriptions, hasLength(1));
      expect(snapshot().subscriptions.single.query, 'cat   dog');
      expect(snapshot().subscriptions.single.name, 'Pets');
      await notifier().pin(profileId: config.id, query: 'cat dog', name: null);
      expect(snapshot().subscriptions.single.name, 'Pets');
      await notifier().rename(snapshot().subscriptions.single.id, ' ');
      expect(snapshot().subscriptions.single.name, isNull);
    },
  );

  test(
    'serializes mutations and publishes profile lists and NEW state',
    () async {
      await seed('first', checkedAt: checkpoint, unread: 3);
      await seed('second', checkedAt: checkpoint, unread: 2);
      await seed(
        'other',
        profileId: '00000000-0000-4000-8000-000000000063',
        unread: 9,
      );
      await container.read(searchSubscriptionsProvider.future);
      expect(
        container.read(profilePinnedSearchHasNewPostsProvider(config.id)),
        isTrue,
      );
      final publications = <List<String>>[];
      container.listen(searchSubscriptionsProvider, (_, next) {
        if (next.valueOrNull case final value?) {
          publications.add(
            value.subscriptions
                .map((item) => '${item.id}:${item.name}:${item.unreadCount}')
                .toList(),
          );
        }
      });
      await Future.wait([
        notifier().rename('first', 'Renamed'),
        notifier().markRead('first'),
        notifier().reorder(config.id, 1, 0),
        notifier().delete('second'),
      ]);
      expect(publications, contains(contains('first:Renamed:1')));
      expect(publications, contains(contains('first:Renamed:0')));
      expect(
        container
            .read(profilePinnedSearchesProvider(config.id))
            .requireValue
            .map((item) => item.id),
        ['first'],
      );
      expect(
        container.read(profilePinnedSearchHasNewPostsProvider(config.id)),
        isFalse,
      );
      expect(
        container.read(
          profilePinnedSearchHasNewPostsProvider(
            '00000000-0000-4000-8000-000000000063',
          ),
        ),
        isTrue,
      );
    },
  );

  test('reorders only the requested profile in published state', () async {
    await seed('first');
    await seed('second');
    await seed('other', profileId: '00000000-0000-4000-8000-000000000063');
    await notifier().reorder(config.id, 1, 0);
    expect(
      container
          .read(profilePinnedSearchesProvider(config.id))
          .requireValue
          .map((item) => item.id),
      ['second', 'first'],
    );
    expect(
      container
          .read(
            profilePinnedSearchesProvider(
              '00000000-0000-4000-8000-000000000063',
            ),
          )
          .requireValue
          .single
          .id,
      'other',
    );
  });

  test(
    'coalesces refreshes and lets mark-read finish during network work',
    () async {
      await seed('cat', checkedAt: checkpoint, unread: 4);
      final fetched = Completer<void>();
      final release = Completer<void>();
      var fetchCount = 0;
      posts = TestSearchPostRepository((_, _, _) async {
        fetchCount++;
        fetched.complete();
        await release.future;
        return Either.of(
          PostResult(
            posts: [
              testSearchPost(1, checkpoint.add(const Duration(minutes: 1))),
            ],
            total: 1,
          ),
        );
      });
      final first = notifier().refresh('cat');
      final second = notifier().refresh('cat');
      expect(identical(first, second), isTrue);
      await fetched.future;
      await notifier().markRead('cat');
      expect(snapshot().subscriptions.single.unreadCount, 0);
      expect(snapshot().refreshingIds, {'cat'});
      expect(snapshot().pendingRefreshIds, {'cat'});
      release.complete();
      await Future.wait([first, second]);
      expect(fetchCount, 1);
      expect(snapshot().subscriptions.single.unreadCount, 1);
      expect(snapshot().refreshingIds, isEmpty);
    },
  );

  test(
    'folder progress includes queued members and settles each terminal result',
    () async {
      await seed('a');
      await seed('b');
      await repository.replaceOrganization(
        SearchOrganization(
          folders: [
            SharedSearchFolder(
              id: 'folder',
              name: 'Folder',
              searchIds: const ['a', 'b'],
            ),
          ],
          homeSearchIds: const [],
        ),
      );
      final releases = <String, Completer<void>>{};
      posts = TestSearchPostRepository((query, _, _) async {
        await (releases[query] = Completer<void>()).future;
        return query == 'a'
            ? Either.left(ServerError(httpStatusCode: 503, message: 'failure'))
            : Either.of(PostResult.empty());
      });
      final result = notifier().refreshSharedFolder('folder');
      await pumpEventQueue();
      expect(snapshot().pendingRefreshIds, {'a', 'b'});
      expect(snapshot().refreshingIds, {'a'});
      releases['a']!.complete();
      await pumpEventQueue();
      expect(snapshot().pendingRefreshIds, {'b'});
      releases['b']!.complete();
      await result;
      expect(snapshot().pendingRefreshIds, isEmpty);
    },
  );

  test(
    'overlapping progress owners cannot clear each other or a running request',
    () async {
      await seed('a');
      await seed('b');
      await container.read(searchSubscriptionsProvider.future);
      final first = notifier().beginRefreshProgress(['a']);
      final second = notifier().beginRefreshProgress(['a', 'b']);
      final release = Completer<void>();
      posts = TestSearchPostRepository((_, _, _) async {
        await release.future;
        return Either.of(PostResult.empty());
      });
      final running = notifier().refresh('a');
      await pumpEventQueue();
      first.close();
      expect(snapshot().pendingRefreshIds, {'a', 'b'});
      second.settle('a');
      expect(snapshot().pendingRefreshIds, {'a', 'b'});
      second.close();
      expect(snapshot().pendingRefreshIds, {'a'});
      release.complete();
      await running;
      expect(snapshot().pendingRefreshIds, isEmpty);
    },
  );

  test(
    'root progress reserves later profiles until their own terminal outcomes',
    () async {
      await seed('a');
      const laterProfile = '00000000-0000-4000-8000-000000000063';
      await seed('b', profileId: laterProfile);
      final progress = await notifier().planIndependentRefreshes([
        config.id,
        laterProfile,
      ]);
      final release = Completer<void>();
      posts = TestSearchPostRepository((_, _, _) async {
        await release.future;
        return Either.of(PostResult.empty());
      });
      final first = notifier().refreshAll(
        config.id,
        progress: progress,
      );
      await pumpEventQueue();
      expect(snapshot().pendingRefreshIds, {'a', 'b'});
      release.complete();
      await first;
      expect(snapshot().pendingRefreshIds, {'b'});
      await notifier().refreshAll(laterProfile, progress: progress);
      expect(snapshot().pendingRefreshIds, isEmpty);
      progress.close();
    },
  );

  for (final readFailure in [false, true]) {
    test(
      'root reservation settles ${readFailure ? "failed" : "omitted"} middle-profile work while later profiles remain planned',
      () async {
        const middle = '00000000-0000-4000-8000-000000000063';
        const last = '00000000-0000-4000-8000-000000000064';
        configs.addAll([
          for (final id in [middle, last])
            BooruConfig.fromJson({...config.toJson(), 'id': id}),
        ]);
        final storage = _FailOnceOrganizationBox();
        if (readFailure) {
          repository = HiveSearchSubscriptionRepository(
            box: MemorySubscriptionBox(),
            organizationBox: storage,
          );
        }
        await seed('a');
        await seed('b', profileId: middle);
        await seed('c', profileId: last);
        final releases = <String, Completer<void>>{};
        posts = TestSearchPostRepository((query, _, _) async {
          if (query != 'edited-b') {
            await (releases[query] = Completer<void>()).future;
          }
          return Either.of(PostResult.empty());
        });
        final root = await notifier().planIndependentRefreshes([
          config.id,
          middle,
          last,
        ]);
        final first = notifier().refreshAll(config.id, progress: root);
        await pumpEventQueue();
        expect(snapshot().pendingRefreshIds, {'a', 'b', 'c'});
        if (!readFailure) {
          await notifier().edit(
            'b',
            profileId: config.id,
            query: 'edited-b',
            name: null,
          );
        }
        releases['a']!.complete();
        await first;
        Future<SearchRefreshOutcome>? joined;
        SearchRefreshProgress? other;
        if (readFailure) {
          joined = notifier().refresh('b');
          final coalesced = notifier().refresh('b');
          expect(identical(joined, coalesced), isTrue);
          other = notifier().beginRefreshProgress(['b']);
          await pumpEventQueue();
          storage.failNextRead = true;
          await expectLater(
            notifier().refreshAll(middle, progress: root),
            throwsStateError,
          );
          expect(snapshot().pendingRefreshIds, {'b', 'c'});
          releases['b']!.complete();
          await Future.wait([joined, coalesced]);
          expect(snapshot().pendingRefreshIds, {'b', 'c'});
          other.close();
        } else {
          await notifier().refreshAll(middle, progress: root);
        }
        final finalProfile = notifier().refreshAll(last, progress: root);
        await pumpEventQueue();
        expect(snapshot().pendingRefreshIds, {'c'});
        releases['c']!.complete();
        await finalProfile;
        root.close();
        expect(snapshot().pendingRefreshIds, isEmpty);
      },
    );
  }

  test(
    'refreshes never-checked then oldest searches with three workers and continues after failure',
    () async {
      await seed(
        'newest',
        checkedAt: checkpoint.add(const Duration(minutes: 3)),
      );
      await seed('next', checkedAt: checkpoint.add(const Duration(minutes: 1)));
      await seed('oldest', checkedAt: checkpoint);
      await seed('never');
      await seed(
        'later',
        checkedAt: checkpoint.add(const Duration(minutes: 2)),
      );
      await seed('other', profileId: '00000000-0000-4000-8000-000000000063');
      final starts = <String>[];
      final releases = <String, Completer<void>>{};
      final initialWorkers = Completer<void>();
      var active = 0;
      var maxActive = 0;
      posts = TestSearchPostRepository((query, _, _) async {
        starts.add(query);
        active++;
        if (active > maxActive) maxActive = active;
        final release = releases[query] = Completer<void>();
        if (starts.length == 3) initialWorkers.complete();
        await release.future;
        active--;
        return query == 'never'
            ? Either.left(ServerError(httpStatusCode: 503, message: 'private'))
            : Either.of(PostResult.empty());
      });
      final batch = notifier().refreshAll(config.id);
      await initialWorkers.future;
      expect(starts, ['never', 'oldest', 'next']);
      expect(snapshot().batchTotal, 5);
      expect(snapshot().pendingRefreshIds, {
        'never',
        'oldest',
        'next',
        'later',
        'newest',
      });
      releases['never']!.complete();
      await pumpEventQueue();
      expect(starts, ['never', 'oldest', 'next', 'later']);
      expect(snapshot().batchCompleted, 1);
      expect(snapshot().pendingRefreshIds, {
        'oldest',
        'next',
        'later',
        'newest',
      });
      releases['oldest']!.complete();
      await pumpEventQueue();
      expect(starts.last, 'newest');
      for (final release in releases.values) {
        if (!release.isCompleted) release.complete();
      }
      final outcomes = await batch;
      expect(outcomes, hasLength(5));
      expect(
        outcomes.first,
        const SearchRefreshFailed(SearchRefreshErrorKind.network),
      );
      expect(maxActive, lessThanOrEqualTo(3));
      expect(snapshot().batchCompleted, 5);
      expect(snapshot().pendingRefreshIds, isEmpty);
      expect(snapshot().refreshingIds, isEmpty);
      expect(
        (await repository.getById('other'))?.lastSuccessfulCheckAt,
        isNull,
      );
    },
  );

  test('refresh all only checks independent pinned searches', () async {
    await seed('visible');
    final feed = await repository.saveFeed(
      profileId: config.id,
      name: 'Animals',
      queries: ['hidden'],
    );
    final fetched = <String>[];
    posts = TestSearchPostRepository((query, _, _) async {
      fetched.add(query);
      return Either.of(PostResult.empty());
    });

    final outcomes = await notifier().refreshAll(config.id);

    expect(outcomes, hasLength(1));
    expect(fetched, ['visible']);
    expect(snapshot().batchTotal, 1);
    expect(feed.sourceIds, hasLength(1));
  });

  test('discards a missing subscription without fetching posts', () async {
    posts = TestSearchPostRepository(
      (_, _, _) async => throw StateError('Must not fetch'),
    );
    expect(await notifier().refresh('missing'), const SearchRefreshDiscarded());
    expect(snapshot().refreshingIds, isEmpty);
  });

  test(
    'creates a shared folder and keeps its member when creation succeeds',
    () async {
      final cat = await seed('cat', unread: 2);
      await container.read(searchSubscriptionsProvider.future);

      final folder = await notifier().createSharedFolderAndMovePin(
        cat.id,
        'Animals',
      );

      expect(folder.searchIds, [cat.id]);
      expect(snapshot().organization.folders, [folder]);
    },
  );

  test('a failed shared create-and-move keeps the pin in Home', () async {
    final cat = await seed('cat', unread: 2);
    await container.read(searchSubscriptionsProvider.future);

    await expectLater(
      notifier().createSharedFolderAndMovePin(cat.id, ' '),
      throwsFormatException,
    );

    expect(snapshot().organization.homeSearchIds, [cat.id]);
  });
}

class _RepositoryNotifier extends SearchSubscriptionRepositoryNotifier {
  _RepositoryNotifier(this.repository);
  final SearchSubscriptionRepository repository;
  @override
  Future<SearchSubscriptionRepository> build() async => repository;
}

class _SourceAdapter implements HttpClientAdapter {
  _SourceAdapter(this.respond);
  final Future<ResponseBody> Function(RequestOptions) respond;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) => respond(options);
  @override
  void close({bool force = false}) {}
}

class _FailOnceOrganizationBox extends MemoryBox<dynamic> {
  var failNextRead = false;
  @override
  Iterable<dynamic> get values {
    if (failNextRead) {
      failNextRead = false;
      throw StateError('Injected storage read failure');
    }
    return super.values;
  }
}
