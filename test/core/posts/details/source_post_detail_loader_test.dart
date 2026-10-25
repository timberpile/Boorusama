import 'dart:async';

import 'package:boorusama/boorus/shared/source_post_detail_loader.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/posts/details/types.dart';
import 'package:boorusama/core/posts/details/src/widgets/post_details_controller.dart';
import 'package:boorusama/core/posts/post/providers.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/rating/types.dart';
import 'package:boorusama/core/posts/sources/types.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/material.dart';

void main() {
  final config = BooruConfig.fromJson({
    ...BooruConfig.defaultConfig(
      booruType: BooruType.hybooru,
      url: 'https://hybooru.test/',
      customDownloadFileNameFormat: null,
    ).toJson(),
    'id': '550e8400-e29b-41d4-a716-446655440020',
  });

  Future<PostDetailsController<Post>> mount(
    WidgetTester tester,
    Future<Post?> Function(int) fetch, {
    int count = 100,
  }) async {
    final posts = [for (var i = 1; i <= count; i++) _post(config, i)];
    final controller = PostDetailsController<Post>(
      scrollController: null,
      initialPage: 0,
      posts: posts,
      initialThumbnailUrl: null,
      reduceAnimations: true,
      dislclaimer: null,
      doubleTapSeekDuration: 10,
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentReadOnlyBooruConfigProvider.overrideWithValue(config),
          booruConfigProvider.overrideWith(
            () => BooruConfigNotifier(initialConfigs: [config]),
          ),
          sourcePostDetailProvider.overrideWith(
            (ref, request) => fetch(request.$2),
          ),
        ],
        child: MaterialApp(
          home: ValueListenableBuilder<Post>(
            valueListenable: controller.currentPost,
            builder: (_, post, _) => PostDetails(
              data: PostDetailsData<Post>(posts: posts, controller: controller),
              child: SourcePostDetailLoader(
                post: post,
                child: const SizedBox(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return controller;
  }

  testWidgets(
    '100 listing entries admit only the opened post and retain its source facts on replacement',
    (tester) async {
      final result = Completer<Post?>();
      final requests = <int>[];
      final controller = await mount(tester, (id) {
        requests.add(id);
        return result.future;
      });
      expect(requests, [1]);
      expect(controller.currentPost.value.detailFacts.originalByteSize, isNull);
      result.complete(_post(config, 1, resolved: true));
      await tester.pumpAndSettle();
      expect(controller.currentPost.value.detailFacts.originalByteSize, 900);
      expect(controller.currentPost.value.origin.profileIdHint, config.id);
      expect(requests, [1]);
      expect(
        controller.posts
            .skip(1)
            .every((p) => p.detailFacts.originalByteSize == null),
        isTrue,
      );
    },
  );

  testWidgets(
    'rapid swipes keep one lookup active, skip intermediate pages and discard obsolete results',
    (tester) async {
      final requests = <int>[];
      final first = Completer<Post?>();
      final latest = Completer<Post?>();
      final controller = await mount(tester, (id) {
        requests.add(id);
        return id == 1 ? first.future : latest.future;
      });
      controller.setPage(1);
      controller.updateCurrentPost(1);
      await tester.pump();
      controller.setPage(2);
      controller.updateCurrentPost(2);
      await tester.pump();
      expect(requests, [1]);
      first.complete(_post(config, 1, resolved: true));
      await tester.pumpAndSettle();
      expect(requests, [1, 3]);
      expect(controller.posts.first.detailFacts.originalByteSize, isNull);
      latest.complete(_post(config, 3, resolved: true));
      await tester.pumpAndSettle();
      expect(controller.currentPost.value.id, 3);
      expect(controller.currentPost.value.detailFacts.originalByteSize, 900);
      expect(controller.posts[1].detailFacts.originalByteSize, isNull);
    },
  );

  testWidgets(
    'failed details leave the listing visible without a rebuild request loop',
    (tester) async {
      var calls = 0;
      final failure = Completer<Post?>();
      final controller = await mount(tester, (id) {
        calls++;
        return failure.future;
      });
      final original = controller.currentPost.value;
      failure.completeError(StateError('offline'));
      await tester.pumpAndSettle();
      await tester.pump();
      expect(controller.currentPost.value, same(original));
      expect(calls, 1);
      expect(tester.takeException(), isNull);
    },
  );
}

Post _post(BooruConfig config, int id, {bool resolved = false}) => Post(
  origin: postOriginFromConfig(config),
  booruData: const EmptyPostData(typeKey: 'hybooru'),
  core: PostCoreData(
    id: id,
    thumbnailImageUrl: 'https://media.test/thumb.jpg',
    sampleImageUrl: 'https://media.test/sample.jpg',
    originalImageUrl: resolved
        ? 'https://media.test/original.jpg'
        : 'https://media.test/sample.jpg',
    videoUrl: '',
    videoThumbnailUrl: '',
    width: 1200,
    height: 800,
    format: 'jpg',
    md5: '',
    fileSize: 0,
    duration: 0,
    tags: const {},
    rating: Rating.unknown,
    hasComment: false,
    isTranslated: false,
    hasParentOrChildren: false,
    source: PostSource.none(),
    score: 0,
    metadata: resolved ? null : const PostMetadata(page: 1),
    detailFacts: resolved
        ? const PostDetailFacts(
            originalByteSize: 900,
            originalWidth: 1200,
            originalHeight: 800,
            originalFormat: 'jpg',
          )
        : const PostDetailFacts(),
  ),
);
