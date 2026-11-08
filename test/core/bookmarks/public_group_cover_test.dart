import 'package:boorusama/core/blacklists/providers.dart';
import 'package:boorusama/core/blacklists/src/types/blacklisted_tag.dart';
import 'package:boorusama/core/bookmarks/src/providers/pool_bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/src/types/pool_bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/pool_bookmark_cover.dart';
import 'package:boorusama/core/bookmarks/src/widgets/bookmark_pool_card.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/content/anonymous_access_provider.dart';
import 'package:boorusama/core/content/anonymous_read_scope.dart';
import 'package:boorusama/core/content/anonymous_source_policy.dart';
import 'package:boorusama/core/content/content_access.dart';
import 'package:boorusama/core/content/content_access_provider.dart';
import 'package:boorusama/core/content/content_media_access.dart';
import 'package:boorusama/core/developer_options/providers.dart';
import 'package:boorusama/core/images/booru_image.dart';
import 'package:boorusama/core/posts/listing/providers.dart';
import 'package:boorusama/core/posts/listing/src/types/grid_thumbnail_url_generator.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/src/types/settings.dart';
import 'package:boorusama/core/themes/colors/src/colors.dart';
import 'package:foundation/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/src/gen/strings.g.dart' show TranslationProvider;
import 'package:kurumi/material.dart';
import 'package:kurumi/kurumi.dart';
import 'package:material_ui/material_ui.dart';

const _publicSite = 'https://safebooru.donmai.us';
const _privateSite = 'https://private.example.test';
const _publicId = '00000000-0000-4000-8000-000000000000';
const _profileId = '11111111-1111-4111-8111-111111111111';
const _otherProfileId = '22222222-2222-4222-8222-222222222222';
const _savedPolicy = 'approved-cover-policy';

final _cover = PoolBookmarkCover(
  thumbnail: 'https://cdn.donmai.us/thumb/pool-cover.jpg',
  sample: 'https://cdn.donmai.us/sample/pool-cover.jpg',
  original: 'https://cdn.donmai.us/original/pool-cover.jpg',
  variants: const {
    '180x180': 'https://cdn.donmai.us/180/pool-cover.jpg',
  },
);

class _Configs extends BooruConfigNotifier {
  _Configs(List<BooruConfig> configs) : super(initialConfigs: configs);
}

class _EmptyBlacklist extends GlobalBlacklistedTagsNotifier {
  @override
  IList<BlacklistedTag> build() => <BlacklistedTag>[].lock;
}

class _CoverResolver implements GridThumbnailStaticCoverResolver {
  _CoverResolver(this.result);
  final GridThumbnailMedia result;

  @override
  GridThumbnailMedia resolve(
    Post post, {
    required GridThumbnailSettings settings,
  }) => throw StateError('Pool cover must not construct a synthetic Post');

  @override
  GridThumbnailMedia resolveStaticCover(
    GridThumbnailStaticMedia cover, {
    required GridThumbnailSettings settings,
  }) => result;
}

BooruConfig _config(String id, String site, {String? login}) =>
    BooruConfig.fromJson({
      ...BooruConfig.defaultConfig(
        booruType: BooruType.danbooru,
        url: site,
        customDownloadFileNameFormat: null,
      ).toJson(),
      'id': id,
      'login': login,
    });

PoolBookmark _pool({
  required String site,
  String? profileHint,
  bool proveSite = true,
  String coverPolicy = _savedPolicy,
}) => PoolBookmark(
  localId: '33333333-3333-4333-8333-333333333333',
  origin: PostOrigin.fromSource(
    booruType: BooruType.danbooru,
    booruId: BooruType.danbooru.id,
    source: site,
    profileIdHint: profileHint,
  ),
  poolId: 42,
  sourceSite: proveSite ? Uri.parse(site) : null,
  category: BookmarkedPoolCategory.collection,
  title: 'Pool cover fixture',
  createdAt: DateTime.utc(2026),
  observedAt: DateTime.utc(2026, 1, 2),
  groupIds: const {},
  tags: const {},
  coverage: PoolTagCoverage.unknown,
  total: 3,
  coverUrl: _cover.thumbnail,
  cover: _cover,
  coverPolicy: coverPolicy,
);

final class _Mounted {
  const _Mounted({required this.container, this.scope, this.access});
  final ProviderContainer container;
  final AnonymousReadScope? scope;
  final ContentAccessContext? access;
}

Future<_Mounted> _pumpCover(
  WidgetTester tester, {
  required PoolBookmark pool,
  List<BooruConfig> profiles = const [],
  AsyncValue<String> coverPolicyState = const AsyncData(_savedPolicy),
  bool allowPublic = true,
  bool privatePolicyReady = true,
}) async {
  final sourcePolicy = AnonymousSourcePolicy(enabled: allowPublic);
  final publicSource = const AnonymousSourcePolicy().resolve(
    BooruType.danbooru,
    Uri.parse(_publicSite),
  )!;
  var clientCreations = 0;
  final key = ContentAccessKey(
    engine: BooruType.danbooru,
    siteNamespace: publicSource.site.host,
    authEpoch: 1,
    policyEpoch: 1,
  );
  final scope = AnonymousReadScope(
    source: publicSource,
    key: key,
    createDio: () {
      clientCreations++;
      throw StateError('Cover fixture must not issue media requests');
    },
    current: () => true,
  );
  final publicConfig = BooruConfig.fromJson({
    ...BooruConfig.empty.toJson(),
    'id': _publicId,
    'booruId': BooruType.danbooru.id,
    'booruIdHint': BooruType.danbooru.id,
    'url': _publicSite,
  }).copyWith(anonymousReadScope: scope);
  final publicAccess = ContentAccessContext.anonymous(
    config: publicConfig,
    scope: scope,
  );
  final private = profiles
      .where((profile) => profile.id == pool.origin.profileIdHint)
      .firstOrNull;
  final privateAccess = private == null
      ? null
      : ContentAccessContext.profile(
          config: private,
          authEpoch: 1,
          policyEpoch: 1,
        );
  final container = ProviderContainer(
    overrides: [
      booruConfigProvider.overrideWith(() => _Configs(profiles)),
      globalBlacklistedTagsProvider.overrideWith(_EmptyBlacklist.new),
      anonymousSourcePolicyProvider.overrideWith((ref) => sourcePolicy),
      anonymousContentAccessProvider(publicSource).overrideWith(
        (ref) => publicAccess,
      ),
      contentEffectivePolicyProvider.overrideWith(
        (ref, profileId) => privatePolicyReady
            ? const AsyncData('private-visibility-policy')
            : const AsyncLoading(),
      ),
      poolCoverPolicyProvider.overrideWith(
        (ref, config) => coverPolicyState,
      ),
      imageListingSettingsProvider.overrideWithValue(
        Settings.defaultSettings.listing,
      ),
      automaticMediaLoadingEnabledProvider.overrideWithValue(false),
      gridThumbnailUrlGeneratorProvider.overrideWith(
        (ref, config) => _CoverResolver(
          GridThumbnailMedia(url: _cover.sample, aspectRatio: 1),
        ),
      ),
    ],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: TranslationProvider(
        child: MaterialApp(
          theme: ThemeData(extensions: const [KurumiExtendedColorScheme()])
              .withBoorusamaColors(),
          builder: (context, child) => KurumiTheme(
            data: KurumiThemeData.fromMaterial(
              Theme.of(context).withBoorusamaColors(),
            ),
            child: child!,
          ),
          home: Scaffold(body: BookmarkPoolCoverImage(pool: pool)),
        ),
      ),
    ),
  );
  await tester.pump();
  if (clientCreations != 0) {
    throw StateError('Cover created a network client during fixture pump');
  }
  return _Mounted(
    container: container,
    scope: scope,
    access: privateAccess ?? publicAccess,
  );
}

Future<void> _close(WidgetTester tester, _Mounted mounted) async {
  await tester.pumpWidget(const SizedBox.shrink());
  mounted.container.dispose();
  mounted.scope?.dispose();
}

void main() {
  testWidgets(
    'approved public native cover uses the access-scoped image path',
    (
      tester,
    ) async {
      final mounted = await _pumpCover(
        tester,
        pool: _pool(site: _publicSite),
      );
      addTearDown(() => _close(tester, mounted));

      expect(find.byType(BooruImage), findsOneWidget);
      final image = tester.widget<BooruImage>(find.byType(BooruImage));
      expect(image.imageUrl, _cover.sample);
      expect(
        image.config.anonymousReadScope,
        same(mounted.access!.config!.anonymousReadScope),
      );
      expect(mounted.access!.key.profileId, isNull);
      expect(mounted.access!.config!.anonymousReadScope!.isCurrent, isTrue);
      final scoped = ProviderScope.containerOf(
        tester.element(find.byType(BooruImage)),
        listen: false,
      );
      expect(scoped.read(currentContentAccessKeyProvider), mounted.access!.key);
      expect(scoped.read(contentAccessRequiredProvider), isTrue);
    },
  );

  testWidgets('cover policy mismatch and loading policy both hide the image', (
    tester,
  ) async {
    final stale = await _pumpCover(
      tester,
      pool: _pool(site: _publicSite, coverPolicy: 'old-policy'),
    );
    expect(find.byType(BooruImage), findsNothing);
    await _close(tester, stale);

    final loading = await _pumpCover(
      tester,
      pool: _pool(site: _publicSite),
      coverPolicyState: const AsyncLoading(),
    );
    addTearDown(() => _close(tester, loading));
    expect(find.byType(BooruImage), findsNothing);
  });

  testWidgets('unsafe or unproven public source never creates an image', (
    tester,
  ) async {
    for (final pool in [
      _pool(site: 'http://safebooru.donmai.us'),
      _pool(site: 'https://unapproved.example.test'),
      _pool(site: _publicSite, proveSite: false),
    ]) {
      final mounted = await _pumpCover(tester, pool: pool);
      expect(find.byType(BooruImage), findsNothing);
      await _close(tester, mounted);
    }

    final policyDisabled = await _pumpCover(
      tester,
      pool: _pool(site: _publicSite),
      allowPublic: false,
    );
    addTearDown(() => _close(tester, policyDisabled));
    expect(find.byType(BooruImage), findsNothing);
  });

  testWidgets('a matching private profile keeps its saved cover available', (
    tester,
  ) async {
    final profile = _config(_profileId, _privateSite, login: 'private-user');
    final mounted = await _pumpCover(
      tester,
      pool: _pool(site: _privateSite, profileHint: _profileId),
      profiles: [profile],
    );
    addTearDown(() => _close(tester, mounted));

    expect(find.byType(BooruImage), findsOneWidget);
    final image = tester.widget<BooruImage>(find.byType(BooruImage));
    expect(image.config.login, profile.login);
    expect(image.imageUrl, _cover.sample);
  });

  testWidgets('a stale private source hint cannot borrow a same-host profile', (
    tester,
  ) async {
    final profile = _config(_otherProfileId, _privateSite, login: 'other-user');
    final mounted = await _pumpCover(
      tester,
      pool: _pool(site: _privateSite, profileHint: _profileId),
      profiles: [profile],
    );
    addTearDown(() => _close(tester, mounted));

    expect(find.byType(BooruImage), findsNothing);
  });
}
