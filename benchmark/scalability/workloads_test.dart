// This file and fixtures.dart must be copied unchanged to both measured trees.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:boorusama/core/bookmarks/src/providers/bookmark_group_selectors.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_shuffle_provider.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_library_state.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_view.dart';
import 'package:boorusama/core/posts/media_preload/src/preload_manager.dart';
import 'package:boorusama/core/posts/media_preload/src/types.dart';
import 'package:boorusama/core/search/following_topics/src/data/hive/following_topic_repository_hive.dart';
import 'package:boorusama/core/search/following_topics/src/types/topic_feed.dart';
import 'package:cache_manager/cache_manager.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/performance.dart';

import '../../test/core/search/following_topics/topic_test_utils.dart';
import 'fixtures.dart';

const _scale = String.fromEnvironment(
  'SCALABILITY_SCALE',
  defaultValue: 'small',
);
const _warmups = int.fromEnvironment('SCALABILITY_WARMUPS', defaultValue: 2);
const _iterations = int.fromEnvironment(
  'SCALABILITY_ITERATIONS',
  defaultValue: 7,
);
const _sizes = {
  'small': (bookmarks: 250, feeds: 3, posts: 50, urls: 128, files: 32),
  'medium': (bookmarks: 5000, feeds: 10, posts: 250, urls: 1000, files: 256),
  'large': (bookmarks: 25000, feeds: 25, posts: 1000, urls: 10000, files: 1024),
};

void emit(
  String scenario,
  Map<String, Object?> inputs,
  List<int> samples,
  Map<String, Object?> work,
  String limits,
) {
  print(
    'SCALABILITY_RESULT ${jsonEncode({
      'schema': 1,
      'scenario': scenario,
      'scale': _scale,
      'inputs': inputs,
      'warmups': _warmups,
      'samples_us': samples,
      'work': work,
      'limits': limits,
    })}',
  );
}

List<int> measureSync(void Function() operation) {
  final samples = <int>[];
  for (var i = -_warmups; i < _iterations; i++) {
    final stopwatch = Stopwatch()..start();
    operation();
    stopwatch.stop();
    if (i >= 0) samples.add(stopwatch.elapsedMicroseconds);
  }
  return samples;
}

Future<List<int>> measureAsync(Future<void> Function() operation) async {
  final samples = <int>[];
  for (var i = -_warmups; i < _iterations; i++) {
    final stopwatch = Stopwatch()..start();
    await operation();
    stopwatch.stop();
    if (i >= 0) samples.add(stopwatch.elapsedMicroseconds);
  }
  return samples;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  if (!_sizes.containsKey(_scale) || _warmups < 0 || _iterations < 1) {
    throw ArgumentError('Invalid scalability workload parameters');
  }
  final size = _sizes[_scale]!;

  for (final groupOnly in [true, false]) {
    test('measure ${groupOnly ? "group" : "all"} cover selection', () {
      final members = <int>{1, size.bookmarks ~/ 2, size.bookmarks};
      final view = groupOnly
          ? BookmarkView.group(scalabilityGroupId)
          : const BookmarkView.all();
      List<Bookmark> rows([BookmarkReadCounter? counter]) => [
        for (var id = 1; id <= size.bookmarks; id++)
          scalabilityBookmark(id, counter: counter),
      ];
      final state = scalabilityLibrary(rows(), members: members);
      List<Bookmark> select(BookmarkLibraryState value) =>
          selectBookmarkPreviews(
            state: value,
            view: view,
            sortType: BookmarkSortType.newest,
          );
      final expected = selectBookmarks(
        state: state,
        view: view,
        selectedTags: const [],
        sortType: BookmarkSortType.newest,
      ).take(4).map((b) => b.id).toList();
      List<Bookmark> result = [];
      final samples = measureSync(() => result = select(state));
      expect(result.map((b) => b.id), expected);
      final counter = BookmarkReadCounter();
      final counted = scalabilityLibrary(rows(counter), members: members);
      counter.reset();
      final probe = select(counted);
      final work = counter.toJson();
      expect(probe.map((b) => b.id), expected);
      emit(
        groupOnly ? 'cover_group' : 'cover_all',
        {'bookmarks': size.bookmarks, 'group_members': members.length},
        samples,
        {...work, 'returned': probe.length},
        'CPU wall time, not frame time. Property reads are a separate probe, not allocations.',
      );
    });
  }

  for (final largeGroup in [false, true]) {
    test('measure random ${largeGroup ? "large" : "tiny"} group covers', () {
      final members = largeGroup
          ? {for (var id = 1; id <= size.bookmarks; id += 2) id}
          : {1, size.bookmarks ~/ 2, size.bookmarks};
      final view = BookmarkView.group(scalabilityGroupId);
      const shuffle = BookmarkShuffleState(seed: 17);
      List<Bookmark> rows([BookmarkReadCounter? counter]) => [
        for (var id = 1; id <= size.bookmarks; id++)
          scalabilityBookmark(id, counter: counter),
      ];
      final state = scalabilityLibrary(rows(), members: members);
      List<Bookmark> select(BookmarkLibraryState value) =>
          selectBookmarkPreviews(
            state: value,
            view: view,
            sortType: BookmarkSortType.random,
            shuffleState: shuffle,
          );
      final expected = select(state).map((b) => b.id).toList();
      List<Bookmark> result = [];
      final samples = measureSync(() => result = select(state));
      expect(result.map((b) => b.id), expected);
      expect(result.length, members.length < 4 ? members.length : 4);
      expect(result.every((b) => members.contains(b.id)), isTrue);
      final counter = BookmarkReadCounter();
      final counted = scalabilityLibrary(rows(counter), members: members);
      counter.reset();
      final probe = select(counted);
      final work = counter.toJson();
      expect(probe.map((b) => b.id), expected);
      emit(
        largeGroup ? 'cover_random_large_group' : 'cover_random_group',
        {
          'bookmarks': size.bookmarks,
          'group_members': members.length,
          'seed': 17,
        },
        samples,
        {...work, 'returned': probe.length},
        'Seed-stable within each revision; historical random output need not match. CPU, not frames.',
      );
    });
  }

  test('measure immutable bookmark-row publication', () {
    final base = scalabilityLibrary([
      for (var id = 1; id <= size.bookmarks; id++) scalabilityBookmark(id),
    ]);
    final changed = scalabilityBookmark(
      size.bookmarks ~/ 2,
      savedAt: scalabilityEpoch.add(const Duration(days: 1)),
    );
    late BookmarkLibraryState result;
    final samples = measureSync(() {
      result = base.applyCommittedChanges(
        upserts: [changed],
        groups: base.groups,
        folders: base.folders,
      );
    });
    expect(result.bookmarksById[changed.id], same(changed));
    expect(identical(base.bookmarksById[changed.id], changed), isFalse);
    expect(result.items.length, base.items.length);
    emit(
      'bookmark_publication',
      {'bookmarks': size.bookmarks, 'upserts': 1},
      samples,
      {
        'published_rows': result.items.length,
        'lookup_entries': result.bookmarksById.length,
      },
      'Allocation improvement needs DevTools allocation sampling; row counts are not allocation counts.',
    );
  });

  test('measure full cached-feed materialization', () async {
    final snapshots = [
      for (var id = 1; id <= size.posts; id++)
        feedPostSnapshotFromPost(
          testSearchPost(id, scalabilityEpoch.add(Duration(seconds: id))),
        ),
    ];
    Future<
      ({
        HiveFollowingTopicRepository repository,
        List<ReadCountingList<Object?>> counters,
      })
    >
    fixture(bool count) async {
      final storage = MemoryBox<dynamic>();
      final counters = <ReadCountingList<Object?>>[];
      for (var id = 0; id < size.feeds; id++) {
        final json = TopicFeed(
          id: 'feed-$id',
          profileId: scalabilityProfileId,
          name: 'Feed $id',
          position: id,
          maxPosts: size.posts,
          sourceIds: ['source-$id'],
          posts: snapshots,
        ).toJson();
        if (count) {
          final list = ReadCountingList<Object?>(json['posts'] as List);
          json['posts'] = list;
          counters.add(list);
        }
        await storage.put('feed:feed-$id', json);
      }
      return (
        repository: HiveFollowingTopicRepository(
          box: MemorySubscriptionBox(),
          organizationBox: storage,
        ),
        counters: counters,
      );
    }

    final plain = await fixture(false);
    var returned = 0;
    final samples = await measureAsync(() async {
      returned = (await plain.repository.getFeeds()).length;
    });
    expect(returned, size.feeds);
    final counted = await fixture(true);
    await counted.repository.getFeeds();
    emit(
      'feed_materialization',
      {'feeds': size.feeds, 'posts_per_feed': size.posts},
      samples,
      {
        'stored_post_visits': counted.counters.fold<int>(
          0,
          (sum, list) => sum + list.reads,
        ),
      },
      'Real repository and decoder over memory-backed boxes. No disk/network; not a full refresh benchmark.',
    );
  });

  test('measure preload history over a long synthetic browsing session', () {
    ({int retained, int calls}) run() {
      var retained = 0;
      var calls = 0;
      fakeAsync((async) {
        // Only baseline public APIs: the injected-clock constructor is not used.
        final manager = PreloadManager(
          preloader: (_, _) async {
            calls++;
          },
        );
        try {
          for (var id = 0; id < size.urls; id++) {
            manager.preloadMedias(
              PreloadResult(
                prioritizedUrls: [
                  PrioritizedUrl(
                    url: 'https://fixture.test/$id',
                    priority: 1,
                    distance: 1,
                    relevanceZone: RelevanceZone.immediate,
                  ),
                ],
              ),
            );
            async.flushMicrotasks();
          }
          retained = manager.state.completedUrls.length;
          expect(manager.state.activeDownloads, isEmpty);
        } finally {
          manager.dispose();
        }
      });
      return (retained: retained, calls: calls);
    }

    late ({int retained, int calls}) result;
    final samples = measureSync(() {
      result = run();
    });
    expect(result.calls, size.urls);
    emit(
      'preload_history',
      {'distinct_urls': size.urls},
      samples,
      {
        'retained_completion_entries': result.retained,
        'preloader_calls': result.calls,
      },
      'Synthetic asynchronous completion; no media transport. Cardinality is not heap bytes.',
    );
  });

  test('measure native disk-cache hit and miss queue work', () async {
    final root = await Directory.systemTemp.createTemp(
      'scalability-benchmark-',
    );
    final manager = DefaultImageCacheManager(
      cacheRootPathProvider: () => root.path,
      maxBytes: size.files * 128 + 128,
    );
    const accesses = 64;
    try {
      for (var i = 0; i < size.files; i++)
        await manager.saveFile('entry-$i', Uint8List(128));
      Future<void> batch() async {
        for (var i = 0; i < accesses; i++) {
          final hit = await manager.getCachedFileBytes(
            'entry-${i % size.files}',
          );
          if (hit?.length != 128) throw StateError('Lost fixture payload');
          if (await manager.getCachedFileBytes('missing-$i') != null)
            throw StateError('Unexpected hit');
        }
      }

      performanceRecorder.stop();
      performanceRecorder.clear();
      final samples = await measureAsync(batch);
      performanceRecorder.start();
      await batch();
      performanceRecorder.stop();
      final summary = performanceRecorder.snapshot()['summary'] as Map;
      final counters = summary['counters'] as Map;
      final operations = (summary['operations'] as List).cast<Map>();
      num counter(String name) =>
          (counters[name] as Map?)?['total'] as num? ?? 0;
      num count(String name) => operations
          .where((row) => row['op'] == name)
          .fold<num>(0, (sum, row) => sum + (row['count'] as num));
      emit(
        'cache_byte_reads',
        {
          'files': size.files,
          'payload_bytes': 128,
          'hits': accesses,
          'misses': accesses,
        },
        samples,
        {
          'lookup_hits': counter('cacheLookupHit'),
          'lookup_misses': counter('cacheLookupMiss'),
          'queue_operations': count('cacheQueueWait'),
          'journal_appends': count('cacheJournalAppend'),
          'checkpoints': count('cacheCheckpoint'),
        },
        'Native filesystem wall time; no RAM cache, network or decoded-image work. OS page cache is uncontrolled.',
      );
    } finally {
      performanceRecorder.stop();
      await manager.dispose();
      performanceRecorder.clear();
      await root.delete(recursive: true);
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}
