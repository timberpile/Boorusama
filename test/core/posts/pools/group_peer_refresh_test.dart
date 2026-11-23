import 'package:boorusama/core/blacklists/providers.dart';

import 'dart:async';

import 'package:boorusama/boorus/danbooru/pools/content_group_source.dart';
import 'package:boorusama/boorus/danbooru/pools/pool/types.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/content/content_access_provider.dart';
import 'package:boorusama/core/content/groups/group_source_provider.dart';
import 'package:boorusama/core/content/types.dart';
import 'package:boorusama/core/errors/types.dart';
import 'package:boorusama/core/navigation/destination_activity.dart';
import 'package:boorusama/core/posts/listing/providers.dart';
import 'package:boorusama/core/posts/listing/types.dart';
import 'package:boorusama/core/posts/listing/widgets.dart';
import 'package:boorusama/core/posts/pools/group_post_scope.dart';
import 'package:boorusama/core/posts/post/providers.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation/foundation.dart';
import 'package:kurumi/material.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

import '../../../support/fakes/test_post.dart';
import '../../search/following_topics/following_topic_test_utils.dart';

void main() {
  for (final paginated in [false, true]) {
    for (final inactive in [false, true]) {
      testWidgets(
        'Pool peers refresh coherently (pages=$paginated, inactive=$inactive)',
        (tester) async {
          final config = BooruConfig.fromJson({
            ...testProfile.toJson(),
            'booruId': BooruType.danbooru.id,
            'booruIdHint': BooruType.danbooru.id,
          });
          final reference = const ContentReferenceCodec().parse(
            engine: BooruType.danbooru,
            site: Uri.parse(config.url),
            kind: ContentKind.group,
            sourceKey: 'pool:42',
          );
          final active = ValueNotifier(true);
          final policy = StateProvider<Set<String>>((ref) => {});
          final scroll = [AutoScrollController(), AutoScrollController()];
          addTearDown(active.dispose);
          for (final controller in scroll) {
            addTearDown(controller.dispose);
          }
          var version = 1;
          var envelopes = 0;
          late _Source source;
          final harness = FollowingTopicHarness(
            profiles: [config],
            overrides: [
              blacklistTagsProvider.overrideWith(
                (ref, filter) => ref.watch(policy),
              ),
              contentGroupSourceProvider.overrideWith((ref, key) {
                final delegate = DanbooruGroupSource(
                  access: ref.read(contentAccessContextProvider(key))!,
                  fetchPool: (id) async {
                    envelopes++;
                    return DanbooruPool.empty().copyWith(
                      id: id,
                      postIds: version == 1 ? [1, 2, 3, 4] : [3, 1, 2, 4],
                    );
                  },
                  postRepository: () => _Posts(config),
                );
                source = _Source(delegate);
                ref.onDispose(source.dispose);
                return source;
              }),
              imageListingSettingsProvider.overrideWith(
                (ref) => Settings.defaultSettings.listing.copyWith(
                  postsPerPage: 2,
                  pageMode: paginated ? PageMode.paginated : PageMode.infinite,
                ),
              ),
            ],
          );
          addTearDown(harness.dispose);
          harness.container
              .read(selectedTestProfileProvider.notifier)
              .select(config);
          final controllers = <int, PostGridController<Post>>{};
          Widget group(int index) => GroupPostScope(
            reference: reference,
            perPage: 2,
            scrollController: scroll[index],
            builder: (context, controller) {
              controllers[index] = controller;
              return PostGrid<Post>(
                controller: controller,
                scrollController: scroll[index],
                automaticContinuationEnabled: false,
              );
            },
          );
          await harness.pump(
            tester,
            Scaffold(
              body: SizedBox(
                height: 180,
                child: Row(
                  children: [
                    Expanded(
                      child: ValueListenableBuilder<bool>(
                        valueListenable: active,
                        builder: (_, visible, _) => Offstage(
                          offstage: !visible,
                          child: NavigationActivity(
                            active: visible,
                            child: group(0),
                          ),
                        ),
                      ),
                    ),
                    Expanded(child: group(1)),
                  ],
                ),
              ),
            ),
          );
          await _until(
            tester,
            () =>
                controllers.length == 2 &&
                controllers.values.every(
                  (c) => !c.refreshing && c.items.length == 2,
                ),
          );
          if (paginated && !inactive) {
            // A previous actor's own revision must not suppress the new actor's
            // first peer revision, even though both counters start at one.
            await _finish(tester, controllers[0]!.refresh());
            final oldAccess = source.access.key;
            harness.container.read(policy.notifier).state = {'unrelated'};
            await _until(
              tester,
              () =>
                  source.access.key != oldAccess &&
                  controllers.values.every(
                    (c) => !c.refreshing && c.items.length == 2,
                  ),
            );
          }
          final envelopesBeforeRefresh = envelopes;
          final old = controllers[0]!;
          if (paginated) {
            await _finish(tester, old.jumpToPage(2));
            await _until(tester, () => !old.refreshing && old.page == 2);
            expect(old.items.map((p) => p.id), [3, 4]);
          } else {
            scroll[0].jumpTo(20);
            source.holdNextPage = true;
            unawaited(old.fetchMore());
            await _until(tester, () => source.held.isCompleted);
          }
          if (inactive) {
            active.value = false;
            await tester.pump();
          }
          final before = source.memberReads;
          version = 2;
          unawaited(controllers[1]!.refresh());
          await _until(
            tester,
            () =>
                !controllers[1]!.refreshing &&
                controllers[1]!.items.first.id == 3,
          );
          if (inactive) {
            expect(
              source.memberReads,
              before + 1,
              reason: 'inactive peer must not request another page',
            );
          }
          source.release.complete();
          if (inactive) {
            active.value = true;
          }
          await _until(
            tester,
            () =>
                !identical(controllers[0], old) &&
                !controllers[0]!.refreshing &&
                controllers[0]!.items.length == 2,
          );
          final peer = controllers[0]!;
          expect(peer.page, paginated ? 2 : 1);
          expect(peer.items.map((p) => p.id), paginated ? [2, 4] : [3, 1]);
          expect(scroll[0].offset, 0);
          if (!paginated) {
            await _finish(tester, peer.fetchMore());
            await _until(tester, () => peer.items.length == 4);
            expect(peer.items.map((p) => p.id), [3, 1, 2, 4]);
          }
          expect(
            envelopes,
            envelopesBeforeRefresh + 1,
            reason: 'one shared envelope per explicit refresh',
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}

Future<void> _finish(WidgetTester tester, Future<void> action) async {
  var done = false;
  final pending = action.whenComplete(() => done = true);
  await _until(tester, () => done);
  await pending;
}

Future<void> _until(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 100 && !done(); i++) {
    await tester.pump(const Duration(milliseconds: 50));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  }
  expect(done(), isTrue);
}

class _Source extends ContentGroupSource implements IndexedGroupMemberSource {
  _Source(this.delegate);
  final DanbooruGroupSource delegate;
  var memberReads = 0;
  var holdNextPage = false;
  final held = Completer<void>();
  final release = Completer<void>();
  @override
  ContentAccessContext get access => delegate.access;
  @override
  TaskEither<BooruError, ContentGroupSummary> loadSummary(
    ContentReference reference,
  ) => delegate.loadSummary(reference);
  @override
  TaskEither<BooruError, ContentGroupDetails> loadDetails(
    ContentReference reference,
  ) => delegate.loadDetails(reference);
  @override
  TaskEither<BooruError, GroupMemberBatch> loadMembers(
    GroupMemberQuery query,
  ) => delegate.loadMembers(query);
  @override
  TaskEither<BooruError, GroupMemberBatch> loadMemberPage(
    GroupMemberQuery query, {
    required int page,
  }) => TaskEither(() async {
    memberReads++;
    final result = await delegate.loadMemberPage(query, page: page).run();
    if (holdNextPage && page == 2) {
      holdNextPage = false;
      held.complete();
      await release.future;
    }
    return result;
  });
  @override
  void invalidate(ContentReference reference) => delegate.invalidate(reference);
  @override
  void dispose() => delegate.dispose();
}

class _Posts implements PostRepository<Post> {
  _Posts(this.config);
  final BooruConfig config;
  @override
  PostsOrError<Post> getPosts(
    String tags,
    int page, {
    int? limit,
    PostFetchOptions? options,
  }) => TaskEither.right(
    PostResult(
      posts: [
        for (final id in tags.substring(3).split(',').map(int.parse))
          TestPost(id: id, origin: postOriginFromConfig(config)),
      ],
      total: null,
    ),
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
