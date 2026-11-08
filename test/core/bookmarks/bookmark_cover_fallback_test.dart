import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:boorusama/core/http/client/providers.dart';
import 'package:boorusama/core/bookmarks/src/widgets/bookmark_local_group_card.dart';
import 'package:boorusama/core/bookmarks/src/widgets/bookmark_pool_card.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_cover_failures.dart';
import 'package:boorusama/core/bookmarks/src/types/post_bookmark.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/content/content_access_provider.dart';
import 'package:boorusama/core/content/content_media_access.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:extended_image/src/image/raw_image.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/material.dart';

import '../posts/details/progressive_image_test_utils.dart';
import '../search/following_topics/following_topic_test_utils.dart';
import '../../support/fakes/test_post.dart';
import 'pool_bookmark_test_utils.dart';

void main() {
  for (final count in [1, 2]) {
    testWidgets(
      '$count cached Posts retain $count distinct Pool covers in remaining slots',
      (tester) async {
        final profile = BooruConfig.fromJson({
          ...testProfile.toJson(),
          'booruId': BooruType.danbooru.id,
          'booruIdHint': BooruType.danbooru.id,
        });
        final cache = _Cache();
        final requests = <String>[];
        final harness = FollowingTopicHarness(
          profiles: [profile],
          imageCacheManager: cache,
          loadImages: true,
          overrides: [
            dioForWidgetProvider.overrideWith(
              (ref, auth) =>
                  Dio()..httpClientAdapter = _MissingAdapter(requests),
            ),
          ],
        );
        addTearDown(harness.dispose);
        final previews = [
          for (var id = 1; id <= count; id++) _bookmark(profile, id),
        ];
        for (final bookmark in previews)
          await cache.saveFile(
            cache.generateCacheKey(bookmark.thumbnailUrl),
            lowerPng,
          );
        final pools = [
          for (var id = 1; id <= count; id++)
            testPool(id: id, host: 'unavailable.example'),
        ];
        await harness.pump(
          tester,
          Scaffold(
            body: SizedBox.square(
              dimension: 200,
              child: BookmarkLocalGroupCard(
                title: 'Mixed',
                previews: previews,
                pools: pools,
                group: null,
                onTap: () {},
                onRename: null,
                onDuplicate: null,
                onDelete: null,
              ),
            ),
          ),
        );
        await tester.runAsync(
          () => pumpUntil(
            tester,
            () =>
                tester
                    .widgetList<ExtendedRawImage>(find.byType(ExtendedRawImage))
                    .where((image) => image.image != null)
                    .length ==
                count,
            reason: 'cached mixed cover decode',
          ),
        );
        expect(
          tester
              .widgetList<BookmarkPoolCoverImage>(
                find.byType(BookmarkPoolCoverImage),
              )
              .map((cover) => cover.pool.referenceId),
          orderedEquals(pools.map((pool) => pool.poolId)),
        );
        expect(find.byTooltip('Retry'), findsNothing);
        expect(requests, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'four failed covers yield to an authorized cached later candidate within the source budget',
    (tester) async {
      final profile = BooruConfig.fromJson({
        ...testProfile.toJson(),
        'booruId': BooruType.danbooru.id,
        'booruIdHint': BooruType.danbooru.id,
      });
      final cache = _Cache();
      final requests = <String>[];
      final harness = FollowingTopicHarness(
        profiles: [profile],
        imageCacheManager: cache,
        loadImages: true,
        overrides: [
          dioForWidgetProvider.overrideWith(
            (ref, auth) => Dio()..httpClientAdapter = _MissingAdapter(requests),
          ),
        ],
      );
      addTearDown(harness.dispose);
      final hold = harness.container.listen(
        contentProfileAccessProvider(profile.id),
        (_, _) {},
      );
      addTearDown(hold.close);
      await harness.container.pump();
      final access = harness.container.read(
        contentProfileAccessProvider(profile.id),
      )!;
      final managerProvider = contentMediaCacheManagerProvider((
        manager: cache,
        access: access.key,
      ));
      final managerHold = harness.container.listen(managerProvider, (_, _) {});
      addTearDown(managerHold.close);
      const good = 'https://active.example/thumb5.png';
      final manager = harness.container.read(managerProvider);
      await manager.saveFile(manager.generateCacheKey(good), lowerPng);
      final candidates = [
        for (var id = 1; id <= 20; id++)
          () {
            final post = TestPost(
              id: id,
              booruData: const LegacyPostData(
                typeKey: 'legacy_danbooru',
                custom: {},
              ),
              thumbnailImageUrl: 'https://active.example/thumb$id.png',
              sampleImageUrl: 'https://active.example/large$id.png',
              originalImageUrl: 'https://active.example/original$id.png',
              origin: PostOrigin.fromSource(
                booruType: BooruType.danbooru,
                booruId: BooruType.danbooru.id,
                source: profile.url,
                profileIdHint: profile.id,
              ),
            );
            return PostBookmark.fromSnapshot(
              id: id,
              createdAt: DateTime.utc(2026),
              updatedAt: DateTime.utc(2026),
              postId: id,
              snapshot: const StoredPostCodec().encode(post),
              post: post,
            );
          }(),
      ];
      await harness.pump(
        tester,
        Scaffold(
          body: Center(
            child: SizedBox.square(
              dimension: 200,
              child: BookmarkLocalGroupCard(
                title: 'Fixture',
                previews: candidates,
                group: null,
                onTap: () {},
                onRename: null,
                onDuplicate: null,
                onDelete: null,
              ),
            ),
          ),
        ),
      );
      bool decoded() => tester
          .widgetList<ExtendedRawImage>(find.byType(ExtendedRawImage))
          .any((w) => w.image != null);
      await tester.runAsync(
        () => pumpUntil(
          tester,
          decoded,
          reason: 'bounded later cached cover decode',
        ),
      );
      expect(decoded(), isTrue);
      expect(requests.length, lessThanOrEqualTo(4));
      expect(requests.every((path) => path.startsWith('/thumb')), isTrue);
      expect(
        harness.container
            .read(bookmarkCoverFailuresProvider)[access.key]
            ?.length,
        4,
      );
      expect(find.text('Fixture'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(BookmarkGroupPreviewGrid),
          matching: find.byType(Scrollable),
        ),
        findsNothing,
      );
      await tester.runAsync(
        () => pumpUntil(
          tester,
          () => find.byTooltip('Retry').evaluate().isNotEmpty,
          reason: 'single foreground cover retry',
        ),
      );
      expect(find.byTooltip('Retry'), findsOneWidget);
      await tester.tap(find.byTooltip('Retry'));
      await tester.runAsync(
        () => pumpUntil(
          tester,
          decoded,
          reason: 'cached cover after explicit retry',
        ),
      );
      expect(requests.length, lessThanOrEqualTo(8));
      expect(tester.takeException(), isNull);
    },
  );
}

PostBookmark _bookmark(BooruConfig profile, int id) {
  final post = TestPost(
    id: id,
    booruData: const LegacyPostData(typeKey: 'legacy_danbooru', custom: {}),
    thumbnailImageUrl: 'https://active.example/thumb$id.png',
    sampleImageUrl: 'https://active.example/large$id.png',
    originalImageUrl: 'https://active.example/original$id.png',
    origin: PostOrigin.fromSource(
      booruType: BooruType.danbooru,
      booruId: BooruType.danbooru.id,
      source: profile.url,
      profileIdHint: profile.id,
    ),
  );
  return PostBookmark.fromSnapshot(
    id: id,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
    postId: id,
    snapshot: const StoredPostCodec().encode(post),
    post: post,
  );
}

class _Cache extends TestImageCache {
  _Cache() : super({});
  @override
  String generateCacheKey(String url, {String? customKey}) => customKey ?? url;
  @override
  FutureOr<bool> hasValidCache(String key, {Duration? maxAge}) =>
      bytes.containsKey(key);
}

class _MissingAdapter implements HttpClientAdapter {
  _MissingAdapter(this.requests);
  final List<String> requests;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? body,
    Future<void>? cancel,
  ) async {
    requests.add(options.uri.path);
    return ResponseBody.fromString('missing', 404);
  }

  @override
  void close({bool force = false}) {}
}
