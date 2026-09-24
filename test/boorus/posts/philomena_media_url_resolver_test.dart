// Package imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:boorusama/boorus/philomena/posts/types.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/images/types.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/rating/types.dart';
import 'package:boorusama/core/posts/sources/types.dart';

void main() {
  const representations = PhilomenaRepresentation(
    full: 'full',
    large: 'large',
    medium: 'medium',
    small: 'small',
    tall: 'tall',
    thumb: 'thumb',
    thumbSmall: 'thumbSmall',
    thumbTiny: 'thumbTiny',
  );
  final post = _post(
    const PhilomenaPostData(
      description: '',
      commentCount: 0,
      favCount: 0,
      upvotes: 0,
      representation: representations,
    ),
  );
  final resolver = PhilomenaMediaUrlResolver(
    imageQuality: ImageQuality.automatic,
  );
  final cases = <String, String>{
    'full': representations.full,
    'large': representations.large,
    'medium': representations.medium,
    'small': representations.small,
    'tall': representations.tall,
    'thumb': representations.thumb,
    'thumbSmall': representations.thumbSmall,
    'thumbTiny': representations.thumbTiny,
  };

  for (final entry in cases.entries) {
    test('resolves ${entry.key} from the concrete Philomena payload', () {
      expect(
        resolver.resolveMediaUrl(post, _viewer(entry.key)),
        entry.value,
      );
    });
  }

  test('falls back to the sample URL for an incompatible payload', () {
    expect(
      resolver.resolveMediaUrl(
        _post(const EmptyPostData(typeKey: 'empty')),
        _viewer('full'),
      ),
      'sample',
    );
  });

  test('falls back to the small representation for an unknown quality', () {
    expect(
      resolver.resolveMediaUrl(post, _viewer('unknown')),
      representations.small,
    );
  });

  test('uses the sample URL when no quality is configured', () {
    expect(resolver.resolveMediaUrl(post, _viewer(null)), 'sample');
  });
}

BooruConfigViewer _viewer(String? quality) {
  final config = BooruConfig.defaultConfig(
    booruType: BooruType.philomena,
    url: 'https://philomena.example',
    customDownloadFileNameFormat: null,
  );
  return BooruConfig.fromJson({
    ...config.toJson(),
    'imageDetaisQuality': quality,
  }).viewer;
}

Post _post(BooruPostData data) => Post(
  origin: PostOrigin.fromSource(
    booruType: BooruType.philomena,
    booruId: BooruType.philomena.id,
    source: 'https://philomena.example',
  ),
  core: PostCoreData(
    id: 1,
    thumbnailImageUrl: 'thumbnail',
    sampleImageUrl: 'sample',
    originalImageUrl: 'original',
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
  booruData: data,
);
