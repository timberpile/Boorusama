import 'package:boorusama/core/content/groups/related_group_counts.dart';
import 'package:kurumi/kurumi.dart';
import 'package:boorusama/boorus/danbooru/posts/related/related_gallery.dart';
import 'package:boorusama/boorus/danbooru/pools/content_group_source.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:boorusama/core/images/booru_image.dart';
import 'package:boorusama/core/posts/listing/types.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:boorusama/boorus/danbooru/posts/search/src/widgets/search_series_grid.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/widgets.dart';
import 'package:boorusama/core/content/content_access_provider.dart';
import 'package:boorusama/core/content/groups/group_source_provider.dart';
import 'package:boorusama/core/content/types.dart';
import 'package:boorusama/core/posts/details/src/routes/details_route_context.dart';
import 'package:boorusama/core/posts/details/src/types/viewer_entry.dart';
import 'package:boorusama/core/posts/listing/widgets.dart';
import 'package:boorusama/core/posts/listing/providers.dart';
import 'package:boorusama/core/posts/pools/pool_grid_item.dart';
import 'package:boorusama/core/posts/post/providers.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/selection/ordered_selection_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import '../../bookmarks/pool_bookmark_test_utils.dart';
import '../../search/following_topics/following_topic_test_utils.dart';

void main() {
  for (final knownTotal in <int?>[null, 27]) {
    for (final singleton in [false, true]) {
      final cases = knownTotal == null && !singleton
          ? [
              for (final mode in ImageListType.values)
                for (final ratio in [.5, 1.0, 2.0]) (mode, ratio),
            ]
          : [(ImageListType.masonry, 1.0)];
      for (final (mode, ratio) in cases) {
        testWidgets(
          'Related card uses first thumbnail, cached count ($knownTotal), singleton=$singleton, $mode ratio=$ratio, full family route and raw selection',
          (tester) async {
            final config = BooruConfig.fromJson({
              ...testProfile.toJson(),
              'url': 'https://danbooru.donmai.us',
              'booruId': BooruType.danbooru.id,
              'booruIdHint': BooruType.danbooru.id,
            });
            final posts =
                [
                      testRelatedPost(11, parent: 10),
                      testRelatedPost(99),
                      if (!singleton) testRelatedPost(12, parent: 10),
                    ]
                    .map(
                      (p) => p.copyWith(origin: postOriginFromConfig(config)),
                    )
                    .toList();
            final access = ContentAccessContext.profile(
              config: config,
              authEpoch: 1,
              policyEpoch: 1,
            );
            final reference = const ContentReferenceCodec().parse(
              engine: BooruType.danbooru,
              site: Uri.parse(config.url),
              kind: ContentKind.group,
              sourceKey: 'related:10',
            );
            var metadataRequests = 0;
            var memberRequests = 0;
            final openGallery =
                knownTotal == null &&
                !singleton &&
                mode == ImageListType.masonry &&
                ratio == 1;
            final resolvedRatio = StateProvider<double?>((ref) => ratio);
            final harness = FollowingTopicHarness(
              settings: Settings.defaultSettings.copyWith(
                groupRelatedPosts: true,
              ),
              profiles: [config],
              listingSettings: Settings.defaultSettings.listing.copyWith(
                imageListType: mode,
              ),
              overrides: [
                contentGroupSourceProvider.overrideWith((ref, key) {
                  final source = DanbooruGroupSource(
                    access: access,
                    fetchPool: (_) => throw StateError(
                      'Related never requests Pool metadata',
                    ),
                    postRepository: () =>
                        _GalleryPosts(posts.first, () => memberRequests++),
                  );
                  ref.onDispose(source.dispose);
                  return source;
                }),
                gridThumbnailUrlGeneratorProvider.overrideWith(
                  (ref, config) => DefaultGridThumbnailUrlGenerator(
                    mediaMapper: (post, settings) => GridThumbnailMedia(
                      url: 'https://fixture.test/cover.jpg',
                      aspectRatio: ref.watch(resolvedRatio),
                    ),
                  ),
                ),
                contentProfileAccessProvider.overrideWith(
                  () => _Access(access),
                ),
                groupSummaryProvider.overrideWith(
                  (ref, key) {
                    metadataRequests++;
                    return Future.value(
                      ContentGroupSummary(
                        reference: reference,
                        memberCount: knownTotal,
                      ),
                    );
                  },
                ),
              ],
            );
            addTearDown(harness.dispose);
            harness.container.read(contentProfileAccessProvider(config.id));
            if (knownTotal != null) {
              final metadata = GroupMetadataKey(
                reference: reference,
                access: access.key,
              );
              final subscription = harness.container.listen(
                groupSummaryProvider(metadata),
                (_, _) {},
              );
              addTearDown(subscription.close);
              await harness.container.read(
                groupSummaryProvider(metadata).future,
              );
            }
            final controller = PostGridController<Post>(
              fetcher: (_) => TaskEither.right(
                PostResult(posts: posts, total: null, hasMore: false),
              ),
              blacklistedTagsFetcher: () async => {},
              mountedChecker: () => true,
              duplicateTracker: PostDuplicateTracker<Post>(),
              onError: (_) {},
            );
            addTearDown(controller.dispose);
            await controller.refresh();
            final index = SearchSeriesIndex();
            addTearDown(index.dispose);
            final selection = OrderedSelectionController<Object>();
            addTearDown(selection.dispose);
            DetailsRouteContext? opened;
            var query = 'artist';
            late StateSetter changeQuery;
            final router = GoRouter(
              routes: [
                GoRoute(
                  path: '/',
                  builder: (_, _) => CurrentBooruConfigScope(
                    config: config,
                    child: StatefulBuilder(
                      builder: (context, setState) {
                        changeQuery = setState;
                        return Scaffold(
                          body: PostGrid<Post>(
                            controller: controller,
                            header: const SizedBox.shrink(),
                            multiSelectActions: const SizedBox.shrink(),
                            selectionModeController: selection,
                            itemBuilder: (context, i, scroll, hero) =>
                                Text('raw-${posts[i].id}'),
                            gridBuilder: (context, itemBuilder) =>
                                SearchSeriesGrid(
                                  controller: controller,
                                  config: config,
                                  query: query,
                                  index: index,
                                  itemBuilder: itemBuilder,
                                ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                GoRoute(
                  path: '/details',
                  builder: (_, state) {
                    opened = state.extra! as DetailsRouteContext;
                    return openGallery
                        ? CurrentBooruConfigScope(
                            config: config,
                            child: Scaffold(
                              body: RelatedGallery(
                                entry:
                                    opened!.entries!.first as GroupViewerEntry,
                              ),
                            ),
                          )
                        : const Scaffold(body: Text('full family'));
                  },
                ),
              ],
            );
            harness.router = router;
            addTearDown(router.dispose);
            await ensureI18nInitialized('en-US');
            tester.view.physicalSize = const Size(320, 900);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            tester.platformDispatcher.textScaleFactorTestValue = 2;
            addTearDown(
              tester.platformDispatcher.clearTextScaleFactorTestValue,
            );
            await tester.pumpWidget(
              harness.wrap(
                MaterialApp.router(
                  routerConfig: router,
                  builder: themeBuilder,
                  theme: ThemeData(
                    extensions: const [KurumiExtendedColorScheme()],
                  ),
                ),
              ),
            );
            await settle(tester);
            expect(find.byType(PoolGridItem), findsOneWidget);
            final card = tester.widget<PoolGridItem>(find.byType(PoolGridItem));
            expect(card.kind, PoolGridItemKind.related);
            expect(card.sourceIcon, isNull);
            expect(
              find.byKey(const ValueKey('pool-source-icon')),
              findsNothing,
            );
            expect(
              tester.getSize(find.byType(PoolGridItem)).aspectRatio,
              closeTo(
                mode == ImageListType.masonry
                    ? ratio
                    : Settings.defaultSettings.listing.imageGridAspectRatio,
                0.001,
              ),
            );
            expect(
              find.byKey(const ValueKey('pool-kind-related')),
              findsOneWidget,
            );
            expect(card.total, knownTotal);
            expect(card.displayedCount, isNull);
            final image = card.image as PostGridImage;
            expect(image.post, posts.first);
            expect(image.media.aspectRatio, ratio);
            expect(
              image.fit,
              mode == ImageListType.standard ? BoxFit.cover : BoxFit.contain,
            );
            expect(
              tester.getRect(find.byType(BooruImage)),
              tester.getRect(find.byType(PoolGridItem)),
            );

            final firstGeometry = tester.getRect(find.byType(PoolGridItem));
            harness.container.read(resolvedRatio.notifier).state = 3;
            await tester.pumpAndSettle();
            expect(tester.getRect(find.byType(PoolGridItem)), firstGeometry);
            expect(metadataRequests, knownTotal == null ? 0 : 1);
            final badgeText = find.descendant(
              of: find.byKey(const ValueKey('pool-badge')),
              matching: find.byType(Text),
            );
            if (knownTotal == null) {
              expect(badgeText, findsNothing);
            } else {
              expect(find.text('$knownTotal'), findsOneWidget);
            }
            expect(find.text('raw-99'), findsOneWidget);
            await tester.tap(find.byType(PoolGridItem));
            await tester.pumpAndSettle();
            expect(opened!.config, config);
            final group = opened!.entries!.first as GroupViewerEntry;
            expect(group.summary.reference.sourceKey, 'related:10');
            expect(group.source!.config, config);
            expect(opened!.useMixedViewer, isTrue);
            // Route entry identifies the full family; it carries no partial inline members.
            expect(group.summary.reference, reference);
            if (openGallery) {
              expect(find.byType(RelatedGallery), findsOneWidget);
              expect(memberRequests, 1);
            }
            router.pop();
            await tester.pumpAndSettle();
            expect(
              tester.widget<PoolGridItem>(find.byType(PoolGridItem)).total,
              openGallery ? 37 : knownTotal,
            );
            expect(memberRequests, openGallery ? 1 : 0);
            expect(metadataRequests, knownTotal == null ? 0 : 1);
            expect(tester.getRect(find.byType(PoolGridItem)), firstGeometry);
            if (openGallery) {
              final actor = harness.container.read(
                contentProfileAccessProvider(config.id).notifier,
              ) as _Access;
              actor.replace(null);
              await tester.pumpAndSettle();
              expect(
                tester.widget<PoolGridItem>(find.byType(PoolGridItem)).total,
                isNull,
              );
              final next = ContentAccessContext.profile(
                config: config,
                authEpoch: 1,
                policyEpoch: 2,
              );
              actor.replace(next);
              await tester.pumpAndSettle();
              expect(
                tester.widget<PoolGridItem>(find.byType(PoolGridItem)).total,
                isNull,
              );
              final counts = harness.container.read(
                relatedGroupCountsProvider.notifier,
              );
              counts.publish(
                counts.begin(
                  GroupMetadataKey(reference: reference, access: access.key),
                ),
                999,
              );
              await tester.pumpAndSettle();
              expect(
                tester.widget<PoolGridItem>(find.byType(PoolGridItem)).total,
                isNull,
              );
              counts.publish(
                counts.begin(
                  GroupMetadataKey(reference: reference, access: next.key),
                ),
                51,
              );
              await tester.pumpAndSettle();
              expect(
                tester.widget<PoolGridItem>(find.byType(PoolGridItem)).total,
                51,
              );
              expect(tester.getRect(find.byType(PoolGridItem)), firstGeometry);
              expect(memberRequests, 1);
            }
            selection.enable(initialSelected: [0]);
            await tester.pumpAndSettle();
            expect(find.byType(PoolGridItem), findsNothing);
            expect(find.text('raw-11'), findsOneWidget);
            expect(
              find.text('raw-12'),
              singleton ? findsNothing : findsOneWidget,
            );
            selection.disable();
            await tester.pumpAndSettle();
            expect(tester.getRect(find.byType(PoolGridItem)), firstGeometry);
            changeQuery(() => query = 'parent:10');
            await tester.pumpAndSettle();
            expect(find.byType(PoolGridItem), findsNothing);
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
          },
        );
      }
    }
  }
  test('explicit family and collection queries disable grouping', () {
    for (final query in [
      'pool:1',
      'series:2',
      'parent:3',
      'child:any',
      'id:4,5',
      'tag -parent:10',
    ]) {
      expect(isExplicitSeriesSearch(query), isTrue, reason: query);
    }
    expect(isExplicitSeriesSearch('artist_name rating:g'), isFalse);
  });
}

class _Access extends ContentProfileAccess {
  _Access(this.access);
  final ContentAccessContext access;
  @override
  ContentAccessContext? build(String arg) => access;
  void replace(ContentAccessContext? next) => state = next;
}

final class _GalleryPosts extends PostRepository<Post> {
  _GalleryPosts(this.post, this.onFetch);
  final Post post;
  final void Function() onFetch;
  @override
  PostsOrError<Post> getPosts(
    String tags,
    int page, {
    int? limit,
    PostFetchOptions? options,
  }) {
    onFetch();
    return TaskEither.right(
      PostResult(posts: [post], total: 37, hasMore: false),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
