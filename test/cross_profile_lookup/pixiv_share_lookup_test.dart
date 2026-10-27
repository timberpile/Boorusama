import 'dart:async';

import 'package:boorusama/core/blacklists/providers.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/developer_options/providers.dart';
import 'package:boorusama/core/posts/cross_profile_lookup/page.dart';
import 'package:boorusama/core/posts/cross_profile_lookup/providers.dart';
import 'package:boorusama/core/posts/cross_profile_lookup/src/data/source_post_lookup.dart';
import 'package:boorusama/core/posts/cross_profile_lookup/types.dart';
import 'package:boorusama/core/posts/cross_profile_lookup/data.dart';
import 'package:boorusama/core/posts/cross_profile_lookup/src/data/pixiv_original_hashes.dart';
import 'package:boorusama/core/posts/post/providers.dart';
import 'package:boorusama/core/posts/details/src/routes/details_route_context.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';
import 'package:i18n/src/gen/strings.g.dart' show TranslationProvider;
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

import '../core/posts/links/boorusama_post_link_test.dart' show config;
import 'providers_test.dart'
    show Profiles, Repository, sourceProfile, targetProfile, post;

const artworkUrl = 'https://www.pixiv.net/artworks/12345';
PixivArtworkReference artwork() =>
    PixivArtworkReference.parseSharedText(artworkUrl)!;

class _Repository extends Fake implements PostRepository<Post> {
  _Repository(this.fetch);
  final Future<PostResult<Post>> Function(int) fetch;

  @override
  PostsOrError<Post> getPosts(
    String tags,
    int page, {
    int? limit,
    PostFetchOptions? options,
  }) {
    expect(tags, 'pixiv_id:12345');
    expect(options?.cascadeRequest, isFalse);
    expect(limit, 100);
    return TaskEither(() async => right(await fetch(page)));
  }
}

Future<GoRouter> pumpPixivLookup(
  WidgetTester tester, {
  required Profiles profiles,
  required Future<PostResult<Post>> Function(BooruConfig, int) fetch,
  double textScale = 1,
  List<Override> additionalOverrides = const [],
}) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('Original browsing')),
        routes: [
          crossProfileLookupRoute(),
          GoRoute(
            path: 'details',
            builder: (_, state) {
              final payload = state.extra! as DetailsRouteContext;
              return Scaffold(
                appBar: AppBar(),
                body: Text(
                  'Opened ${payload.posts.single.id} with ${payload.config!.name}',
                ),
              );
            },
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        routerProvider.overrideWithValue(router),
        booruConfigProvider.overrideWith(() => profiles),
        automaticMediaLoadingEnabledProvider.overrideWithValue(false),
        originAwarePostRepoProvider.overrideWith(
          (ref, profile) => _Repository((page) => fetch(profile, page)),
        ),
        blacklistTagsProvider.overrideWith(
          (ref, filter) => <String>{'blocked'},
        ),
        crossProfileLookupSessionProvider.overrideWith((ref, post) {
          throw StateError(
            'Shared artwork must not refresh or fabricate a source post',
          );
        }),
        ...additionalOverrides,
      ],
      child: MaterialApp.router(
        routerConfig: router,
        theme: ThemeData(extensions: const [KurumiExtendedColorScheme()]),
        builder: (context, child) => KurumiTheme(
          data: KurumiThemeData.fromMaterial(Theme.of(context)),
          child: TranslationProvider(
            child: MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
          ),
        ),
      ),
    ),
  );
  unawaited(router.push('/cross-profile-lookup', extra: artwork()));
  await tester.pump();
  await tester.pump();
  return router;
}

void main() {
  test('unsupported engines never acquire a source repository', () async {
    final session = SharedPixivLookupSession(
      artwork: artwork(),
      lookup: (_) => throw StateError('No request permitted'),
    );
    for (final type in [
      BooruType.gelbooru,
      BooruType.gelbooruV2,
      BooruType.pixiv,
    ]) {
      expect(
        await session.find(
          config('https://unsupported.test', type: type),
          cancellation: PostLookupCancellation(),
        ),
        isA<PostLookupUnavailable>().having(
          (r) => r.reason,
          'reason',
          PostLookupUnavailableReason.unsupported,
        ),
      );
    }
  });

  test(
    'cancellation while resolving a profile cannot start its request',
    () async {
      final gate = Completer<SourcePostLookup>();
      final cancellation = PostLookupCancellation();
      var requested = false;
      final pending = SharedPixivLookupSession(
        artwork: artwork(),
        lookup: (_) => gate.future,
      ).find(targetProfile, cancellation: cancellation);
      cancellation.cancel();
      gate.complete(
        SourcePostLookup(
          repository: _Repository((_) async {
            requested = true;
            return PostResult.empty();
          }),
          targetOrigin: postOriginFromConfig(targetProfile),
          isVisible: (_) => true,
        ),
      );
      expect(await pending, isA<PostLookupCancelled>());
      expect(requested, isFalse);
    },
  );

  testWidgets(
    'all compatible accounts search, filter and open without changing the browsing profile',
    (tester) async {
      final calls = <BooruConfig>[];
      final unsupported = config(
        'https://other.test',
        id: '00000000-0000-4000-8000-000000000009',
        type: BooruType.gelbooru,
      );
      final profiles = Profiles([sourceProfile, targetProfile, unsupported]);
      final router = await pumpPixivLookup(
        tester,
        profiles: profiles,
        fetch: (profile, _) async {
          calls.add(profile);
          return PostResult(
            total: null,
            hasMore: false,
            posts: [
              post(
                profile,
                sourceUrl: 'https://i.pximg.net/img-original/12345_p1.png',
                md5: '',
              ),
              post(profile, id: 43, sourceUrl: artworkUrl, tags: {'blocked'}),
              post(profile, id: 44, sourceUrl: '${artworkUrl}6'),
            ],
          );
        },
      );
      await tester.pumpAndSettle();
      expect(calls, unorderedEquals([sourceProfile, targetProfile]));
      expect(find.text('Pixiv Artwork Match'), findsNWidgets(2));
      expect(find.text('Exact File Match'), findsNothing);
      expect(find.textContaining('Results: 1'), findsNWidgets(2));
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('unsupported-profiles')),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.byKey(const ValueKey('unsupported-profiles')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey('match-${targetProfile.id}-43')),
        findsNothing,
      );
      await tester.ensureVisible(
        find.byKey(ValueKey('match-${targetProfile.id}-42')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('match-${targetProfile.id}-42')));
      await tester.pumpAndSettle();
      expect(find.text('Opened 42 with Target'), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('Find Pixiv Artwork'), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('Original browsing'), findsOneWidget);
      expect(profiles.state, [sourceProfile, targetProfile, unsupported]);
    },
  );

  testWidgets(
    'partial counts remain inexact and pagination deduplicates source matches',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final pages = <int>[];
      await pumpPixivLookup(
        tester,
        profiles: Profiles([targetProfile]),
        textScale: 2,
        fetch: (profile, page) async {
          pages.add(page);
          return PostResult(
            total: 1000,
            hasMore: page == 1,
            posts: [
              post(profile, sourceUrl: artworkUrl),
              if (page == 2) post(profile, id: 43, sourceUrl: artworkUrl),
            ],
          );
        },
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Results loaded: 1'), findsOneWidget);
      expect(find.textContaining('Results: 1000'), findsNothing);
      await tester.ensureVisible(find.text('Load More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Load More'));
      await tester.pumpAndSettle();
      expect(pages, [1, 2]);
      expect(find.textContaining('Results: 2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('failures and incomplete original coverage remain distinct', (
    tester,
  ) async {
    await pumpPixivLookup(
      tester,
      profiles: Profiles([sourceProfile, targetProfile]),
      fetch: (profile, _) async {
        if (profile == targetProfile) throw StateError('private server detail');
        return PostResult.empty();
      },
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Sign in to a Pixiv profile'), findsOneWidget);
    expect(find.textContaining('No visible matches'), findsNothing);
    expect(find.textContaining('Lookup failed'), findsOneWidget);
    expect(find.textContaining('private server detail'), findsNothing);
  });

  testWidgets(
    'MD5-only profiles without Pixiv authentication show incomplete coverage',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final safe = config('https://safebooru.org', type: BooruType.gelbooruV2);
      await pumpPixivLookup(
        tester,
        profiles: Profiles([safe]),
        textScale: 2,
        fetch: (_, _) =>
            throw StateError('No verified source method for Safebooru'),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Sign in to a Pixiv profile'), findsOneWidget);
      expect(find.textContaining('No visible matches'), findsNothing);
      expect(find.text('Load More'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'restricted originals explain access limits without claiming no match',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await pumpPixivLookup(
        tester,
        profiles: Profiles([targetProfile]),
        textScale: 2,
        fetch: (_, _) async => PostResult.empty(),
        additionalOverrides: [
          sharedPixivLookupSessionProvider.overrideWith(
            (ref, artwork) => SharedPixivLookupSession(
              artwork: artwork,
              lookup: (_) async => SourcePostLookup(
                repository: Repository(),
                targetOrigin: postOriginFromConfig(targetProfile),
                isVisible: (_) => true,
              ),
              resolveHashes: () async => const PixivOriginalHashes(
                [],
                issue: PixivLookupCoverageIssue.restricted,
              ),
            ),
          ),
        ],
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('block access'), findsOneWidget);
      expect(find.textContaining('Some Pixiv originals'), findsNothing);
      expect(find.textContaining('No visible matches'), findsNothing);
      expect(find.text('Load More'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'partial exact matches keep provenance and do not offer an impossible next page',
    (tester) async {
      final repository = Repository()
        ..result = PostResult(
          posts: [post(targetProfile)],
          total: null,
          hasMore: false,
        );
      await pumpPixivLookup(
        tester,
        profiles: Profiles([targetProfile]),
        fetch: (_, _) async => PostResult.empty(),
        additionalOverrides: [
          sharedPixivLookupSessionProvider.overrideWith(
            (ref, artwork) => SharedPixivLookupSession(
              artwork: artwork,
              lookup: (_) async => SourcePostLookup(
                repository: Repository(),
                targetOrigin: postOriginFromConfig(targetProfile),
                isVisible: (_) => true,
              ),
              exactLookup: (_) async => ExactPostLookup(
                repository: repository,
                targetOrigin: postOriginFromConfig(targetProfile),
                apiMode: true,
                isVisible: (_) => true,
              ),
              resolveHashes: () async => const PixivOriginalHashes([
                '0123456789abcdef0123456789abcdef',
              ], issue: PixivLookupCoverageIssue.originalsUnavailable),
            ),
          ),
        ],
      );
      await tester.pumpAndSettle();
      expect(find.text('Exact File Match'), findsOneWidget);
      expect(find.textContaining('Some Pixiv originals'), findsOneWidget);
      expect(find.textContaining('Results loaded: 1'), findsOneWidget);
      expect(find.textContaining('Results: 1'), findsNothing);
      expect(find.text('Load More'), findsNothing);
    },
  );

  testWidgets(
    'bounded fan-out does not access a disposed page for queued profiles',
    (tester) async {
      final profiles = List.generate(
        5,
        (i) => config(
          'https://target$i.test',
          id: '00000000-0000-4000-8000-00000000000${i + 1}',
        ),
      );
      final gates = <Completer<PostResult<Post>>>[];
      final router = await pumpPixivLookup(
        tester,
        profiles: Profiles(profiles),
        fetch: (_, _) {
          final gate = Completer<PostResult<Post>>();
          gates.add(gate);
          return gate.future;
        },
      );
      await tester.pump();
      expect(gates, hasLength(3));
      router.pop();
      await tester.pumpAndSettle();
      for (final gate in gates.toList()) {
        gate.complete(PostResult.empty());
      }
      await tester.pumpAndSettle();
      expect(gates, hasLength(3));
      expect(tester.takeException(), isNull);
    },
  );
}
