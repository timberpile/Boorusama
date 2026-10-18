// Project imports:
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/rating/types.dart';
import 'package:boorusama/core/posts/sources/types.dart';
import 'package:boorusama/core/boorus/booru/types.dart';

final class TestPost extends Post {
  TestPost({
    required int id,
    PostOrigin? origin,
    BooruPostData booruData = const EmptyPostData(typeKey: 'test'),
    Set<String> tags = const {},
    PostSource? source,
    String thumbnailImageUrl = '',
    String sampleImageUrl = '',
    String originalImageUrl = '',
    String md5 = '',
    double width = 100,
    double height = 100,
    int fileSize = 1024,
    String format = '.jpg',
  }) : super(
         origin: origin ?? PostOrigin.forBooruType(BooruType.unknown),
         booruData: booruData,
         core: PostCoreData(
           id: id,
           tags: tags,
           thumbnailImageUrl: thumbnailImageUrl,
           sampleImageUrl: sampleImageUrl,
           originalImageUrl: originalImageUrl,
           md5: md5,
           width: width,
           height: height,
           fileSize: fileSize,
           format: format,
           rating: Rating.general,
           hasComment: false,
           isTranslated: false,
           hasParentOrChildren: false,
           source: source ?? PostSource.none(),
           score: 10,
           duration: kNoduration,
           hasSound: null,
           videoThumbnailUrl: '',
           videoUrl: '',
         ),
       );
}

/// Posts with consecutive IDs from [first] to [last], both inclusive.
List<TestPost> testPostRange(int first, int last) => [
  for (var id = first; id <= last; id++) TestPost(id: id),
];

PostResult<Post> testPostResult(List<Post> posts, {int maxPage = 1}) =>
    PostResult<Post>(
      posts: List<Post>.unmodifiable(posts),
      total: posts.length,
      maxPage: maxPage,
    );
