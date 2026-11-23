import 'package:boorusama/core/boorus/engine/providers.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/bookmarks/src/data/bookmark_convert.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_button_state_provider.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_identity.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/listing/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/content/anonymous_read_scope.dart';
import 'package:boorusama/core/content/anonymous_source_policy.dart';
import 'package:boorusama/core/content/content_access.dart';
import 'package:boorusama/core/posts/details_parts/widgets.dart';
import 'package:boorusama/core/posts/listing/src/widgets/default_image_quick_actions.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:material_ui/material_ui.dart';

import '../../../support/fakes/test_post.dart';

void main() {
  testWidgets(
    'public quick actions retain local bookmarks and hide server actions',
    (
      tester,
    ) async {
      final fixture = _publicFixture(
        actions: ThumbnailActions(
          primary: ThumbnailAction.defaultAction,
          secondary: ThumbnailAction.bookmark,
        ),
      );
      addTearDown(fixture.scope.dispose);
      await _pumpActions(tester, fixture);

      expect(find.byType(BookmarkPostLikeButtonButton), findsOneWidget);
      expect(find.text('server favorite'), findsNothing);
      expect(find.byTooltip('Download'), findsNothing);
    },
  );

  testWidgets('public actors hide grid download and artist actions', (
    tester,
  ) async {
    final fixture = _publicFixture(
      actions: ThumbnailActions(
        primary: ThumbnailAction.download,
        secondary: ThumbnailAction.artist,
      ),
    );
    addTearDown(fixture.scope.dispose);
    await _pumpActions(tester, fixture);

    expect(
      tester
          .widget<ThumbnailActionGroup>(find.byType(ThumbnailActionGroup))
          .children,
      isEmpty,
    );
    expect(find.byTooltip('view_artist: artist'), findsNothing);
  });
}

_Fixture _publicFixture({required ThumbnailActions actions}) {
  final source = const AnonymousSourcePolicy().resolve(
    BooruType.danbooru,
    Uri.parse('https://safebooru.donmai.us'),
  )!;
  final scope = AnonymousReadScope(
    source: source,
    key: ContentAccessKey(
      engine: source.engine,
      siteNamespace: source.site.host,
      authEpoch: 1,
      policyEpoch: 1,
    ),
    current: () => true,
    createDio: () =>
        throw StateError('Quick action tests must not create HTTP clients'),
  );
  final config = BooruConfig.fromJson({
    ...BooruConfig.empty.toJson(),
    'id': '00000000-0000-4000-8000-000000000000',
    'booruId': source.engine.id,
    'booruIdHint': source.engine.id,
    'url': source.site.toString(),
    'login': null,
    'apiKey': null,
    'passHash': null,
    'proxySettings': null,
    'networkSettings': null,
  }).copyWith(anonymousReadScope: scope, thumbnailActions: actions);
  final auth = BooruConfigAuth.fromConfig(config);
  final post = _postWithArtist();
  final uniqueId = bookmarkIdentityForPost(post, auth.booruIdHint);
  return _Fixture(
    config: config,
    auth: auth,
    post: post,
    scope: scope,
    uniqueId: uniqueId,
  );
}

Post _postWithArtist() {
  final base = TestPost(id: 91);
  return base.copyWith(
    core: PostCoreData(
      id: base.id,
      thumbnailImageUrl: base.thumbnailImageUrl,
      sampleImageUrl: base.sampleImageUrl,
      originalImageUrl: base.originalImageUrl,
      videoUrl: base.videoUrl,
      videoThumbnailUrl: base.videoThumbnailUrl,
      width: base.width,
      height: base.height,
      format: base.format,
      md5: base.md5,
      fileSize: base.fileSize,
      duration: base.duration,
      tags: base.tags,
      rating: base.rating,
      hasComment: base.hasComment,
      isTranslated: base.isTranslated,
      hasParentOrChildren: base.hasParentOrChildren,
      source: base.source,
      score: base.score,
      artistTags: const {'artist'},
    ),
  );
}

Future<void> _pumpActions(WidgetTester tester, _Fixture fixture) async {
  final container = ProviderContainer(
    overrides: [
      currentReadOnlyBooruConfigProvider.overrideWithValue(fixture.config),
      currentReadOnlyBooruConfigAuthProvider.overrideWithValue(fixture.auth),
      booruBuilderProvider(fixture.auth).overrideWithValue(null),
      bookmarkButtonStateProvider(fixture.uniqueId).overrideWithValue(
        const BookmarkButtonState(isLoading: false),
      ),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: BooruLocalization(
        child: MaterialApp(
          theme: ThemeData(
            extensions: const [KurumiExtendedColorScheme()],
          ),
          home: Scaffold(
            body: SizedBox(
              width: 120,
              height: 120,
              child: DefaultImagePreviewQuickActions(
                post: fixture.post,
                config: fixture.auth,
                defaultActionButton: const Text('server favorite'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

class _Fixture {
  const _Fixture({
    required this.config,
    required this.auth,
    required this.post,
    required this.scope,
    required this.uniqueId,
  });

  final BooruConfig config;
  final BooruConfigAuth auth;
  final Post post;
  final AnonymousReadScope scope;
  final BookmarkUniqueId uniqueId;
}
