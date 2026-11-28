import 'dart:async';

import 'package:booru_clients/pixiv.dart';
import 'package:boorusama/boorus/pixiv/client_provider.dart';
import 'package:boorusama/boorus/pixiv/works/work_mapper.dart';
import 'package:boorusama/core/blacklists/providers.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/cache/misc_data_store.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/content/content_access_provider.dart';
import 'package:boorusama/core/content/content_entry.dart';
import 'package:boorusama/core/developer_options/providers.dart';
import 'package:boorusama/core/images/providers.dart';
import 'package:boorusama/core/posts/cross_profile_lookup/lookup_preferences.dart';
import 'package:boorusama/core/posts/cross_profile_lookup/page.dart';
import 'package:boorusama/core/posts/cross_profile_lookup/pixiv_artwork_lookup.dart';
import 'package:boorusama/core/posts/cross_profile_lookup/types.dart';
import 'package:boorusama/core/posts/details/src/routes/details_route_context.dart';
import 'package:boorusama/core/posts/details/src/types/viewer_entry.dart';
import 'package:boorusama/core/posts/post/providers.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/router.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/src/gen/strings.g.dart' show TranslationProvider;
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

import '../core/posts/links/boorusama_post_link_test.dart' show config;
import '../support/fakes/memory_repositories.dart';
import 'providers_test.dart' show Profiles, Repository, post, sourceProfile;
import 'widget_test_support.dart';

const _artworkId = 12345;
const _artworkUrl = 'https://www.pixiv.net/en/artworks/12345';
final _pixiv = config(
  'https://www.pixiv.net',
  type: BooruType.pixiv,
).copyWith(name: 'Pixiv Profile', apiKey: 'fixture-pixiv-token');

PixivIllustDto _artwork({
  int id = _artworkId,
  String type = 'illust',
  bool muted = false,
  int? sanityLevel,
}) => PixivIllustDto.fromJson({
  'id': id,
  'user': {'id': 111},
  'type': type,
  'title': 'Two-page artwork',
  'page_count': type == 'ugoira' ? 1 : 2,
  'x_restrict': 0,
  'sanity_level': ?sanityLevel,
  'is_muted': muted,
  'tags': [
    {'name': 'wildlife'},
  ],
  if (type == 'ugoira')
    'meta_single_page': {
      'original_image_url': 'https://i.pximg.net/img-original/${id}_p0.jpg',
    }
  else
    'meta_pages': [
      for (var page = 0; page < 2; page++)
        {
          'image_urls': {
            'original': 'https://i.pximg.net/img-original/${id}_p$page.jpg',
          },
        },
    ],
});

class _PixivClient extends Fake implements PixivClient {
  _PixivClient(this.fetch);

  final Future<PixivIllustDto?> Function() fetch;
  final requestedIds = <int>[];

  @override
  Future<PixivIllustDto?> getIllustDetail({required int illustId}) {
    requestedIds.add(illustId);
    return fetch();
  }
}

void main() {
  test('Pixiv target method needs a configured account and validated ID', () {
    final linked = post(sourceProfile, sourceUrl: _artworkUrl);
    expect(
      remoteLookupMethods(_pixiv, linked),
      {PostLookupMatchKind.pixivSource},
    );
    expect(
      remoteLookupMethods(
        _pixiv,
        post(
          sourceProfile,
          sourceUrl: 'https://pixiv.net.example/artworks/12345',
        ),
      ),
      isEmpty,
    );
    final guest = config('https://www.pixiv.net', type: BooruType.pixiv);
    expect(remoteLookupMethods(guest, linked), isEmpty);
  });

  test(
    'verified Pixiv detail preserves a Work or Ugoira and filters it',
    () async {
      var dto = _artwork();
      var blocked = <String>{};
      final client = _PixivClient(() async => dto);
      final profiles = Profiles([sourceProfile, _pixiv]);
      final container = ProviderContainer(
        overrides: [
          booruConfigProvider.overrideWith(() => profiles),
          blacklistTagsProvider.overrideWith((_, _) => blocked),
          pixivClientProvider.overrideWith((_, auth) {
            expect(auth, _pixiv.auth);
            return client;
          }),
        ],
      );
      addTearDown(container.dispose);
      Future<PostLookupResult> lookup([BooruConfig? target]) =>
          container.read(pixivArtworkLookupProvider)(
            target ?? _pixiv,
            _artworkId,
            PostLookupCancellation(),
          );

      final work = await lookup() as PixivArtworkMatch;
      expect(work.access.profileId, _pixiv.id);
      expect((work.entry as GroupContentEntry).summary.memberCount, 2);
      expect(work.entry.reference.sourceKey, 'work:12345');
      dto = _artwork(type: 'ugoira');
      final animated = await lookup() as PixivArtworkMatch;
      expect(animated.entry, isA<PostContentEntry>());
      expect(animated.entry.reference.sourceKey, 'work-page:12345:0');

      dto = _artwork(id: 912345);
      expect(await lookup(), isA<PostLookupInvalidResponse>());
      dto = _artwork(muted: true);
      expect((await lookup() as PostLookupPage).posts, isEmpty);

      blocked = {'wildlife'};
      container.invalidate(blacklistTagsProvider(_pixiv.filter));
      dto = _artwork();
      expect((await lookup() as PostLookupPage).hasFilteredMatches, isTrue);

      final restricted = BooruConfig.fromJson({
        ..._pixiv.toJson(),
        'ratingFilter': BooruConfigRatingFilter.hideExplicit.index,
      });
      profiles.replace([sourceProfile, restricted]);
      blocked = {};
      dto = _artwork(type: 'ugoira', sanityLevel: 6);
      final hiddenAnimation = await lookup(restricted) as PostLookupPage;
      expect(hiddenAnimation.hasFilteredMatches, isTrue);
      expect(hiddenAnimation.posts, isEmpty);
      expect(client.requestedIds, everyElement(_artworkId));
    },
  );

  test(
    'a profile revoked during the request cannot publish an artwork',
    () async {
      final started = Completer<void>();
      final response = Completer<PixivIllustDto?>();
      final client = _PixivClient(() {
        started.complete();
        return response.future;
      });
      final profiles = Profiles([sourceProfile, _pixiv]);
      final container = ProviderContainer(
        overrides: [
          booruConfigProvider.overrideWith(() => profiles),
          blacklistTagsProvider.overrideWith((_, _) => <String>{}),
          pixivClientProvider.overrideWith((_, _) => client),
        ],
      );
      addTearDown(container.dispose);

      final pending = container.read(pixivArtworkLookupProvider)(
        _pixiv,
        _artworkId,
        PostLookupCancellation(),
      );
      await started.future;
      profiles.replace([sourceProfile]);
      response.complete(_artwork());
      expect(await pending, isA<PostLookupCancelled>());
    },
  );

  testWidgets(
    'a linked post finds one Work and opens it under the Pixiv profile',
    (
      tester,
    ) async {
      final client = _PixivClient(() async => _artwork());
      var blocked = <String>{};
      DetailsRouteContext? opened;
      final linked = post(sourceProfile, sourceUrl: _artworkUrl);
      final router = _router(
        onOpen: (ref) => findOnOtherProfiles(ref, linked),
        onViewer: (context, state) {
          opened = state.extra! as DetailsRouteContext;
          return const Scaffold(body: Text('Opened Work'));
        },
      );
      addTearDown(router.dispose);
      await _pump(
        tester,
        router,
        [pixivClientProvider.overrideWith((_, _) => client)],
        blacklist: () => blocked,
      );
      await tester.tap(find.text('Find'));
      await tester.pumpAndSettle();
      expect(find.text(_pixiv.name), findsOneWidget);
      final chip = find.widgetWithText(FilterChip, 'Pixiv Artwork ID');
      expect(tester.widget<FilterChip>(chip).selected, isTrue);
      await tester.tap(find.widgetWithText(FilledButton, 'Search'));
      await tester.pumpAndSettle();

      expect(client.requestedIds, [_artworkId]);
      expect(find.text('Two-page artwork'), findsOneWidget);
      await tester.tap(find.text('Two-page artwork'));
      await tester.pumpAndSettle();
      expect(opened?.config, _pixiv);
      final entry = opened!.entries!.single as GroupViewerEntry;
      expect(entry.contentReference.sourceKey, 'work:12345');
      expect(entry.source?.config, _pixiv);
      expect(opened?.posts, isEmpty);
      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('Two-page artwork'), findsOneWidget);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(CrossProfileLookupPage)),
        listen: false,
      );
      blocked = {'wildlife'};
      container.invalidate(blacklistTagsProvider(_pixiv.filter));
      await tester.pumpAndSettle();
      expect(find.text('Two-page artwork'), findsNothing);
      expect(client.requestedIds, [_artworkId]);
    },
  );

  for (final action in ['Find Work', 'Find']) {
    testWidgets('$action searches only selected Pixiv profiles and modes', (
      tester,
    ) async {
      final safebooru = config(
        'https://safebooru.org',
        type: BooruType.gelbooruV2,
        id: '00000000-0000-4000-8000-000000000004',
      ).copyWith(name: 'Safebooru Profile');
      final repository = Repository()
        ..result = PostResult(
          posts: [post(sourceProfile, id: 77, sourceUrl: _artworkUrl)],
          total: null,
          hasMore: false,
        );
      final safebooruRepository = Repository();
      final pixivClient = _PixivClient(
        () async => throw StateError('Artwork ID must not fetch originals'),
      );
      final router = _router(
        onOpen: (ref) {
          final access = ref.read(contentProfileAccessProvider(_pixiv.id))!;
          final nativePage = pixivWorkPagePosts(_artwork(), access).last;
          return findOnOtherProfiles(ref, nativePage, access: access);
        },
        onOpenWork: (ref) {
          final access = ref.read(contentProfileAccessProvider(_pixiv.id))!;
          return findPixivWorkOnOtherProfiles(
            ref,
            pixivWorkReference(access, _artworkId),
            access,
          );
        },
      );
      addTearDown(router.dispose);
      await _pump(
        tester,
        router,
        [
          originAwarePostRepoProvider.overrideWith((_, profile) {
            if (profile == safebooru) return safebooruRepository;
            expect(profile, sourceProfile);
            return repository;
          }),
          pixivClientProvider.overrideWith((_, _) => pixivClient),
        ],
        profiles: [sourceProfile, safebooru, _pixiv],
      );

      final container = ProviderScope.containerOf(
        tester.element(find.text(action)),
        listen: false,
      );
      final savedChoices = action == 'Find'
          ? <String, LookupProfileChoice>{
              safebooru.id: (
                endpoint: lookupEndpoint(safebooru),
                methods: const {PostLookupMatchKind.exactFile},
              ),
            }
          : null;
      if (savedChoices != null) {
        await container
            .read(lookupPreferencesProvider.notifier)
            .saveProfiles(savedChoices);
      }

      final sheet = find.text('Matching Profiles');
      final danbooru = find.widgetWithText(ListTile, sourceProfile.name);
      final safebooruTile = find.widgetWithText(ListTile, safebooru.name);
      Finder mode(Finder tile, String label) => find.descendant(
        of: tile,
        matching: find.widgetWithText(FilterChip, label),
      );
      final artworkMode = mode(danbooru, 'Pixiv Artwork ID');
      final exactMode = mode(danbooru, 'Exact MD5');
      final safebooruExact = mode(safebooruTile, 'Exact MD5');
      final selectAll = find.widgetWithText(TextButton, 'Select All');

      for (final confirm in [false, true]) {
        await tester.tap(find.text(action));
        await tester.pumpAndSettle();
        expect(sheet, findsOneWidget);
        expect(artworkMode, findsOneWidget);
        expect(exactMode, findsOneWidget);
        expect(safebooruExact, findsOneWidget);
        expect(mode(safebooruTile, 'Pixiv Artwork ID'), findsNothing);
        expect(find.text(_pixiv.name), findsNothing);

        if (!confirm) {
          if (!tester.widget<FilterChip>(artworkMode).selected) {
            await tester.tap(artworkMode);
            await tester.pump();
          }
          expect(tester.widget<FilterChip>(safebooruExact).selected, isTrue);
          expect(tester.widget<FilterChip>(exactMode).selected, isFalse);
          expect(tester.widget<TextButton>(selectAll).onPressed, isNotNull);

          await tester.tap(selectAll);
          await tester.pump();
          for (final chip in [artworkMode, exactMode, safebooruExact]) {
            expect(tester.widget<FilterChip>(chip).selected, isTrue);
          }
          expect(tester.widget<TextButton>(selectAll).onPressed, isNull);

          await tester.tap(exactMode);
          await tester.pump();
          expect(tester.widget<TextButton>(selectAll).onPressed, isNotNull);
        }

        await tester.tap(find.widgetWithText(TextButton, 'Clear All'));
        await tester.pumpAndSettle();
        await tester.tap(artworkMode);
        await tester.pumpAndSettle();
        expect(tester.widget<FilterChip>(artworkMode).selected, isTrue);
        expect(tester.widget<FilterChip>(exactMode).selected, isFalse);
        expect(tester.widget<FilterChip>(safebooruExact).selected, isFalse);
        expect(repository.queries, isEmpty);
        expect(safebooruRepository.queries, isEmpty);
        expect(pixivClient.requestedIds, isEmpty);

        if (confirm) {
          await tester.tap(find.widgetWithText(FilledButton, 'Search'));
        } else {
          Navigator.of(tester.element(sheet)).pop();
        }
        await tester.pumpAndSettle();
        expect(sheet, findsNothing);
        if (!confirm) {
          expect(find.text('Find Pixiv Artwork'), findsNothing);
          expect(repository.queries, isEmpty);
          expect(safebooruRepository.queries, isEmpty);
          expect(pixivClient.requestedIds, isEmpty);
        }
      }

      expect(find.text('Find Pixiv Artwork'), findsOneWidget);
      expect(
        find.byKey(ValueKey('match-${sourceProfile.id}-77')),
        findsOneWidget,
      );
      expect(find.text(safebooru.name), findsNothing);
      expect(repository.queries, ['pixiv_id:12345']);
      expect(safebooruRepository.queries, isEmpty);
      expect(pixivClient.requestedIds, isEmpty);
      expect(container.read(lookupPreferencesProvider).profiles, savedChoices);
    });
  }
}

GoRouter _router({
  required Future<void> Function(WidgetRef ref) onOpen,
  Future<void> Function(WidgetRef ref)? onOpenWork,
  Widget Function(BuildContext context, GoRouterState state)? onViewer,
}) => GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => Consumer(
        builder: (context, ref, _) {
          if (onOpenWork != null) {
            ref.watch(contentProfileAccessProvider(_pixiv.id));
          }
          return Scaffold(
            body: Column(
              children: [
                TextButton(
                  onPressed: () => onOpen(ref),
                  child: const Text('Find'),
                ),
                if (onOpenWork != null)
                  TextButton(
                    onPressed: () => onOpenWork(ref),
                    child: const Text('Find Work'),
                  ),
              ],
            ),
          );
        },
      ),
      routes: [
        crossProfileLookupRoute(),
        if (onViewer != null) GoRoute(path: 'details', builder: onViewer),
      ],
    ),
  ],
);

Future<void> _pump(
  WidgetTester tester,
  GoRouter router,
  List<Override> additional, {
  Set<String> Function()? blacklist,
  List<BooruConfig>? profiles,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        routerProvider.overrideWithValue(router),
        booruConfigProvider.overrideWith(
          () => Profiles(profiles ?? [sourceProfile, _pixiv]),
        ),
        blacklistTagsProvider.overrideWith((_, _) => blacklist?.call() ?? {}),
        settingsNotifierProvider.overrideWith(
          () => SettingsNotifier(Settings.defaultSettings),
        ),
        miscDataStoreProvider.overrideWithValue(MemoryMiscDataStore()),
        automaticMediaLoadingEnabledProvider.overrideWithValue(false),
        defaultImageCacheManagerProvider.overrideWithValue(
          UnusedLookupImageCache(),
        ),
        ...additional,
      ],
      child: TranslationProvider(
        child: MaterialApp.router(
          routerConfig: router,
          theme: ThemeData(extensions: const [KurumiExtendedColorScheme()]),
          builder: (context, child) => KurumiTheme(
            data: KurumiThemeData.fromMaterial(Theme.of(context)),
            child: child!,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
