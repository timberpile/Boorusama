import 'dart:async';
import 'dart:io';

import 'package:boorusama/boorus/gelbooru_v2/posts/post_codec.dart';
import 'package:boorusama/boorus/gelbooru_v2/posts/post_data.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_group_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_group_repository_hive.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/repository.dart';
import 'package:boorusama/core/bookmarks/src/data/providers.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_hydration_provider.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/http/client/coordination.dart';
import 'package:boorusama/core/http/client/types.dart';
import 'package:boorusama/core/bookmarks/src/services/bookmark_hydration_service.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_hydration_log.dart';
import 'package:boorusama/core/bookmarks/src/services/bookmark_library_service.dart';
import 'package:boorusama/core/bookmarks/types.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/hive/hive_adapters.dart';
import 'package:boorusama/core/errors/types.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/src/types/settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

final config = BooruConfig.fromJson({
  ...BooruConfig.defaultConfig(
    booruType: BooruType.gelbooruV2,
    url: 'https://gelbooru.example',
    customDownloadFileNameFormat: null,
  ).toJson(),
  'id': '00000000-0000-4000-8000-000000000001',
});

Bookmark legacy(int id, {BooruConfig? profile}) => Bookmark(
  id: id,
  booruId: (profile ?? config).booruId,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  thumbnailUrl: 'https://gelbooru.example/$id.jpg',
  sampleUrl: '',
  originalUrl: 'https://gelbooru.example/$id.jpg',
  sourceUrl: (profile ?? config).url,
  width: 100,
  height: 100,
  md5: '',
  tags: const {},
  realSourceUrl: null,
  format: 'jpg',
  imageUrlResolver: const DefaultImageUrlResolver(),
  postId: id,
  metadata: const {},
);
Post native(int id) => legacy(
  id,
).post.copyWith(booruData: const GelbooruV2PostData(hasNotes: true));

void main() {
  late Directory directory;
  late Box<BookmarkHiveObject> bookmarkBox;
  late Box<BookmarkGroupHiveObject> groupBox;
  late _CountingRepository repository;
  late BookmarkGroupRepositoryHive groups;
  late BookmarkLibraryService library;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('bookmark-hydration-');
    Hive.init(directory.path);
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(BookmarkHiveObjectAdapter());
    }
    if (!Hive.isAdapterRegistered(5)) {
      Hive.registerAdapter(BookmarkGroupHiveObjectAdapter());
    }
    bookmarkBox = await Hive.openBox<BookmarkHiveObject>('bookmarks');
    groupBox = await Hive.openBox<BookmarkGroupHiveObject>('groups');
    repository = _CountingRepository(bookmarkBox);
    groups = BookmarkGroupRepositoryHive(groupBox);
    library = BookmarkLibraryService(
      bookmarkRepository: repository,
      groupRepository: groups,
      imageUrlResolver: (_) => const DefaultImageUrlResolver(),
    );
  });
  tearDown(() async {
    await bookmarkBox.close();
    await groupBox.close();
    await directory.delete(recursive: true);
  });

  Future<List<Bookmark>> load() async =>
      (await library.load(const BookmarkTarget.defaultGroup())).items;
  BookmarkRecoveryService recovery({
    Future<Post?> Function(BooruConfig, int)? fetch,
    bool codecAvailable = true,
  }) => BookmarkRecoveryService(
    fetchPost: fetch ?? (_, id) async => native(id),
    codecFor: (_) => codecAvailable ? const GelbooruV2PostCodec() : null,
  );
  Future<BookmarkHydrationProgress> run({
    List<BooruConfig>? profiles,
    List<Bookmark>? bookmarks,
    BookmarkRecoveryService? recover,
    BookmarkHydrationCancellation? cancellation,
    void Function(BookmarkHydrationProgress)? onProgress,
    DateTime Function()? now,
    Future<void> Function(Duration, BookmarkHydrationCancellation)? wait,
  }) async =>
      BookmarkHydrationService(
        library: library,
        recovery: recover ?? recovery(),
        now: now,
        wait: wait,
      ).run(
        bookmarks: bookmarks ?? await load(),
        configs: profiles ?? [config],
        cancellation: cancellation ?? BookmarkHydrationCancellation(),
        onProgress: onProgress ?? (_) {},
      );

  test(
    'detects legacy and unknown snapshots while leaving native snapshots alone',
    () {
      final original = legacy(1);
      expect(needsBookmarkHydration(original), isTrue);
      final post = native(1);
      final complete = Bookmark.fromSnapshot(
        id: 1,
        createdAt: original.createdAt,
        updatedAt: original.updatedAt,
        postId: 1,
        post: post,
        snapshot: const StoredPostCodec().encode(
          post,
          dataCodec: const GelbooruV2PostCodec(),
        ),
      );
      expect(needsBookmarkHydration(complete), isFalse);
      final unknown = post.copyWith(
        booruData: const UnknownPostData(
          typeKey: 'gelbooru_v2',
          schemaVersion: 99,
          custom: {},
          reason: UnknownPostDataReason.unsupportedVersion,
        ),
      );
      expect(
        needsBookmarkHydration(
          Bookmark.fromSnapshot(
            id: 1,
            createdAt: original.createdAt,
            updatedAt: original.updatedAt,
            postId: 1,
            post: unknown,
            snapshot: complete.snapshot,
          ),
        ),
        isTrue,
      );
    },
  );

  test(
    'persists native snapshots preserving IDs, creation time and all memberships, then resumes only remaining work',
    () async {
      final stored = await repository.addBookmarkWithBookmarks([
        legacy(1),
        legacy(2),
        legacy(3),
      ]);
      final first = await groups.createGroup('First');
      final second = await groups.createGroup('Second');
      final ids = stored.map((b) => b.id).toSet();
      await groups.addBookmarks(first.id, ids);
      await groups.addBookmarks(second.id, ids);
      final result = await run(
        wait: (_, cancellation) async => cancellation.cancel(),
        recover: recovery(
          fetch: (_, id) async {
            if (id == 2) throw StateError('temporary network failure');
            return native(id);
          },
        ),
      );
      expect((result.updated, result.skipped, result.failed), (2, 0, 1));
      final reloaded = await load();
      expect(reloaded.map((b) => b.id).toSet(), ids);
      expect(reloaded.every((b) => b.createdAt == DateTime(2026)), isTrue);
      expect(reloaded.where(needsBookmarkHydration).map((b) => b.postId), [2]);
      expect((await groups.getGroup(first.id))!.bookmarkIds, ids);
      expect((await groups.getGroup(second.id))!.bookmarkIds, ids);
      final requested = <int>[];
      final resumed = await run(
        recover: recovery(
          fetch: (_, id) async {
            requested.add(id);
            return native(id);
          },
        ),
      );
      expect(resumed.updated, 1);
      expect(requested, [2]);
      final empty = await run(
        recover: recovery(
          fetch: (_, _) async => fail('complete snapshots must not be fetched'),
        ),
      );
      expect(empty.total, 0);
    },
  );

  for (final scenario in [
    'missing profile',
    'ambiguous profile',
    'missing ID',
    'removed post',
    'unavailable codec',
    'request failure',
  ]) {
    test('continues after $scenario and reports the correct counts', () async {
      await repository.addBookmarkWithBookmarks([legacy(1), legacy(2)]);
      var profiles = [config];
      var recover = recovery();
      if (scenario == 'missing profile') profiles = [];
      if (scenario == 'ambiguous profile') {
        profiles = [
          config,
          BooruConfig.fromJson({
            ...config.toJson(),
            'id': '00000000-0000-4000-8000-000000000002',
          }),
        ];
      }
      List<Bookmark>? candidates;
      if (scenario == 'missing ID') {
        final bookmarks = await load();
        candidates = [
          bookmarks.first.copyWith(postId: () => null),
          bookmarks.last,
        ];
      }
      if (scenario == 'removed post') {
        recover = recovery(fetch: (_, id) async => id == 1 ? null : native(id));
      }
      if (scenario == 'request failure') {
        recover = recovery(
          fetch: (_, id) async {
            if (id == 1) throw StateError('CAPTCHA or network error');
            return native(id);
          },
        );
      }
      if (scenario == 'unavailable codec') {
        recover = recovery(codecAvailable: false);
      }
      final result = await run(
        profiles: profiles,
        recover: recover,
        bookmarks: candidates,
        wait: (_, cancellation) async => cancellation.cancel(),
      );
      expect(result.processed, 2);
      final expectedReason = switch (scenario) {
        'missing profile' => BookmarkHydrationLogReason.missingProfile,
        'ambiguous profile' => BookmarkHydrationLogReason.ambiguousProfile,
        'missing ID' => BookmarkHydrationLogReason.missingPostId,
        'removed post' => BookmarkHydrationLogReason.removedPost,
        'unavailable codec' => BookmarkHydrationLogReason.unsupportedSnapshot,
        _ => BookmarkHydrationLogReason.requestFailed,
      };
      expect(result.logEntries.first.reason, expectedReason);
      expect(result.logEntries.first.domain, 'gelbooru.example');
      expect(result.logEntries.first.bookmarkId, (await load()).first.id);
      expect(
        result.logEntries.first.postId,
        scenario == 'missing ID' ? null : 1,
      );
      expect(result.logEntries, hasLength(2));
      if ([
        'missing profile',
        'ambiguous profile',
        'unavailable codec',
      ].contains(scenario)) {
        expect((result.updated, result.skipped, result.failed), (0, 2, 0));
      } else if (scenario == 'request failure') {
        expect((result.updated, result.skipped, result.failed), (1, 0, 1));
      } else {
        expect((result.updated, result.skipped, result.failed), (1, 1, 0));
      }
    });
  }

  test(
    'log retains only the last 100 entries and snapshots are immutable',
    () async {
      final snapshots = <BookmarkHydrationProgress>[];
      final timestamp = DateTime.utc(2026, 10, 7, 12);
      final result = await run(
        bookmarks: List.generate(105, (index) => legacy(index + 1)),
        profiles: [],
        now: () => timestamp,
        onProgress: snapshots.add,
      );
      expect(result.skipped, 105);
      expect(result.logEntries, hasLength(100));
      expect(result.logEntries.first.postId, 6);
      expect(result.logEntries.last.postId, 105);
      expect(result.logEntries.last.timestamp, timestamp);
      expect(snapshots.first.logEntries, isEmpty);
      expect(snapshots[1].logEntries.single.postId, 1);
      expect(snapshots.every((p) => p.logEntries.length <= 100), isTrue);
      expect(() => result.logEntries.clear(), throwsUnsupportedError);
      final nextRun = await run(bookmarks: [legacy(106)], profiles: []);
      expect(nextRun.logEntries.single.postId, 106);
    },
  );

  test(
    'HTTP failures retain the safe status code and successful posts are logged',
    () async {
      await repository.addBookmarkWithBookmarks([legacy(1), legacy(2)]);
      final result = await run(
        wait: (_, cancellation) async => cancellation.cancel(),
        recover: recovery(
          fetch: (_, id) async {
            if (id == 1) {
              throw ServerError(
                httpStatusCode: 403,
                message: 'https://example.invalid/?api_key=private-test-secret',
              );
            }
            return native(id);
          },
        ),
      );
      expect(
        result.logEntries.first.reason,
        BookmarkHydrationLogReason.requestFailed,
      );
      expect(result.logEntries.first.httpStatusCode, 403);
      expect(result.logEntries.last.reason, BookmarkHydrationLogReason.updated);
      expect(result.logEntries.last.postId, 2);
    },
  );

  test(
    'automatic passes retry only failures until all remaining posts succeed',
    () async {
      final other = BooruConfig.fromJson({
        ...config.toJson(),
        'id': '00000000-0000-4000-8000-000000000002',
        'url': 'https://other.example',
      });
      await repository.addBookmarkWithBookmarks([
        legacy(1),
        legacy(2),
        legacy(3),
        legacy(4, profile: other),
      ]);
      final calls = <int, int>{};
      final readsBefore = repository.reads;
      final snapshots = <BookmarkHydrationProgress>[];
      final waits = <Duration>[];
      var now = DateTime.utc(2026, 10, 7, 12);
      final result = await run(
        profiles: [config, other],
        now: () => now,
        onProgress: snapshots.add,
        wait: (duration, _) async {
          waits.add(duration);
          now = now.add(duration);
        },
        recover: recovery(
          fetch: (_, id) async {
            calls[id] = (calls[id] ?? 0) + 1;
            if ((id == 1 && calls[id] == 1) || (id == 4 && calls[id]! <= 2)) {
              throw ServerError(httpStatusCode: 503, message: 'Unavailable');
            }
            return id == 3 ? null : native(id);
          },
        ),
      );
      expect(calls, {1: 2, 2: 1, 3: 1, 4: 3});
      expect(waits, [
        const Duration(seconds: 30),
        const Duration(seconds: 120),
      ]);
      expect((result.updated, result.skipped, result.failed), (3, 1, 0));
      expect(result.total, 4);
      expect(result.retryPass, 2);
      expect(result.running, isFalse);
      expect(result.cancelled, isFalse);
      expect(result.retryAt, isNull);
      expect(repository.reads, readsBefore + 1);
      expect(
        snapshots.every((p) => p.processed <= p.total && p.failed >= 0),
        isTrue,
      );
      expect(snapshots.where((p) => p.retryAt != null).map((p) => p.failed), [
        2,
        1,
      ]);
      expect((await load()).where(needsBookmarkHydration).single.postId, 3);
    },
  );

  test(
    'a temporary save failure is retried without refetching successful bookmarks',
    () async {
      await repository.addBookmarkWithBookmarks([legacy(1), legacy(2)]);
      repository.failPostId = 1;
      final calls = <int>[];
      final result = await run(
        wait: (_, _) async {
          repository.failPostId = null;
        },
        recover: recovery(
          fetch: (_, id) async {
            calls.add(id);
            return native(id);
          },
        ),
      );
      expect(calls, [1, 2, 1]);
      expect((result.updated, result.failed), (2, 0));
      expect(
        result.logEntries.first.reason,
        BookmarkHydrationLogReason.saveFailed,
      );
      expect((await load()).any(needsBookmarkHydration), isFalse);
    },
  );

  test(
    'persistent failures back off without inflating counts and cancellation ends retries',
    () async {
      await repository.addBookmarkWithBookmarks([legacy(1)]);
      var now = DateTime.utc(2026, 10, 7, 12);
      final waits = <Duration>[];
      final snapshots = <BookmarkHydrationProgress>[];
      var requests = 0;
      final result = await run(
        now: () => now,
        onProgress: snapshots.add,
        wait: (duration, cancellation) async {
          waits.add(duration);
          now = now.add(duration);
          if (waits.length == 5) cancellation.cancel();
        },
        recover: recovery(
          fetch: (_, id) {
            requests++;
            return Future.error(
              AppError(
                type: AppErrorType.cannotReachServer,
                message: 'Offline',
              ),
            );
          },
        ),
      );
      expect(waits.map((d) => d.inSeconds), [30, 120, 600, 1800, 1800]);
      expect(requests, 5);
      expect((result.updated, result.failed, result.processed), (0, 1, 1));
      expect(result.cancelled, isTrue);
      expect(result.retryAt, isNull);
      expect(snapshots.every((p) => p.failed <= 1), isTrue);
      expect(result.logEntries, hasLength(5));
      expect(
        result.logEntries.last.failureKind,
        BookmarkHydrationFailureKind.connection,
      );
    },
  );

  test(
    'rate limiting during a failed-post retry preserves the same pending post and counts',
    () async {
      await repository.addBookmarkWithBookmarks([legacy(1)]);
      var now = DateTime.utc(2026, 10, 7, 12);
      final waits = <Duration>[];
      var requests = 0;
      final result = await run(
        now: () => now,
        wait: (duration, _) async {
          waits.add(duration);
          now = now.add(duration);
        },
        recover: recovery(
          fetch: (_, id) async {
            requests++;
            if (requests == 1) {
              throw ServerError(httpStatusCode: 500, message: 'Server failure');
            }
            if (requests == 2) {
              throw RateLimitedError(now.add(const Duration(seconds: 60)));
            }
            return native(id);
          },
        ),
      );
      expect(requests, 3);
      expect(waits.map((d) => d.inSeconds), [30, 60]);
      expect((result.updated, result.failed), (1, 0));
      expect(result.logEntries.map((e) => e.reason), [
        BookmarkHydrationLogReason.requestFailed,
        BookmarkHydrationLogReason.rateLimited,
        BookmarkHydrationLogReason.updated,
      ]);
    },
  );

  test(
    'recovery preserves useful response diagnostics with secrets and URLs redacted',
    () async {
      final secretConfig = BooruConfig.fromJson({
        ...config.toJson(),
        'apiKey': 'synthetic secret+key',
        'login': 'synthetic-account',
        'passHash': 'synthetic-hash',
      });
      final outcome = await recovery(
        fetch: (_, _) {
          return Future.error(
            AppError(
              type: AppErrorType.loadDataFromServerFailed,
              message:
                  'FormatException: invalid metadata synthetic secret+key synthetic%20secret%2Bkey synthetic-account synthetic-hash https://example.invalid/?api_key=another-secret\nraw payload',
            ),
          );
        },
      ).recover(legacy(1), secretConfig);
      final failure = outcome as BookmarkRecoveryFailed;
      expect(failure.kind, BookmarkHydrationFailureKind.invalidResponse);
      expect(failure.detail, startsWith('FormatException: invalid metadata'));
      expect(failure.detail, isNot(contains('synthetic')));
      expect(failure.detail, isNot(contains('another-secret')));
      expect(failure.detail, isNot(contains('raw payload')));
      final timeout =
          await recovery(
                fetch: (_, _) {
                  return Future.error(
                    AppError(
                      type: AppErrorType.cannotReachServer,
                      message: 'DioException [receive timeout]',
                    ),
                  );
                },
              ).recover(legacy(1), config)
              as BookmarkRecoveryFailed;
      expect(timeout.kind, BookmarkHydrationFailureKind.timeout);
    },
  );

  test(
    'repository error mapping preserves a parser diagnostic for recovery',
    () async {
      final outcome =
          await recovery(
                fetch: (_, _) async {
                  final result = await tryFetchRemoteData<Post?>(
                    fetcher: () {
                      return Future.error(
                        const FormatException(
                          'Rule34 API returned post 43 instead of 42',
                        ),
                      );
                    },
                  ).run();
                  return result.fold((error) => throw error, (post) => post);
                },
              ).recover(legacy(1), config)
              as BookmarkRecoveryFailed;
      expect(outcome.kind, BookmarkHydrationFailureKind.invalidResponse);
      expect(
        outcome.detail,
        contains('Rule34 API returned post 43 instead of 42'),
      );
    },
  );

  test(
    'cancellation interrupts the failed-post retry wait immediately',
    () async {
      await repository.addBookmarkWithBookmarks([legacy(1)]);
      final cancellation = BookmarkHydrationCancellation();
      final waiting = Completer<void>();
      var requests = 0;
      final future = run(
        cancellation: cancellation,
        onProgress: (progress) {
          if (progress.retryAt != null && !waiting.isCompleted) {
            waiting.complete();
          }
        },
        recover: recovery(
          fetch: (_, _) {
            requests++;
            return Future.error(StateError('Persistent failure'));
          },
        ),
      );
      await waiting.future;
      cancellation.cancel();
      final result = await future.timeout(const Duration(seconds: 1));
      expect(requests, 1);
      expect(result.cancelled, isTrue);
      expect(result.failed, 1);
      expect(result.retryAt, isNull);
    },
  );

  test(
    'cancellation completes the in-flight request and persists it without starting another',
    () async {
      await repository.addBookmarkWithBookmarks([legacy(1), legacy(2)]);
      final entered = Completer<void>();
      final response = Completer<Post?>();
      final cancellation = BookmarkHydrationCancellation();
      final requested = <int>[];
      final future = run(
        cancellation: cancellation,
        recover: recovery(
          fetch: (_, id) {
            requested.add(id);
            entered.complete();
            return response.future;
          },
        ),
      );
      await entered.future;
      cancellation.cancel();
      response.complete(native(1));
      final result = await future;
      expect(result.cancelled, isTrue);
      expect(result.running, isFalse);
      expect(result.updated, 1);
      expect(requested, [1]);
      expect((await load()).where(needsBookmarkHydration).length, 1);
      expect((await run()).updated, 1);
    },
  );

  test(
    'uses the origin profile hint instead of choosing an arbitrary matching profile',
    () async {
      final original = legacy(1);
      final post = original.post.copyWith(
        origin: PostOrigin.fromSource(
          booruType: BooruType.gelbooruV2,
          booruId: config.booruId,
          source: config.url,
          profileIdHint: config.id,
        ),
      );
      await repository.addBookmarkWithBookmarks([
        Bookmark.fromSnapshot(
          id: original.id,
          createdAt: original.createdAt,
          updatedAt: original.updatedAt,
          post: post,
          postId: 1,
          snapshot: const StoredPostCodec().encode(post),
        ),
      ]);
      BooruConfig? used;
      await run(
        profiles: [
          BooruConfig.fromJson({
            ...config.toJson(),
            'id': '00000000-0000-4000-8000-000000000002',
          }),
          config,
        ],
        recover: recovery(
          fetch: (profile, id) async {
            used = profile;
            return native(id);
          },
        ),
      );
      expect(used?.id, config.id);
    },
  );

  test(
    'a persistence failure leaves that bookmark incomplete and continues with the next',
    () async {
      await repository.addBookmarkWithBookmarks([legacy(1), legacy(2)]);
      repository.failPostId = 1;
      final result = await run(
        wait: (_, cancellation) async => cancellation.cancel(),
      );
      expect((result.updated, result.failed), (1, 1));
      expect(
        result.logEntries.first.reason,
        BookmarkHydrationLogReason.saveFailed,
      );
      expect(result.logEntries.first.postId, 1);
      expect((await load()).where(needsBookmarkHydration).single.postId, 1);
      repository.failPostId = null;
      expect((await run()).updated, 1);
    },
  );

  test('cancelling before processing starts makes no request', () async {
    await repository.addBookmarkWithBookmarks([legacy(1)]);
    final cancellation = BookmarkHydrationCancellation()..cancel();
    final result = await run(
      cancellation: cancellation,
      recover: recovery(
        fetch: (_, _) async => fail('cancelled runs must not fetch'),
      ),
    );
    expect(result.processed, 0);
    expect(result.cancelled, isTrue);
    expect((await load()).every(needsBookmarkHydration), isTrue);
  });

  for (final typedCooldown in [true, false]) {
    test(
      'a ${typedCooldown ? 'shared cooldown' : 'raw 429'} waits and retries automatically without counting a failed bookmark',
      () async {
        await repository.addBookmarkWithBookmarks([
          legacy(1),
          legacy(2),
          legacy(3),
        ]);
        var now = DateTime.utc(2026, 10, 7, 12);
        final waits = <Duration>[];
        final progress = <BookmarkHydrationProgress>[];
        final requests = <int>[];
        final result = await run(
          now: () => now,
          wait: (duration, _) async {
            waits.add(duration);
            now = now.add(duration);
          },
          onProgress: progress.add,
          recover: recovery(
            fetch: (_, id) async {
              requests.add(id);
              if (requests.length == 1) {
                if (typedCooldown) {
                  throw RateLimitedError(now.add(const Duration(seconds: 37)));
                }
                throw ServerError(
                  httpStatusCode: 429,
                  message: 'Too many requests',
                );
              }
              return native(id);
            },
          ),
        );
        expect(requests, [1, 1, 2, 3]);
        expect(waits, [Duration(seconds: typedCooldown ? 37 : 30)]);
        expect((result.updated, result.failed, result.skipped), (3, 0, 0));
        expect(
          progress.any(
            (p) =>
                p.rateLimitedSites.contains('gelbooru.example') &&
                p.processed == 0,
          ),
          isTrue,
        );
        expect(result.rateLimitedSites, isEmpty);
        final waiting = result.logEntries.first;
        expect(waiting.reason, BookmarkHydrationLogReason.rateLimited);
        expect(waiting.httpStatusCode, 429);
        expect(waiting.postId, 1);
        expect(waiting.retryAt, waiting.timestamp.add(waits.single));
        expect(result.logEntries[1].reason, BookmarkHydrationLogReason.updated);
        expect(result.logEntries[1].postId, 1);
        expect((await load()).any(needsBookmarkHydration), isFalse);
      },
    );
  }

  test(
    'repeated raw rate limits back off and resume within the same run',
    () async {
      await repository.addBookmarkWithBookmarks([legacy(1)]);
      var now = DateTime.utc(2026, 10, 7, 12);
      final waits = <Duration>[];
      var requests = 0;
      final result = await run(
        now: () => now,
        wait: (duration, _) async {
          waits.add(duration);
          now = now.add(duration);
        },
        recover: recovery(
          fetch: (_, id) async {
            requests++;
            if (requests <= 3) {
              throw ServerError(httpStatusCode: 429, message: 'Rate limited');
            }
            return native(id);
          },
        ),
      );
      expect(requests, 4);
      expect(waits, [
        const Duration(seconds: 30),
        const Duration(seconds: 120),
        const Duration(seconds: 600),
      ]);
      expect((result.updated, result.failed, result.skipped), (1, 0, 0));
    },
  );

  test(
    'cancellation interrupts a long cooldown immediately and leaves the bookmark pending',
    () async {
      await repository.addBookmarkWithBookmarks([legacy(1)]);
      final waiting = Completer<void>();
      final cancellation = BookmarkHydrationCancellation();
      var requests = 0;
      final future = run(
        cancellation: cancellation,
        onProgress: (p) {
          if (p.rateLimitedSites.isNotEmpty && !waiting.isCompleted) {
            waiting.complete();
          }
        },
        recover: recovery(
          fetch: (_, _) {
            requests++;
            throw RateLimitedError(
              DateTime.now().toUtc().add(const Duration(minutes: 30)),
            );
          },
        ),
      );
      await waiting.future;
      cancellation.cancel();
      final result = await future.timeout(const Duration(seconds: 1));
      expect(requests, 1);
      expect(result.cancelled, isTrue);
      expect(result.processed, 0);
      expect((await load()).every(needsBookmarkHydration), isTrue);
    },
  );

  test(
    'three cooling sites release workers so a fourth site can still hydrate',
    () async {
      final profiles = List.generate(
        4,
        (i) => BooruConfig.fromJson({
          ...config.toJson(),
          'id': '00000000-0000-4000-8000-00000000000${i + 1}',
          'url': 'https://site-$i.example',
        }),
      );
      await repository.addBookmarkWithBookmarks([
        for (var i = 0; i < 4; i++) legacy(i + 1, profile: profiles[i]),
      ]);
      final cancellation = BookmarkHydrationCancellation();
      final requests = <int>[];
      final result = await run(
        profiles: profiles,
        cancellation: cancellation,
        onProgress: (p) {
          if (p.updated == 1) cancellation.cancel();
        },
        recover: recovery(
          fetch: (profile, id) async {
            requests.add(id);
            if (id < 4) {
              throw RateLimitedError(
                DateTime.now().toUtc().add(const Duration(minutes: 30)),
              );
            }
            return native(id).copyWith(
              origin: PostOrigin.fromSource(
                booruType: BooruType.gelbooruV2,
                booruId: profile.booruId,
                source: profile.url,
                profileIdHint: profile.id,
              ),
            );
          },
        ),
      );
      expect(requests, [1, 2, 3, 4]);
      expect((result.updated, result.failed, result.skipped), (1, 0, 0));
      expect(result.cancelled, isTrue);
      expect((await load()).where(needsBookmarkHydration).length, 3);
    },
  );

  for (final expiredDeadline in [true, false]) {
    test(
      '${expiredDeadline ? 'an expired server deadline' : 'a slow request ending in raw 429'} still waits before automatically retrying',
      () async {
        await repository.addBookmarkWithBookmarks([legacy(1)]);
        var now = DateTime.utc(2026, 10, 7, 12);
        final waits = <Duration>[];
        var requests = 0;
        final result = await run(
          now: () => now,
          wait: (duration, _) async {
            waits.add(duration);
            now = now.add(duration);
          },
          recover: recovery(
            fetch: (_, id) async {
              requests++;
              if (requests == 1) {
                if (expiredDeadline) {
                  throw RateLimitedError(
                    now.subtract(const Duration(seconds: 1)),
                  );
                }
                now = now.add(const Duration(minutes: 5));
                throw ServerError(httpStatusCode: 429, message: 'Rate limited');
              }
              return native(id);
            },
          ),
        );
        expect(waits, [Duration(seconds: expiredDeadline ? 1 : 30)]);
        expect(result.updated, 1);
        expect(result.failed, 0);
      },
    );
  }

  test(
    'starting maintenance supplies bulk priority and cancellation checks to the request path',
    () async {
      await repository.addBookmarkWithBookmarks([legacy(1), legacy(2)]);
      late ProviderContainer container;
      ApiRequestContext? context;
      container = ProviderContainer(
        overrides: [
          bookmarkRepoProvider.overrideWith((ref) => repository),
          bookmarkGroupRepoProvider.overrideWith((ref) => groups),
          bookmarkUrlResolverProvider.overrideWith(
            (ref, _) => const DefaultImageUrlResolver(),
          ),
          settingsProvider.overrideWithValue(Settings.defaultSettings),
          booruConfigProvider.overrideWith(
            () => BooruConfigNotifier(initialConfigs: [config]),
          ),
          bookmarkRecoveryServiceProvider.overrideWithValue(
            recovery(
              fetch: (_, id) async {
                context = ApiRequestContext.current();
                expect(context!.canStart!(), isTrue);
                container.read(bookmarkHydrationProvider.notifier).cancel();
                expect(context!.canStart!(), isFalse);
                return native(id);
              },
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(bookmarkHydrationProvider.notifier).start();
      expect(context!.requestClass, ApiRequestClass.bulkTransfer);
      expect(context!.allowCooldownRetry, isFalse);
      final result = container.read(bookmarkHydrationProvider);
      expect(result.updated, 1);
      expect(result.failed, 0);
      expect(result.cancelled, isTrue);
      expect(result.running, isFalse);
      expect(
        result.logEntries.single.reason,
        BookmarkHydrationLogReason.updated,
      );
      expect(result.logEntries.single.postId, 1);
      await container.read(bookmarkHydrationProvider.notifier).start();
      final restarted = container.read(bookmarkHydrationProvider);
      expect(restarted.logEntries.single.postId, 2);
    },
  );

  test(
    'a waiting site does not prevent another profile site from starting',
    () async {
      final other = BooruConfig.fromJson({
        ...config.toJson(),
        'id': '00000000-0000-4000-8000-000000000002',
        'url': 'https://other.example',
      });
      await repository.addBookmarkWithBookmarks([
        legacy(1),
        legacy(2, profile: other),
      ]);
      final release = Completer<void>();
      final bothStarted = Completer<void>();
      final requested = <int>[];
      final future = run(
        profiles: [config, other],
        recover: recovery(
          fetch: (profile, id) async {
            requested.add(id);
            if (requested.length == 2) bothStarted.complete();
            await release.future;
            return native(id).copyWith(
              origin: PostOrigin.fromSource(
                booruType: BooruType.gelbooruV2,
                booruId: profile.booruId,
                source: profile.url,
                profileIdHint: profile.id,
              ),
            );
          },
        ),
      );
      try {
        await bothStarted.future.timeout(const Duration(seconds: 2));
        expect(requested, [1, 2]);
      } finally {
        release.complete();
        expect((await future).updated, 2);
      }
    },
  );

  test(
    'a large mixed library has at most three requests in flight and stops new work on cancellation',
    () async {
      final profiles = List.generate(
        5,
        (index) => BooruConfig.fromJson({
          ...config.toJson(),
          'id': '00000000-0000-4000-8000-00000000000${index + 1}',
          'url': 'https://site-$index.example',
        }),
      );
      await repository.addBookmarkWithBookmarks([
        for (var index = 0; index < profiles.length; index++)
          legacy(index + 1, profile: profiles[index]),
      ]);
      final release = Completer<void>();
      final threeStarted = Completer<void>();
      final cancellation = BookmarkHydrationCancellation();
      var active = 0;
      var maximum = 0;
      var requests = 0;
      final future = run(
        profiles: profiles,
        cancellation: cancellation,
        recover: recovery(
          fetch: (profile, id) async {
            requests++;
            active++;
            if (active > maximum) maximum = active;
            if (requests == 3) threeStarted.complete();
            await release.future;
            active--;
            return native(id).copyWith(
              origin: PostOrigin.fromSource(
                booruType: BooruType.gelbooruV2,
                booruId: profile.booruId,
                source: profile.url,
                profileIdHint: profile.id,
              ),
            );
          },
        ),
      );
      try {
        await threeStarted.future.timeout(const Duration(seconds: 2));
        expect(requests, 3);
        cancellation.cancel();
      } finally {
        release.complete();
        final result = await future;
        expect(maximum, 3);
        expect(result.updated, 3);
        expect(result.cancelled, isTrue);
        expect((await load()).where(needsBookmarkHydration).length, 2);
      }
    },
  );

  test(
    'profiles on the same site share a sequential queue and keep their own credentials',
    () async {
      final other = BooruConfig.fromJson({
        ...config.toJson(),
        'id': '00000000-0000-4000-8000-000000000002',
      });
      final profiles = [config, other];
      await repository.addBookmarkWithBookmarks([
        for (var index = 0; index < profiles.length; index++)
          () {
            final bookmark = legacy(index + 1);
            final post = bookmark.post.copyWith(
              origin: PostOrigin.fromSource(
                booruType: BooruType.gelbooruV2,
                booruId: config.booruId,
                source: config.url,
                profileIdHint: profiles[index].id,
              ),
            );
            return bookmark.copyWith(
              post: post,
              snapshot: const StoredPostCodec().encode(post),
            );
          }(),
      ]);
      final firstStarted = Completer<void>();
      final release = Completer<void>();
      final usedProfiles = <String>[];
      final future = run(
        profiles: profiles,
        recover: recovery(
          fetch: (profile, id) async {
            usedProfiles.add(profile.id);
            if (id == 1) {
              firstStarted.complete();
              await release.future;
            }
            return native(id);
          },
        ),
      );
      try {
        await firstStarted.future;
        expect(usedProfiles, [config.id]);
      } finally {
        release.complete();
        expect((await future).updated, 2);
      }
      expect(usedProfiles, [config.id, other.id]);
    },
  );

  test(
    'notifier batch reloads the library once for several successful upgrades',
    () async {
      await repository.addBookmarkWithBookmarks([
        legacy(1),
        legacy(2),
        legacy(3),
      ]);
      final container = ProviderContainer(
        overrides: [
          bookmarkRepoProvider.overrideWith((ref) => repository),
          bookmarkGroupRepoProvider.overrideWith((ref) => groups),
          bookmarkUrlResolverProvider.overrideWith(
            (ref, _) => const DefaultImageUrlResolver(),
          ),
          settingsProvider.overrideWithValue(Settings.defaultSettings),
        ],
      );
      addTearDown(container.dispose);
      await container.read(bookmarkProvider.future);
      final reads = repository.reads;
      final updates = <int>[];
      final result = await container
          .read(bookmarkProvider.notifier)
          .hydrateBookmarks(
            configs: [config],
            recovery: recovery(),
            cancellation: BookmarkHydrationCancellation(),
            onProgress: (progress) {
              updates.add(progress.processed);
            },
          );
      expect(result.updated, 3);
      expect(repository.reads - reads, 1);
      expect(
        container
            .read(bookmarkProvider)
            .requireValue
            .items
            .any(needsBookmarkHydration),
        isFalse,
      );
      expect(updates, [0, 1, 2, 3, 3]);
    },
  );
}

class _CountingRepository extends BookmarkHiveRepository {
  _CountingRepository(super._box)
    : super(postDataCodec: (_) => const GelbooruV2PostCodec());
  var reads = 0;
  int? failPostId;
  @override
  Future<void> updateBookmark(Bookmark bookmark) {
    if (bookmark.postId == failPostId) throw StateError('write failed');
    return super.updateBookmark(bookmark);
  }

  @override
  BookmarksOrError getAllBookmarks({
    required ImageUrlResolver Function(int?) imageUrlResolver,
  }) {
    reads++;
    return super.getAllBookmarks(imageUrlResolver: imageUrlResolver);
  }
}
