import 'dart:async';

import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/posts/listing/providers.dart';
import 'package:boorusama/core/posts/listing/widgets.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';

import '../../../support/fakes/test_post.dart';

void main() {
  test(
    'removal revokes a pending count snapshot before it can restore posts',
    () async {
      final started = Completer<void>();
      final newerCount = Completer<void>();
      final release = Completer<void>();
      var counts = 0;
      final controller = _controller(
        [
          _post('a.example', {'cat'}),
        ],
        counter: (posts, rules) async {
          final result = countPostBlacklistMatches(posts, rules);
          if (++counts == 1) {
            started.complete();
            await release.future;
          } else {
            newerCount.complete();
          }
          return result;
        },
      );
      await controller.refresh();
      final old = controller.setBlacklistedTags({'cat'});
      await started.future;
      controller.remove([42], (post) => post.id);
      await newerCount.future;
      release.complete();
      await old;
      expect(controller.items, isEmpty);
      expect(controller.tagCounts.value, isEmpty);
    },
  );

  test(
    'out-of-order count completion keeps only the latest rule snapshot',
    () async {
      final started = Completer<void>();
      final release = Completer<void>();
      var calls = 0;
      final controller = _controller(
        [
          _post('a.example', {'cat'}),
        ],
        counter: (posts, rules) async {
          final result = countPostBlacklistMatches(posts, rules);
          if (++calls == 1) {
            started.complete();
            await release.future;
          }
          return result;
        },
      );
      await controller.refresh();
      final oldUpdate = controller.setBlacklistedTags({'cat'});
      await started.future;
      await controller.setBlacklistedTags({'dog'});
      release.complete();
      await oldUpdate;
      expect(controller.tagCounts.value, isEmpty);
      expect(controller.items, hasLength(1));
      expect(controller.activeFilters.value, {'dog': true});
    },
  );

  test(
    'late lazy blacklist read cannot overwrite a live rule update',
    () async {
      final oldRead = Completer<Set<String>>();
      final controller = _controller([
        _post('a.example', {'cat'}),
      ], tags: () => oldRead.future);
      final refresh = controller.refresh();
      await controller.setBlacklistedTags({'cat'});
      oldRead.complete({'dog'});
      await refresh;
      expect(controller.blacklistedTags, {'cat'});
      expect(controller.items, isEmpty);
    },
  );

  test(
    'live rules normalize spelling and preserve unchanged disabled rules',
    () async {
      final controller = _controller([
        _post('a.example', {'cat'}),
      ]);
      await controller.refresh();
      await controller.setBlacklistedTags({'CaT'});
      expect(controller.items, isEmpty);
      expect(controller.visibleHiddenTags.value, [
        (name: 'cat', count: 1, active: true),
      ]);
      await controller.disableTag('cat');
      await controller.setBlacklistedTags({'CAT', 'dog'});
      expect(controller.items, hasLength(1));
      expect(controller.activeFilters.value, {'cat': false, 'dog': true});
      await controller.setBlacklistedTags({'dog'});
      expect(controller.activeFilters.value, {'dog': true});
      expect(controller.visibleHiddenTags.value, isEmpty);
    },
  );

  for (final bothMatch in [false, true]) {
    test(
      'equal numeric IDs keep distinct source matches ($bothMatch)',
      () async {
        final controller = _controller([
          _post('a.example', {'cat'}),
          _post('b.example', {if (bothMatch) 'cat' else 'dog'}),
        ]);
        await controller.refresh();
        await controller.setBlacklistedTags({'cat'});
        expect(controller.allItems, hasLength(2));
        expect(controller.items, hasLength(bothMatch ? 0 : 1));
        expect(controller.tagCounts.value['cat'], hasLength(bothMatch ? 2 : 1));
        if (!bothMatch) {
          expect(controller.items.single.origin.sourceHost, 'b.example');
        }
        await controller.disableAllTags();
        expect(controller.items, hasLength(2));
        expect(
          controller.visibleHiddenTags.value.map((tag) => tag.active),
          everyElement(isFalse),
        );
      },
    );
  }

  test('older filter completion cannot publish over newer rules', () async {
    final started = Completer<void>();
    final oldUrls = Completer<Set<String>>();
    var requests = 0;
    final controller = _controller(
      [
        _post('a.example', {'cat'}),
      ],
      urls: () {
        if (++requests == 2) {
          started.complete();
          return oldUrls.future;
        }
        return Future.value({});
      },
    );
    await controller.refresh();
    final oldUpdate = controller.setBlacklistedTags({'cat'});
    await started.future;
    await controller.setBlacklistedTags({'dog'});
    expect(controller.items, hasLength(1));
    oldUrls.complete({''});
    await oldUpdate;
    expect(controller.items, hasLength(1));
    expect(controller.activeFilters.value, {'dog': true});
  });
}

Post _post(String host, Set<String> tags) => TestPost(
  id: 42,
  tags: tags,
  origin: PostOrigin.fromSource(
    booruType: BooruType.danbooru,
    booruId: 0,
    source: 'https://$host',
  ),
);

PostGridController<Post> _controller(
  List<Post> posts, {
  Future<Set<String>> Function()? urls,
  Future<Set<String>> Function()? tags,
  PostBlacklistCounter? counter,
}) {
  final controller = PostGridController<Post>(
    fetcher: (_) =>
        TaskEither.right(PostResult(posts: posts, total: posts.length)),
    blacklistedTagsFetcher: tags ?? () async => {},
    blacklistCounter: counter,
    blacklistedUrlsFetcher: urls,
    mountedChecker: () => true,
    duplicateTracker: PostDuplicateTracker(
      mode: DuplicateCheckMode.originAndId,
    ),
    onError: (_) {},
  );
  addTearDown(controller.dispose);
  return controller;
}
