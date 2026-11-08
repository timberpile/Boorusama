import 'dart:async';

import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/blacklists/providers.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/content/content_access_provider.dart';
import 'package:boorusama/core/content/groups/group_source_provider.dart';
import 'package:boorusama/core/content/types.dart';
import 'package:boorusama/core/errors/types.dart';
import 'package:boorusama/core/posts/listing/src/widgets/post_grid_controller.dart';
import 'package:boorusama/core/posts/listing/widgets.dart';
import 'package:boorusama/core/posts/pools/group_post_scope.dart';
import 'package:boorusama/core/posts/post/providers.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/selection/ordered_selection_controller.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';
import 'package:kurumi/material.dart';
import 'package:selection_mode/selection_mode.dart';

import '../../bookmarks/pool_bookmark_test_utils.dart';
import '../../search/following_topics/following_topic_test_utils.dart';

void main() {
  for (final engine in [BooruType.danbooru, BooruType.szurubooru]) {
    testWidgets(
      'GroupPostScope preserves ordered member occurrences: $engine',
      (
        tester,
      ) async {
        final config = BooruConfig.fromJson({
          ...testProfile.toJson(),
          'booruId': engine.id,
          'booruIdHint': engine.id,
        });
        final reference = const ContentReferenceCodec().parse(
          engine: engine,
          site: Uri.parse(config.url),
          kind: ContentKind.group,
          sourceKey: 'pool:42',
        );
        final selection = OrderedSelectionController<Object>();
        addTearDown(selection.dispose);
        final bulkTargets = <List<int>>[];
        final fixture = _Fixture(config, reference);
        final harness = FollowingTopicHarness(
          profiles: [config],
          overrides: [
            contentGroupSourceProvider.overrideWith((ref, key) {
              final access = ref.read(contentAccessContextProvider(key))!;
              return fixture.source = _Source(access, reference);
            }),
            blacklistTagsProvider.overrideWith(
              (ref, config) => Future.value({'filtered'}),
            ),
            imageListingSettingsProvider.overrideWith(
              (ref) => Settings.defaultSettings.listing.copyWith(
                postsPerPage: 3,
              ),
            ),
          ],
        );
        addTearDown(harness.dispose);
        harness.container
            .read(selectedTestProfileProvider.notifier)
            .select(config);
        await harness.pump(
          tester,
          Scaffold(
            body: GroupPostScope(
              reference: reference,
              perPage: 3,
              orderKey: 'order',
              builder: (context, controller) => PostGrid<Post>(
                controller: controller,
                selectionModeController: selection,
                multiSelectActions: DefaultMultiSelectionActions<Post>(
                  postController: controller,
                  extraActions: (posts) {
                    bulkTargets.add(posts.map((post) => post.id).toList());
                    return const [];
                  },
                ),
              ),
            ),
          ),
        );

        final controller = _controller(tester);
        await _pumpUntil(
          tester,
          () =>
              !controller.refreshing &&
              controller.allItems.length == 3 &&
              controller.items.length == 2,
        );
        expect(controller.allItems.map((post) => post.id), [3, 2, 3]);
        expect(controller.items.map((post) => post.id), [3, 3]);

        // Select the second occurrence of ID 3; the manifest key, not its Post
        // ID, must keep it selected as more filtered members arrive.
        selection.click(1);
        await tester.pump();
        expect(selection.selection, {1});
        await _complete(tester, controller.fetchMore());
        expect(controller.allItems.map((post) => post.id), [3, 2, 3, 3, 1]);
        expect(controller.items.map((post) => post.id), [3, 3, 3, 1]);
        expect(selection.selection, {1});
        expect(
          selection
              .selectedFrom(controller.items.toList())
              .toList()
              .map((post) => post.id)
              .toList(),
          [3],
        );
        expect(bulkTargets.last, [3]);

        selection.click(0);
        await tester.pump();
        expect(selection.selection, {0, 1});
        expect(
          selection
              .selectedFrom(controller.items.toList())
              .toList()
              .map((post) => post.id)
              .toList(),
          [3, 3],
        );
        expect(bulkTargets.last, [3]);

        await _complete(
          tester,
          controller.setBlacklistedTags({'filtered', 'extra'}),
        );
        expect(selection.selection, isEmpty);
        expect(fixture.source!.queries.map((query) => query.cursor?.token), [
          null,
          'next',
        ]);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}

PostGridController<Post> _controller(WidgetTester tester) =>
    tester.widget<PostGrid<Post>>(find.byType(PostGrid<Post>)).controller;

Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  for (var i = 0; i < 100 && !condition(); i++) {
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  }
  expect(condition(), isTrue, reason: 'Group Post grid did not load members');
}

Future<void> _complete(WidgetTester tester, Future<void> future) async {
  var done = false;
  unawaited(
    future.then(
      (_) => done = true,
      onError: (Object _, StackTrace _) => done = true,
    ),
  );
  for (var i = 0; i < 100 && !done; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  }
  expect(done, isTrue, reason: 'Group Post grid operation did not complete');
  await future;
}

final class _Fixture {
  _Fixture(this.config, this.reference);

  final BooruConfig config;
  final ContentReference reference;
  _Source? source;
}

final class _Source extends ContentGroupSource {
  _Source(this.access, this.group);

  @override
  final ContentAccessContext access;
  final ContentReference group;
  final queries = <GroupMemberQuery>[];

  @override
  TaskEither<BooruError, GroupMemberBatch> loadMembers(
    GroupMemberQuery query,
  ) => TaskEither(() async {
    queries.add(query);
    final members = query.cursor == null
        ? [
            _member(3, 'member-a', 0),
            _member(2, 'member-b', 1),
            _member(3, 'member-c', 2),
          ]
        : [
            _member(
              99,
              'missing-member',
              3,
              availability: MemberAvailability.unavailable,
            ),
            _member(3, 'member-e', 4),
            _member(1, 'member-f', 5),
          ];
    return right((
      page: ContentPage(
        items: members,
        next: query.cursor == null ? ContentCursor('next') : null,
        total: 6,
      ),
      resolved: [
        for (final id
            in members.map((member) => member.reference.sourceKey).toSet())
          if (id != 'id:99')
            PostContentEntry(
              reference: _postReference(int.parse(id.substring(3))),
              post: _post(int.parse(id.substring(3))),
            ),
      ],
    ));
  });

  GroupMember _member(
    int id,
    String memberKey,
    int sourcePosition, {
    MemberAvailability availability = MemberAvailability.available,
  }) => GroupMember(
    reference: _postReference(id),
    memberKey: memberKey,
    sourcePosition: sourcePosition,
    availability: availability,
  );

  ContentReference _postReference(int id) =>
      const ContentReferenceCodec().parse(
        engine: access.key.engine,
        site: group.site,
        kind: ContentKind.post,
        sourceKey: 'id:$id',
      );

  Post _post(int id) => testPoolPost(
    id,
    tags: id == 2 ? {'filtered'} : const {},
  ).post.copyWith(origin: postOriginFromConfig(access.config!));

  @override
  TaskEither<BooruError, ContentGroupSummary> loadSummary(
    ContentReference reference,
  ) => TaskEither(() async => right(ContentGroupSummary(reference: group)));

  @override
  TaskEither<BooruError, ContentGroupDetails> loadDetails(
    ContentReference reference,
  ) => TaskEither(
    () async => right(
      ContentGroupDetails(
        summary: ContentGroupSummary(reference: group),
      ),
    ),
  );
}
