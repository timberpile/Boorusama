// Dart imports:
import 'dart:async';

// Package imports:
import 'package:clock/clock.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:boorusama/core/posts/media_preload/types.dart';

void main() {
  for (final active in [false, true]) {
    test('planning work stays bounded with active downloads: $active', () {
      final counts = <int>[];
      for (final count in [100, 10000]) {
        var calls = 0;
        final result = _strategy().calculatePreload(
          PreloadContext(
            currentPage: 50,
            itemCount: count,
            mediaBuilder: (index) {
              calls++;
              return _media(index);
            },
            activeDownloads: active ? {'thumb-48', 'thumb-10'} : {},
            completedUrls: const {},
          ),
        );
        counts.add(calls);
        expect(result.allUrls, unorderedEquals(['thumb-49', 'thumb-51']));
        expect(result.cancelUrls, active ? {'thumb-10'} : isEmpty);
      }
      expect(counts[0], counts[1]);
      expect(counts[0], lessThanOrEqualTo(8));
    });
  }

  test('already desired downloads need no cancellation media lookups', () {
    final indices = <int>[];
    final result = _strategy().calculatePreload(
      PreloadContext(
        currentPage: 50,
        itemCount: 10000,
        mediaBuilder: (index) {
          indices.add(index);
          return _media(index);
        },
        activeDownloads: const {'thumb-49', 'thumb-51'},
        completedUrls: const {},
      ),
    );
    expect(indices, unorderedEquals([49, 50, 51]));
    expect(result.cancelUrls, isEmpty);
    expect(result.skipUrls, {'thumb-50', 'image-50'});
  });

  test('retains any nearby occurrence of a repeated URL', () {
    final result = _strategy().calculatePreload(
      PreloadContext(
        currentPage: 50,
        itemCount: 10000,
        mediaBuilder: (index) => index == 48 || index == 9999
            ? ImageMedia.fromUrl('shared')
            : _media(index),
        activeDownloads: const {'shared', 'missing', 'thumb-47'},
        completedUrls: const {},
      ),
    );
    expect(result.cancelUrls, {'missing', 'thumb-47'});
  });

  for (final direction in [-1, 1]) {
    test('retains current media when moving confidently in direction $direction', () {
      final strategy = _strategy([direction, direction, direction, direction]);
      expect(strategy.directionHistory.confidence, DirectionConfidence.high);
      final result = strategy.calculatePreload(
        PreloadContext(
          currentPage: 50,
          itemCount: 10000,
          mediaBuilder: _media,
          activeDownloads: {
            'image-50',
            'image-${50 - direction}',
            'image-${50 - 2 * direction}',
            'image-${50 + 2 * direction}',
            'image-80',
          },
          completedUrls: const {},
        ),
      );
      expect(result.cancelUrls, {'image-${50 - 2 * direction}', 'image-80'});
      expect(result.allUrls, contains('image-${50 + 3 * direction}'));
      expect(result.allUrls, isNot(contains('image-50')));
    });
  }

  for (final page in [0, 99]) {
    test('resolution respects collection boundary at page $page', () {
      final strategy = _strategy();
      final indices = strategy.getResolutionIndices(
        currentPage: page,
        itemCount: 100,
      );
      expect(indices.length, 3);
      expect(indices.every((index) => index >= 0 && index < 100), isTrue);
      expect(
        strategy.getResolutionIndices(currentPage: page, itemCount: 0),
        isEmpty,
      );
    });
  }

  test('mixed resolution is bounded and preserves global indices and groups', () {
    final counts = <int>[];
    for (final count in [100, 10000]) {
      final downloads = _Downloads();
      final grouped = GroupedPreloadManager<int>(
        managerBuilder: (group) => downloads.manager('$group'),
      );
      addTearDown(grouped.cancelAll);
      final resolved = <int>[];
      grouped.preloadWithStrategy(
        strategy: _strategy(),
        currentPage: 50,
        itemCount: count,
        mediaBuilder: (index) {
          resolved.add(index);
          // Unresolvable origin at the current page must not shift neighbors.
          if (index == 50) return null;
          return (group: index % 3, media: _media(index));
        },
      );
      counts.add(resolved.length);
      expect(resolved, unorderedEquals([48, 49, 50, 51, 52]));
      expect(downloads.requests.map((request) => request.key), unorderedEquals([
        '1:thumb-49',
        '0:thumb-51',
      ]));
    }
    expect(counts, [5, 5]);
  });

  test('identical URLs use separate profile managers', () {
    final downloads = _Downloads();
    final grouped = GroupedPreloadManager<int>(
      managerBuilder: (group) => downloads.manager('$group'),
    );
    addTearDown(grouped.cancelAll);
    grouped.preloadWithStrategy(
      strategy: _strategy(),
      currentPage: 1,
      itemCount: 3,
      mediaBuilder: (index) => (
        group: index,
        media: ImageMedia.fromUrl('shared'),
      ),
    );
    expect(downloads.requests.map((request) => request.key), unorderedEquals([
      '0:shared',
      '2:shared',
    ]));
  });

  test('jumps cancel old profile work and resolve changed media on return', () {
    final downloads = _Downloads();
    final grouped = GroupedPreloadManager<int>(
      managerBuilder: (group) => downloads.manager('$group'),
    );
    addTearDown(grouped.cancelAll);
    var suffix = 'old';
    void visit(int page) => grouped.preloadWithStrategy(
      strategy: _strategy(),
      currentPage: page,
      itemCount: 10000,
      mediaBuilder: (index) => (
        group: index ~/ 10,
        media: ImageMedia.fromUrl('$suffix-$index'),
      ),
    );

    visit(5);
    final old = downloads.requests.toList();
    visit(55);
    expect(old.every((request) => request.token.isCancelled), isTrue);
    final middle = downloads.requests
        .where((request) => !request.token.isCancelled)
        .toList();
    suffix = 'new';
    visit(5);
    expect(middle.every((request) => request.token.isCancelled), isTrue);
    expect(
      downloads.requests.map((request) => request.key),
      contains('0:new-4'),
    );
    expect(downloads.createdGroups, ['0', '5', '0']);

    grouped.preloadWithStrategy(
      strategy: _strategy(),
      currentPage: 5,
      itemCount: 10000,
      mediaBuilder: (_) => null,
    );
    expect(
      downloads.requests.every((request) => request.token.isCancelled),
      isTrue,
    );
  });

  test('leaving a profile clears queued work as well as active downloads', () async {
    final downloads = _Downloads();
    final grouped = GroupedPreloadManager<int>(
      managerBuilder: (group) => downloads.manager('$group'),
    );
    addTearDown(grouped.cancelAll);
    void visit(int page) => grouped.preloadWithStrategy(
      strategy: _strategy([1, 1, 1, 1]),
      currentPage: page,
      itemCount: 10000,
      mediaBuilder: (index) => (group: index ~/ 10, media: _media(index)),
    );
    visit(5);
    final old = downloads.requests.toList();
    expect(old.length, 2);
    visit(55);
    expect(old.every((request) => request.token.isCancelled), isTrue);
    for (final request in old) {
      request.done.complete();
    }
    await Future<void>.delayed(Duration.zero);
    expect(
      downloads.requests
          .where((request) => request.key.startsWith('0:'))
          .length,
      2,
    );
    expect(
      downloads.requests
          .where((request) => request.key.startsWith('5:'))
          .length,
      2,
    );
  });

  test('appending posts makes new neighbors available without rebuilding an index', () {
    final downloads = _Downloads();
    final grouped = GroupedPreloadManager<int>(
      managerBuilder: (group) => downloads.manager('$group'),
    );
    addTearDown(grouped.cancelAll);
    void visit(int count) => grouped.preloadWithStrategy(
      strategy: _strategy(),
      currentPage: 1,
      itemCount: count,
      mediaBuilder: (index) => (group: 0, media: _media(index)),
    );
    visit(2);
    expect(downloads.requests.map((request) => request.key), ['0:thumb-0']);
    visit(3);
    expect(downloads.requests.map((request) => request.key), contains('0:thumb-2'));
  });

  for (final failOldRequest in [false, true]) {
    test('late canceled request cannot erase its replacement: failure $failOldRequest', () async {
      final downloads = _Downloads();
      final manager = downloads.manager('profile');
      addTearDown(manager.dispose);
      final result = PreloadResult(
        prioritizedUrls: const [
          PrioritizedUrl(
            url: 'shared',
            priority: 100,
            distance: 1,
            relevanceZone: RelevanceZone.immediate,
          ),
        ],
      );
      manager.preloadMedias(result);
      final old = downloads.requests.single;
      manager.cancelAll();
      manager.preloadMedias(result);
      final replacement = downloads.requests.last;
      expect(old.token.isCancelled, isTrue);
      if (failOldRequest) {
        old.done.completeError(StateError('canceled request completed late'));
      } else {
        old.done.complete();
      }
      await Future<void>.delayed(Duration.zero);
      expect(manager.state.activeDownloads, {'shared'});
      expect(manager.state.activeCancelTokensCount, 1);
      expect(manager.state.completedUrls, isEmpty);
      expect(replacement.token.isCancelled, isFalse);
      replacement.done.complete();
      await Future<void>.delayed(Duration.zero);
      expect(manager.state.activeDownloads, isEmpty);
      expect(manager.state.completedUrls, {'shared'});
    });
  }

  test('disabled preloading does not resolve media', () {
    final manager = PreloadManager(
      preloader: (_, _) async {},
      isEnabled: () => false,
    );
    addTearDown(manager.dispose);
    manager.preloadWithStrategy(
      strategy: _strategy(),
      currentPage: 50,
      itemCount: 10000,
      mediaBuilder: (_) =>
          throw StateError('disabled media must not be resolved'),
    );
    expect(manager.state.activeDownloads, isEmpty);
  });
}

DirectionBasedPreloadStrategy _strategy([List<int> directions = const []]) =>
    DirectionBasedPreloadStrategy(
      directionHistory: DirectionHistory.fromDirections(
        directions,
        options: const DirectionHistoryOptions(highConfidenceThreshold: 2),
        clock: Clock.fixed(DateTime(2024)),
      ),
    );

ImageMedia _media(int index) => ImageMedia(
  thumbnailUrl: 'thumb-$index',
  originalUrl: 'image-$index',
);

class _Downloads {
  final requests = <({String key, CancelToken token, Completer<void> done})>[];
  final createdGroups = <String>[];

  PreloadManager manager(String group) {
    createdGroups.add(group);
    return PreloadManager(
      preloader: (url, token) {
        final done = Completer<void>();
        requests.add((key: '$group:$url', token: token, done: done));
        return done.future;
      },
    );
  }
}
