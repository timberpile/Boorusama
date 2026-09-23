// Project imports:
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/rating/types.dart';
import 'package:boorusama/core/posts/sources/types.dart';

Post dummyPost({
  int id = 0,
  String thumbnailImageUrl = '',
  String sampleImageUrl = '',
  String originalImageUrl = '',
  Set<String> tags = const {},
}) => Post(
  origin: PostOrigin.forBooruType(BooruType.unknown),
  core: PostCoreData(
    id: id,
    thumbnailImageUrl: thumbnailImageUrl,
    sampleImageUrl: sampleImageUrl,
    originalImageUrl: originalImageUrl,
    videoUrl: '',
    videoThumbnailUrl: '',
    width: 0,
    height: 0,
    format: '',
    md5: '',
    fileSize: 0,
    duration: 0,
    tags: tags,
    rating: Rating.unknown,
    hasComment: false,
    isTranslated: false,
    hasParentOrChildren: false,
    source: PostSource.none(),
    score: 0,
  ),
  booruData: const LegacyPostData(typeKey: 'test_download', custom: {}),
);
