import 'dart:async';

import 'package:foundation/foundation.dart';

import 'package:boorusama/foundation/platform.dart';

import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/posts/listing/src/widgets/post_grid_item.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/search/following_topics/providers.dart';
import 'package:boorusama/core/search/following_topics/src/widgets/topic_follow_control.dart';
import 'package:boorusama/core/search/following_topics/types.dart';
import 'package:boorusama/core/search/search/src/routes/route_utils.dart';
import 'package:boorusama/core/search/search/src/types/topic_search_origin.dart';
import 'package:boorusama/core/search/search/src/widgets/search_page_scaffold.dart';
import 'package:boorusama/core/search/search/src/widgets/search_app_bar.dart';
import 'package:boorusama/core/search/search/src/widgets/search_controller.dart';
import 'package:boorusama/core/search/selected_tags/types.dart';
import 'package:boorusama/core/tags/metatag/providers.dart';
import 'package:boorusama/core/tags/metatag/types.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/material.dart';
import 'package:oktoast/oktoast.dart';

import 'following_topic_test_utils.dart';
import 'topic_query_test_builder.dart';
import 'topic_test_utils.dart';

void main() {
  late FollowingTopicHarness harness;
  late WidgetTester activeTester;
  Future<T> io<T>(Future<T> Function() operation) async {
    late T result;
    Object? error;
    StackTrace? trace;
    var complete = false;
    unawaited(
      operation().then<void>(
        (value) {
          result = value;
          complete = true;
        },
        onError: (Object failure, StackTrace stack) {
          error = failure;
          trace = stack;
          complete = true;
        },
      ),
    );
    // Mutations can queue behind a refresh started in Flutter's fake zone.
    // Yield both zones until the memory operation signals completion.
    for (var turn = 0; !complete && turn < 100; turn++) {
      await drain(activeTester);
    }
    if (!complete) fail('The memory operation did not complete');
    if (error case final failure?) {
      Error.throwWithStackTrace(failure, trace!);
    }
    return result;
  }

  late SearchPageController editor;
  late BooruConfig editorProfile;
  late FollowingTopic original;
  late List<Post> posts;
  var failRefresh = false;

  setUp(() {
    posts = [];
    failRefresh = false;
    harness = FollowingTopicHarness(
      fetchPosts: (_, _, _, _) async {
        if (failRefresh) throw StateError('offline');
        return Either.of(const PostResult(posts: <Post>[], total: 0));
      },
      booruBuilder: (_) => TopicQueryTestBuilder(
        posts: () => posts,
        onController: (profile, controller) {
          editor = controller;
          editorProfile = profile;
        },
      ),
      overrides: [
        appPlatformProvider.overrideWithValue(AppPlatform.android),
        booruConfigProvider.overrideWith(_Profiles.new),
        metatagExtractorProvider.overrideWith((ref, auth) => _Extractor()),
      ],
    );
  });
  tearDown(() {
    dismissAllToast();
    harness.dispose();
  });

  Future<void> open(
    WidgetTester tester, {
    bool ordinary = false,
    bool raw = false,
    bool inFolder = false,
    String? rawQuery,
  }) async {
    activeTester = tester;
    await tester.runAsync(() async {
      await harness.seed([
        topicFixture(
          query: raw ? rawQuery ?? '( cat ~ dog ) source:"a b"' : 'cat',
          queryStructure: raw
              ? null
              : SearchQueryStructure.typedTags(const ['cat']),
        ),
      ]);
      if (inFolder) {
        await harness.repository.replaceOrganization(
          TopicOrganization(
            folders: [
              TopicFolder(
                id: 'folder',
                name: 'Original Folder',
                searchIds: const ['cats'],
              ),
            ],
          ),
        );
        await harness.repository.setAutoUpdate(['cats'], false);
      }
      original = (await harness.repository.getById('cats'))!;
      await harness.container.read(followingTopicsProvider.future);
    });
    await pumpTopicQueryRouter(
      harness,
      tester,
      Scaffold(
        body: Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () => goToSearchPage(
              ref,
              config: testProfile,
              originatingTopicId: ordinary ? null : original.id,
              tag: raw ? original.query : null,
              tags: raw
                  ? null
                  : SearchTagSet.fromList(original.queryStructure!.typedTags),
              queryType: raw ? QueryType.simple : QueryType.list,
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await drain(tester);
    await settle(tester);
    await drain(tester);
  }

  TopicFollowPill pill(WidgetTester tester) =>
      tester.widget<TopicFollowPill>(find.byType(TopicFollowPill));
  TopicSearchOrigin? origin(WidgetTester tester) =>
      TopicSearchOriginScope.of(tester.element(find.byType(FollowTopicButton)))!
          .value;
  String? activeTopicId(WidgetTester tester) => tester
      .widget<SearchPageScaffold<Post>>(find.byType(SearchPageScaffold<Post>))
      .params
      .originatingTopicId;

  Future<void> change(WidgetTester tester, [String query = 'dog']) async {
    editor.tagsController
      ..clear()
      ..addTag(TagSearchItem.fromString(query));
    editor.closeEditor();
    await drain(tester);
    await settle(tester);
  }

  Future<void> follow(WidgetTester tester) async {
    await tester.tap(find.byType(TopicFollowPill));
    await drain(tester);
    await settle(tester);
  }

  Finder confirmationText(String text) => find.descendant(
    of: find.byType(AlertDialog).last,
    matching: find.text(text),
  );

  Future<void> confirm(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Update Original Topic'));
    await settle(tester);
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Update Topic'));
    await drain(tester);
    await settle(tester);
    await drain(tester);
    // Advance the third-party toast's fixed dismissal lifecycle.
    await tester.pump(const Duration(seconds: 3));
    await settle(tester);
  }

  Future<void> cancel(WidgetTester tester) async {
    await tester.tap(find.text('Cancel'));
    await settle(tester);
  }

  Future<void> dismissPicker(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await settle(tester);
  }

  Future<FollowingTopic> saved() async => (await io<FollowingTopic?>(
    () => harness.repository.getById(original.id),
  ))!;

  testWidgets(
    'ordinary and unchanged Search preserve Follow with no badge or Save; numerical badge is removed',
    (tester) async {
      await open(tester, ordinary: true);
      expect(pill(tester).count, 1);
      expect(pill(tester).modified, isFalse);
      expect(find.byType(Badge), findsNothing);
      await follow(tester);
      expect(find.byTooltip('Update Original Topic'), findsNothing);
      expect(
        find.byType(Badge),
        findsOneWidget,
        reason: 'The folder count remains',
      );
      await dismissPicker(tester);
      await change(tester);
      expect(pill(tester).count, 0);
      expect(pill(tester).modified, isFalse);
      await follow(tester);
      expect(find.byTooltip('Update Original Topic'), findsNothing);
    },
  );

  testWidgets(
    'query modifications overlay the unchanged button bounds and restoring the original removes Save',
    (tester) async {
      await open(tester);
      expect(pill(tester).modified, isFalse);
      await follow(tester);
      expect(find.byTooltip('Update Original Topic'), findsNothing);
      await dismissPicker(tester);
      final before = tester.getSize(find.byType(TopicFollowPill));
      // Same label length/state: another followed query still gets a modification indicator.
      final folder = await io(
        () => harness.container
            .read(followingTopicsProvider.notifier)
            .createSharedFolder('Other'),
      );
      await io(
        () => harness.container
            .read(followingTopicsProvider.notifier)
            .setFollowDestinations(
              profileId: testProfile.id,
              query: 'dog',
              folderIds: {folder.id},
            ),
      );
      await change(tester);
      expect(pill(tester).modified, isTrue);
      expect(pill(tester).count, 1);
      expect(tester.getSize(find.byType(TopicFollowPill)), before);
      expect(
        find.descendant(
          of: find.byType(TopicFollowPill),
          matching: find.byIcon(Icons.edit),
        ),
        findsOneWidget,
      );
      await follow(tester);
      expect(find.byTooltip('Update Original Topic'), findsOneWidget);
      await dismissPicker(tester);
      await change(tester, 'cat');
      expect(pill(tester).modified, isFalse);
      await follow(tester);
      expect(find.byTooltip('Update Original Topic'), findsNothing);
    },
  );

  testWidgets(
    'Cancel preserves folder selections; Save preserves identity, settings and organization and refreshes separately',
    (tester) async {
      await open(tester, inFolder: true);
      await change(tester);
      await follow(tester);
      await tester.tap(find.text('Home'));
      await confirm(tester);
      expect(find.text('Current Query'), findsOneWidget);
      expect(find.text('New Query'), findsOneWidget);
      expect(find.textContaining('post-tracking baseline'), findsNothing);
      expect(confirmationText('Original Folder'), findsOneWidget);
      await cancel(tester);
      expect(
        tester.widget<Checkbox>(find.byType(Checkbox).first).value,
        isTrue,
      );
      expect(await saved(), original);
      final organization = await io(() => harness.repository.getOrganization());
      harness.refreshGate = Completer<void>();
      await confirm(tester);
      await save(tester);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(SearchAppBarBackButton), findsOneWidget);
      expect(pill(tester).modified, isFalse);
      final result = await saved();
      expect(result.id, original.id);
      expect(result.createdAt, original.createdAt);
      expect(result.name, original.name);
      expect(result.autoUpdateEnabled, isFalse);
      expect(result.query, 'dog');
      expect(result.queryStructure!.typedTags, ['dog']);
      expect(
        await io(() => harness.repository.getOrganization()),
        organization,
      );
      expect(
        await io(() => harness.repository.getAll()),
        hasLength(1),
        reason: 'Pending Home destination was not applied',
      );
      harness.refreshGate!.complete();
      await drain(tester);
      await change(tester, 'bird');
      await follow(tester);
      await confirm(tester);
      expect(
        find.descendant(
          of: find.byType(AlertDialog).last,
          matching: find.text('dog'),
        ),
        findsOneWidget,
        reason: 'Next save uses the successful baseline',
      );
    },
  );

  testWidgets(
    'Done adopts one new Topic and subsequent Update targets it independently',
    (tester) async {
      await open(tester, inFolder: true);
      final folder = await io(
        () => harness.container
            .read(followingTopicsProvider.notifier)
            .createSharedFolder('Folder B'),
      );
      await change(tester);
      await follow(tester);
      await tester.tap(find.text('Folder B'));
      await tester.tap(find.widgetWithText(FilledButton, 'Done'));
      await drain(tester);
      await settle(tester);
      final created = (await io(() => harness.repository.getAll()))
          .singleWhere((t) => t.id != original.id);
      expect(await saved(), original);
      expect(origin(tester)!.topic.id, created.id);
      expect(origin(tester)!.topic.profileId, created.profileId);
      expect(origin(tester)!.topic.queryStructure, created.queryStructure);
      expect(
        origin(tester)!.topic.autoUpdateEnabled,
        created.autoUpdateEnabled,
      );
      expect(activeTopicId(tester), created.id);
      expect(
        tester
            .widget<FollowTopicButton>(find.byType(FollowTopicButton))
            .originatingTopicId,
        created.id,
      );
      expect(pill(tester).modified, isFalse);
      expect(pill(tester).count, 1);
      expect(find.byType(SearchAppBarBackButton), findsOneWidget);
      await change(tester, 'bird');
      expect(pill(tester).modified, isTrue);
      await follow(tester);
      await confirm(tester);
      expect(find.widgetWithText(SelectableText, 'dog'), findsOneWidget);
      expect(confirmationText('Folder B'), findsOneWidget);
      await save(tester);
      expect(
        (await io(() => harness.repository.getById(created.id)))!.query,
        'bird',
      );
      expect(await saved(), original);
      expect(origin(tester)!.topic.id, created.id);
      expect(pill(tester).modified, isFalse);
      final organization = await io(() => harness.repository.getOrganization());
      expect(organization.directIds(folder.id), [created.id]);
      expect(organization.directIds('folder'), [original.id]);
    },
  );

  Future<TopicFolder> createFolder(String name, {String? parentId}) => io(
    () => harness.container
        .read(followingTopicsProvider.notifier)
        .createSharedFolder(name, parentId: parentId),
  );

  Future<void> done(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Done'));
    await drain(tester);
    await settle(tester);
  }

  Future<void> switchProfile(WidgetTester tester, String label) async {
    await tester.tap(find.byTooltip('Choose a Profile'));
    await settle(tester);
    await tester.tap(find.text(label).last);
    await drain(tester);
    await settle(tester);
  }

  testWidgets(
    'multiple new Topics clear the origin through profile rebuilds without reverting the query',
    (tester) async {
      await open(tester, inFolder: true);
      await createFolder('Folder B');
      await change(tester);
      await follow(tester);
      await tester.tap(find.text('Home'));
      await tester.tap(find.text('Folder B'));
      await done(tester);
      expect(await saved(), original);
      expect(
        (await io(() => harness.repository.getAll()))
            .where((t) => t.query == 'dog'),
        hasLength(2),
      );
      expect(origin(tester), isNull);
      expect(activeTopicId(tester), isNull);
      expect(
        tester
            .widget<FollowTopicButton>(find.byType(FollowTopicButton))
            .originatingTopicId,
        isNull,
      );
      expect(pill(tester).modified, isFalse);
      expect(pill(tester).count, 2);
      for (final label in ['other.example', 'active.example']) {
        await switchProfile(tester, label);
        expect(origin(tester), isNull);
        expect(activeTopicId(tester), isNull);
        expect(editor.tagsController.rawTagsString, 'dog');
      }
      await change(tester, 'bird');
      expect(pill(tester).modified, isFalse);
      await follow(tester);
      expect(find.byTooltip('Update Original Topic'), findsNothing);
    },
  );

  testWidgets(
    'failed and cancelled Follow preserve the origin and modification state',
    (tester) async {
      await open(tester, inFolder: true);
      await createFolder('Folder B');
      final before = origin(tester);
      await change(tester);
      await follow(tester);
      await tester.tap(find.text('Folder B'));
      harness.box.failWrites = true;
      await done(tester);
      expect(find.text('Could not save the topic. Try again.'), findsOneWidget);
      expect(origin(tester), same(before));
      expect(activeTopicId(tester), original.id);
      expect(pill(tester).modified, isTrue);
      expect(await saved(), original);
      expect(await io(() => harness.repository.getAll()), hasLength(1));
      harness.box.failWrites = false;
      await follow(tester);
      await tester.tap(find.text('Folder B'));
      await dismissPicker(tester);
      expect(origin(tester), same(before));
      expect(pill(tester).modified, isTrue);
      expect(await io(() => harness.repository.getAll()), hasLength(1));
    },
  );

  for (final removeMatch in [false, true]) {
    testWidgets(
      'no new Topic never adopts an existing match, removed=$removeMatch',
      (tester) async {
        await open(tester, inFolder: true);
        final existing = await io(
          () => harness.container
              .read(followingTopicsProvider.notifier)
              .followLocally(
                profileId: testProfile.id,
                query: 'dog',
                name: 'Existing match',
              ),
        );
        final before = origin(tester);
        await change(tester);
        await follow(tester);
        expect(
          tester.widget<Checkbox>(find.byType(Checkbox).first).value,
          isTrue,
        );
        if (removeMatch) {
          await tester.tap(find.text('Home'));
        }
        await done(tester);
        expect(origin(tester), same(before));
        expect(activeTopicId(tester), original.id);
        expect(pill(tester).modified, isTrue);
        expect(await saved(), original);
        expect(
          await io(() => harness.repository.getById(existing.id)),
          removeMatch ? isNull : existing,
        );
        if (removeMatch) {
          // Advance the third-party Undo toast's dismissal lifecycle.
          await tester.pump(const Duration(seconds: 6));
          await settle(tester);
        }
      },
    );
  }

  testWidgets(
    'adoption uses persisted settings copied from a matching Topic without changing that match',
    (tester) async {
      await open(tester, inFolder: true);
      await createFolder('Folder B');
      final notifier = harness.container.read(followingTopicsProvider.notifier);
      final existing = await io(
        () => notifier.followLocally(
          profileId: testProfile.id,
          query: 'dog',
          name: 'Template',
        ),
      );
      await io(() => notifier.setAutoUpdate([existing.id], false));
      final template = await io(() => harness.repository.getById(existing.id));
      await change(tester);
      await follow(tester);
      await tester.tap(find.text('Folder B'));
      await done(tester);
      final adopted = origin(tester)!.topic;
      expect(adopted.id, isNot(existing.id));
      expect(adopted.name, 'Template');
      expect(adopted.autoUpdateEnabled, isFalse);
      expect(adopted.queryStructure!.typedTags, ['dog']);
      expect(await io(() => harness.repository.getById(existing.id)), template);
      expect(await saved(), original);
      await change(tester, 'bird');
      await follow(tester);
      await confirm(tester);
      expect(confirmationText('Folder B'), findsOneWidget);
      await save(tester);
      final edited = (await io(() => harness.repository.getById(adopted.id)))!;
      expect(edited.query, 'bird');
      expect(edited.name, 'Template');
      expect(edited.autoUpdateEnabled, isFalse);
      expect(await io(() => harness.repository.getById(existing.id)), template);
      expect(await saved(), original);
    },
  );

  testWidgets(
    'ordinary Search adopts a newly followed Topic and keeps its source local after clearing an ambiguous origin',
    (tester) async {
      await open(tester, ordinary: true);

      await change(tester);

      await follow(tester);

      await tester.tap(find.text('Home'));
      await done(tester);

      final adopted = origin(tester)!.topic;
      expect(activeTopicId(tester), adopted.id);
      expect(pill(tester).modified, isFalse);
      await switchProfile(tester, 'other.example');

      expect(origin(tester)!.topic.id, adopted.id);
      expect(pill(tester).modified, isTrue);
      await createFolder('Folder B');

      await follow(tester);

      await tester.tap(find.text('Home'));
      await tester.tap(find.text('Folder B'));
      await done(tester);

      expect(origin(tester), isNull);
      expect(activeTopicId(tester), isNull);
      expect(editorProfile.id, otherTestProfile.id);
      expect(editor.tagsController.rawTagsString, 'dog');
      expect(
        harness.container.read(currentBooruConfigProvider).id,
        testProfile.id,
      );
      expect(await saved(), original);
    },
  );

  testWidgets(
    'an adopted origin survives the viewer and profile replacement and remains the Update target',
    (tester) async {
      posts = [_SquarePost(testSearchPost(60, checkedAt))];
      await open(tester, inFolder: true);
      await createFolder('Folder B');
      await change(tester);
      await follow(tester);
      await tester.tap(find.text('Folder B'));
      await done(tester);
      final adopted = origin(tester)!.topic;
      final controller = editor;
      await tester.tap(find.byType(PostGridItem).first);
      await settle(tester);
      expect(find.text('Post details'), findsOneWidget);
      harness.router.pop();
      await settle(tester);
      expect(editor, same(controller));
      expect(origin(tester)!.topic.id, adopted.id);
      expect(pill(tester).modified, isFalse);
      for (final label in ['other.example', 'active.example']) {
        await switchProfile(tester, label);
        expect(origin(tester)!.topic.id, adopted.id);
        expect(activeTopicId(tester), adopted.id);
      }
      await change(tester, 'bird');
      await follow(tester);
      await confirm(tester);
      await save(tester);
      expect(
        (await io(() => harness.repository.getById(adopted.id)))!.query,
        'bird',
      );
      expect(await saved(), original);
    },
  );

  testWidgets(
    'confirmation resolves the exact Topic path and follows live folder changes without moving it on Update',
    (tester) async {
      await open(tester);
      final root = await createFolder('Collections');
      final child = await createFolder('Landscapes', parentId: root.id);
      final leaf = await createFolder('Unseen', parentId: child.id);
      final notifier = harness.container.read(followingTopicsProvider.notifier);
      await io(() => notifier.moveTopicToSharedFolder(original.id, leaf.id));
      // An independent copy with an equal query must not supply its Home path.
      final copy = await io(
        () => notifier.followLocally(
          profileId: testProfile.id,
          query: original.query,
          name: 'Other copy',
        ),
      );
      await change(tester);
      await follow(tester);
      await confirm(tester);
      expect(find.text('Collections / Landscapes / Unseen'), findsOneWidget);
      expect(confirmationText('Home'), findsNothing);
      expect(find.textContaining('post-tracking baseline'), findsNothing);
      await io(
        () => notifier.renameSharedFolder(root.id, 'Library', parentId: null),
      );
      await drain(tester);
      expect(find.text('Library / Landscapes / Unseen'), findsOneWidget);
      await io(() => notifier.moveTopicToSharedFolder(original.id, null));
      await drain(tester);
      expect(confirmationText('Home'), findsOneWidget);
      expect(find.text('Library / Landscapes / Unseen'), findsNothing);
      await save(tester);
      expect((await saved()).query, 'dog');
      final organization = await io(() => harness.repository.getOrganization());
      expect(organization.directIds(null), containsAll([original.id, copy.id]));
      expect(organization.directIds(leaf.id), isEmpty);
      expect(await io(() => harness.repository.getById(copy.id)), copy);
    },
  );

  testWidgets(
    'a deleted Topic has a graceful missing-location fallback and cannot be updated',
    (tester) async {
      await open(tester, inFolder: true);
      await change(tester);
      await follow(tester);
      await confirm(tester);
      await io(
        () => harness.container
            .read(followingTopicsProvider.notifier)
            .delete(original.id),
      );
      await drain(tester);
      expect(find.text('No Folder'), findsOneWidget);
      expect(confirmationText('Original Folder'), findsNothing);
      expect(tester.takeException(), isNull);
      await save(tester);
      expect(
        find.text(
          'This topic changed or was deleted. Reopen it to edit the latest version.',
        ),
        findsOneWidget,
      );
      expect(await io(() => harness.repository.getById(original.id)), isNull);
    },
  );

  testWidgets(
    'a query followed in another folder can still update the original without mutating the other Topic',
    (tester) async {
      await open(tester, inFolder: true);
      final other = await io(
        () => harness.container
            .read(followingTopicsProvider.notifier)
            .followLocally(
              profileId: testProfile.id,
              query: 'dog',
              name: 'Other',
            ),
      );
      await change(tester);
      expect(pill(tester).count, 1);
      expect(pill(tester).modified, isTrue);
      await follow(tester);
      await confirm(tester);
      await save(tester);
      expect((await saved()).query, 'dog');
      expect(await io(() => harness.repository.getById(other.id)), other);
    },
  );

  testWidgets(
    'profile switching keeps original context, confirmation profiles, pending input and local ownership',
    (tester) async {
      await open(tester);
      editor.textController.text = 'bird';
      await tester.tap(find.byTooltip('Choose a Profile'));
      await settle(tester);
      await tester.tap(find.text('other.example').last);
      await drain(tester);
      await settle(tester);
      expect(editorProfile.id, otherTestProfile.id);
      expect(editor.textController.text, 'bird');
      expect(pill(tester).modified, isTrue);
      // Invoke the covered result action without discarding the pending input.
      pill(tester).onPressed!();
      await drain(tester);
      await settle(tester);
      await confirm(tester);
      expect(find.text('Current Profile: ${testProfile.name}'), findsOneWidget);
      expect(
        find.text('New Profile: ${otherTestProfile.name}'),
        findsOneWidget,
      );
      await save(tester);
      expect((await saved()).profileId, otherTestProfile.id);
      expect((await saved()).query, 'cat bird');
      expect(pill(tester).modified, isFalse);
      expect(
        harness.container.read(currentBooruConfigProvider).id,
        testProfile.id,
      );
    },
  );

  testWidgets(
    'raw expressions remain opaque and long comparisons are selectable without truncation',
    (tester) async {
      await open(
        tester,
        raw: true,
        rawQuery:
            '( cat ~ dog ) source:"${List.filled(80, 'long expression ').join()}"',
      );
      editor.tagsController.addTag(const TagSearchItem.raw(tag: '-id:1..999'));
      await drain(tester);
      await follow(tester);
      await confirm(tester);
      expect(
        find.widgetWithText(SelectableText, original.query),
        findsOneWidget,
      );
      await save(tester);
      expect((await saved()).query, '${original.query} -id:1..999');
      expect((await saved()).queryStructure, isNull);
    },
  );

  testWidgets('valid pending chip and parked input are both included', (
    tester,
  ) async {
    await open(tester);
    editor.textController.text = 'bird';
    editor.editTag(editor.tagsController.tags.single);
    editor.textController.text = '-dog';
    pill(tester).onPressed!();
    await drain(tester);
    await settle(tester);
    await confirm(tester);
    expect(find.widgetWithText(SelectableText, '-dog bird'), findsOneWidget);
    await save(tester);
    expect((await saved()).queryStructure!.typedTags, ['-dog', 'bird']);
  });

  for (final mode in ['operator', 'composition', 'empty']) {
    testWidgets('$mode input cannot open a save flow or discard the draft', (
      tester,
    ) async {
      await open(tester);
      final action = pill(tester).onPressed!;
      if (mode == 'empty') {
        editor.tagsController.clear();
      } else {
        editor.textController.value = TextEditingValue(
          text: mode == 'operator' ? 'score:' : 'dog',
          composing: mode == 'composition'
              ? const TextRange(start: 0, end: 3)
              : TextRange.empty,
        );
      }
      action();
      await settle(tester);
      expect(find.byType(AlertDialog), findsNothing);
      expect(await saved(), original);
      expect(
        editor.textController.text,
        mode == 'operator'
            ? 'score:'
            : mode == 'composition'
            ? 'dog'
            : '',
      );
    });
  }

  for (final mode in ['disk', 'duplicate', 'stale', 'deleted', 'profile']) {
    testWidgets(
      '$mode failure retains query and confirmation without changing original',
      (tester) async {
        await open(tester);
        await change(tester);
        await follow(tester);
        await confirm(tester);
        if (mode == 'disk') harness.box.failWrites = true;
        if (mode == 'duplicate') {
          await io(
            () => harness.repository.create(
              profileId: testProfile.id,
              query: 'dog',
              name: 'Duplicate',
            ),
          );
        }
        if (mode == 'stale') {
          await io(
            () => harness.repository.rename(original.id, 'Concurrent name'),
          );
        }
        if (mode == 'deleted') {
          await io(() => harness.repository.delete(original.id));
        }
        if (mode == 'profile') {
          (harness.container.read(booruConfigProvider.notifier) as _Profiles)
              .remove(testProfile.id);
        }
        final before = await io(() => harness.repository.getAll());
        await save(tester);
        expect(find.text('Update Original Topic?'), findsOneWidget);
        expect(await io(() => harness.repository.getAll()), before);
        expect(editor.tagsController.rawTagsString, 'dog');
        if (mode == 'disk' || mode == 'duplicate') {
          harness.box.failWrites = false;
          if (mode == 'duplicate') {
            final duplicate = (await io(() => harness.repository.getAll()))
                .singleWhere(
                  (t) => t.id != original.id,
                );
            await io(() => harness.repository.delete(duplicate.id));
          }
          await save(tester);
          expect((await saved()).query, 'dog');
          expect(find.byType(AlertDialog), findsNothing);
        } else {
          expect(
            find.text(
              mode == 'profile' ? 'Choose an available profile before saving.' : 'This topic changed or was deleted. Reopen it to edit the latest version.',
            ),
            findsOneWidget,
          );
        }
      },
    );
  }

  testWidgets(
    'repeated Save, confirmation and Back cannot duplicate an in-flight write',
    (tester) async {
      await open(tester);
      await change(tester);
      await follow(tester);
      final saveAction = tester
          .widget<IconButton>(
            find.byWidgetPredicate(
              (w) => w is IconButton && w.tooltip == 'Update Original Topic',
            ),
          )
          .onPressed!;
      saveAction();
      saveAction();
      await settle(tester);
      expect(find.text('Update Original Topic?'), findsOneWidget);
      harness.box.writeGate = Completer<void>();
      final confirmAction = tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Update Topic'),
          )
          .onPressed!;
      confirmAction();
      confirmAction();
      await tester.pump();
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(find.byType(CircularProgressIndicator), findsWidgets);
      expect((await saved()).query, 'cat');
      harness.box.writeGate!.complete();
      await drain(tester);
      await settle(tester);
      expect((await saved()).runtimeRevision, original.runtimeRevision + 1);
      expect(pill(tester).modified, isFalse);
      await tester.pump(const Duration(seconds: 3));
      await settle(tester);
    },
  );

  testWidgets(
    'post round-trip retains query, profile and modification baseline',
    (tester) async {
      posts = [_SquarePost(testSearchPost(60, checkedAt))];
      await open(tester);
      await change(tester);
      await tester.tap(find.byType(PostGridItem).first);
      await settle(tester);
      expect(find.text('Post details'), findsOneWidget);
      harness.router.pop();
      await settle(tester);
      expect(editor.tagsController.rawTagsString, 'dog');
      expect(pill(tester).modified, isTrue);
      await follow(tester);
      await confirm(tester);
      expect(find.widgetWithText(SelectableText, 'cat'), findsOneWidget);
    },
  );

  testWidgets('multi-day workflow reopens saved query and profile', (
    tester,
  ) async {
    await open(tester);
    await change(tester);
    await follow(tester);
    await confirm(tester);
    await save(tester);
    await tester.tap(find.byType(SearchAppBarBackButton));
    await settle(tester);
    original = await saved();
    await tester.tap(find.text('Open'));
    await drain(tester);
    await settle(tester);
    expect(editor.tagsController.rawTagsString, 'dog');
    expect(pill(tester).modified, isFalse);
    expect(pill(tester).count, 1);
  });

  testWidgets(
    'a failed baseline refresh does not turn a successful save into an error or restore the badge',
    (tester) async {
      await open(tester);
      await change(tester);
      harness.refreshGate = Completer<void>();
      await follow(tester);
      await confirm(tester);
      await save(tester);
      expect((await saved()).query, 'dog');
      expect(pill(tester).modified, isFalse);
      failRefresh = true;
      harness.refreshGate!.complete();
      await drain(tester);
      await settle(tester);
      expect((await saved()).query, 'dog');
      expect(pill(tester).modified, isFalse);
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        find.text(
          'Topic updated, but its preview could not be loaded. Refresh it later.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'raw whitespace differences are harmless but a changed persisted representation is visible',
    (tester) async {
      await open(tester, raw: true);
      editor.tagsController
        ..clear()
        ..addTag(
          TagSearchItem.raw(tag: '  ${original.query.replaceAll(' ', '  ')}  '),
        );
      await drain(tester);
      expect(pill(tester).modified, isFalse);
      // Explicit typed structure has persistence semantics even for equal text.
      editor.tagsController
        ..clear()
        ..addTag(const TagSearchItem.raw(tag: 'cat'));
      await drain(tester);
      await follow(tester);
      await confirm(tester);
      await save(tester);
      await change(tester, 'cat');
      expect(pill(tester).modified, isTrue);
      await follow(tester);
      await confirm(tester);
      await save(tester);
      expect((await saved()).queryStructure!.typedTags, ['cat']);
    },
  );

  testWidgets(
    'restoring original profile removes the badge and Save after engine replacement',
    (tester) async {
      await open(tester);
      for (final label in ['other.example', 'active.example']) {
        await tester.tap(find.byTooltip('Choose a Profile'));
        await settle(tester);
        await tester.tap(find.text(label).last);
        await drain(tester);
        await settle(tester);
        expect(pill(tester).modified, label == 'other.example');
      }
      await follow(tester);
      expect(find.byTooltip('Update Original Topic'), findsNothing);
      expect(await saved(), original);
    },
  );

  for (final keyboard in [false, true]) {
    testWidgets(
      '320dp enlarged footer and confirmation fit with keyboard=$keyboard',
      (tester) async {
        tester.view.physicalSize = const Size(320, 740);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 1.7;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
          tester.view.resetViewInsets();
          tester.platformDispatcher.clearTextScaleFactorTestValue();
        });
        await open(tester);
        final root = await createFolder('A long collection folder name');
        final child = await createFolder(
          'A long nested landscape folder name',
          parentId: root.id,
        );
        await io(
          () => harness.container
              .read(followingTopicsProvider.notifier)
              .moveTopicToSharedFolder(original.id, child.id),
        );
        await change(tester);
        if (keyboard) {
          tester.view.viewInsets = const FakeViewPadding(bottom: 280);
        }
        await follow(tester);
        final saveButton = find.byTooltip('Update Original Topic');
        expect(
          tester.getRect(saveButton).bottom,
          lessThanOrEqualTo(keyboard ? 460 : 740),
        );
        expect(
          tester.getRect(find.text('Done')).bottom,
          lessThanOrEqualTo(keyboard ? 460 : 740),
        );
        expect(find.byTooltip('New Folder'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await confirm(tester);
        expect(
          find.text(
            'A long collection folder name / A long nested landscape folder name',
          ),
          findsOneWidget,
        );
        expect(find.textContaining('post-tracking baseline'), findsNothing);
        await tester.ensureVisible(find.text('Update Topic'));
        expect(
          tester.getRect(find.text('Update Topic')).bottom,
          lessThanOrEqualTo(keyboard ? 460 : 740),
        );
        expect(tester.takeException(), isNull);
        await save(tester);
        expect((await saved()).query, 'dog');
      },
    );
  }
}

class _Extractor implements MetatagExtractor {
  @override
  String? fromString(String value) =>
      value.startsWith('score:') ? 'score' : null;
  @override
  bool hasMetatag(String value) => fromString(value) != null;
}

final class _SquarePost extends Post {
  _SquarePost(Post post)
    : super(origin: post.origin, core: post.core, booruData: post.booruData);
  @override
  double get aspectRatio => 1;
}

class _Profiles extends BooruConfigNotifier {
  _Profiles() : super(initialConfigs: [testProfile, otherTestProfile]);
  void remove(String id) => state = state.where((p) => p.id != id).toList();
}
