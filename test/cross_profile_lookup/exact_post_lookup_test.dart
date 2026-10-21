// Dart imports:
import 'dart:async';

// Package imports:
import 'package:foundation/foundation.dart';
import 'package:test/test.dart';

// Project imports:
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/errors/error.dart';
import 'package:boorusama/core/posts/cross_profile_lookup/data.dart';
import 'package:boorusama/core/posts/cross_profile_lookup/types.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/rating/types.dart';
import 'package:boorusama/core/posts/sources/types.dart';
import 'package:boorusama/core/search/queries/types.dart';
import 'package:boorusama/core/search/selected_tags/types.dart';

const _hash = '0123456789abcdef0123456789abcdef';
const _otherHash = 'fedcba9876543210fedcba9876543210';

final _sourceOrigin = PostOrigin.fromSource(
  booruType: BooruType.gelbooru,
  booruId: 1,
  source: 'https://gelbooru.com',
  profileIdHint: '00000000-0000-4000-8000-000000000001',
);
final _targetOrigin = PostOrigin.fromSource(
  booruType: BooruType.danbooru,
  booruId: 2,
  source: 'https://danbooru.donmai.us',
  profileIdHint: '00000000-0000-4000-8000-000000000002',
);

void main() {
  late _Repository repository;

  ExactPostLookup lookup({
    PostOrigin? targetOrigin,
    bool apiMode = true,
    bool Function(Post)? isVisible,
  }) => ExactPostLookup(
    repository: repository,
    targetOrigin: targetOrigin ?? _targetOrigin,
    apiMode: apiMode,
    isVisible: isVisible ?? ((_) => true),
  );

  setUp(() {
    repository = _Repository();
  });

  test(
    'uses only the normalized original hash and target repository',
    () async {
      final target = _post(id: 42, origin: _targetOrigin);
      repository.response = PostResult(posts: [target], total: 1);
      final result = await lookup().find(
        _post(md5: ' ${_hash.toUpperCase()} '),
      );

      expect(repository.queries, ['md5:$_hash']);
      expect(repository.pages, [1]);
      expect(repository.limits, [100]);
      expect(repository.options.single?.cascadeRequest, isFalse);
      expect(result, isA<PostLookupPage>());
      final page = result as PostLookupPage;
      expect(page.posts, [target]);
      expect(page.targetOrigin, _targetOrigin);
      expect(page.canOpenDirectly, isTrue);
      expect(page.posts.single.origin, isNot(_sourceOrigin));
    },
  );

  test('supports Gelbooru API targets as well as Danbooru', () async {
    repository.response = PostResult(
      posts: [_post(origin: _sourceOrigin)],
      total: 1,
    );
    final result = await lookup(targetOrigin: _sourceOrigin).find(
      _post(origin: _targetOrigin),
    );
    expect(result, isA<PostLookupPage>());
    expect(repository.queries, ['md5:$_hash']);
  });

  test('does not send requests for unsupported access modes', () async {
    final result = await lookup(apiMode: false).find(_post());
    expect(result, isA<PostLookupUnavailable>());
    expect(
      (result as PostLookupUnavailable).reason,
      PostLookupUnavailableReason.unsupported,
    );
    expect(repository.queries, isEmpty);
  });

  test('does not opt unknown engines into hash lookup', () async {
    final origin = PostOrigin.fromSource(
      booruType: BooruType.fromLegacyId(-999),
      booruId: -999,
      source: 'https://unsupported.example',
      profileIdHint: _targetOrigin.profileIdHint,
    );
    final result = await lookup(targetOrigin: origin).find(_post());
    expect(result, isA<PostLookupUnavailable>());
    expect(repository.queries, isEmpty);
  });

  for (final hash in ['', 'unknown', 'abc', '${_hash}x', '$_hash rating:g']) {
    test('does not request an invalid or missing hash: "$hash"', () async {
      final result = await lookup().find(_post(md5: hash));
      expect(result, isA<PostLookupUnavailable>());
      expect(
        (result as PostLookupUnavailable).reason,
        PostLookupUnavailableReason.missingHash,
      );
      expect(repository.queries, isEmpty);
    });
  }

  test('requires a concrete profile origin', () async {
    final result = await lookup(
      targetOrigin: PostOrigin.forBooruType(BooruType.danbooru),
    ).find(_post());
    expect(result, isA<PostLookupUnavailable>());
    expect(repository.queries, isEmpty);
  });

  test('empty successful result is not a request error', () async {
    final result = await lookup().find(_post()) as PostLookupPage;
    expect(result.posts, isEmpty);
    expect(result.hasFilteredMatches, isFalse);
    expect(result.hasMore, isFalse);
    expect(result.canOpenDirectly, isFalse);
  });

  test('multiple exact matches remain a list', () async {
    repository.response = PostResult(
      posts: [
        _post(id: 10, origin: _targetOrigin),
        _post(id: 20, origin: _targetOrigin),
      ],
      total: 2,
    );
    final result = await lookup().find(_post()) as PostLookupPage;
    expect(result.posts.map((post) => post.id), [10, 20]);
    expect(result.canOpenDirectly, isFalse);
    expect(() => result.posts.clear(), throwsUnsupportedError);
  });

  test('deduplicates repeated IDs within one target page', () async {
    final target = _post(origin: _targetOrigin);
    repository.response = PostResult(posts: [target, target], total: 2);
    final result = await lookup().find(_post()) as PostLookupPage;
    expect(result.posts, [target]);
  });

  test('accepts uppercase hashes in target metadata', () async {
    repository.response = PostResult(
      posts: [_post(origin: _targetOrigin, md5: _hash.toUpperCase())],
      total: 1,
    );
    expect(await lookup().find(_post()), isA<PostLookupPage>());
  });

  for (final hash in [_otherHash, '']) {
    test(
      'does not trust results with a different or absent hash: "$hash"',
      () async {
        repository.response = PostResult(
          posts: [_post(origin: _targetOrigin, md5: hash)],
          total: 1,
        );
        expect(
          await lookup().find(_post()),
          isA<PostLookupInvalidResponse>(),
        );
      },
    );
  }

  test('rejects results carrying the source profile origin', () async {
    repository.response = PostResult(posts: [_post()], total: 1);
    expect(await lookup().find(_post()), isA<PostLookupInvalidResponse>());
  });

  test('rejects a different account on the same endpoint', () async {
    final wrongAccount = PostOrigin.fromSource(
      booruType: _targetOrigin.booruType,
      booruId: _targetOrigin.booruId,
      source: _targetOrigin.sourceHost,
      profileIdHint: _sourceOrigin.profileIdHint,
    );
    repository.response = PostResult(
      posts: [_post(origin: wrongAccount)],
      total: 1,
    );
    expect(await lookup().find(_post()), isA<PostLookupInvalidResponse>());
  });

  test('applies target visibility without exposing hidden posts', () async {
    final target = _post(origin: _targetOrigin);
    repository.response = PostResult(posts: [target], total: 1);
    final checked = <Post>[];
    final result = await lookup(
      isVisible: (post) {
        checked.add(post);
        return false;
      },
    ).find(_post()) as PostLookupPage;
    expect(checked, [target]);
    expect(result.posts, isEmpty);
    expect(result.hasFilteredMatches, isTrue);
    expect(result.canOpenDirectly, isFalse);
  });

  test(
    'preserves pagination even when all current matches are hidden',
    () async {
      repository.response = PostResult(
        posts: [_post(origin: _targetOrigin)],
        total: 101,
        hasMore: true,
      );
      final result = await lookup(
        isVisible: (_) => false,
      ).find(_post()) as PostLookupPage;
      expect(result.hasMore, isTrue);
      expect(result.posts, isEmpty);
    },
  );

  test('does not auto-open an incomplete first page', () async {
    repository.response = PostResult(
      posts: [_post(origin: _targetOrigin)],
      total: 101,
    );
    final result = await lookup().find(_post()) as PostLookupPage;
    expect(result.hasMore, isTrue);
    expect(result.canOpenDirectly, isFalse);
  });

  test('does not auto-open one match from a later page', () async {
    repository.response = PostResult(
      posts: [_post(origin: _targetOrigin)],
      total: 101,
      hasMore: false,
    );
    final result = await lookup().find(_post(), page: 2) as PostLookupPage;
    expect(repository.pages, [2]);
    expect(result.canOpenDirectly, isFalse);
  });

  test(
    'preserves a repository exception rather than reporting no match',
    () async {
      final error = StateError('request failed');
      repository.error = error;
      final result = await lookup().find(_post()) as PostLookupFailed;
      expect(result.error, same(error));
    },
  );

  for (final status in [401, 403, 429]) {
    test('preserves typed server failure $status', () async {
      final failure = ServerError(httpStatusCode: status, message: 'test');
      repository.failure = failure;
      final result = await lookup().find(_post()) as PostLookupFailed;
      expect(result.error, same(failure));
    });
  }

  test('recognizes cancellation returned by the repository', () async {
    repository.failure = RequestCancelledError();
    expect(await lookup().find(_post()), isA<PostLookupCancelled>());
  });

  test('visibility policy failure does not bypass filtering', () async {
    repository.response = PostResult(
      posts: [_post(origin: _targetOrigin)],
      total: 1,
    );
    final result = await lookup(
      isVisible: (_) => throw StateError('visibility unavailable'),
    ).find(_post());
    expect(result, isA<PostLookupFailed>());
  });

  test('cancellation before lookup prevents the request', () async {
    final cancellation = PostLookupCancellation()..cancel();
    final result = await lookup().find(_post(), cancellation: cancellation);
    expect(result, isA<PostLookupCancelled>());
    expect(repository.queries, isEmpty);
  });

  test('cancellation discards a late result without fixed sleeps', () async {
    final gate = Completer<PostResult<Post>>();
    repository.pending = gate.future;
    final cancellation = PostLookupCancellation();
    final pending = lookup().find(_post(), cancellation: cancellation);
    await repository.started.future;
    cancellation.cancel();
    gate.complete(PostResult(posts: [_post(origin: _targetOrigin)], total: 1));
    expect(await pending, isA<PostLookupCancelled>());
  });

  test('cancellation also discards a late request failure', () async {
    final gate = Completer<PostResult<Post>>();
    repository.pending = gate.future;
    final cancellation = PostLookupCancellation();
    final pending = lookup().find(_post(), cancellation: cancellation);
    await repository.started.future;
    cancellation.cancel();
    gate.completeError(StateError('late failure'));
    expect(await pending, isA<PostLookupCancelled>());
  });

  test('invalid page is rejected before requesting', () async {
    await expectLater(lookup().find(_post(), page: 0), throwsArgumentError);
    expect(repository.queries, isEmpty);
  });
}

class _Repository extends PostRepository<Post> {
  var response = PostResult<Post>.empty();
  Future<PostResult<Post>>? pending;
  Object? error;
  BooruError? failure;
  final started = Completer<void>();
  final queries = <String>[];
  final pages = <int>[];
  final limits = <int?>[];
  final options = <PostFetchOptions?>[];

  @override
  PostsOrError<Post> getPosts(
    String tags,
    int page, {
    int? limit,
    PostFetchOptions? options,
  }) {
    queries.add(tags);
    pages.add(page);
    limits.add(limit);
    this.options.add(options);
    if (!started.isCompleted) started.complete();
    // Exercise defensive handling of arbitrary repository failures.
    // ignore: only_throw_errors
    if (error case final thrown?) throw thrown;
    if (failure case final returned?) return TaskEither.left(returned);
    return TaskEither(
      () async => right(await (pending ?? Future.value(response))),
    );
  }

  @override
  PostsOrError<Post> getPostsFromController(
    SearchTagSet controller,
    int page, {
    int? limit,
    PostFetchOptions? options,
  }) => throw StateError('Lookup must not reuse the browsing controller');

  @override
  PostOrError<Post> getPost(PostId id, {PostFetchOptions? options}) =>
      throw StateError('Hash lookup must not reuse an unrelated post ID');

  @override
  TagQueryComposer get tagComposer =>
      throw StateError('Lookup must not use the browsing query');
}

Post _post({int id = 1, String md5 = _hash, PostOrigin? origin}) => Post(
  origin: origin ?? _sourceOrigin,
  core: PostCoreData(
    id: id,
    thumbnailImageUrl: '',
    sampleImageUrl: '',
    originalImageUrl: '',
    videoUrl: '',
    videoThumbnailUrl: '',
    width: 1,
    height: 1,
    format: 'png',
    md5: md5,
    fileSize: 0,
    duration: 0,
    tags: const {},
    rating: Rating.general,
    hasComment: false,
    isTranslated: false,
    hasParentOrChildren: false,
    source: const NoSource(),
    score: 0,
  ),
  booruData: const EmptyPostData(typeKey: 'lookup-test'),
);
