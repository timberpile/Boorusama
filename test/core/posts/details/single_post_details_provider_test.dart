// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';

// Project imports:
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/posts/details/providers.dart';
import 'package:boorusama/core/posts/post/providers.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/rating/types.dart';
import 'package:boorusama/core/posts/sources/types.dart';
import 'package:boorusama/core/search/queries/types.dart';
import 'package:boorusama/core/search/selected_tags/types.dart';

void main() {
  test('binds the full profile origin to a directly fetched post', () async {
    final config = BooruConfig.fromJson({
      ...BooruConfig.defaultConfig(
        booruType: BooruType.danbooru,
        url: 'https://direct.example',
        customDownloadFileNameFormat: null,
      ).toJson(),
      'id': 42,
    });
    final container = ProviderContainer(
      overrides: [
        postRepoProvider.overrideWith((ref, config) => _Repository(_post)),
      ],
    );
    addTearDown(container.dispose);

    final post = await container.read(
      singlePostDetailsProvider((const NumericPostId(1), config)).future,
    );

    expect(post?.origin.sourceHost, 'direct.example');
    expect(post?.origin.profileIdHint, 42);
  });
}

class _Repository implements PostRepository<Post> {
  const _Repository(this.post);

  final Post post;

  @override
  TagQueryComposer get tagComposer => EmptyTagQueryComposer();

  @override
  PostOrError<Post> getPost(PostId id, {PostFetchOptions? options}) =>
      TaskEither.right(post);

  @override
  PostsOrError<Post> getPosts(
    String tags,
    int page, {
    int? limit,
    PostFetchOptions? options,
  }) => TaskEither.right(PostResult.empty());

  @override
  PostsOrError<Post> getPostsFromController(
    SearchTagSet controller,
    int page, {
    int? limit,
    PostFetchOptions? options,
  }) => TaskEither.right(PostResult.empty());
}

final _post = Post(
  origin: PostOrigin.forBooruType(BooruType.danbooru),
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
  booruData: const EmptyPostData(typeKey: 'test'),
);
