import 'dart:async';

import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/posts/listing/widgets.dart';

import '../../application/support/fake_booru_backend.dart';

import 'package:boorusama/core/boorus/engine/types.dart';
import 'package:boorusama/core/boorus/defaults/src/base_booru_builder.dart';
import 'package:boorusama/core/configs/config/providers.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/count/providers.dart';
import 'package:boorusama/core/search/search/src/pages/search_page.dart';
import 'package:boorusama/core/search/search/src/widgets/search_controller.dart';
import 'package:boorusama/core/search/search/src/widgets/search_page_scaffold.dart';
import 'package:boorusama/core/search/suggestions/providers.dart';
import 'package:boorusama/core/tags/metatag/providers.dart';
import 'package:boorusama/core/tags/metatag/types.dart';
import 'package:boorusama/core/search/selected_tags/types.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';
import 'package:boorusama/foundation/networking.dart';
import 'package:go_router/go_router.dart';
import 'package:i18n/i18n.dart';
import 'package:boorusama/core/navigation/destination_id.dart';
import 'package:boorusama/core/navigation/destination_profile_scope.dart';
import 'package:boorusama/core/navigation/destination_router.dart';
import 'package:boorusama/core/navigation/profile_context_menu.dart';
import 'package:boorusama/core/search/search/src/routes/params.dart';
import 'package:boorusama/core/search/following_topics/src/widgets/topic_follow_control.dart';
import 'package:boorusama/core/search/following_topics/providers.dart';

import 'following_topics/following_topic_test_utils.dart';

BooruConfig profile(String id, String name, BooruType type, String url) =>
    BooruConfig.fromJson({
      ...BooruConfig.defaultConfig(
        booruType: type,
        url: url,
        customDownloadFileNameFormat: null,
      ).toJson(),
      'id': '00000000-0000-4000-8000-00000000000$id',
      'name': name,
    });

void main() {
  final first = BooruConfig.fromJson({
    ...profile(
      'a',
      'Review A',
      BooruType.danbooru,
      'https://danbooru.donmai.us',
    ).toJson(),
    'login': 'review-a',
  });
  final sameSite = BooruConfig.fromJson({
    ...first.toJson(),
    'id': '00000000-0000-4000-8000-00000000000b',
    'name': 'Review B',
    'login': 'review-b',
  });
  final crossEngine = profile(
    'c',
    'Review C',
    BooruType.gelbooru,
    'https://gelbooru.com',
  );
  for (final next in [sameSite, crossEngine]) {
    testWidgets(
      'Following search switches locally to ${next.name} and preserves its folder and Topic',
      (tester) async {
        final oldResponse = Completer<PostResult<Post>>();
        final observed = <SearchPageController>[];
        final fetches = <String>[];
        final owners = <BooruConfig>[];
        final suggestions = <String>[];
        final harness = FollowingTopicHarness(
          profiles: [first, next],
          booruBuilder: (_) =>
              _SearchBuilder(observed, fetches, owners, oldResponse, first.id),
        );
        addTearDown(harness.dispose);
        await ensureI18nInitialized('en-US');
        const query = '-cat (dog ~ bird) rating:safe';
        await harness.seed([
          topicFixture(id: 'original-topic', profileId: first.id, query: query),
        ]);
        const following = DestinationId.app(AppDestination.following);
        const browse = DestinationId.browse('independent-browse');
        final binding = DestinationRouterBinding(
          definitions: [
            DestinationRouteDefinition(
              id: following,
              builder: (_, _) => const Scaffold(body: Text('Following root')),
              children: [
                GoRoute(
                  path: 'folder',
                  builder: (_, _) =>
                      const Scaffold(body: Text('Original folder')),
                ),
                GoRoute(
                  path: 'search',
                  builder: (_, _) => InheritedInitialSearchQuery(
                    params: const SearchParams(
                      query: query,
                      queryType: QueryType.simple,
                      originatingTopicId: 'original-topic',
                    ),
                    child: SearchPage(initialConfig: first),
                  ),
                ),
              ],
            ),
            DestinationRouteDefinition(
              id: browse,
              builder: (_, _) =>
                  const Scaffold(body: Text('Independent Browse')),
            ),
          ],
          navigatorWrapper: (_, id, selected, child) =>
              DestinationScope(id: id, active: selected, child: child),
          shellBuilder: (_, _, shell) => shell,
        );
        final router = GoRouter.routingConfig(
          routingConfig: binding.routingConfig,
          initialLocation: following.location,
        );
        binding.attach(router);
        addTearDown(router.dispose);
        addTearDown(binding.dispose);
        await tester.pumpWidget(
          harness.wrap(
            ProviderScope(
              overrides: [
                postCountProvider.overrideWith((ref, args) async => 0),
                networkStateProvider.overrideWithValue(
                  NetworkDisconnectedState(),
                ),
                metatagExtractorProvider.overrideWith(
                  (ref, config) => _Extractor(config.url),
                ),
                suggestionsNotifierProvider.overrideWith(
                  () => _Suggestions(suggestions),
                ),
              ],
              child: MaterialApp.router(
                routerConfig: router,
                builder: themeBuilder,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        router.push<void>('${following.location}/folder');
        await tester.pumpAndSettle();
        final folder = tester.element(find.text('Original folder'));
        router.push<void>('${following.location}/search');
        await _until(
          tester,
          () => find.byType(FollowTopicButton).evaluate().isNotEmpty,
        );
        final oldController = observed.last;
        oldController.tagsController
          ..clear()
          ..addTags([
            TagSearchItem.fromString('-cat', category: 'artist'),
            const TagSearchItem.raw(tag: '(dog ~ bird) rating:safe'),
          ]);
        expect(oldController.tagsController.tags.first.category, 'artist');
        expect(
          tester
              .widget<FollowTopicButton>(find.byType(FollowTopicButton))
              .originatingTopicId,
          'original-topic',
        );
        oldController.textController.value = const TextEditingValue(
          text: 'pending',
          selection: TextSelection.collapsed(offset: 3),
        );
        await tester.pump();
        final globalBefore = harness.container
            .read(currentBooruConfigProvider)
            .id;
        await tester.tap(find.byType(ProfileContextMenuButton));
        await _until(
          tester,
          () => find.text(next.name).hitTestable().evaluate().isNotEmpty,
        );
        await tester.tap(find.text(next.name));
        await _until(
          tester,
          () =>
              owners.last.id == next.id &&
              suggestions.last == '${next.url}|pending' &&
              find.byType(FollowTopicButton).evaluate().isNotEmpty,
        );
        expect(observed.last, isNot(same(oldController)));
        expect(observed.last.tagsController.rawTagsString, query);
        expect(observed.last.tagsController.tags.first.category, isNull);
        expect(observed.last.textController.value.text, 'pending');
        expect(observed.last.textController.selection.baseOffset, 3);
        expect(owners.last.id, next.id);
        expect(owners.last.auth, next.auth);
        expect(fetches.last, startsWith('${next.url}|$query'));
        expect(suggestions.last, '${next.url}|pending');
        expect(
          harness.container.read(currentBooruConfigProvider).id,
          globalBefore,
        );
        expect(binding.currentDestination, following);
        expect(
          tester
              .widget<FollowTopicButton>(find.byType(FollowTopicButton))
              .originatingTopicId,
          isNull,
        );
        var oldFinished = false;
        unawaited(oldResponse.future.then((_) => oldFinished = true));
        oldResponse.complete(
          PostResult(posts: FakeBooruBackend().posts, total: 10),
        );
        await _until(tester, () => oldFinished);
        await tester.pump();
        expect(
          find.byType(SliverPostGridImageGridItem),
          findsNothing,
          reason:
              'The old source result must not populate the replacement grid',
        );
        expect(owners.last.id, next.id);
        final topics = await harness.container.read(
          followingTopicsProvider.future,
        );
        expect(topics.topics.single.profileId, first.id);
        expect(topics.topics.single.query, query);
        expect(
          tester.widget<TopicFollowPill>(find.byType(TopicFollowPill)).count,
          0,
        );
        await tester.tap(find.byType(FollowTopicButton));
        await _until(
          tester,
          () => find.byType(AlertDialog).hitTestable().evaluate().isNotEmpty,
        );
        // Confirming no selected destinations must not unfollow the old owner.
        expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
        await tester.tap(find.text('Done'));
        await _until(tester, () => find.byType(AlertDialog).evaluate().isEmpty);
        expect(
          (await harness.container.read(followingTopicsProvider.future))
              .topics
              .single
              .profileId,
          first.id,
        );
        final controller = observed.last;
        binding.select(browse);
        await tester.pumpAndSettle();
        binding.select(following);
        await _until(
          tester,
          () =>
              binding.currentDestination == following &&
              find.byType(FollowTopicButton).evaluate().isNotEmpty,
        );
        expect(observed.last, same(controller));
        router.pop();
        await tester.pumpAndSettle();
        expect(tester.element(find.text('Original folder')), same(folder));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}

class _SearchBuilder extends BaseBooruBuilder {
  _SearchBuilder(
    this.observed,
    this.fetches,
    this.owners,
    this.oldResponse,
    this.originalId,
  );
  final Completer<PostResult<Post>> oldResponse;
  final String originalId;
  final List<BooruConfig> owners;
  final List<SearchPageController> observed;
  final List<String> fetches;

  @override
  SearchPageBuilder get searchPageBuilder =>
      (context, params) => Consumer(
        builder: (context, ref, _) {
          final config = ref.watchConfig;
          return SearchPageScaffold<Post>(
            params: params,
            fetcher: (page, tags) {
              owners.add(config);
              fetches.add('${config.url}|${tags.rawTagsString}|$page');
              if (config.id == originalId)
                return TaskEither(
                  () async => Either.of(await oldResponse.future),
                );
              return TaskEither.of(const PostResult(posts: <Post>[], total: 0));
            },
            landingViewBuilder: (_) => const SizedBox.expand(),
            searchRegionBuilder: (posts, controller) {
              observed.add(controller);
              return DefaultSearchRegion(
                controller: controller,
                initialQuery: params.query,
                postController: posts,
              );
            },
            extraHeaders: (_, _) => [
              SliverToBoxAdapter(child: Text('Results ${config.url}')),
            ],
          );
        },
      );
}

class _Suggestions extends SuggestionsNotifier {
  _Suggestions(this.queries);
  final List<String> queries;
  @override
  void getSuggestions(String query) => queries.add('${arg.url}|$query');
}

class _Extractor implements MetatagExtractor {
  _Extractor(this.url);
  final String url;
  @override
  String? fromString(String value) =>
      value.startsWith('rating:') ? 'rating' : null;
  @override
  bool hasMetatag(String query) => fromString(query) != null;
}

Future<void> _until(WidgetTester tester, bool Function() done) async {
  for (var frame = 0; frame < 100; frame++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (done()) return;
  }
  fail('Search did not reach its expected completion signal');
}
