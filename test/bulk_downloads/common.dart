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
  String videoUrl = '',
  String format = '',
  double width = 0,
  double height = 0,
  int fileSize = 0,
  PostSource? source,
}) => Post(
  origin: PostOrigin.forBooruType(BooruType.unknown),
  core: PostCoreData(
    id: id,
    thumbnailImageUrl: thumbnailImageUrl,
    sampleImageUrl: sampleImageUrl,
    originalImageUrl: originalImageUrl,
    videoUrl: videoUrl,
    videoThumbnailUrl: '',
    width: width,
    height: height,
    format: format,
    md5: '',
    fileSize: fileSize,
    duration: 0,
    tags: tags,
    rating: Rating.unknown,
    hasComment: false,
    isTranslated: false,
    hasParentOrChildren: false,
    source: source ?? PostSource.none(),
    score: 0,
  ),
  booruData: const LegacyPostData(typeKey: 'test_download', custom: {}),
);
