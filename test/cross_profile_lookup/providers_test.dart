import 'dart:async';

import 'package:boorusama/core/blacklists/providers.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/posts/cross_profile_lookup/providers.dart';
import 'package:boorusama/core/posts/cross_profile_lookup/types.dart';
import 'package:boorusama/core/posts/post/providers.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/rating/types.dart';
import 'package:boorusama/core/posts/sources/types.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';

import '../bulk_downloads/common.dart';
import '../core/posts/links/boorusama_post_link_test.dart' show config;

const hash = '0123456789abcdef0123456789abcdef';
final sourceProfile = config(
  'https://source.test',
  id: '00000000-0000-4000-8000-000000000001',
);
final targetProfile = config('https://target.test')
    .copyWith(name: 'Target', login: 'target-user', apiKey: 'target-key');

Post post(
  BooruConfig profile, {
  int id = 42,
  String md5 = hash,
  Set<String> tags = const {},
  Rating rating = Rating.general,
  String? sourceUrl,
}) {
  final base = dummyPost(id: id, tags: tags);
  return base.copyWith(
    origin: postOriginFromConfig(profile),
    core: PostCoreData(
      id: id,
      thumbnailImageUrl: '',
      sampleImageUrl: '',
      originalImageUrl: '',
      videoUrl: '',
      videoThumbnailUrl: '',
      width: 100,
      height: 100,
      format: 'jpg',
      md5: md5,
      fileSize: 100,
      duration: 0,
      tags: tags,
      rating: rating,
      hasComment: false,
      isTranslated: false,
      hasParentOrChildren: false,
      source: sourceUrl == null ? base.source : PostSource.from(sourceUrl),
      score: 0,
    ),
  );
}

class Profiles extends BooruConfigNotifier {
  Profiles(List<BooruConfig> profiles) : super(initialConfigs: profiles);
  // Used by the widget tests sharing this fixture.
  // ignore: unreachable_from_main
  void replace(List<BooruConfig> profiles) => state = profiles;
}

class Repository extends Fake implements PostRepository<Post> {
  PostResult<Post> result = PostResult.empty();
  Post? metadata;
  final queries = <String>[];
  final ids = <PostId>[];
  @override
  PostsOrError<Post> getPosts(
    String tags,
    int page, {
    int? limit,
    PostFetchOptions? options,
  }) {
    queries.add(tags);
    expect(options?.cascadeRequest, isFalse);
    return TaskEither.right(result);
  }

  @override
  PostOrError<Post> getPost(PostId id, {PostFetchOptions? options}) {
    ids.add(id);
    expect(options?.cascadeRequest, isFalse);
    return TaskEither.right(metadata);
  }
}

void main() {
  testWidgets('source metadata refresh is bounded by a controlled timeout', (
    tester,
  ) async {
    final gate = Completer<Post?>();
    final session = CrossProfileLookupSession(
      source: post(sourceProfile, md5: ''),
      refreshSource: () => gate.future,
      lookup: (_) => throw StateError('Must not search'),
    );
    final pending = session.find(
      targetProfile,
      cancellation: PostLookupCancellation(),
    );
    await tester.pump(const Duration(seconds: 15));
    expect(
      await pending,
      isA<PostLookupFailed>().having(
        (r) => r.error,
        'error',
        isA<TimeoutException>(),
      ),
    );
    gate.complete(null);
  });

  test(
    'target provider selects exact account and filters target blacklist',
    () async {
      final repository = Repository()
        ..result = PostResult(
          total: null,
          posts: [
            post(targetProfile),
            post(targetProfile, id: 43, tags: {'blocked'}),
          ],
          hasMore: false,
        );
      final seen = <BooruConfig>[];
      final container = ProviderContainer(
        overrides: [
          originAwarePostRepoProvider.overrideWith((ref, profile) {
            seen.add(profile);
            return repository;
          }),
          blacklistTagsProvider.overrideWith((ref, filter) {
            expect(filter.auth, targetProfile.auth);
            return {'blocked'};
          }),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        exactPostLookupProvider(targetProfile),
        (_, _) {},
      );
      addTearDown(subscription.close);
      final lookup = await container.read(
        exactPostLookupProvider(targetProfile).future,
      );
      final result = await lookup.find(post(sourceProfile)) as PostLookupPage;
      expect(seen, [targetProfile]);
      expect(seen.single.auth.login, 'target-user');
      expect(result.posts.map((p) => p.id), [42]);
      expect(result.hasFilteredMatches, isTrue);
      expect(repository.queries, ['md5:$hash']);
    },
  );

  test(
    'source refresh uses origin account once across target selections',
    () async {
      final source = post(sourceProfile, md5: '');
      final sourceRepo = Repository()..metadata = post(sourceProfile);
      final targetRepo = Repository()
        ..result = PostResult(
          total: null,
          posts: [post(targetProfile)],
          hasMore: false,
        );
      final container = ProviderContainer(
        overrides: [
          booruConfigProvider.overrideWith(
            () => Profiles([sourceProfile, targetProfile]),
          ),
          originAwarePostRepoProvider.overrideWith(
            (ref, profile) =>
                profile == sourceProfile ? sourceRepo : targetRepo,
          ),
          blacklistTagsProvider.overrideWith((ref, filter) => <String>{}),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        crossProfileLookupSessionProvider(source),
        (_, _) {},
      );
      addTearDown(subscription.close);
      final session = container.read(crossProfileLookupSessionProvider(source));
      expect(sourceRepo.ids, isEmpty);
      expect(targetRepo.queries, isEmpty);
      for (var i = 0; i < 2; i++) {
        expect(
          await session.find(
            targetProfile,
            cancellation: PostLookupCancellation(),
          ),
          isA<PostLookupPage>(),
        );
      }
      expect(sourceRepo.ids, [const NumericPostId(42)]);
      expect(sourceRepo.queries, isEmpty);
      expect(targetRepo.queries, ['md5:$hash', 'md5:$hash']);
    },
  );

  test(
    'missing originating account never refreshes through another account',
    () async {
      final source = post(sourceProfile, md5: '');
      final otherAccount = config(sourceProfile.url);
      final container = ProviderContainer(
        overrides: [
          booruConfigProvider.overrideWith(
            () => Profiles([otherAccount, targetProfile]),
          ),
          originAwarePostRepoProvider.overrideWith(
            (ref, profile) => throw StateError('Must not fetch'),
          ),
        ],
      );
      addTearDown(container.dispose);
      final session = container.read(crossProfileLookupSessionProvider(source));
      final result = await session.find(
        targetProfile,
        cancellation: PostLookupCancellation(),
      );
      expect(
        result,
        isA<PostLookupUnavailable>().having(
          (r) => r.reason,
          'reason',
          PostLookupUnavailableReason.missingHash,
        ),
      );
    },
  );

  test('cancel during refresh prevents target lookup', () async {
    final gate = Completer<Post?>();
    var lookups = 0;
    final session = CrossProfileLookupSession(
      source: post(sourceProfile, md5: ''),
      refreshSource: () => gate.future,
      lookup: (_) {
        lookups++;
        throw StateError('Unexpected lookup');
      },
    );
    final cancellation = PostLookupCancellation();
    final pending = session.find(targetProfile, cancellation: cancellation);
    cancellation.cancel();
    gate.complete(post(sourceProfile));
    expect(await pending, isA<PostLookupCancelled>());
    expect(lookups, 0);
  });

  test('refresh failure stays a failure and is not repeated', () async {
    var refreshes = 0;
    final session = CrossProfileLookupSession(
      source: post(sourceProfile, md5: ''),
      refreshSource: () {
        refreshes++;
        throw StateError('private diagnostics');
      },
      lookup: (_) => throw StateError('Unexpected lookup'),
    );
    for (var i = 0; i < 2; i++) {
      expect(
        await session.find(
          targetProfile,
          cancellation: PostLookupCancellation(),
        ),
        isA<PostLookupFailed>(),
      );
    }
    expect(refreshes, 1);
  });

  test('target rating restrictions are enforced locally', () {
    final restricted = BooruConfig.fromJson({
      ...targetProfile.toJson(),
      'ratingFilter': 2,
    });
    expect(
      isExactLookupPostVisible(post(targetProfile), restricted, {}),
      isTrue,
    );
    for (final rating in [
      Rating.explicit,
      Rating.questionable,
      Rating.sensitive,
      Rating.unknown,
    ]) {
      expect(
        isExactLookupPostVisible(
          post(targetProfile, rating: rating),
          restricted,
          {},
        ),
        isFalse,
      );
    }
  });
}
