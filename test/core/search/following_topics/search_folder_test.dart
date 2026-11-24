import 'dart:async';

import 'package:boorusama/core/blacklists/providers.dart';
import 'package:boorusama/core/blacklists/src/types/blacklisted_tag.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/content/content_access_provider.dart';
import 'package:boorusama/core/debug/src/logging/app_logger.dart';
import 'package:boorusama/core/developer_options/providers.dart';
import 'package:boorusama/core/http/client/coordination.dart';
import 'package:boorusama/core/images/booru_image.dart';
import 'package:boorusama/core/navigation/destination_activity.dart';
import 'package:boorusama/core/posts/post/providers.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/search/following_topics/providers.dart';
import 'package:boorusama/core/search/following_topics/src/pages/following_topics_page.dart';
import 'package:boorusama/core/search/following_topics/src/providers/untracked_topic_preview_provider.dart';
import 'package:boorusama/core/search/following_topics/src/widgets/following_topic_card.dart';
import 'package:boorusama/core/search/following_topics/types.dart';
import 'package:boorusama/foundation/loggers.dart';
import 'package:clock/clock.dart';
import 'package:kurumi/kurumi.dart';
import 'package:i18n/i18n.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../application/support/fake_image_dio.dart';
import 'following_topic_test_utils.dart';
import 'topic_test_utils.dart';

void main() {
  late FollowingTopicHarness harness;
  setUp(() {
    harness = FollowingTopicHarness();
  });
  tearDown(() => harness.dispose());

  Finder pageOverflow() => find.descendant(
    of: find.byType(AppBar),
    matching: find.bySemanticsLabel(RegExp(r'^(More|Mehr)$')),
  );

  Finder folderCard(String folderId) => find.byKey(
    ValueKey('following-topic-folder-$folderId'),
  );

  Finder folderImages(String folderId) => find.descendant(
    of: folderCard(folderId),
    matching: find.byType(BooruImage),
  );

  Future<String> seedPreviewFolder(
    WidgetTester tester,
    List<FollowingTopic> topics, {
    List<FollowingTopic> nested = const [],
  }) async => (await tester.runAsync(() async {
    await harness.seed([...topics, ...nested]);
    await harness.container.read(followingTopicsProvider.future);
    final notifier = harness.container.read(followingTopicsProvider.notifier);
    final folder = await notifier.createSharedFolder('Animals');
    for (final topic in topics) {
      await notifier.moveTopicToSharedFolder(topic.id, folder.id);
    }
    if (nested.isNotEmpty) {
      final child = await notifier.createSharedFolder(
        'Kittens',
        parentId: folder.id,
      );
      for (final topic in nested) {
        await notifier.moveTopicToSharedFolder(topic.id, child.id);
      }
    }
    return folder.id;
  }))!;

  Future<void> openFolderMenu(WidgetTester tester, String folderId) async {
    await tester.tap(
      find.descendant(
        of: folderCard(folderId),
        matching: followingCardMenus(),
      ),
    );
    await settle(tester);
  }

  Future<void> chooseFolderAction(
    WidgetTester tester,
    String folderId,
    String label,
  ) async {
    await openFolderMenu(tester, folderId);
    await tester.ensureVisible(find.text(label).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await settle(tester);
    await drain(tester);
  }

  KurumiPopupMenuItem actionItem(WidgetTester tester, String label) =>
      tester.widget<KurumiPopupMenuItem>(
        find.ancestor(
          of: find.text(label),
          matching: find.byWidgetPredicate(
            (widget) => widget is KurumiPopupMenuItem,
          ),
        ),
      );

  Future<void> dismissMenu(WidgetTester tester) async {
    await tester.tapAt(const Offset(1, 1));
    await settle(tester);
  }

  FollowingTopic cachedFixture({
    required String id,
    required List<DateTime?> postCreatedAts,
    bool checked = true,
  }) => FollowingTopic(
    id: id,
    profileId: '00000000-0000-4000-8000-00000000000c',
    query: id,
    name: id,
    position: 0,
    createdAt: checkedAt,
    previews: [
      for (final (index, postCreatedAt) in postCreatedAts.indexed)
        SearchPostPreview(
          postId: index,
          postCreatedAt: postCreatedAt,
          thumbnailUrl: 'https://images.example/$id-$index.jpg',
          sampleUrl: null,
          discoveredAt: checkedAt,
        ),
    ],
    recentPostIdentities: const [],
    unreadCount: 0,
    lastSuccessfulCheckAt: checked ? checkedAt : null,
  );

  test(
    'feed option persists through folder changes and remains opt-in',
    () async {
      final notifier = harness.container.read(
        followingTopicsProvider.notifier,
      );
      await harness.container.read(followingTopicsProvider.future);

      final parent = await notifier.createSharedFolder('Parent');
      final folder = await notifier.createSharedFolder(
        'Artists',
        parentId: parent.id,
        feedEnabled: true,
        feedMaxPosts: 2000,
      );
      expect(folder.feedEnabled, isTrue);
      expect(folder.feedMaxPosts, 2000);

      await notifier.renameSharedFolder(
        folder.id,
        'Favorite artists',
        parentId: null,
      );
      await notifier.moveFolderItems(
        folderIds: {folder.id},
        destination: null,
      );
      await notifier.setSharedFolderFeedOptions(
        folder.id,
        enabled: false,
        maxPosts: 250,
      );
      final stored = await harness.repository.getOrganization();
      final current = stored.folders.singleWhere((f) => f.id == folder.id);
      expect(current.name, 'Favorite artists');
      expect(current.parentId, isNull);
      expect(current.feedEnabled, isFalse);
      expect(current.feedMaxPosts, 250);

      await notifier.setSharedFolderFeedOptions(folder.id, enabled: true);
      final restored = TopicOrganization.fromJson(
        (await harness.repository.getOrganization()).toJson(),
      );
      final reenabled = restored.folders.singleWhere((f) => f.id == folder.id);
      expect(reenabled.feedEnabled, isTrue);
      expect(reenabled.feedMaxPosts, 250);
    },
  );

  test('legacy folders have feed mode off with the new default limit', () {
    final organization = TopicOrganization(
      folders: [TopicFolder(id: 'legacy', name: 'Older folder')],
    );
    final data = organization.toJson();
    final rows = (data['folders']! as List).cast<Map<String, Object?>>();
    rows.single
      ..remove('feedEnabled')
      ..remove('feedMaxPosts');

    final restored = TopicOrganization.fromJson(data);

    expect(restored.folders.single.feedEnabled, isFalse);
    expect(restored.folders.single.feedMaxPosts, 1000);
  });

  test(
    'refresh all includes topics belonging to an enabled folder feed',
    () async {
      await harness.seed([topicFixture(query: 'cat')]);
      final notifier = harness.container.read(
        followingTopicsProvider.notifier,
      );
      await harness.container.read(followingTopicsProvider.future);
      final folder = await notifier.createSharedFolder(
        'Artists',
        feedEnabled: true,
      );
      await notifier.moveTopicToSharedFolder('cats', folder.id);
      await notifier.openFolderFeed(folder.id);

      final outcomes = await notifier.refreshAll(testProfile.id);

      expect(outcomes, hasLength(1));
      expect(
        harness.requests.where((request) => request.query == 'cat'),
        hasLength(1),
      );
    },
  );

  test('the same query can be followed independently in two folders', () async {
    final notifier = harness.container.read(
      followingTopicsProvider.notifier,
    );
    await harness.container.read(followingTopicsProvider.future);
    final first = await notifier.createSharedFolder('First');
    final second = await notifier.createSharedFolder('Second');

    final firstTopic = await notifier.follow(
      profileId: testProfile.id,
      query: 'artist',
      name: 'Artist',
      folderId: first.id,
    );
    final secondTopic = await notifier.follow(
      profileId: testProfile.id,
      query: 'artist',
      name: 'Artist copy',
      folderId: second.id,
    );

    expect(firstTopic.topic.id, isNot(secondTopic.topic.id));
    final organization = await harness.repository.getOrganization();
    expect(organization.directIds(first.id), [firstTopic.topic.id]);
    expect(organization.directIds(second.id), [secondTopic.topic.id]);
  });

  test(
    'shared folders order topics from different profiles and leave Home ungrouped',
    () async {
      final cats = topicFixture(query: 'cat');
      final dogs = topicFixture(
        id: 'dogs',
        name: 'Dogs',
        profileId: '00000000-0000-4000-8000-000000000063',
        query: 'dog',
      );
      await harness.seed([cats, dogs]);
      final notifier = harness.container.read(
        followingTopicsProvider.notifier,
      );
      await harness.container.read(followingTopicsProvider.future);

      final folder = await notifier.createSharedFolder('Animals');
      await notifier.moveTopicToSharedFolder(cats.id, folder.id);
      await notifier.moveTopicToSharedFolder(dogs.id, folder.id);
      expect(
        harness.container
            .read(organizedFollowingTopicsProvider(folder.id))
            .requireValue
            .map((search) => search.id),
        [cats.id, dogs.id],
      );

      await notifier.reorderSharedTopics(folder.id, 1, 0);
      expect(
        harness.container
            .read(organizedFollowingTopicsProvider(folder.id))
            .requireValue
            .map((search) => search.id),
        [dogs.id, cats.id],
      );

      await notifier.reorderSharedTopics(folder.id, 0, 1);
      expect(
        harness.container
            .read(organizedFollowingTopicsProvider(folder.id))
            .requireValue
            .map((search) => search.id),
        [cats.id, dogs.id],
      );

      await notifier.moveTopicToSharedFolder(cats.id, null);
      expect(
        harness.container
            .read(organizedFollowingTopicsProvider(folder.id))
            .requireValue
            .map((search) => search.id),
        [dogs.id],
      );
      expect(
        harness.container
            .read(organizedFollowingTopicsProvider(null))
            .requireValue
            .map((search) => search.id),
        [cats.id],
      );
      expect(
        harness.container
            .read(organizedFollowingTopicsProvider(folder.id))
            .requireValue
            .any((search) => search.hasNewPosts),
        isTrue,
      );
    },
  );

  testWidgets(
    'creating a folder from More keeps text input alive through dialog closing',
    (tester) async {
      await harness.pump(tester, const FollowingTopicsPage());
      for (
        var i = 0;
        i < 20 &&
            harness.container.read(followingTopicsProvider).valueOrNull == null;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 1)),
        );
      }
      expect(
        harness.container.read(followingTopicsProvider).valueOrNull,
        isNotNull,
      );
      expect(find.byTooltip('Manage Folders'), findsNothing);
      await tester.tap(pageOverflow());
      await settle(tester);
      await tester.tap(find.text('Create Folder'));
      await settle(tester);
      await tester.enterText(find.byType(TextField), 'Animals');
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'))
            .onPressed,
        isNotNull,
      );
      await tester.tap(find.text('Save'));
      await settle(tester);
      for (var i = 0; i < 20 && find.byType(Card).evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
      }
      expect(find.text('Animals'), findsOneWidget);
      expect(find.byType(Card), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'folder cards refresh, rename, reorder, and confirm unfollowingOperation across owners',
    (tester) async {
      late String folderId;
      await tester.runAsync(() async {
        await harness.seed([
          topicFixture(query: 'cat'),
          topicFixture(
            id: 'dogs',
            profileId: '00000000-0000-4000-8000-000000000063',
            name: 'Dogs',
            query: 'dog',
          ),
          topicFixture(id: 'home', name: 'Home topic'),
        ]);
        await harness.container.read(followingTopicsProvider.future);
        final notifier = harness.container.read(
          followingTopicsProvider.notifier,
        );
        final folder = await notifier.createSharedFolder('Animals');
        folderId = folder.id;
        await notifier.moveTopicToSharedFolder('cats', folderId);
        await notifier.moveTopicToSharedFolder('dogs', folderId);
        await notifier.createSharedFolder('Other folder');
      });
      await harness.pump(tester, const FollowingTopicsPage());
      expect(find.text('2 items'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Animals')).dy,
        lessThan(tester.getTopLeft(find.text('Home topic')).dy),
      );
      expect(
        find.descendant(
          of: folderCard(folderId),
          matching: find.byType(Card),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: folderCard(folderId),
          matching: find.text('2+'),
        ),
        findsOneWidget,
      );
      await chooseFolderAction(tester, folderId, 'Refresh');
      expect(harness.requests, [
        (profileId: '00000000-0000-4000-8000-00000000000c', query: 'cat'),
        (profileId: '00000000-0000-4000-8000-000000000063', query: 'dog'),
      ]);
      await chooseFolderAction(tester, folderId, 'Settings');
      await tester.enterText(find.byType(TextField), 'Pets');
      await tester.tap(find.text('Save'));
      await settle(tester);
      await drain(tester);
      expect(find.text('Pets'), findsOneWidget);
      await chooseFolderAction(tester, folderId, 'Move Down');
      expect(
        tester.getTopLeft(find.text('Other folder')).dy,
        lessThan(tester.getTopLeft(find.text('Pets')).dy),
      );
      await chooseFolderAction(tester, folderId, 'Move Up');
      expect(
        tester.getTopLeft(find.text('Pets')).dy,
        lessThan(tester.getTopLeft(find.text('Other folder')).dy),
      );
      await chooseFolderAction(tester, folderId, 'Delete');
      expect(find.text('Delete "Pets"?'), findsOneWidget);
      expect(
        find.text(
          'This will permanently delete 1 folders and 2 topics.',
        ),
        findsOneWidget,
      );
      expect(find.text('Removal cannot be undone.'), findsNothing);
      await tester.tap(find.text('Cancel'));
      await settle(tester);
      await drain(tester);
      expect(
        harness.container
            .read(followingTopicsProvider)
            .requireValue
            .topics
            .length,
        3,
      );
      await chooseFolderAction(tester, folderId, 'Delete');
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await settle(tester);
      await drain(tester);
      expect(find.text('Pets'), findsNothing);
      expect(
        harness.container
            .read(followingTopicsProvider)
            .requireValue
            .topics
            .map((s) => s.id),
        ['home'],
      );
      expect(find.text('Home topic'), findsOneWidget);
    },
  );

  testWidgets(
    'manual view keeps move actions with disabled boundaries for folders and their searches',
    (tester) async {
      late String animalsId;
      late String otherId;
      await tester.runAsync(() async {
        await harness.seed([
          topicFixture(query: 'cat'),
          topicFixture(id: 'dogs', name: 'Dogs', query: 'dog', position: 1),
        ]);
        await harness.container.read(followingTopicsProvider.future);
        final notifier = harness.container.read(
          followingTopicsProvider.notifier,
        );
        final animals = await notifier.createSharedFolder('Animals');
        animalsId = animals.id;
        await notifier.moveTopicToSharedFolder('cats', animals.id);
        await notifier.moveTopicToSharedFolder('dogs', animals.id);
        otherId = (await notifier.createSharedFolder('Other')).id;
      });
      await harness.pump(tester, const FollowingTopicsPage());

      for (final c in [
        (id: animalsId, moveUp: false, moveDown: true),
        (id: otherId, moveUp: true, moveDown: false),
      ]) {
        await openFolderMenu(tester, c.id);
        expect(actionItem(tester, 'Move Up').onTap != null, c.moveUp);
        expect(actionItem(tester, 'Move Down').onTap != null, c.moveDown);
        await dismissMenu(tester);
      }

      await tester.tap(find.text('Animals'));
      await settle(tester);
      for (final c in [
        (name: 'Cats', moveUp: false, moveDown: true),
        (name: 'Dogs', moveUp: true, moveDown: false),
      ]) {
        final card = find.ancestor(
          of: find.text(c.name),
          matching: find.byType(FollowingTopicCard),
        );
        await tester.tap(
          find.descendant(
            of: card,
            matching: followingCardMenus(),
          ),
        );
        await settle(tester);
        expect(actionItem(tester, 'Move Up').onTap != null, c.moveUp);
        expect(actionItem(tester, 'Move Down').onTap != null, c.moveDown);
        await dismissMenu(tester);
      }
    },
  );

  testWidgets(
    'sorted views omit move actions from folder cards and searches inside folders',
    (tester) async {
      late String folderId;
      await tester.runAsync(() async {
        await harness.seed([topicFixture(previewCount: 1)]);
        await harness.container.read(followingTopicsProvider.future);
        final notifier = harness.container.read(
          followingTopicsProvider.notifier,
        );
        final folder = await notifier.createSharedFolder('Animals');
        folderId = folder.id;
        await notifier.moveTopicToSharedFolder('cats', folder.id);
      });
      await harness.pump(tester, const FollowingTopicsPage());
      await tester.tap(find.byTooltip('Sort By'));
      await settle(tester);
      await tester.tap(find.text('Unread First'));
      await settle(tester);
      await drain(tester);

      await openFolderMenu(tester, folderId);
      for (final label in ['Move Up', 'Move Down']) {
        expect(find.text(label), findsNothing);
      }
      await dismissMenu(tester);

      await tester.tap(find.text('Animals'));
      await settle(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(FollowingTopicCard),
          matching: followingCardMenus(),
        ),
      );
      await settle(tester);
      for (final label in ['Move Up', 'Move Down']) {
        expect(find.text(label), findsNothing);
      }
    },
  );

  for (final topicCount in [1, 2, 4, 5]) {
    testWidgets(
      'parent folder and Realbooru Topic share previews with $topicCount untracked members',
      (tester) async {
        tester.view.physicalSize = const Size(320, 800);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 1.5;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final realbooru = BooruConfig.fromJson({
          ...BooruConfig.defaultConfig(
            booruType: BooruType.gelbooruV2,
            url: 'https://realbooru.com/',
            customDownloadFileNameFormat: null,
          ).toJson(),
          'id': testProfile.id,
        });
        final topics = [
          for (var i = 0; i < topicCount; i++)
            topicFixture(
              id: 'cats-$i',
              profileId: realbooru.id,
              query: 'cat_$i',
              error: SearchRefreshErrorKind.unsupported,
              checked: false,
            ),
        ];
        final topic = topics.first;
        List<String> urlsFor(String query) => [
          for (var i = 0; i < 4; i++) 'https://realbooru.com/$query-$i.jpg',
        ];
        final requests = <UntrackedTopicPreviewKey>[];
        harness.dispose();
        harness = FollowingTopicHarness(
          profiles: [realbooru, otherTestProfile],
          supported: false,
          loadImages: true,
          overrides: [
            deterministicImageDioOverride(),
            untrackedTopicPreviewProvider.overrideWith((ref, key) {
              requests.add(key);
              return Future.value(urlsFor(key.query));
            }),
          ],
        );
        harness.container
            .read(selectedTestProfileProvider.notifier)
            .select(otherTestProfile);
        final folderId = await seedPreviewFolder(tester, topics);
        final before = await tester.runAsync(harness.repository.getAll);
        final mutations = harness.box.mutationCount;

        Widget topicCard() => FollowingTopicCard(
          topic: topic,
          config: realbooru.auth,
          refreshing: false,
          onOpen: () {},
          onAction: (_) {},
        );
        final showTopic = ValueNotifier(false);
        addTearDown(showTopic.dispose);
        await harness.pump(
          tester,
          Column(
            children: [
              const Expanded(child: FollowingTopicsPage()),
              ValueListenableBuilder(
                valueListenable: showTopic,
                builder: (_, visible, _) =>
                    visible ? topicCard() : const SizedBox.shrink(),
              ),
            ],
          ),
        );

        final folderThumbnails = folderImages(folderId);
        final visibleTopics = topics.take(4);
        final thumbnails = tester.widgetList<BooruImage>(folderThumbnails);
        expect(thumbnails.map((image) => image.imageUrl), [
          for (final member in visibleTopics) urlsFor(member.query).first,
        ]);
        for (final image in thumbnails) {
          expect(image.config, realbooru.auth);
          final size = tester.getSize(find.byWidget(image));
          expect(size.width, size.height);
        }
        expect(requests.map((key) => (key.config, key.query)), [
          for (final member in visibleTopics) (realbooru, member.query),
        ]);

        showTopic.value = true;
        await settle(tester);
        final topicImages = find.descendant(
          of: find.byType(FollowingTopicCard),
          matching: find.byType(BooruImage),
        );
        expect(
          tester.widgetList<BooruImage>(topicImages).map((i) => i.imageUrl),
          urlsFor(topic.query),
        );
        expect(folderThumbnails, findsNWidgets(visibleTopics.length));
        expect(requests, hasLength(visibleTopics.length));
        expect(harness.requests, isEmpty);
        expect(harness.box.mutationCount, mutations);
        expect(await tester.runAsync(harness.repository.getAll), before);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'nested folder previews backfill empty and failed slots without starting more searches',
    (tester) async {
      final pending = Completer<void>();
      final queries = <String>[];
      FollowingTopic transient(String id) => topicFixture(
        id: id,
        query: id,
        error: SearchRefreshErrorKind.unsupported,
        checked: false,
      );
      harness.dispose();
      harness = FollowingTopicHarness(
        loadImages: true,
        overrides: [
          deterministicImageDioOverride(),
          loggerProvider.overrideWithValue(AppLogger()),
          originAwarePostRepoProvider.overrideWith(
            (_, config) => TestSearchPostRepository((query, page, limit) async {
              expect(config, testProfile);
              expect((page, limit), (1, 4));
              queries.add(query);
              if (query == 'pending') await pending.future;
              if (query == 'failed') throw StateError('Preview request failed');
              final posts = switch (query) {
                'pending' => [_previewPost(''), testSearchPost(1, null)],
                'ready order:score' => [
                  testSearchPost(2, null),
                  testSearchPost(3, null),
                ],
                _ => <Post>[],
              };
              return Either.of(PostResult(posts: posts, total: posts.length));
            }),
          ),
        ],
      );
      final folderId = await seedPreviewFolder(
        tester,
        [transient('pending')],
        nested: [
          transient('empty'),
          transient('failed'),
          topicFixture(id: 'ready', query: 'ready order:score', checked: false),
          for (var i = 0; i < 40; i++) transient('later-$i'),
          for (final id in ['cached-first', 'cached-second', 'cached-excluded'])
            cachedFixture(id: id, postCreatedAts: [checkedAt, checkedAt]),
        ],
      );
      final before = await tester.runAsync(harness.repository.getAll);
      final mutations = harness.box.mutationCount;
      final images = folderImages(folderId);
      Iterable<String> urls() =>
          tester.widgetList<BooruImage>(images).map((image) => image.imageUrl);
      const storedUrls = [
        'https://images.example/cached-first-0.jpg',
        'https://images.example/cached-second-0.jpg',
      ];

      await harness.pump(tester, const FollowingTopicsPage());
      const expectedQueries = [
        'pending',
        'empty',
        'failed',
        'ready order:score',
      ];
      expect(queries, expectedQueries);
      expect(urls(), ['https://example.com/2-thumb.jpg', ...storedUrls]);
      final readyImage = images.first;
      final width = tester.getSize(readyImage).width;
      final slot = find
          .ancestor(of: readyImage, matching: find.byType(AspectRatio))
          .first;
      final row = find.ancestor(of: slot, matching: find.byType(Row)).first;
      const padding = followingTopicCardThumbnailPadding;
      expect(tester.widget<Row>(row).children, hasLength(4));
      expect(
        tester.getTopLeft(slot).dx - tester.getTopLeft(row).dx,
        closeTo(width + padding.horizontal + padding.left, 0.01),
      );

      pending.complete();
      await settle(tester);
      const populated = [
        'https://example.com/1-thumb.jpg',
        'https://example.com/2-thumb.jpg',
        ...storedUrls,
      ];
      expect(urls(), populated);
      for (final image in tester.widgetList<BooruImage>(images)) {
        expect(tester.getSize(find.byWidget(image)), Size.square(width));
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await harness.pump(tester, const FollowingTopicsPage());
      expect(urls(), populated);
      expect(queries, expectedQueries);
      expect(harness.requests, isEmpty);
      expect(harness.box.mutationCount, mutations);
      expect(await tester.runAsync(harness.repository.getAll), before);
      await tester.pumpWidget(const SizedBox());
      harness.dispose();
    },
  );

  testWidgets(
    'folder previews stop with inactive routes, disabled media, and removed or changed profiles',
    (tester) async {
      final mediaEnabled = StateProvider((_) => false);
      final active = ValueNotifier(false);
      addTearDown(active.dispose);
      final firstResult = Completer<void>();
      final requests = <(BooruConfig, ApiRequestContext)>[];
      final newProfile = testProfile.copyWith(apiKey: 'test-profile-update');
      harness.dispose();
      harness = FollowingTopicHarness(
        supported: false,
        overrides: [
          deterministicImageDioOverride(),
          automaticMediaLoadingEnabledProvider.overrideWith(
            (ref) => ref.watch(mediaEnabled),
          ),
          booruConfigProvider.overrideWith(_PreviewProfiles.new),
          originAwarePostRepoProvider.overrideWith(
            (_, config) => TestSearchPostRepository((_, _, _) async {
              requests.add((config, ApiRequestContext.current()));
              if (requests.length == 1) await firstResult.future;
              final id = config == newProfile ? 2 : 1;
              return Either.of(
                PostResult(posts: [testSearchPost(id, null)], total: 1),
              );
            }),
          ),
        ],
      );
      final folderId = await seedPreviewFolder(tester, [
        topicFixture(query: 'cat'),
      ]);
      final page = ValueListenableBuilder(
        valueListenable: active,
        builder: (_, isActive, child) =>
            NavigationActivity(active: isActive, child: child!),
        child: const FollowingTopicsPage(),
      );
      final images = folderImages(folderId);
      await harness.pump(tester, page);
      active.value = true;
      await settle(tester);
      expect(requests, isEmpty);
      expect(images, findsNothing);

      active.value = false;
      harness.container.read(mediaEnabled.notifier).state = true;
      await settle(tester);
      expect(requests, isEmpty);
      active.value = true;
      await settle(tester);
      expect(requests.single.$1, testProfile);

      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.push<void>(
        MaterialPageRoute(
          builder: (_) => const Scaffold(body: Text('Outside Following')),
        ),
      );
      await tester.pumpAndSettle();
      expect(requests.single.$2.cancelToken!.isCancelled, isTrue);
      firstResult.complete();
      await settle(tester);
      expect(find.byType(BooruImage, skipOffstage: false), findsNothing);

      navigator.pop();
      await tester.pumpAndSettle();
      expect(requests, hasLength(2));
      expect(
        tester.widget<BooruImage>(images).imageUrl,
        'https://example.com/1-thumb.jpg',
      );
      final profiles = harness.container.read(
        booruConfigProvider.notifier,
      ) as _PreviewProfiles;
      profiles.replace([newProfile, otherTestProfile]);
      await settle(tester);
      expect(requests.last.$1, newProfile);
      expect(tester.widget<BooruImage>(images).config, newProfile.auth);
      expect(
        tester.widget<BooruImage>(images).imageUrl,
        'https://example.com/2-thumb.jpg',
      );

      profiles.replace([otherTestProfile]);
      await settle(tester);
      expect(folderCard(folderId), findsOneWidget);
      expect(images, findsNothing);
      expect(requests, hasLength(3));
      await tester.pumpWidget(const SizedBox());
      harness.dispose();
    },
  );

  testWidgets(
    'public folder previews enforce the current media allowlist and blacklist',
    (tester) async {
      final requests = <BooruConfig>[];
      final topic = FollowingTopic(
        id: 'public-cats',
        profileId: testProfile.id,
        localSource: FollowingTopicSource(
          booruType: 'gelbooruV2',
          url: 'https://safebooru.org',
        ),
        query: 'cat',
        position: 0,
        createdAt: checkedAt,
        previews: topicFixture(previewCount: 1).previews,
        recentPostIdentities: const [],
        unreadCount: 0,
      );
      const permitted = 'https://wimg.safebooru.org/images/1.jpg';
      harness.dispose();
      harness = FollowingTopicHarness(
        profiles: [],
        loadImages: true,
        overrides: [
          deterministicImageDioOverride(),
          globalBlacklistedTagsProvider.overrideWith(_PreviewBlacklist.new),
          contentEffectivePolicyProvider.overrideWith(
            (_, _) => const AsyncData('safe'),
          ),
          originAwarePostRepoProvider.overrideWith(
            (_, config) => TestSearchPostRepository((_, _, _) async {
              requests.add(config);
              return Either.of(
                PostResult(
                  posts: [
                    _previewPost(
                      'https://unlisted.example/1.jpg',
                      public: true,
                    ),
                    _previewPost(permitted, public: true),
                  ],
                  total: 2,
                ),
              );
            }),
          ),
        ],
      );
      final folderId = await seedPreviewFolder(tester, [topic]);
      final images = folderImages(folderId);
      await harness.pump(tester, const FollowingTopicsPage());
      final scope = requests.single.anonymousReadScope!;
      expect(scope.isCurrent, isTrue);
      expect(requests.single.auth.apiKey, isNull);
      expect(tester.widget<BooruImage>(images).imageUrl, permitted);
      expect(tester.widget<BooruImage>(images).config, requests.single.auth);

      (harness.container.read(
        globalBlacklistedTagsProvider.notifier,
      ) as _PreviewBlacklist).blockGeneral();
      await settle(tester);
      expect(folderCard(folderId), findsOneWidget);
      expect(scope.isCurrent, isFalse);
      expect(requests, hasLength(2));
      expect(images, findsNothing);
      await tester.pumpWidget(const SizedBox());
      harness.dispose();
    },
  );

  testWidgets(
    'folder previews use one cached image from the first four populated members in order',
    (tester) async {
      harness.dispose();
      var previewSearches = 0;
      harness = FollowingTopicHarness(
        loadImages: true,
        overrides: [
          deterministicImageDioOverride(),
          untrackedTopicPreviewProvider.overrideWith((_, _) {
            previewSearches++;
            return const <String>[];
          }),
        ],
      );
      FollowingTopic fixture({
        required String id,
        required String profileId,
        required List<String> thumbnails,
        String? query,
      }) => FollowingTopic(
        id: id,
        profileId: profileId,
        query: query ?? id,
        name: id.toUpperCase(),
        position: 0,
        createdAt: checkedAt,
        previews: [
          for (final (index, thumbnail) in thumbnails.indexed)
            SearchPostPreview(
              postId: index,
              postCreatedAt: checkedAt,
              thumbnailUrl: thumbnail,
              sampleUrl: null,
              discoveredAt: checkedAt,
            ),
        ],
        recentPostIdentities: const [],
        unreadCount: 0,
        lastSuccessfulCheckAt: checkedAt,
      );

      final items = [
        fixture(
          id: 'first',
          profileId: '00000000-0000-4000-8000-00000000000c',
          thumbnails: ['https://images.example/first.jpg'],
          query: 'first order:score',
        ),
        fixture(
          id: 'empty',
          profileId: '00000000-0000-4000-8000-00000000000c',
          thumbnails: [],
        ),
        fixture(
          id: 'second',
          profileId: '00000000-0000-4000-8000-000000000063',
          thumbnails: ['https://images.example/second.jpg'],
        ),
        fixture(
          id: 'third',
          profileId: '00000000-0000-4000-8000-00000000000c',
          thumbnails: [
            'https://images.example/third.jpg',
            'https://images.example/third-extra.jpg',
          ],
        ),
        fixture(
          id: 'fourth',
          profileId: '00000000-0000-4000-8000-000000000063',
          thumbnails: ['https://images.example/fourth.jpg'],
        ),
        fixture(
          id: 'excluded',
          profileId: '00000000-0000-4000-8000-00000000000c',
          thumbnails: ['https://images.example/excluded.jpg'],
        ),
      ];
      await tester.runAsync(() async {
        await harness.seed(items);
        await harness.container.read(followingTopicsProvider.future);
        final notifier = harness.container.read(
          followingTopicsProvider.notifier,
        );
        final folder = await notifier.createSharedFolder('Animals');
        for (final item in items) {
          await notifier.moveTopicToSharedFolder(item.id, folder.id);
        }
      });

      await harness.pump(tester, const FollowingTopicsPage());

      final images = tester
          .widgetList<BooruImage>(find.byType(BooruImage))
          .toList();
      expect(images.map((image) => image.imageUrl), [
        'https://images.example/first.jpg',
        'https://images.example/second.jpg',
        'https://images.example/third.jpg',
        'https://images.example/fourth.jpg',
      ]);
      expect(images.map((image) => image.config), [
        testProfile.auth,
        otherTestProfile.auth,
        testProfile.auth,
        otherTestProfile.auth,
      ]);
      for (final image in images) {
        final size = tester.getSize(find.byWidget(image));
        expect(size.width, size.height);
      }
      expect(previewSearches, 0);
      expect(harness.requests, isEmpty);
    },
  );

  testWidgets('folder icon is immediately before the folder name', (
    tester,
  ) async {
    late String folderId;
    await tester.runAsync(() async {
      await harness.container.read(followingTopicsProvider.future);
      folderId =
          (await harness.container
                  .read(followingTopicsProvider.notifier)
                  .createSharedFolder('Animals'))
              .id;
    });

    await harness.pump(tester, const FollowingTopicsPage());

    final card = folderCard(folderId);
    final icon = find.descendant(
      of: card,
      matching: find.byIcon(Symbols.folder),
    );
    final name = find.descendant(of: card, matching: find.text('Animals'));
    expect(icon, findsOneWidget);
    expect(name, findsOneWidget);
    expect(tester.getRect(icon).right, lessThan(tester.getRect(name).left));
    expect(
      tester.getRect(name).left - tester.getRect(icon).right,
      lessThanOrEqualTo(6),
    );
  });

  testWidgets(
    'folder shows the newest cached member post regardless of member and preview order without fetching',
    (tester) async {
      await withClock(Clock.fixed(DateTime.utc(2026, 9, 14, 12)), () async {
        final items = [
          cachedFixture(
            id: 'older',
            postCreatedAts: [
              DateTime.utc(2026, 9, 14, 5),
              DateTime.utc(2026, 9, 14, 9),
            ],
          ),
          cachedFixture(id: 'unknown', postCreatedAts: [null]),
          cachedFixture(
            id: 'newest',
            postCreatedAts: [DateTime.utc(2026, 9, 14, 10)],
          ),
        ];
        await tester.runAsync(() async {
          await harness.seed(items);
          await harness.container.read(followingTopicsProvider.future);
          final notifier = harness.container.read(
            followingTopicsProvider.notifier,
          );
          final folder = await notifier.createSharedFolder('Animals');
          for (final item in items) {
            await notifier.moveTopicToSharedFolder(item.id, folder.id);
          }
        });

        await harness.pump(tester, const FollowingTopicsPage());

        expect(find.text('Last Post: 2 hours ago'), findsOneWidget);
        expect(harness.requests, isEmpty);
      });
    },
  );

  for (final c in [
    (
      name: 'an empty folder',
      hasMember: false,
      label: 'Last Post: Not checked',
    ),
    (
      name: 'a cached post without an upload time',
      hasMember: true,
      label: 'Last Post: No posts',
    ),
  ]) {
    testWidgets('${c.name} uses the matching search card Last post state', (
      tester,
    ) async {
      late String folderId;
      await tester.runAsync(() async {
        if (c.hasMember) {
          await harness.seed([
            cachedFixture(id: 'unknown', postCreatedAts: [null]),
          ]);
        }
        await harness.container.read(followingTopicsProvider.future);
        final notifier = harness.container.read(
          followingTopicsProvider.notifier,
        );
        final folder = await notifier.createSharedFolder('Animals');
        folderId = folder.id;
        if (c.hasMember) {
          await notifier.moveTopicToSharedFolder('unknown', folder.id);
        }
      });

      await harness.pump(tester, const FollowingTopicsPage());

      expect(
        find.descendant(
          of: folderCard(folderId),
          matching: find.text(c.label),
        ),
        findsOneWidget,
      );
      expect(harness.requests, isEmpty);
    });
  }

  for (final c in [
    (name: 'normal text', width: 800.0, textScale: 1.0),
    (name: 'a narrow screen with large text', width: 320.0, textScale: 2.0),
  ]) {
    testWidgets(
      'folder and search cards keep compact padding, thumbnails, and accessible actions with ${c.name}',
      (tester) async {
        await tester.binding.setSurfaceSize(Size(c.width, 700));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        late String folderId;
        await tester.runAsync(() async {
          await harness.seed([
            topicFixture(
              id: 'folder-topic',
              name: 'Folder topic',
              previewCount: 1,
            ),
            topicFixture(
              id: 'home',
              name: 'Home topic',
              query: 'Home topic',
              previewCount: 1,
            ),
          ]);
          await harness.container.read(followingTopicsProvider.future);
          final notifier = harness.container.read(
            followingTopicsProvider.notifier,
          );
          final folder = await notifier.createSharedFolder('Animals');
          folderId = folder.id;
          await notifier.moveTopicToSharedFolder('folder-topic', folder.id);
        });

        await harness.pump(
          tester,
          MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(c.textScale)),
            child: const FollowingTopicsPage(),
          ),
        );

        final folder = folderCard(folderId);
        final search = find.byType(FollowingTopicCard);
        final folderIcon = find.descendant(
          of: folder,
          matching: find.byIcon(Symbols.folder),
        );
        final searchTitle = find.descendant(
          of: search,
          matching: find.text('Home topic'),
        );
        final folderImage = find.descendant(
          of: folder,
          matching: find.byType(BooruImage),
        );
        final searchImage = find.descendant(
          of: search,
          matching: find.byType(BooruImage),
        );
        final folderMenu = find.descendant(
          of: folder,
          matching: followingCardMenus(),
        );
        final searchMenu = find.descendant(
          of: search,
          matching: followingCardMenus(),
        );
        final folderItemCount = find.descendant(
          of: folder,
          matching: find.text('1 items'),
        );
        final searchOwner = find.descendant(
          of: search,
          matching: find.text('https://active.example'),
        );
        final folderName = find.descendant(
          of: folder,
          matching: find.text('Animals'),
        );
        final folderBadge = find.descendant(
          of: folder,
          matching: find.text('1+'),
        );
        final searchBadge = find.descendant(
          of: search,
          matching: find.text('NEW'),
        );
        final folderHeaderRects = [
          folderName,
          folderBadge,
          folderMenu,
        ].map(tester.getRect).toList();
        final searchHeaderRects = [
          searchTitle,
          searchBadge,
          searchMenu,
        ].map(tester.getRect).toList();
        final folderHeaderTop = folderHeaderRects
            .map((rect) => rect.top)
            .reduce((left, right) => left < right ? left : right);
        final folderHeaderBottom = folderHeaderRects
            .map((rect) => rect.bottom)
            .reduce((left, right) => left > right ? left : right);
        final searchHeaderTop = searchHeaderRects
            .map((rect) => rect.top)
            .reduce((left, right) => left < right ? left : right);
        final searchHeaderBottom = searchHeaderRects
            .map((rect) => rect.bottom)
            .reduce((left, right) => left > right ? left : right);

        expect(folder, findsOneWidget);
        expect(search, findsOneWidget);
        expect(folderImage, findsOneWidget);
        expect(searchImage, findsOneWidget);
        expect(
          tester.getRect(folderIcon).left - tester.getRect(folder).left,
          closeTo(12, 1),
        );
        expect(
          tester.getRect(searchTitle).left - tester.getRect(search).left,
          closeTo(12, 1),
        );
        expect(
          tester.getRect(folderImage).left - tester.getRect(folder).left,
          closeTo(13, 1),
        );
        expect(
          tester.getRect(searchImage).left - tester.getRect(search).left,
          closeTo(13, 1),
        );
        expect(
          folderHeaderTop - tester.getRect(folder).top,
          closeTo(8, 1),
        );
        expect(
          searchHeaderTop - tester.getRect(search).top,
          closeTo(8, 1),
        );
        expect(
          tester.getRect(folderImage).top - folderHeaderBottom,
          closeTo(4, 1),
        );
        expect(
          tester.getRect(searchImage).top - searchHeaderBottom,
          closeTo(4, 1),
        );
        expect(
          tester.getRect(folder).bottom -
              tester.getRect(folderItemCount).bottom,
          closeTo(12, 1),
        );
        expect(
          tester.getRect(search).bottom - tester.getRect(searchOwner).bottom,
          closeTo(12, 1),
        );
        for (final menu in [folderMenu, searchMenu]) {
          expect(tester.getSize(menu).width, greaterThanOrEqualTo(48));
          expect(tester.getSize(menu).height, greaterThanOrEqualTo(48));
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('empty folders disable refresh on the card and opened page', (
    tester,
  ) async {
    late String folderId;
    await tester.runAsync(() async {
      await harness.container.read(followingTopicsProvider.future);
      folderId =
          (await harness.container
                  .read(followingTopicsProvider.notifier)
                  .createSharedFolder('Empty'))
              .id;
    });

    await harness.pump(tester, const FollowingTopicsPage());
    await openFolderMenu(tester, folderId);
    expect(actionItem(tester, 'Refresh').onTap != null, isFalse);
    await dismissMenu(tester);

    await harness.pump(tester, FollowingTopicsPage(folderId: folderId));
    await tester.tap(pageOverflow());
    await settle(tester);
    expect(actionItem(tester, 'Refresh').onTap != null, isFalse);
  });

  testWidgets(
    'unsupported-only folders disable refresh and cannot dispatch from either menu',
    (tester) async {
      harness.dispose();
      harness = FollowingTopicHarness(supported: false);
      late String folderId;
      await tester.runAsync(() async {
        await harness.seed([topicFixture(query: 'cat')]);
        await harness.container.read(followingTopicsProvider.future);
        final notifier = harness.container.read(
          followingTopicsProvider.notifier,
        );
        folderId = (await notifier.createSharedFolder('Animals')).id;
        await notifier.moveTopicToSharedFolder('cats', folderId);
      });

      await harness.pump(tester, const FollowingTopicsPage());
      await openFolderMenu(tester, folderId);
      expect(actionItem(tester, 'Refresh').onTap != null, isFalse);
      await tester.tap(find.text('Refresh').last);
      await settle(tester);
      expect(harness.requests, isEmpty);
      await dismissMenu(tester);

      await harness.pump(tester, FollowingTopicsPage(folderId: folderId));
      await tester.tap(pageOverflow());
      await settle(tester);
      expect(actionItem(tester, 'Refresh').onTap != null, isFalse);
      await tester.tap(find.text('Refresh'));
      await settle(tester);
      expect(harness.requests, isEmpty);
    },
  );

  testWidgets(
    'an active folder refresh disables refresh on the card and opened page',
    (tester) async {
      harness.refreshGate = Completer<void>();
      late String folderId;
      await tester.runAsync(() async {
        await harness.seed([
          topicFixture(query: 'cat'),
          topicFixture(id: 'dogs', query: 'dog'),
        ]);
        await harness.container.read(followingTopicsProvider.future);
        final notifier = harness.container.read(
          followingTopicsProvider.notifier,
        );
        folderId = (await notifier.createSharedFolder('Animals')).id;
        await notifier.moveTopicToSharedFolder('cats', folderId);
        await notifier.moveTopicToSharedFolder('dogs', folderId);
      });

      await harness.pump(tester, const FollowingTopicsPage());
      await openFolderMenu(tester, folderId);
      await tester.tap(find.text('Refresh').last);
      await settle(tester);
      for (var i = 0; i < 20 && harness.requests.isEmpty; i++) {
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
      }
      expect(harness.requests, [
        (profileId: '00000000-0000-4000-8000-00000000000c', query: 'cat'),
      ]);
      await tester.pump();
      expect(find.text('Refreshing… 2 left'), findsOneWidget);

      await openFolderMenu(tester, folderId);
      expect(actionItem(tester, 'Refresh').onTap != null, isFalse);
      await dismissMenu(tester);

      await harness.pump(tester, FollowingTopicsPage(folderId: folderId));
      await tester.tap(pageOverflow());
      await settle(tester);
      expect(actionItem(tester, 'Refresh').onTap != null, isFalse);
      expect(find.text('Topic updates'), findsNothing);
      await dismissMenu(tester);

      harness.refreshGate!.complete();
      await settle(tester);
      await drain(tester);
    },
  );

  for (final locale in ['en-US', 'de-DE']) {
    testWidgets(
      'remaining folder work wraps on a narrow screen in $locale without fetching',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(280, 700));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        addTearDown(() => ensureI18nInitialized('en-US'));
        late SearchRefreshProgress progress;
        await tester.runAsync(() async {
          await ensureI18nInitialized(locale);
          await harness.seed([topicFixture(), topicFixture(id: 'dogs')]);
          await harness.container.read(followingTopicsProvider.future);
          final notifier = harness.container.read(
            followingTopicsProvider.notifier,
          );
          final folder = await notifier.createSharedFolder(
            'A long folder title',
          );
          await notifier.moveTopicToSharedFolder('cats', folder.id);
          await notifier.moveTopicToSharedFolder('dogs', folder.id);
          progress = notifier.beginRefreshProgress(['cats', 'dogs']);
        });
        addTearDown(progress.close);
        await tester.pumpWidget(
          harness.wrap(
            const MaterialApp(
              builder: themeBuilder,
              home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(2)),
                child: FollowingTopicsPage(),
              ),
            ),
          ),
        );
        await settle(tester);
        expect(
          find.text(
            locale == 'de-DE'
                ? 'Aktualisieren… 2 verbleibend'
                : 'Refreshing… 2 left',
          ),
          findsOneWidget,
        );
        expect(harness.requests, isEmpty);
        expect(tester.takeException(), isNull);
        progress.settle('cats');
        await tester.pump();
        expect(
          find.text(
            locale == 'de-DE'
                ? 'Aktualisieren… 1 verbleibend'
                : 'Refreshing… 1 left',
          ),
          findsOneWidget,
        );
        progress.close();
        await tester.pump();
        expect(
          find.textContaining(locale == 'de-DE' ? 'verbleibend' : 'left'),
          findsNothing,
        );
      },
    );
  }

  testWidgets('a missing folder returns the opened page to Home', (
    tester,
  ) async {
    await harness.pump(
      tester,
      const FollowingTopicsPage(folderId: 'missing-folder'),
    );

    await tester.tap(pageOverflow());
    await settle(tester);
    expect(actionItem(tester, 'Refresh All').onTap != null, isFalse);
    expect(find.text('Refresh'), findsNothing);
  });

  testWidgets('folder cards remain usable on a narrow screen with large text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    late String folderId;
    await tester.runAsync(() async {
      await harness.seed([topicFixture()]);
      await harness.container.read(followingTopicsProvider.future);
      final notifier = harness.container.read(
        followingTopicsProvider.notifier,
      );
      final folder = await notifier.createSharedFolder(
        'A long folder name that needs more than one line',
      );
      folderId = folder.id;
      await notifier.moveTopicToSharedFolder('cats', folder.id);
    });

    await harness.pump(
      tester,
      const MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(2)),
        child: FollowingTopicsPage(),
      ),
    );

    expect(folderCard(folderId), findsOneWidget);
    expect(
      find.descendant(
        of: folderCard(folderId),
        matching: find.bySemanticsLabel(RegExp(r'^(More|Mehr)$')),
      ),
      findsOneWidget,
    );
    expect(find.text('1 items'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('refreshing a shared folder uses each topic owner', () async {
    final cats = topicFixture(query: 'cat');
    final dogs = topicFixture(
      id: 'dogs',
      profileId: '00000000-0000-4000-8000-000000000063',
      query: 'dog',
    );
    await harness.seed([cats, dogs]);
    final notifier = harness.container.read(
      followingTopicsProvider.notifier,
    );
    await harness.container.read(followingTopicsProvider.future);
    final folder = await notifier.createSharedFolder('Animals');
    await notifier.moveTopicToSharedFolder(cats.id, folder.id);
    await notifier.moveTopicToSharedFolder(dogs.id, folder.id);

    await notifier.refreshSharedFolder(folder.id);

    expect(harness.requests, [
      (profileId: '00000000-0000-4000-8000-00000000000c', query: 'cat'),
      (profileId: '00000000-0000-4000-8000-000000000063', query: 'dog'),
    ]);
  });

  testWidgets(
    'opening a folder navigates to its own manually ordered search page',
    (tester) async {
      await tester.runAsync(() async {
        final cats = topicFixture(query: 'cat');
        await harness.seed([cats]);
        final notifier = harness.container.read(
          followingTopicsProvider.notifier,
        );
        await harness.container.read(followingTopicsProvider.future);
        final folder = await notifier.createSharedFolder('Animals');
        await notifier.moveTopicToSharedFolder(cats.id, folder.id);
      });
      await harness.pump(tester, const FollowingTopicsPage());
      expect(find.text('Cats'), findsNothing);
      expect(find.text('Animals'), findsOneWidget);
      await tester.tap(find.text('Animals'));
      await settle(tester);
      expect(find.text('Cats'), findsOneWidget);
      expect(find.byType(ReorderableListView), findsNothing);
      expect(harness.requests, isEmpty);
    },
  );
}

Post _previewPost(String url, {bool public = false}) {
  final post = testSearchPost(1, null);
  return post.copyWith(
    origin: public
        ? PostOrigin.fromSource(
            booruType: BooruType.gelbooruV2,
            booruId: BooruType.gelbooruV2.id,
            source: 'https://safebooru.org',
          )
        : null,
    core: PostCoreData.fromPost(post, thumbnailImageUrl: url),
  );
}

class _PreviewProfiles extends BooruConfigNotifier {
  _PreviewProfiles() : super(initialConfigs: [testProfile, otherTestProfile]);

  void replace(List<BooruConfig> profiles) => state = profiles;
}

class _PreviewBlacklist extends GlobalBlacklistedTagsNotifier {
  @override
  IList<BlacklistedTag> build() => <BlacklistedTag>[].lock;

  void blockGeneral() => state = AsyncData(
    [
      BlacklistedTag(
        id: 1,
        name: 'rating:general',
        isActive: true,
        createdDate: checkedAt,
        updatedDate: checkedAt,
      ),
    ].lock,
  );
}
