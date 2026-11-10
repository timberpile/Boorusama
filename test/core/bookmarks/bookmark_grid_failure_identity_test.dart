import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_group.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_library_state.dart';
import 'package:boorusama/core/bookmarks/src/types/post_bookmark.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/content/anonymous_read_scope.dart';
import 'package:boorusama/core/content/anonymous_source_policy.dart';
import 'package:boorusama/core/content/content_access.dart';
import 'package:boorusama/core/content/content_access_provider.dart';
import 'package:boorusama/core/content/content_media_access.dart';
import 'package:boorusama/core/content/content_media_failures.dart';
import 'package:boorusama/core/developer_options/providers.dart';
import 'package:boorusama/core/images/booru_image.dart';
import 'package:boorusama/core/posts/details/src/types/post_presentation_fallback_reason.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';

import '../../support/fakes/test_post.dart';
import '../posts/details/progressive_image_test_utils.dart' as helpers;

final _activeBookmarkId = StateProvider<int?>((ref) => null);

void main() {
  testWidgets(
    'public retained-row failure uses its local ID across identity collision and no-match cases',
    (tester) async {
      const host = 'https://safebooru.donmai.us';
      final source = const AnonymousSourcePolicy().resolve(
        BooruType.danbooru,
        Uri.parse(host),
      )!;
      final accessKey = ContentAccessKey(
        engine: source.engine,
        siteNamespace: source.site.host,
        authEpoch: 1,
        policyEpoch: 1,
      );
      final scope = AnonymousReadScope(
        source: source,
        key: accessKey,
        createDio: () => throw StateError('Forbidden media must not request'),
        current: () => true,
      );
      addTearDown(scope.dispose);
      final config = BooruConfig.fromJson({
        ...BooruConfig.empty.toJson(),
        'id': '11111111-1111-4111-8111-111111111111',
        'booruId': BooruType.danbooru.id,
        'booruIdHint': BooruType.danbooru.id,
        'url': source.site.toString(),
      }).copyWith(anonymousReadScope: scope);
      final access = ContentAccessContext.anonymous(
        config: config,
        scope: scope,
      );
      final origin = PostOrigin.fromSource(
        booruType: BooruType.danbooru,
        booruId: BooruType.danbooru.id,
        source: host,
      );
      Post unsafePost(int id) => TestPost(
        id: id,
        origin: origin,
        booruData: const LegacyPostData(
          typeKey: 'legacy_danbooru',
          custom: {},
        ),
        thumbnailImageUrl: 'https://foreign.example.test/$id-thumb.jpg',
        sampleImageUrl: 'https://foreign.example.test/$id-sample.jpg',
        originalImageUrl: 'https://foreign.example.test/$id-original.jpg',
      );

      PostBookmark saved({
        required int localId,
        required Post post,
        required int? postId,
      }) => PostBookmark.fromSnapshot(
        id: localId,
        createdAt: DateTime.utc(2024),
        updatedAt: DateTime.utc(2024),
        snapshot: const StoredPostCodec().encode(post),
        post: post,
        postId: postId,
      );

      final knownPost = unsafePost(91);
      final retainedPost = unsafePost(91);
      final unmatchedPost = unsafePost(92);
      final known = saved(localId: 101, post: knownPost, postId: 91);
      final retained = saved(localId: 202, post: retainedPost, postId: null);
      final unmatched = saved(localId: 303, post: unmatchedPost, postId: null);
      final library = BookmarkLibraryState(
        bookmarks: [known, retained, unmatched],
        records: [known, retained, unmatched],
        groups: [
          BookmarkGroup(
            id: '22222222-2222-4222-8222-222222222222',
            name: 'Known',
            bookmarkIds: {known.id},
          ),
          BookmarkGroup(
            id: '33333333-3333-4333-8333-333333333333',
            name: 'Retained collision',
            bookmarkIds: {retained.id},
          ),
          BookmarkGroup(
            id: '44444444-4444-4444-8444-444444444444',
            name: 'Retained without match',
            bookmarkIds: {unmatched.id},
          ),
        ],
      );

      expect(library.bookmarkForPost(retainedPost)?.id, known.id);
      expect(library.storedBookmarkForPost(retainedPost)?.id, retained.id);
      expect(library.bookmarkForPost(unmatchedPost), isNull);
      expect(library.storedBookmarkForPost(unmatchedPost)?.id, unmatched.id);

      final container = ProviderContainer(
        overrides: [
          automaticMediaLoadingEnabledProvider.overrideWithValue(true),
          contentAccessContextProvider(access.key).overrideWithValue(access),
          currentContentAccessKeyProvider.overrideWithValue(access.key),
          contentAccessRequiredProvider.overrideWithValue(true),
          _activeBookmarkId.overrideWith((ref) => retained.id),
          currentContentBookmarkIdProvider.overrideWith(
            (ref) => ref.watch(_activeBookmarkId),
          ),
        ],
      );
      addTearDown(container.dispose);
      final retainedFailure = (
        access: access.key,
        bookmarkId: retained.id,
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: helpers.testApp(
            BooruImage(
              config: config.auth,
              imageUrl: retained.post.originalImageUrl,
              fallbackUrls: [
                retained.post.sampleImageUrl,
                retained.post.thumbnailImageUrl,
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        container.read(contentMediaFailuresProvider),
        {retainedFailure: PostPresentationFallbackReason.unavailableEngine},
      );

      container.read(_activeBookmarkId.notifier).state = known.id;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: helpers.testApp(
            const ContentMediaOutcome(
              failed: false,
              child: SizedBox(key: ValueKey('known-media-succeeded')),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey('known-media-succeeded')),
        findsOneWidget,
      );
      expect(
        container.read(contentMediaFailuresProvider),
        {retainedFailure: PostPresentationFallbackReason.unavailableEngine},
        reason: 'known-row success must not clear the retained local record',
      );

      final unmatchedFailure = (access: access.key, bookmarkId: unmatched.id);
      container.read(_activeBookmarkId.notifier).state = unmatched.id;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: helpers.testApp(
            BooruImage(
              config: config.auth,
              imageUrl: unmatched.post.originalImageUrl,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        container.read(contentMediaFailuresProvider),
        {
          retainedFailure: PostPresentationFallbackReason.unavailableEngine,
          unmatchedFailure: PostPresentationFallbackReason.unavailableEngine,
        },
      );
      expect(tester.takeException(), isNull);
    },
  );
}
