import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:boorusama/core/http/client/providers.dart';
import 'package:boorusama/core/bookmarks/src/widgets/bookmark_local_group_card.dart';
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

void main() {
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
      for (var i = 0; i < 100 && !decoded(); i++) {
        await tester.pump();
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      }
      print({
        'requests': requests,
        'failures': harness.container
            .read(bookmarkCoverFailuresProvider)
            .values
            .map((e) => e.length)
            .toList(),
        'imageWidgets': find.byType(ExtendedRawImage).evaluate().length,
      });
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
      expect(tester.takeException(), isNull);
    },
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
