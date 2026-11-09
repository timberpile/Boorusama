import 'dart:async';
import 'dart:typed_data';

import 'package:boorusama/core/bookmarks/src/types/content_group_bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_cover_failures.dart';
import 'package:boorusama/core/posts/post/types.dart';

import '../../support/fakes/test_post.dart';

import 'package:boorusama/core/bookmarks/src/types/stored_group_snapshot.dart';
import 'package:boorusama/core/bookmarks/src/widgets/bookmark_local_group_card.dart';
import 'package:boorusama/core/bookmarks/src/widgets/bookmark_native_group_card.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/content/types.dart';
import 'package:boorusama/core/content/content_access_provider.dart';
import 'package:boorusama/core/http/client/providers.dart';
import 'package:dio/dio.dart';
import 'package:extended_image/src/image/raw_image.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/material.dart';

import '../posts/details/progressive_image_test_utils.dart';
import '../search/following_topics/following_topic_test_utils.dart';

class Cache extends TestImageCache {
  Cache() : super({});
  @override
  String generateCacheKey(String url, {String? customKey}) => customKey ?? url;
  @override
  FutureOr<bool> hasValidCache(String key, {Duration? maxAge}) =>
      bytes.containsKey(key);
}

class MissingAdapter implements HttpClientAdapter {
  final requests = <Uri>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? body,
    Future<void>? cancel,
  ) async {
    requests.add(options.uri);
    return ResponseBody.fromString('missing', 404);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  testWidgets(
    'Post mosaic waits for a pending cached sample before trying a broken thumbnail',
    (tester) async {
      final config = BooruConfig.fromJson({
        ...testProfile.toJson(),
        'booruId': BooruType.danbooru.id,
        'booruIdHint': BooruType.danbooru.id,
        'url': 'https://danbooru.donmai.us',
        'ratingFilter': BooruConfigRatingFilter.none.index,
      });
      const sample = 'https://cdn.donmai.us/sample/sample.png';
      const thumbnail = 'https://cdn.donmai.us/thumb/missing.png';
      final cache = _GatedSampleCache(sample);
      await cache.saveFile(sample, lowerPng);
      final adapter = MissingAdapter();
      final post = TestPost(
        id: 103,
        booruData: const LegacyPostData(typeKey: 'legacy_danbooru', custom: {}),
        origin: PostOrigin.fromSource(
          booruType: config.auth.booruType,
          booruId: config.booruId,
          source: config.url,
          profileIdHint: config.id,
        ),
        thumbnailImageUrl: thumbnail,
        sampleImageUrl: sample,
      );
      final record = PostBookmark.fromSnapshot(
        id: 103,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
        postId: post.id,
        snapshot: const StoredPostCodec().encode(post),
        post: post,
      );
      final harness = FollowingTopicHarness(
        profiles: [config],
        imageCacheManager: cache,
        loadImages: true,
        overrides: [
          dioForWidgetProvider.overrideWith(
            (_, _) => Dio()..httpClientAdapter = adapter,
          ),
        ],
      );
      addTearDown(harness.dispose);
      await harness.pump(
        tester,
        Scaffold(
          body: Center(
            child: SizedBox.square(
              dimension: 200,
              child: BookmarkLocalGroupCard(
                title: 'Post',
                previews: [record],
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
      final access = harness.container.read(
        contentAccessForOriginProvider(post.origin),
      );
      expect(
        access,
        isNotNull,
        reason: 'The Post fixture has a registered, authorized source',
      );
      expect(
        harness.container
            .read(
              contentPostVisibilityProvider((access: access!.key, post: post)),
            )
            .asData
            ?.value,
        isTrue,
        reason:
            'The Post fixture must pass policy before testing the cache race',
      );
      await tester.runAsync(
        () => pumpUntil(
          tester,
          () => cache.started.isCompleted,
          reason: 'held sample cache probe',
        ),
      );
      await tester.pump();
      expect(
        adapter.requests,
        isEmpty,
        reason: 'A pending cache probe cannot authorize a failing thumbnail request',
      );
      expect(harness.container.read(bookmarkCoverFailuresProvider), isEmpty);
      expect(find.byTooltip('Retry'), findsNothing);
      cache.release.complete(true);
      await tester.runAsync(
        () => pumpUntil(
          tester,
          () => tester
              .widgetList<ExtendedRawImage>(find.byType(ExtendedRawImage))
              .any((image) => image.image != null),
          reason: 'Post cached sample decoder',
        ),
      );
      expect(adapter.requests, isEmpty);
      expect(harness.container.read(bookmarkCoverFailuresProvider), isEmpty);
      expect(find.byTooltip('Retry'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'native-only local Group mosaic decodes a cached sample without detail/network and stays clickable',
    (tester) async {
      final config = BooruConfig.fromJson({
        ...testProfile.toJson(),
        'booruId': BooruType.nhentai.id,
        'booruIdHint': BooruType.nhentai.id,
        'url': 'https://nhentai.net',
        'ratingFilter': BooruConfigRatingFilter.none.index,
      });
      final cache = Cache();
      final adapter = MissingAdapter();
      const sample = 'https://t1.nhentai.net/galleries/7001/sample.png';
      await cache.saveFile(cache.generateCacheKey(sample), lowerPng);
      final summary = ContentGroupSummary(
        reference: const ContentReferenceCodec().parse(
          engine: BooruType.nhentai,
          site: Uri.parse(config.url),
          kind: ContentKind.group,
          sourceKey: 'gallery:101',
        ),
        title: 'Fixture Gallery',
        memberCount: 3,
        cover: GroupCover(
          thumbnail: Uri.parse(
            'https://t1.nhentai.net/galleries/7001/missing.png',
          ),
          sample: Uri.parse(sample),
          visibility: GroupCoverVisibility(
            tags: const [],
            rating: 'unknown',
            deleted: false,
            banned: false,
          ),
        ),
      );
      final record = ContentGroupBookmark(
        id: 1,
        snapshot: StoredGroupSnapshot(summary: summary),
        createdAt: DateTime.utc(2026),
        observedAt: DateTime.utc(2026),
        sourceProfileHint: config.id,
      );
      final harness = FollowingTopicHarness(
        profiles: [config],
        imageCacheManager: cache,
        loadImages: true,
        overrides: [
          dioForWidgetProvider.overrideWith(
            (_, _) => Dio()..httpClientAdapter = adapter,
          ),
        ],
      );
      addTearDown(harness.dispose);
      var taps = 0;
      await harness.pump(
        tester,
        Scaffold(
          body: Center(
            child: SizedBox.square(
              dimension: 200,
              child: BookmarkLocalGroupCard(
                title: 'Native',
                previews: const [],
                nativeGroups: [record],
                group: null,
                onTap: () => taps++,
                onRename: null,
                onDuplicate: null,
                onDelete: null,
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(
        () => pumpUntil(
          tester,
          () => tester
              .widgetList<ExtendedRawImage>(find.byType(ExtendedRawImage))
              .any((image) => image.image != null),
          reason: 'native cached sample mosaic decode',
        ),
      );
      expect(find.byType(BookmarkNativeGroupCover), findsOneWidget);
      expect(adapter.requests, isEmpty);
      expect(find.byTooltip('Retry'), findsNothing);
      await tester.tap(find.byType(BookmarkLocalGroupCard));
      expect(taps, 1);
      expect(tester.takeException(), isNull);
    },
  );
}

class _GatedSampleCache extends Cache {
  _GatedSampleCache(this.sample);
  final String sample;
  final started = Completer<void>();
  final release = Completer<bool>();
  @override
  FutureOr<bool> hasValidCache(String key, {Duration? maxAge}) {
    if (key == sample) {
      if (!started.isCompleted) started.complete();
      return release.future;
    }
    return super.hasValidCache(key, maxAge: maxAge);
  }
}
