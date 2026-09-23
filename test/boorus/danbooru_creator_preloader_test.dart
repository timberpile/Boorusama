// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:boorusama/boorus/danbooru/posts/_shared/danbooru_creator_preloader.dart';
import 'package:boorusama/boorus/danbooru/posts/_shared/post_creator_preloadable.dart';
import 'package:boorusama/boorus/danbooru/posts/post/types.dart';
import 'package:boorusama/boorus/danbooru/users/creator/src/providers/local_providers.dart';
import 'package:boorusama/boorus/danbooru/users/creator/src/types/creator_repository.dart';
import 'package:boorusama/boorus/danbooru/users/creator/types.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/widgets.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/rating/types.dart';
import 'package:boorusama/core/posts/sources/types.dart';

void main() {
  testWidgets('loads creators again when the visible Danbooru post changes', (
    tester,
  ) async {
    final repository = _RecordingCreatorRepository();
    final first = _post(id: 1, uploaderId: 11, approverId: 12);
    final second = _post(id: 2, uploaderId: 21, approverId: 22);

    Widget build(Post post) => ProviderScope(
      overrides: [
        danbooruCreatorRepoProvider.overrideWith(
          (ref, config) => Future.value(repository),
        ),
      ],
      child: MaterialApp(
        home: CurrentBooruConfigScope(
          config: _config,
          child: DanbooruCreatorPreloader(
            preloadable: PostCreatorsPreloadable.fromPost(post),
            child: const SizedBox(),
          ),
        ),
      ),
    );

    await tester.pumpWidget(build(first));
    await tester.pump();
    expect(repository.requests, ['11,12']);

    await tester.pumpWidget(build(second));
    await tester.pump();
    expect(repository.requests, ['11,12', '21,22']);

    await tester.pumpWidget(
      build(_post(id: 2, uploaderId: 21, approverId: 22)),
    );
    await tester.pump();
    expect(repository.requests, ['11,12', '21,22']);
  });
}

class _RecordingCreatorRepository implements CreatorRepository {
  final requests = <String>[];

  @override
  Future<List<Creator>> getCreatorsByIdStringComma(
    String idComma, {
    dynamic cancelToken,
  }) async {
    requests.add(idComma);
    return [];
  }
}

final _config = BooruConfig.defaultConfig(
  booruType: BooruType.danbooru,
  url: 'https://danbooru.example',
  customDownloadFileNameFormat: null,
);

Post _post({
  required int id,
  required int uploaderId,
  required int approverId,
}) => Post(
  origin: PostOrigin.fromSource(
    booruType: BooruType.danbooru,
    booruId: BooruType.danbooru.id,
    source: _config.url,
  ),
  core: PostCoreData(
    id: id,
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
    uploaderId: uploaderId,
  ),
  booruData: DanbooruPostData(
    lastCommentAt: null,
    upScore: 0,
    downScore: 0,
    favCount: 0,
    approverId: approverId,
    generalTags: const {},
    metaTags: const {},
    hasChildren: false,
    hasLarge: false,
    pixelHash: '',
  ),
);
