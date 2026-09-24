// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:boorusama/boorus/danbooru/versions/routes.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/widgets.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/rating/types.dart';
import 'package:boorusama/core/posts/sources/types.dart';
import 'package:boorusama/core/router.dart';

void main() {
  testWidgets('tag history navigation carries the page-scoped profile', (
    tester,
  ) async {
    DanbooruPostVersionRouteData? opened;
    late final GoRouter router;
    router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => CurrentBooruConfigScope(
            config: _config,
            child: Consumer(
              builder: (context, ref, _) => Scaffold(
                body: TextButton(
                  onPressed: () => goToPostVersionPage(ref, _post),
                  child: const Text('History'),
                ),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/danbooru/post_versions',
          builder: (context, state) {
            opened = state.extra! as DanbooruPostVersionRouteData;
            return const Scaffold(body: Text('Versions'));
          },
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [routerProvider.overrideWithValue(router)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();

    expect(opened?.post, same(_post));
    expect(opened?.config, _config);
  });
}

final _config = BooruConfig.fromJson({
  ...BooruConfig.defaultConfig(
    booruType: BooruType.danbooru,
    url: 'https://page-profile.example',
    customDownloadFileNameFormat: null,
  ).toJson(),
  'id': 42,
});

final _post = Post(
  origin: PostOrigin.fromSource(
    booruType: BooruType.danbooru,
    booruId: BooruType.danbooru.id,
    source: _config.url,
    profileIdHint: _config.id,
  ),
  core: PostCoreData(
    id: 1,
    thumbnailImageUrl: '',
    sampleImageUrl: '',
    originalImageUrl: '',
    videoUrl: '',
    videoThumbnailUrl: '',
    width: 1,
    height: 1,
    format: 'jpg',
    md5: '',
    fileSize: 0,
    duration: 0,
    tags: const {},
    rating: Rating.general,
    hasComment: false,
    isTranslated: false,
    hasParentOrChildren: false,
    source: PostSource.none(),
    score: 0,
  ),
  booruData: const EmptyPostData(typeKey: 'danbooru'),
);
