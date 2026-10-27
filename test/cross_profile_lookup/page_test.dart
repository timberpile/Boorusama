import 'dart:async';

import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/developer_options/providers.dart';
import 'package:boorusama/core/posts/cross_profile_lookup/data.dart';
import 'package:boorusama/core/posts/cross_profile_lookup/page.dart';
import 'package:boorusama/core/posts/cross_profile_lookup/providers.dart';
import 'package:boorusama/core/posts/cross_profile_lookup/results.dart';
import 'package:boorusama/core/posts/cross_profile_lookup/types.dart';
import 'package:boorusama/core/posts/details/routes.dart';
import 'package:boorusama/core/posts/post/providers.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';
import 'package:i18n/src/gen/strings.g.dart' show TranslationProvider;
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

import '../core/posts/links/boorusama_post_link_test.dart' show config;
import 'providers_test.dart' show Profiles, sourceProfile, targetProfile, post;

class _Repository extends Fake implements PostRepository<Post> {
  _Repository(this.fetch);
  final Future<PostResult<Post>> Function(int) fetch;
  @override
  PostsOrError<Post> getPosts(
    String tags,
    int page, {
    int? limit,
    PostFetchOptions? options,
  }) => TaskEither(() async => right(await fetch(page)));
}

Future<GoRouter> pumpLookup(
  WidgetTester tester, {
  required Profiles profiles,
  required Future<PostResult<Post>> Function(BooruConfig, int) fetch,
  double textScale = 1,
  Post? source,
}) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('Source browsing')),
        routes: [
          GoRoute(
            path: 'lookup',
            builder: (_, _) => CrossProfileLookupPage(
              source: source ?? post(sourceProfile),
            ),
          ),
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
        crossProfileLookupSessionProvider.overrideWith(
          (ref, source) => CrossProfileLookupSession(
            source: source,
            refreshSource: () async => null,
            lookup: (profile) async => ExactPostLookup(
              repository: _Repository((page) => fetch(profile, page)),
              targetOrigin: postOriginFromConfig(profile),
              apiMode: true,
              isVisible: (_) => true,
            ),
          ),
        ),
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
  unawaited(router.push('/lookup'));
  await tester.pump();
  await tester.pump();
  return router;
}

Future<void> select(WidgetTester tester, BooruConfig profile) =>
    tester.tap(find.byKey(ValueKey('profile-${profile.id}')));

void main() {
  testWidgets('missing hash is distinct and does not query a target', (
    tester,
  ) async {
    var calls = 0;
    await pumpLookup(
      tester,
      profiles: Profiles([sourceProfile, targetProfile]),
      source: post(sourceProfile, md5: ''),
      fetch: (_, _) async {
        calls++;
        return PostResult.empty();
      },
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('No usable file hash'),
      findsOneWidget,
    );
    expect(calls, 0);
  });

  testWidgets(
    'opening searches automatically and keeps a unique result visible; Back preserves source',
    (tester) async {
      final gate = Completer<PostResult<Post>>();
      final calls = <BooruConfig>[];
      final profiles = Profiles([sourceProfile, targetProfile]);
      final router = await pumpLookup(
        tester,
        profiles: profiles,
        fetch: (profile, _) {
          calls.add(profile);
          return gate.future;
        },
      );
      expect(calls, [targetProfile]);
      await tester.pump();
      expect(find.textContaining('Searching'), findsOneWidget);
      expect(calls, [targetProfile]);
      gate.complete(
        PostResult(total: null, posts: [post(targetProfile)], hasMore: false),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Opened'), findsNothing);
      expect(find.text('Exact File Match'), findsOneWidget);
      await tester.tap(find.byKey(ValueKey('match-${targetProfile.id}-42')));
      await tester.pumpAndSettle();
      expect(find.text('Opened 42 with Target'), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('Find on Other Profiles'), findsOneWidget);
      expect(calls, [targetProfile]);
      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('Source browsing'), findsOneWidget);
      expect(profiles.state, [sourceProfile, targetProfile]);
    },
  );

  testWidgets(
    'multiple results stay grouped and open using their target profile',
    (tester) async {
      await pumpLookup(
        tester,
        profiles: Profiles([sourceProfile, targetProfile]),
        fetch: (profile, _) async => PostResult(
          total: null,
          posts: [post(profile), post(profile, id: 43)],
          hasMore: false,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Results: 2'), findsOneWidget);
      expect(
        find.byKey(ValueKey('match-${targetProfile.id}-42')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(ValueKey('match-${targetProfile.id}-43')));
      await tester.pumpAndSettle();
      expect(find.text('Opened 43 with Target'), findsOneWidget);
    },
  );

  testWidgets(
    'partial single match is not opened and pagination deduplicates without inventing totals',
    (tester) async {
      final pages = <int>[];
      await pumpLookup(
        tester,
        profiles: Profiles([sourceProfile, targetProfile]),
        fetch: (profile, page) async {
          pages.add(page);
          return PostResult(
            total: null,
            posts: [post(profile), if (page == 2) post(profile, id: 43)],
            hasMore: page == 1,
          );
        },
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Results loaded: 1'), findsOneWidget);
      expect(find.textContaining('Opened'), findsNothing);
      await tester.tap(find.text('Load More'));
      await tester.pumpAndSettle();
      expect(pages, [1, 2]);
      expect(find.textContaining('Results: 2'), findsOneWidget);
      expect(
        find.byKey(ValueKey('match-${targetProfile.id}-42')),
        findsOneWidget,
      );
      expect(find.text('Load More'), findsNothing);
    },
  );

  testWidgets('errors are safe and retryable; empty result is distinct', (
    tester,
  ) async {
    var attempts = 0;
    await pumpLookup(
      tester,
      profiles: Profiles([sourceProfile, targetProfile]),
      fetch: (_, _) async {
        if (++attempts == 1) throw StateError('private-token');
        return const PostResult(total: null, posts: [], hasMore: false);
      },
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Lookup failed'), findsOneWidget);
    expect(find.textContaining('private-token'), findsNothing);
    await select(tester, targetProfile);
    await tester.pumpAndSettle();
    expect(find.textContaining('No visible matches'), findsOneWidget);
  });

  testWidgets(
    'profiles finish independently and dismissal ignores late responses',
    (tester) async {
      final other = config(
        'https://other.test',
        id: '00000000-0000-4000-8000-000000000004',
      ).copyWith(name: 'Other');
      final first = Completer<PostResult<Post>>();
      final second = Completer<PostResult<Post>>();
      final router = await pumpLookup(
        tester,
        profiles: Profiles([sourceProfile, targetProfile, other]),
        fetch: (profile, _) =>
            profile == targetProfile ? first.future : second.future,
      );
      await tester.pump();
      await tester.pump();
      first.complete(
        PostResult(total: null, posts: [post(targetProfile)], hasMore: false),
      );
      await tester.pump();
      expect(find.textContaining('Opened'), findsNothing);
      expect(
        find.byKey(ValueKey('match-${targetProfile.id}-42')),
        findsOneWidget,
      );
      expect(find.textContaining('Searching'), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
      second.complete(
        PostResult(total: null, posts: [post(other)], hasMore: false),
      );
      await tester.pumpAndSettle();
      expect(find.text('Source browsing'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'changed credentials discard old results and restart the profile',
    (tester) async {
      final gate = Completer<PostResult<Post>>();
      final profiles = Profiles([sourceProfile, targetProfile]);
      final calls = <BooruConfig>[];
      await pumpLookup(
        tester,
        profiles: profiles,
        fetch: (profile, _) {
          calls.add(profile);
          return profile == targetProfile
              ? gate.future
              : Future.value(
                  PostResult(
                    total: null,
                    posts: [post(profile, id: 99)],
                    hasMore: false,
                  ),
                );
        },
      );
      final changed = targetProfile.copyWith(apiKey: 'changed');
      profiles.replace([sourceProfile, changed]);
      await tester.pump();
      gate.complete(
        PostResult(total: null, posts: [post(targetProfile)], hasMore: false),
      );
      await tester.pumpAndSettle();
      expect(calls, [targetProfile, changed]);
      expect(
        find.byKey(ValueKey('match-${targetProfile.id}-42')),
        findsNothing,
      );
      expect(
        find.byKey(ValueKey('match-${targetProfile.id}-99')),
        findsOneWidget,
      );
    },
  );

  testWidgets('unsupported profiles and narrow enlarged layout remain usable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final unsupported = config(
      'https://unsupported.test',
      type: BooruType.moebooru,
      id: '00000000-0000-4000-8000-000000000005',
    );
    await pumpLookup(
      tester,
      profiles: Profiles([sourceProfile, targetProfile, unsupported]),
      textScale: 2,
      fetch: (_, _) async => PostResult.empty(),
    );
    await tester.scrollUntilVisible(find.text('Unsupported Profiles'), 150);
    expect(find.text('Unsupported Profiles'), findsOneWidget);
    expect(find.byKey(ValueKey('profile-${unsupported.id}')), findsNothing);
    await tester.scrollUntilVisible(
      find.byKey(ValueKey('profile-${targetProfile.id}')),
      -150,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'shared results support artwork reference and incremental source matches',
    (tester) async {
      Widget result(List<CrossProfileResult> results) => ProviderScope(
        overrides: [
          automaticMediaLoadingEnabledProvider.overrideWithValue(false),
        ],
        child: MaterialApp(
          home: TranslationProvider(
            child: Scaffold(
              body: CrossProfileResults(
                reference: const Text('Pixiv artwork 123'),
                results: results,
                onSelect: (_) {},
                onMore: (_) {},
                onOpen: (_, _) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(
        result([
          CrossProfileResult(
            profile: targetProfile,
            status: CrossProfileResultStatus.loading,
          ),
        ]),
      );
      expect(find.textContaining('Searching'), findsOneWidget);
      expect(find.text('Pixiv artwork 123'), findsOneWidget);
      await tester.pumpWidget(
        result([
          CrossProfileResult(
            profile: targetProfile,
            status: CrossProfileResultStatus.success,
            matchKind: PostLookupMatchKind.pixivSource,
            posts: [post(targetProfile)],
            complete: true,
          ),
        ]),
      );
      expect(find.textContaining('Results: 1'), findsOneWidget);
      expect(find.text('Pixiv Artwork Match'), findsOneWidget);
    },
  );
}
