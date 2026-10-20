import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:boorusama/core/widgets/multi_selection_action_bar.dart';
import 'package:boorusama/core/widgets/multi_select_button.dart';
import 'package:flutter/gestures.dart';

import 'dart:async';

import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/images/booru_image.dart';
import 'package:boorusama/core/router.dart';
import 'package:boorusama/core/search/search/src/routes/params.dart';
import 'package:boorusama/core/search/following_topics/providers.dart';
import 'package:boorusama/core/search/following_topics/routes.dart';
import 'package:boorusama/core/search/following_topics/src/pages/following_topics_page.dart';
import 'package:boorusama/core/search/following_topics/src/widgets/following_topic_card.dart';
import 'package:boorusama/core/search/following_topics/src/widgets/following_topic_folder_card.dart';
import 'package:boorusama/core/search/following_topics/types.dart';
import 'package:clock/clock.dart';
import 'package:flutter/material.dart' as legacy;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'following_topic_test_utils.dart';

void main() {
  late FollowingTopicHarness harness;
  Uri? openedUri;

  void initialize({Completer<void>? ready, bool loadImages = false}) {
    harness = FollowingTopicHarness(
      repositoryReady: ready,
      loadImages: loadImages,
    );
    addTearDown(harness.dispose);
    openedUri = null;
  }

  Future<void> pump(WidgetTester tester) =>
      harness.pump(tester, const FollowingTopicsPage());

  testWidgets(
    'selection refresh matches both supported and mixed folder menus',
    (tester) async {
      harness = FollowingTopicHarness(
        trackingSupported: (auth) => auth.url == testProfile.url,
      );
      addTearDown(harness.dispose);
      await harness.seed([
        topicFixture(query: 'cat'),
        topicFixture(id: 'dogs', name: 'Dogs', query: 'dog'),
        topicFixture(
          id: 'manual',
          name: 'Manual',
          query: 'manual',
          profileId: otherTestProfile.id,
        ),
      ]);
      final notifier = harness.container.read(followingTopicsProvider.notifier);
      final first = await notifier.createSharedFolder(
        'Supported',
        feedEnabled: true,
      );
      final mixed = await notifier.createSharedFolder(
        'Mixed',
        feedEnabled: true,
      );
      final child = await notifier.createSharedFolder(
        'Nested',
        parentId: mixed.id,
      );
      await notifier.moveTopicToSharedFolder('cats', first.id);
      await notifier.moveTopicToSharedFolder('dogs', child.id);
      await notifier.moveTopicToSharedFolder('manual', mixed.id);
      await pump(tester);
      for (final card in tester.widgetList<FollowingTopicFolderCard>(
        find.byType(FollowingTopicFolderCard),
      )) {
        expect(card.canRefresh, isTrue);
      }
      await tester.longPress(find.text('Supported'));
      await settle(tester);
      expect(
        find.widgetWithText(MultiSelectButton, 'Refresh').hitTestable(),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Close'));
      await settle(tester);
      await tester.longPress(find.text('Mixed'));
      await settle(tester);
      expect(
        find.widgetWithText(MultiSelectButton, 'Refresh').hitTestable(),
        findsOneWidget,
      );
      for (final label in ['Open feed', 'Settings', 'Edit', 'Details']) {
        expect(find.widgetWithText(MultiSelectButton, label), findsNothing);
      }
      await tester.tap(find.text('Supported'));
      await settle(tester);
      expect(find.text('2 items selected'), findsOneWidget);
      await tester.tap(find.widgetWithText(MultiSelectButton, 'Refresh'));
      await drain(tester);
      expect(
        harness.requests.map((request) => request.query),
        containsAll(['cat', 'dog']),
      );
      expect(
        harness.requests.any((request) => request.query == 'manual'),
        isFalse,
      );
      expect(find.text('2 items selected'), findsOneWidget);
    },
  );

  testWidgets(
    'Mark read closes selection after success and retains it after failure',
    (tester) async {
      initialize();
      await harness.seed([topicFixture()]);
      await pump(tester);
      await tester.longPress(find.text('Cats'));
      await settle(tester);
      for (final label in ['Edit', 'Details', 'Settings', 'Open feed']) {
        expect(find.widgetWithText(MultiSelectButton, label), findsNothing);
      }
      harness.box.failWrites = true;
      await tester.tap(find.widgetWithText(MultiSelectButton, 'Mark read'));
      await drain(tester);
      expect(find.text('1 item selected'), findsOneWidget);
      expect((await harness.repository.getById('cats'))!.hasNewPosts, isTrue);
      harness.box.failWrites = false;
      await tester.tap(find.widgetWithText(MultiSelectButton, 'Mark read'));
      await drain(tester);
      expect((await harness.repository.getById('cats'))!.hasNewPosts, isFalse);
      expect(find.text('1 item selected'), findsNothing);
      await tester.pump(const Duration(seconds: 5));
    },
  );

  Finder pageOverflow() => find.descendant(
    of: find.byType(AppBar),
    matching: find.byTooltip('More'),
  );

  Future<void> openPageMenu(WidgetTester tester) async {
    await tester.tap(pageOverflow());
    await settle(tester);
  }

  Future<void> choosePageAction(WidgetTester tester, String label) async {
    await openPageMenu(tester);
    await tester.tap(find.text(label));
    await settle(tester);
  }

  PopupMenuItem refreshAllItem(WidgetTester tester) =>
      tester.widget<PopupMenuItem>(
        find.ancestor(
          of: find.text('Refresh All'),
          matching: find.byWidgetPredicate(
            (widget) => widget is PopupMenuItem,
          ),
        ),
      );

  Future<void> openMenu(WidgetTester tester, [String name = 'Cats']) async {
    final card = find.ancestor(
      of: find.text(name),
      matching: find.byType(FollowingTopicCard),
    );
    await tester.tap(
      find.descendant(
        of: card,
        matching: find.byType(PopupMenuButton<FollowingTopicAction>),
      ),
    );
    await settle(tester);
  }

  Future<void> choose(
    WidgetTester tester,
    String label, [
    String name = 'Cats',
  ]) async {
    await openMenu(tester, name);
    await tester.tap(find.text(label));
    await settle(tester);
  }

  Future<void> pumpRouter(WidgetTester tester) async {
    harness.router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const SizedBox.shrink(),
          routes: [followingTopicRoutes],
        ),
        GoRoute(
          path: '/search',
          builder: (_, state) {
            openedUri = state.uri;
            return Scaffold(
              body: Text('Opened ${state.uri.queryParameters['query']}'),
            );
          },
        ),
        GoRoute(
          path: '/settings',
          builder: (_, state) {
            openedUri = state.uri;
            return const Scaffold(body: Text('Settings destination'));
          },
        ),
      ],
      initialLocation: '/following-topics',
    );
    addTearDown(harness.router.dispose);
    await tester.pumpWidget(
      harness.wrap(
        MaterialApp.router(routerConfig: harness.router, builder: themeBuilder),
      ),
    );
    await settle(tester);
  }

  for (final location in ['Home', 'folder']) {
    testWidgets('a topic in $location offers Edit without a separate Rename', (
      tester,
    ) async {
      initialize();
      await harness.seed([topicFixture()]);
      final notifier = harness.container.read(
        followingTopicsProvider.notifier,
      );
      final folder = await notifier.createSharedFolder('Favorites');
      if (location == 'folder') {
        await notifier.moveTopicToSharedFolder('cats', folder.id);
        await harness.pump(tester, FollowingTopicsPage(folderId: folder.id));
      } else {
        await pump(tester);
      }

      await openMenu(tester);
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Rename'), findsNothing);

      if (location == 'Home') {
        await tester.tapAt(const Offset(5, 5));
        await settle(tester);
        final folderCard = find.byKey(
          ValueKey('following-topic-folder-${folder.id}'),
        );
        await tester.tap(
          find.descendant(
            of: folderCard,
            matching: find.byType(PopupMenuButton<FollowingTopicAction>),
          ),
        );
        await settle(tester);
        expect(find.text('Settings'), findsOneWidget);
        expect(find.text('Edit'), findsNothing);
      }
    });
  }

  testWidgets('editing a topic changes its query and profile in its folder', (
    tester,
  ) async {
    initialize();
    await harness.seed([topicFixture()]);
    final notifier = harness.container.read(
      followingTopicsProvider.notifier,
    );
    final folder = await notifier.createSharedFolder('Favorites');
    await notifier.moveTopicToSharedFolder('cats', folder.id);
    await harness.pump(tester, FollowingTopicsPage(folderId: folder.id));

    await choose(tester, 'Edit');
    await tester.enterText(
      find.widgetWithText(TextField, 'Name (optional)'),
      'Dogs',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Exact query'),
      'dog',
    );
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await settle(tester);
    await tester.tap(find.text('https://other.example').last);
    await settle(tester);
    await tester.tap(find.text('Save'));
    await settle(tester);
    await drain(tester);

    final edited = (await harness.repository.getById('cats'))!;
    expect(edited.name, 'Dogs');
    expect(edited.query, 'dog');
    expect(edited.profileId, '00000000-0000-4000-8000-000000000063');
    expect(
      (await harness.repository.getOrganization()).folders.single.searchIds,
      ['cats'],
    );
    expect(
      harness.requests,
      contains((
        profileId: '00000000-0000-4000-8000-000000000063',
        query: 'dog',
      )),
    );
  });

  testWidgets('the editor distinguishes profiles with the same name', (
    tester,
  ) async {
    harness = FollowingTopicHarness(
      profiles: [
        testProfile.copyWith(name: 'Shared'),
        otherTestProfile.copyWith(name: 'Shared'),
      ],
    );
    addTearDown(harness.dispose);
    await harness.seed([topicFixture()]);
    await pump(tester);

    await choose(tester, 'Edit');
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await settle(tester);
    expect(find.text('Shared · https://active.example'), findsWidgets);
    await tester.tap(find.text('Shared · https://other.example').last);
    await settle(tester);
    await tester.tap(find.text('Save'));
    await drain(tester);
    await settle(tester);

    expect(find.text('Edit Topic'), findsNothing);
    expect(
      (await harness.repository.getById('cats'))!.profileId,
      '00000000-0000-4000-8000-000000000063',
    );
    expect(find.text('Shared · https://other.example'), findsOneWidget);
  });

  testWidgets('barrier and Back cannot dismiss an editor during save', (
    tester,
  ) async {
    initialize();
    await harness.seed([topicFixture()]);
    await pump(tester);
    await choose(tester, 'Edit');
    await tester.enterText(
      find.widgetWithText(TextField, 'Exact query'),
      'dog',
    );
    final releaseSave = Completer<void>();
    harness.box.writeGate = releaseSave;
    await tester.tap(find.text('Save'));
    await tester.pump();

    await tester.tapAt(const Offset(5, 5));
    await settle(tester);
    expect(find.text('Edit Topic'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.text('Edit Topic'), findsOneWidget);

    releaseSave.complete();
    await drain(tester);
    await settle(tester);
    expect(find.text('Edit Topic'), findsNothing);
    expect((await harness.repository.getById('cats'))!.query, 'dog');
  });

  testWidgets('a colliding edit stays open and writes nothing', (tester) async {
    initialize();
    await harness.seed([
      topicFixture(),
      topicFixture(
        id: 'dogs',
        name: 'Dogs',
        query: 'dog rating:safe',
        position: 1,
      ),
    ]);
    await pump(tester);

    await choose(tester, 'Edit');
    await tester.enterText(
      find.widgetWithText(TextField, 'Exact query'),
      ' dog  rating:safe ',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Name (optional)'),
      'Changed',
    );
    await tester.tap(find.text('Save'));
    await settle(tester);

    expect(
      find.text(
        'Another topic in this folder already uses this query and profile.',
      ),
      findsOneWidget,
    );
    expect(find.text('Edit Topic'), findsOneWidget);
    expect((await harness.repository.getById('cats'))!.name, 'Cats');
    expect(
      (await harness.repository.getById('cats'))!.query,
      'cat  rating:safe order:score',
    );
    expect(
      (await harness.repository.getById('dogs'))!.query,
      'dog rating:safe',
    );
    expect(harness.requests, isEmpty);
    await tester.tap(find.text('Cancel'));
    await settle(tester);
    expect(find.text('Edit Topic'), findsNothing);
  });

  testWidgets(
    'a failed edit save keeps the editor open and the topic unchanged',
    (
      tester,
    ) async {
      initialize();
      await harness.seed([topicFixture()]);
      await pump(tester);
      await choose(tester, 'Edit');
      await tester.enterText(
        find.widgetWithText(TextField, 'Exact query'),
        'dog',
      );
      harness.box.failWrites = true;
      await tester.tap(find.text('Save'));
      await settle(tester);

      expect(
        find.text('Could not save the topic. Try again.'),
        findsOneWidget,
      );
      expect(find.text('Edit Topic'), findsOneWidget);
      expect(
        (await harness.repository.getById('cats'))!.query,
        'cat  rating:safe order:score',
      );
      expect(harness.requests, isEmpty);
    },
  );

  testWidgets('an unsupported profile warns before an edit is saved', (
    tester,
  ) async {
    harness = FollowingTopicHarness(supported: false);
    addTearDown(harness.dispose);
    await harness.seed([topicFixture()]);
    await pump(tester);
    await choose(tester, 'Edit');
    expect(
      find.text(
        'New-post tracking is unavailable for this profile. The search can still open normally.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await settle(tester);
    expect(
      (await harness.repository.getById('cats'))!.query,
      'cat  rating:safe order:score',
    );
  });

  testWidgets('page overflow contains search operations without settings', (
    tester,
  ) async {
    initialize();
    await pumpRouter(tester);
    await tester.tap(find.byTooltip('More').first);
    await settle(tester);
    expect(find.text('Topic updates'), findsNothing);
    expect(find.text('Refresh All'), findsOneWidget);
  });

  testWidgets('topic filters stay closed until requested and clear on close', (
    tester,
  ) async {
    initialize();
    await harness.seed([
      topicFixture(),
      topicFixture(id: 'dogs', name: 'Dogs', query: 'dog', position: 1),
    ]);
    await pump(tester);

    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.byTooltip('Filter topics'));
    await settle(tester);
    expect(find.byType(TextField), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'dogs');
    await settle(tester);
    expect(find.text('Dogs'), findsOneWidget);
    expect(find.text('Cats'), findsNothing);

    await tester.tap(find.byTooltip('Filter topics'));
    await settle(tester);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Dogs'), findsOneWidget);
    expect(find.text('Cats'), findsOneWidget);
  });

  testWidgets('cancelling empty-folder Follow a topic disposes safely', (
    tester,
  ) async {
    initialize();
    await harness.seed([]);
    await pump(tester);

    await tester.tap(find.text('Follow a topic'));
    await settle(tester);
    expect(find.text('Follow Topic'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await settle(tester);

    expect(find.text('Follow Topic'), findsNothing);
    expect(find.text('Following Topics'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Follow a topic in an open folder saves there without a picker', (
    tester,
  ) async {
    initialize();
    await harness.seed([topicFixture(query: 'cat')]);
    final notifier = harness.container.read(followingTopicsProvider.notifier);
    final folder = await notifier.createSharedFolder('Empty');
    await harness.pump(tester, FollowingTopicsPage(folderId: folder.id));

    await tester.tap(find.text('Follow a topic'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'cat');
    await tester.pump();
    final follow = find.widgetWithText(FilledButton, 'Follow');
    expect(find.widgetWithText(FilledButton, 'Next'), findsNothing);
    expect(tester.widget<FilledButton>(follow).onPressed, isNotNull);
    await tester.ensureVisible(follow);
    await tester.tap(follow);
    await settle(tester);
    await drain(tester);

    expect(find.text('Follow Topic'), findsNothing);
    expect(find.text('Done'), findsNothing);
    final topics = await harness.repository.getAll();
    expect(topics, hasLength(2));
    expect(topics.every((topic) => topic.query == 'cat'), isTrue);
    final organization = await harness.repository.getOrganization();
    expect(organization.homeSearchIds, hasLength(1));
    expect(
      organization.folders
          .singleWhere((item) => item.id == folder.id)
          .searchIds,
      hasLength(1),
    );
  });

  testWidgets(
    'empty nested search folders omit breadcrumb navigation',
    (tester) async {
      initialize();
      await harness.container.read(followingTopicsProvider.future);
      final notifier = harness.container.read(
        followingTopicsProvider.notifier,
      );
      final root = await notifier.createSharedFolder('Root');
      final empty = await notifier.createSharedFolder(
        'Empty',
        parentId: root.id,
      );
      await tester.binding.setSurfaceSize(const Size(320, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await harness.pump(tester, FollowingTopicsPage(folderId: empty.id));
      expect(find.text('Home'), findsNothing);
      expect(find.text('Root'), findsNothing);
      expect(find.text('No topics yet'), findsOneWidget);
      expect(harness.requests, isEmpty);
      expect(tester.takeException(), isNull);
      await notifier.deleteSharedFolderAndTopics(empty.id);
      await drain(tester);
      expect(find.text('Following Topics'), findsOneWidget);
      expect(find.text('Root'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(harness.requests, isEmpty);
    },
  );

  testWidgets('folder badges aggregate updates from nested descendants', (
    tester,
  ) async {
    initialize();
    await harness.seed([
      topicFixture(newPostCountEstimate: 5),
      topicFixture(
        id: 'dogs',
        name: 'Dogs',
        query: 'dog',
        position: 1,
        newPostCountEstimate: 7,
        newPostCountIsLowerBound: true,
      ),
    ]);
    final notifier = harness.container.read(followingTopicsProvider.notifier);
    final parent = await notifier.createSharedFolder('Artists');
    final child = await notifier.createSharedFolder(
      'Nested',
      parentId: parent.id,
    );
    await notifier.moveTopicToSharedFolder('cats', parent.id);
    await notifier.moveTopicToSharedFolder('dogs', child.id);
    await pump(tester);

    final parentCard = find.ancestor(
      of: find.text('Artists'),
      matching: find.byType(FollowingTopicFolderCard),
    );
    expect(
      find.descendant(of: parentCard, matching: find.text('12+')),
      findsOneWidget,
    );
  });
  testWidgets(
    'active folder/topic hold-drag selects and reverses in displayed order',
    (tester) async {
      initialize();
      await harness.seed([
        topicFixture(id: 'a', name: 'Alpha', position: 0),
        topicFixture(id: 'b', name: 'Beta', query: 'dog', position: 1),
        topicFixture(id: 'c', name: 'Gamma', query: 'bird', position: 2),
      ]);
      await harness.container
          .read(followingTopicsProvider.notifier)
          .createSharedFolder('Folder');
      await pump(tester);
      await tester.longPress(find.text('Folder'));
      await settle(tester);
      final drag = await tester.startGesture(
        tester.getCenter(find.text('Alpha')),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 10));
      await drag.moveTo(tester.getCenter(find.text('Gamma')));
      await tester.pump();
      expect(find.text('4 items selected'), findsOneWidget);
      await drag.moveTo(tester.getCenter(find.text('Alpha')));
      await tester.pump();
      expect(find.text('2 items selected'), findsOneWidget);
      await drag.up();
      await settle(tester);
      expect(find.byType(PopupMenuButton<FollowingTopicAction>), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final startWithFolder in [false, true]) {
    testWidgets(
      'long press ${startWithFolder ? 'folder' : 'topic'} selects, deselects, and cancels at narrow width',
      (tester) async {
        initialize();
        await tester.binding.setSurfaceSize(const Size(320, 700));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await harness.seed([topicFixture()]);
        final notifier = harness.container.read(
          followingTopicsProvider.notifier,
        );
        final folder = await notifier.createSharedFolder('Favorites');
        await harness.pump(
          tester,
          const MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(2)),
            child: FollowingTopicsPage(),
          ),
        );
        final start = startWithFolder ? 'Favorites' : 'Cats';
        final other = startWithFolder ? 'Cats' : 'Favorites';
        expect(find.byTooltip('Select'), findsNothing);
        expect(find.byTooltip('Sort by'), findsOneWidget);
        expect(pageOverflow(), findsOneWidget);
        // Per-item action menus remain normal actions, not selection gestures.
        await openMenu(tester);
        expect(find.text('1 item selected'), findsNothing);
        await tester.tapAt(const Offset(5, 5));
        await settle(tester);
        final previewsBeforeSelection = tester
            .widget<FollowingTopicFolderCard>(
              find.byType(FollowingTopicFolderCard),
            )
            .previews;
        await tester.longPress(find.text(start));
        await settle(tester);
        expect(
          identical(
            tester
                .widget<FollowingTopicFolderCard>(
                  find.byType(FollowingTopicFolderCard),
                )
                .previews,
            previewsBeforeSelection,
          ),
          isTrue,
        );
        expect(find.text('1 item selected'), findsOneWidget);
        expect(find.widgetWithText(MultiSelectButton, 'Move'), findsOneWidget);
        expect(find.byTooltip('Close'), findsOneWidget);
        expect(find.byTooltip('Sort by'), findsOneWidget);
        expect(
          pageOverflow(),
          findsOneWidget,
        );
        expect(find.text('Remove'), findsOneWidget);
        expect(find.text('Unfollow'), findsNothing);
        if (!startWithFolder) {
          expect(find.text('Mark read'), findsOneWidget);
        }
        expect(
          find.byType(PopupMenuButton<FollowingTopicAction>),
          findsNothing,
        );
        expect(find.byIcon(Icons.check_circle), findsOneWidget);
        final pinCard = tester.widget<FollowingTopicCard>(
          find.byType(FollowingTopicCard),
        );
        final folderCard = tester.widget<FollowingTopicFolderCard>(
          find.byType(FollowingTopicFolderCard),
        );
        expect(pinCard.selected, !startWithFolder);
        expect(folderCard.selected, startWithFolder);
        await tester.tap(find.text(other));
        await settle(tester);
        expect(find.text('2 items selected'), findsOneWidget);
        expect(pageOverflow(), findsOneWidget);
        expect(find.byIcon(Icons.check_circle), findsNWidgets(2));
        await tester.tap(find.text(start));
        await settle(tester);
        expect(find.text('1 item selected'), findsOneWidget);
        await tester.tap(find.text(other));
        await settle(tester);
        expect(find.text('0 items selected'), findsNothing);
        expect(find.byTooltip('Close'), findsNothing);
        expect(find.text('Following Topics'), findsOneWidget);
        expect(find.widgetWithText(MultiSelectButton, 'Move'), findsNothing);
        expect(find.byTooltip('Sort by'), findsOneWidget);
        expect(pageOverflow(), findsOneWidget);
        // Cancel clears both sets, so a new selection starts with one item.
        await tester.longPress(find.text(start));
        await settle(tester);
        await tester.tap(find.text(other));
        await settle(tester);
        await tester.tap(find.byTooltip('Close'));
        await settle(tester);
        await tester.longPress(find.text(other));
        await settle(tester);
        expect(find.text('1 item selected'), findsOneWidget);
        await tester.tap(find.widgetWithText(MultiSelectButton, 'Move'));
        await settle(tester);
        await tester.tap(find.widgetWithText(legacy.TextButton, 'Cancel'));
        await settle(tester);
        expect(find.text('1 item selected'), findsOneWidget);
        await tester.tap(find.byTooltip('Close'));
        await settle(tester);
        // Normal folder navigation is restored.
        await tester.tap(find.text('Favorites'));
        await settle(tester);
        expect(find.text('Home'), findsNothing);
        expect(find.text('Favorites'), findsOneWidget);
        expect(
          (await harness.repository.getOrganization()).folders.single.id,
          folder.id,
        );
        expect(harness.requests, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'multi-selection taps select folder and topic cards before one Move',
    (tester) async {
      initialize();
      await harness.seed([topicFixture()]);
      await harness.container.read(followingTopicsProvider.future);
      final notifier = harness.container.read(
        followingTopicsProvider.notifier,
      );
      final folder = await notifier.createSharedFolder('Selected folder');
      final destination = await notifier.createSharedFolder('Destination');
      final original = await harness.repository.getById('cats');
      await pump(tester);
      await tester.longPress(find.text('Selected folder'));
      await tester.tap(find.text('Cats'));
      await settle(tester);
      expect(find.text('2 items selected'), findsOneWidget);
      expect(harness.requests, isEmpty);
      await tester.tap(find.widgetWithText(MultiSelectButton, 'Move'));
      await settle(tester);
      await tester.tap(find.text('Destination').last);
      await settle(tester);
      await tester.tap(find.widgetWithText(legacy.FilledButton, 'Move'));
      await drain(tester);
      final saved = await harness.repository.getOrganization();
      expect(
        saved.folders.singleWhere((f) => f.id == folder.id).parentId,
        destination.id,
      );
      expect(
        saved.folders.singleWhere((f) => f.id == destination.id).searchIds,
        ['cats'],
      );
      expect(await harness.repository.getById('cats'), original);
      expect(find.text('Following Topics'), findsOneWidget);
      expect(find.widgetWithText(MultiSelectButton, 'Move'), findsNothing);
      expect(find.byIcon(Icons.check_circle), findsNothing);
      expect(find.byTooltip('Sort by'), findsOneWidget);
      expect(pageOverflow(), findsOneWidget);
      expect(harness.requests, isEmpty);
    },
  );

  testWidgets(
    'bulk topic reorder moves all selected siblings and preserves selection',
    (tester) async {
      initialize();
      await harness.seed([
        topicFixture(),
        topicFixture(id: 'dogs', name: 'Dogs', query: 'dog', position: 1),
        topicFixture(id: 'birds', name: 'Birds', query: 'bird', position: 2),
      ]);
      await harness.container
          .read(followingTopicSortProvider.notifier)
          .select(FollowingTopicSort.manual);
      await pump(tester);
      final semantics = tester.ensureSemantics();
      try {
        final before = harness.container
            .read(visibleFollowingTopicsProvider(null))
            .requireValue;
        await tester.longPress(find.text(before[1].displayName));
        await tester.tap(find.text(before[2].displayName));
        await settle(tester);
        expect(find.text('2 items selected'), findsOneWidget);
        expect(
          harness.container.read(followingTopicSortProvider),
          FollowingTopicSort.manual,
        );
        await tester.tap(
          find.descendant(
            of: find.byType(MultiSelectionActionBar),
            matching: find.bySemanticsLabel('More'),
          ),
        );
        await settle(tester);
        await tester.tap(find.text('Move up'));
        await drain(tester);
        expect(
          harness.container
              .read(visibleFollowingTopicsProvider(null))
              .requireValue
              .map((t) => t.id),
          [before[1].id, before[2].id, before[0].id],
        );
        expect(find.text('2 items selected'), findsOneWidget);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets('selection omits Mark read when every topic is read', (
    tester,
  ) async {
    initialize();
    await harness.seed([topicFixture(unreadCount: 0)]);
    await pump(tester);
    await tester.longPress(find.text('Cats'));
    await settle(tester);
    await openPageMenu(tester);
    expect(find.text('Mark read'), findsNothing);
    expect(find.text('Enable auto-update'), findsNothing);
    expect(find.text('Disable auto-update'), findsNothing);
    expect(find.text('Remove'), findsOneWidget);
    expect(find.text('Unfollow'), findsNothing);
  });

  testWidgets('Remove deletes selected folders and separate topics', (
    tester,
  ) async {
    initialize();
    await harness.seed([
      topicFixture(),
      topicFixture(id: 'dogs', name: 'Dogs', query: 'dog', position: 1),
    ]);
    final notifier = harness.container.read(followingTopicsProvider.notifier);
    final parent = await notifier.createSharedFolder('Selected folder');
    final child = await notifier.createSharedFolder(
      'Nested',
      parentId: parent.id,
    );
    await notifier.moveTopicToSharedFolder('cats', child.id);
    await pump(tester);

    await tester.longPress(find.text('Selected folder'));
    await tester.tap(find.text('Dogs'));
    await settle(tester);
    expect(find.widgetWithText(MultiSelectButton, 'Remove'), findsOneWidget);
    expect(find.text('Unfollow'), findsNothing);
    await tester.tap(find.widgetWithText(MultiSelectButton, 'Remove'));
    await settle(tester);
    expect(find.text('Remove selection?'), findsOneWidget);
    expect(
      find.text(
        'Selected topics, folders, and everything inside those folders will be removed.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await drain(tester);
    await settle(tester);

    expect(await harness.repository.getAll(), isEmpty);
    expect((await harness.repository.getOrganization()).folders, isEmpty);
    expect(find.text('No topics yet'), findsOneWidget);
  });

  testWidgets('topic and folder menus omit the generic Move action', (
    tester,
  ) async {
    initialize();
    await harness.seed([topicFixture()]);
    final notifier = harness.container.read(followingTopicsProvider.notifier);
    await notifier.createSharedFolder('Other');
    await pump(tester);

    await openMenu(tester);
    expect(find.text('Move'), findsNothing);
    await tester.tapAt(const Offset(1, 1));
    await settle(tester);

    final folderCard = find.byType(FollowingTopicFolderCard);
    await tester.tap(
      find.descendant(
        of: folderCard,
        matching: find.byType(PopupMenuButton<FollowingTopicAction>),
      ),
    );
    await settle(tester);
    expect(find.text('Move'), findsNothing);
  });

  testWidgets(
    'unsupported profiles keep their cached topics visible and disable refresh all',
    (tester) async {
      harness = FollowingTopicHarness(supported: false);
      addTearDown(harness.dispose);
      await harness.seed([topicFixture()]);
      await pump(tester);
      expect(find.text('Following Topics'), findsOneWidget);
      expect(find.text('Cats'), findsOneWidget);
      expect(harness.requests, isEmpty);
      expect((await harness.repository.getAll()).single.id, 'cats');
      await openPageMenu(tester);
      expect(refreshAllItem(tester).enabled, isFalse);
    },
  );

  testWidgets(
    'Home keeps Sort dedicated and places maintenance actions in More',
    (
      tester,
    ) async {
      initialize();
      await harness.seed([topicFixture()]);
      await pump(tester);

      expect(find.byTooltip('Sort by'), findsOneWidget);
      expect(find.byTooltip('Bulk Follow'), findsNothing);
      expect(find.byTooltip('Refresh settings'), findsNothing);
      expect(find.byTooltip('Manage folders'), findsNothing);
      expect(find.byTooltip('Refresh All'), findsNothing);

      await openPageMenu(tester);
      for (final label in [
        'Bulk Follow',
        'Create folder',
        'Refresh All',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('Refresh settings'), findsNothing);
      expect(find.text('Refresh'), findsNothing);
    },
  );

  testWidgets('a folder keeps Sort dedicated and exposes only folder actions', (
    tester,
  ) async {
    initialize();
    await harness.seed([topicFixture(query: 'cat')]);
    await harness.container.read(followingTopicsProvider.future);
    final notifier = harness.container.read(
      followingTopicsProvider.notifier,
    );
    final folder = await notifier.createSharedFolder('Animals');
    await notifier.moveTopicToSharedFolder('cats', folder.id);
    await harness.pump(tester, FollowingTopicsPage(folderId: folder.id));

    expect(find.byTooltip('Sort by'), findsOneWidget);
    await openPageMenu(tester);
    for (final label in ['Bulk Follow', 'Create folder', 'Refresh']) {
      expect(find.text(label), findsOneWidget);
    }
    for (final label in [
      'Refresh settings',
      'Refresh All',
    ]) {
      expect(find.text(label), findsNothing);
    }
    await tester.tap(find.text('Refresh'));
    await drain(tester);
    expect(harness.requests, [
      (profileId: '00000000-0000-4000-8000-00000000000c', query: 'cat'),
    ]);
  });

  testWidgets(
    'routine check details are available through Details only',
    (
      tester,
    ) async {
      initialize();
      await harness.seed([topicFixture()]);
      await pump(tester);
      expect(find.textContaining('Last checked:'), findsNothing);
      await choose(tester, 'Details');
      expect(find.textContaining('Last checked:'), findsOneWidget);
      expect(find.text('Refresh interval: Adaptive · 1 day'), findsOneWidget);
      expect(harness.requests, isEmpty);
    },
  );

  testWidgets('Details is read-only and Edit contains Auto Update', (
    tester,
  ) async {
    initialize();
    await harness.seed([topicFixture()]);
    await pump(tester);

    expect(find.byTooltip('Refresh settings'), findsNothing);
    await choose(tester, 'Details');
    expect(find.text('Auto Update'), findsNothing);
    expect(find.byType(SwitchListTile), findsNothing);
    await tester.tapAt(const Offset(5, 5));
    await settle(tester);

    await choose(tester, 'Edit');
    expect(find.text('Auto Update'), findsOneWidget);
    expect(find.byType(SwitchListTile), findsOneWidget);
  });

  testWidgets('shows the cached last post time on the profile metadata line', (
    tester,
  ) async {
    await withClock(Clock.fixed(DateTime.utc(2026, 9, 14, 12)), () async {
      initialize();
      await harness.seed([
        topicFixture(
          previewCount: 1,
          postCreatedAt: DateTime.utc(2026, 9, 14, 10),
        ),
      ]);
      await pump(tester);

      expect(find.text('Last post: 2 hours ago'), findsOneWidget);
      expect(
        tester.getCenter(find.text('Last post: 2 hours ago')).dy,
        tester.getCenter(find.text('https://active.example')).dy,
      );
      expect(
        tester.getTopRight(find.byType(FollowingTopicCard)).dx -
            tester.getTopRight(find.text('Last post: 2 hours ago')).dx,
        lessThan(32),
      );
      expect(harness.requests, isEmpty);
    });
  });

  testWidgets('long profile captions truncate before the last post time', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const longUrl = 'https://a-very-long-profile-name.example.test';
    final profile = BooruConfig.fromJson({
      ...BooruConfig.empty.toJson(),
      'id': '00000000-0000-4000-8000-00000000000c',
      'url': longUrl,
    });
    harness = FollowingTopicHarness(profiles: [profile, otherTestProfile]);
    addTearDown(harness.dispose);
    harness.container
        .read(selectedTestProfileProvider.notifier)
        .select(profile);
    await harness.seed([
      topicFixture(
        previewCount: 1,
        postCreatedAt: DateTime.utc(2026, 9, 14, 10),
      ),
    ]);

    await withClock(Clock.fixed(DateTime.utc(2026, 9, 14, 12)), () async {
      await harness.pump(
        tester,
        const MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(2)),
          child: FollowingTopicsPage(),
        ),
      );
    });

    final caption = tester.widget<Text>(find.text(longUrl));
    expect(caption.maxLines, 1);
    expect(caption.overflow, TextOverflow.ellipsis);
    expect(find.text('Last post: 2 hours ago'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('updates the relative last post time while the page stays open', (
    tester,
  ) async {
    var now = DateTime.utc(2026, 9, 14, 12);
    initialize();
    await harness.seed([
      topicFixture(
        previewCount: 1,
        postCreatedAt: DateTime.utc(2026, 9, 14, 10),
      ),
    ]);

    await withClock(Clock(() => now), () async {
      await pump(tester);
      expect(find.text('Last post: 2 hours ago'), findsOneWidget);

      now = DateTime.utc(2026, 9, 14, 13);
      await tester.pump(const Duration(minutes: 1));
      expect(find.text('Last post: 3 hours ago'), findsOneWidget);
    });
  });

  for (final c in [
    (checked: false, label: 'Last post: Not checked'),
    (checked: true, label: 'Last post: No posts'),
  ]) {
    testWidgets('shows ${c.label} when no cached post time is available', (
      tester,
    ) async {
      initialize();
      await harness.seed([topicFixture(checked: c.checked)]);
      await pump(tester);

      expect(find.text(c.label), findsOneWidget);
      expect(harness.requests, isEmpty);
    });
  }

  testWidgets('keeps the cached last post time beside a refresh error', (
    tester,
  ) async {
    await withClock(Clock.fixed(DateTime.utc(2026, 9, 14, 12)), () async {
      initialize();
      await harness.seed([
        topicFixture(
          previewCount: 1,
          postCreatedAt: DateTime.utc(2026, 9, 14, 10),
          error: SearchRefreshErrorKind.network,
        ),
      ]);
      await pump(tester);

      expect(find.text('Last post: 2 hours ago'), findsOneWidget);
      expect(
        find.text('Could not connect. Try refreshing again.'),
        findsOneWidget,
      );
    });
  });

  testWidgets(
    'updates view reorders read Home cards without changing manual order',
    (tester) async {
      initialize();
      await harness.seed([
        topicFixture(
          unreadCount: 0,
          previewCount: 1,
          postCreatedAt: DateTime.utc(2026, 9, 12),
        ),
        topicFixture(
          id: 'dogs',
          name: 'Dogs',
          query: 'dog',
          position: 1,
          unreadCount: 0,
          previewCount: 1,
          postCreatedAt: DateTime.utc(2026, 9, 13),
        ),
      ]);
      await pump(tester);

      await tester.tap(find.byTooltip('Sort by'));
      await settle(tester);
      expect(find.byType(PopupMenuItem<FollowingTopicSort>), findsNWidgets(4));
      expect(
        tester
            .widgetList<PopupMenuItem<FollowingTopicSort>>(
              find.byType(PopupMenuItem<FollowingTopicSort>),
            )
            .map((item) => item.value),
        [
          FollowingTopicSort.manual,
          FollowingTopicSort.nameAsc,
          FollowingTopicSort.updatesFirst,
          FollowingTopicSort.lastPostOldest,
        ],
      );
      expect(find.text('Manual order'), findsOneWidget);
      expect(find.text('Updates first'), findsOneWidget);
      expect(find.text('Oldest post first'), findsOneWidget);
      expect(find.text('Unseen first'), findsNothing);
      expect(find.text('Newest post first'), findsNothing);
      await tester.tap(find.text('Updates first'));
      await settle(tester);

      expect(
        tester.getTopLeft(find.text('Dogs')).dy,
        lessThan(tester.getTopLeft(find.text('Cats')).dy),
      );
      expect((await harness.repository.getOrganization()).homeSearchIds, [
        'cats',
        'dogs',
      ]);
      expect(harness.requests, isEmpty);

      await tester.tap(find.byTooltip('Sort by'));
      await settle(tester);
      await tester.tap(find.text('Manual order'));
      await settle(tester);
      expect(
        tester.getTopLeft(find.text('Cats')).dy,
        lessThan(tester.getTopLeft(find.text('Dogs')).dy),
      );
    },
  );

  testWidgets('updates view groups NEW Home cards before read cards', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    initialize();
    await harness.seed([
      topicFixture(
        name: 'Read first',
        unreadCount: 0,
        previewCount: 1,
        postCreatedAt: DateTime.utc(2026, 9, 14),
      ),
      topicFixture(
        id: 'new',
        name: 'NEW second',
        query: 'new',
        unreadCount: 1,
        position: 1,
        previewCount: 1,
        postCreatedAt: DateTime.utc(2026, 9, 11),
      ),
      topicFixture(
        id: 'new-tie',
        name: 'NEW third',
        query: 'newer',
        unreadCount: 1,
        position: 2,
        previewCount: 1,
        postCreatedAt: DateTime.utc(2026, 9, 12),
      ),
      topicFixture(
        id: 'read-last',
        name: 'Read last',
        query: 'read',
        unreadCount: 0,
        position: 3,
        previewCount: 1,
        postCreatedAt: DateTime.utc(2026, 9, 10),
      ),
    ]);
    await pump(tester);

    await tester.tap(find.byTooltip('Sort by'));
    await settle(tester);
    await tester.tap(find.text('Updates first'));
    await settle(tester);

    expect(
      tester.getTopLeft(find.text('NEW third')).dy,
      lessThan(tester.getTopLeft(find.text('NEW second')).dy),
    );
    expect(
      tester.getTopLeft(find.text('NEW second')).dy,
      lessThan(tester.getTopLeft(find.text('Read first')).dy),
    );
    expect(
      tester.getTopLeft(find.text('Read first')).dy,
      lessThan(tester.getTopLeft(find.text('Read last')).dy),
    );
    expect((await harness.repository.getOrganization()).homeSearchIds, [
      'cats',
      'new',
      'new-tie',
      'read-last',
    ]);
    expect(harness.requests, isEmpty);
  });

  testWidgets('updates view is shared with folders and sorts their cards', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    initialize();
    await harness.seed([
      topicFixture(
        name: 'Read',
        unreadCount: 0,
        previewCount: 1,
        postCreatedAt: DateTime.utc(2026, 9, 14),
      ),
      topicFixture(
        id: 'new',
        name: 'New',
        query: 'new',
        unreadCount: 1,
        position: 1,
        previewCount: 1,
        postCreatedAt: DateTime.utc(2026, 9, 11),
      ),
      topicFixture(
        id: 'newer',
        name: 'Newer',
        query: 'newer',
        unreadCount: 1,
        position: 2,
        previewCount: 1,
        postCreatedAt: DateTime.utc(2026, 9, 12),
      ),
    ]);
    final notifier = harness.container.read(
      followingTopicsProvider.notifier,
    );
    final folder = await notifier.createSharedFolder('Favorites');
    await notifier.moveTopicToSharedFolder('cats', folder.id);
    await notifier.moveTopicToSharedFolder('new', folder.id);
    await notifier.moveTopicToSharedFolder('newer', folder.id);
    await pump(tester);

    await tester.tap(find.byTooltip('Sort by'));
    await settle(tester);
    await tester.tap(find.text('Updates first'));
    await settle(tester);
    await tester.tap(find.text('Favorites'));
    await settle(tester);

    expect(
      tester.getTopLeft(find.text('Newer')).dy,
      lessThan(tester.getTopLeft(find.text('New')).dy),
    );
    expect(
      tester.getTopLeft(find.text('New')).dy,
      lessThan(tester.getTopLeft(find.text('Read')).dy),
    );
    expect(
      (await harness.repository.getOrganization()).folders.single.searchIds,
      [
        'cats',
        'new',
        'newer',
      ],
    );
    expect(harness.requests, isEmpty);
  });

  testWidgets('oldest post view keeps undated cards after dated cards', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    initialize();
    await harness.seed([
      topicFixture(name: 'Not checked', checked: false),
      topicFixture(
        id: 'newer',
        name: 'Newer',
        query: 'newer',
        position: 1,
        previewCount: 1,
        postCreatedAt: DateTime.utc(2026, 9, 13),
      ),
      topicFixture(
        id: 'older',
        name: 'Older',
        query: 'older',
        position: 2,
        previewCount: 1,
        postCreatedAt: DateTime.utc(2026, 9, 12),
      ),
    ]);
    await pump(tester);

    await tester.tap(find.byTooltip('Sort by'));
    await settle(tester);
    await tester.tap(find.text('Oldest post first'));
    await settle(tester);

    expect(
      tester.getTopLeft(find.text('Older')).dy,
      lessThan(tester.getTopLeft(find.text('Newer')).dy),
    );
    expect(
      tester.getTopLeft(find.text('Newer')).dy,
      lessThan(tester.getTopLeft(find.text('Not checked')).dy),
    );
  });

  testWidgets(
    'manual view keeps move actions and disables impossible directions',
    (tester) async {
      initialize();
      await harness.seed([
        topicFixture(),
        topicFixture(id: 'dogs', name: 'Dogs', query: 'dog', position: 1),
      ]);
      await pump(tester);

      for (final c in [
        (name: 'Cats', moveUp: false, moveDown: true),
        (name: 'Dogs', moveUp: true, moveDown: false),
      ]) {
        await openMenu(tester, c.name);
        for (final action in [
          (label: 'Move up', enabled: c.moveUp),
          (label: 'Move down', enabled: c.moveDown),
        ]) {
          final item = tester.widget<PopupMenuItem<FollowingTopicAction>>(
            find.ancestor(
              of: find.text(action.label),
              matching: find.byType(PopupMenuItem<FollowingTopicAction>),
            ),
          );
          expect(item.enabled, action.enabled);
        }
        await tester.tapAt(const Offset(1, 1));
        await settle(tester);
      }
    },
  );

  testWidgets('date views omit manual move actions', (tester) async {
    initialize();
    await harness.seed([
      topicFixture(
        previewCount: 1,
        postCreatedAt: DateTime.utc(2026, 9, 12),
      ),
      topicFixture(
        id: 'dogs',
        name: 'Dogs',
        query: 'dog',
        position: 1,
        previewCount: 1,
        postCreatedAt: DateTime.utc(2026, 9, 13),
      ),
    ]);
    await pump(tester);
    await tester.tap(find.byTooltip('Sort by'));
    await settle(tester);
    await tester.tap(find.text('Updates first'));
    await settle(tester);
    await openMenu(tester, 'Dogs');

    for (final label in ['Move up', 'Move down']) {
      expect(find.text(label), findsNothing);
    }
  });

  testWidgets('selected date view carries from Home into a folder', (
    tester,
  ) async {
    initialize();
    await harness.seed([
      topicFixture(
        name: 'Newer',
        previewCount: 1,
        postCreatedAt: DateTime.utc(2026, 9, 13),
      ),
      topicFixture(
        id: 'older',
        name: 'Older',
        query: 'older',
        position: 1,
        previewCount: 1,
        postCreatedAt: DateTime.utc(2026, 9, 12),
      ),
    ]);
    final notifier = harness.container.read(
      followingTopicsProvider.notifier,
    );
    final folder = await notifier.createSharedFolder('Favorites');
    await notifier.moveTopicToSharedFolder('cats', folder.id);
    await notifier.moveTopicToSharedFolder('older', folder.id);
    await pump(tester);

    await tester.tap(find.byTooltip('Sort by'));
    await settle(tester);
    await tester.tap(find.text('Oldest post first'));
    await settle(tester);
    await tester.tap(find.text('Favorites'));
    await settle(tester);

    expect(find.widgetWithText(AppBar, 'Favorites'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Older')).dy,
      lessThan(tester.getTopLeft(find.text('Newer')).dy),
    );
  });

  testWidgets('shows loading before cached searches become available', (
    tester,
  ) async {
    final ready = Completer<void>();
    initialize(ready: ready);
    await pump(tester);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    ready.complete();
    await settle(tester);
    expect(find.text('No topics yet'), findsOneWidget);
  });

  testWidgets('reports a storage load failure and allows retrying', (
    tester,
  ) async {
    final ready = Completer<void>();
    initialize(ready: ready);
    await pump(tester);
    ready.completeError(StateError('unavailable'));
    await settle(tester);
    expect(find.text('Could not load topics.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('shows cached cards from all profiles without requesting posts', (
    tester,
  ) async {
    initialize();
    await harness.seed([
      topicFixture(previewCount: 6, error: SearchRefreshErrorKind.network),
      topicFixture(
        id: 'dogs',
        query: 'dog',
        name: null,
        position: 1,
        unreadCount: 0,
        checked: false,
      ),
      topicFixture(
        id: 'other',
        profileId: '00000000-0000-4000-8000-000000000063',
        name: 'Other profile',
        query: 'other',
        unreadCount: 90,
      ),
    ]);
    await pump(tester);
    expect(find.text('Cats'), findsOneWidget);
    expect(find.text('cat  rating:safe order:score'), findsOneWidget);
    expect(find.text('dog'), findsOneWidget);
    expect(find.text('Other profile'), findsOneWidget);
    expect(find.text('NEW'), findsNWidgets(2));
    expect(find.text('Never checked'), findsNothing);
    expect(find.textContaining('Last checked:'), findsNothing);
    expect(
      find.text('Could not connect. Try refreshing again.'),
      findsOneWidget,
    );
    final images = tester
        .widgetList<BooruImage>(find.byType(BooruImage))
        .toList();
    expect(images.map((image) => image.imageUrl), [
      'https://images.example/0.jpg',
      'https://images.example/1.jpg',
      'https://images.example/2.jpg',
      'https://images.example/3.jpg',
    ]);
    expect(images.every((image) => image.config == testProfile.auth), isTrue);
    for (final element in find.byType(BooruImage).evaluate()) {
      final size = tester.getSize(find.byWidget(element.widget));
      expect(size.width, size.height);
    }
    expect(harness.requests, isEmpty);
  });

  for (final c in [
    (
      kind: SearchRefreshErrorKind.authentication,
      message: 'Check this profile’s login details.',
    ),
    (
      kind: SearchRefreshErrorKind.query,
      message: 'This query could not be checked.',
    ),
    (
      kind: SearchRefreshErrorKind.tagLimit,
      message: "This search exceeds the site's search-term limit.",
    ),
    (
      kind: SearchRefreshErrorKind.rateLimited,
      message: 'Rate limited by the site. Try again later.',
    ),
    (
      kind: SearchRefreshErrorKind.pagination,
      message: 'The check was incomplete. Try refreshing again.',
    ),
    (
      kind: SearchRefreshErrorKind.parsing,
      message: 'The site returned unreadable post data.',
    ),
    (
      kind: SearchRefreshErrorKind.unsupported,
      message: 'New-post tracking is unsupported for this search.',
    ),
    (
      kind: SearchRefreshErrorKind.other,
      message: 'Could not refresh this topic. Try again.',
    ),
  ]) {
    testWidgets('presents a stable ${c.kind.name} refresh error', (
      tester,
    ) async {
      initialize();
      await harness.seed([topicFixture(error: c.kind)]);
      await pump(tester);
      expect(find.text(c.message), findsOneWidget);
      expect(find.textContaining('Last checked:'), findsNothing);
    });
  }

  testWidgets('a broken cached preview uses the existing image fallback', (
    tester,
  ) async {
    initialize(loadImages: true);
    await harness.seed([topicFixture(previewCount: 1)]);
    await pump(tester);
    for (
      var i = 0;
      i < 15 && find.byType(ErrorPlaceholder).evaluate().isEmpty;
      i++
    ) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(find.byType(ErrorPlaceholder), findsOneWidget);
    expect(find.text('Cats'), findsOneWidget);
    expect(harness.requests, isEmpty);
  });

  testWidgets(
    'awaits clearing unread before opening the exact stored simple query',
    (tester) async {
      initialize();
      await harness.seed([topicFixture()]);
      await pumpRouter(tester);
      harness.box.writeGate = Completer<void>();
      await tester.tap(find.text('Cats'));
      await settle(tester);
      expect(
        harness.router.routeInformationProvider.value.uri.path,
        '/following-topics',
      );
      harness.box.writeGate!.complete();
      await settle(tester);
      await settle(tester);
      expect((await harness.repository.getById('cats'))!.unreadCount, 0);
      expect(openedUri!.path, '/search');
      expect(find.text('Opened cat  rating:safe order:score'), findsOneWidget);
      expect(openedUri!.queryParameters['query_type'], 'simple');
    },
  );

  testWidgets(
    'opens a structured topic as separate specific tags',
    (tester) async {
      initialize();
      await harness.seed([
        topicFixture(
          query: 'cat rating:safe',
          queryStructure: SearchQueryStructure.typedTags(const [
            'cat',
            'rating:safe',
          ]),
        ),
      ]);
      await pumpRouter(tester);

      await tester.tap(find.text('Cats'));
      await settle(tester);
      await settle(tester);

      expect(openedUri!.path, '/search');
      expect(openedUri!.queryParameters['query'], isNull);
      expect(openedUri!.queryParameters['tags'], '["cat","rating:safe"]');
      expect(openedUri!.queryParameters['query_type'], 'list');
      expect(
        SearchParams.fromUri(openedUri!).tags?.tags.map((tag) => tag.isRaw),
        [false, false],
      );
    },
  );

  testWidgets(
    'opens a mismatched typed payload as the exact stored raw query',
    (tester) async {
      initialize();
      await harness.seed([
        topicFixture(
          query: 'dog  order:score',
          queryStructure: SearchQueryStructure.typedTags(const [
            'cat',
            'order:score',
          ]),
        ),
      ]);
      await pumpRouter(tester);

      await tester.tap(find.text('Cats'));
      await settle(tester);
      await settle(tester);

      expect(openedUri!.path, '/search');
      expect(openedUri!.queryParameters['query'], 'dog  order:score');
      expect(openedUri!.queryParameters['tags'], isNull);
      expect(openedUri!.queryParameters['query_type'], 'simple');
    },
  );

  for (final c in [
    (description: 'tab', typedTag: 'cat\tdog'),
    (description: 'newline', typedTag: 'cat\ndog'),
  ]) {
    testWidgets(
      'opens a ${c.description}-separated typed payload as raw',
      (tester) async {
        initialize();
        await harness.seed([
          topicFixture(
            query: 'cat dog',
            queryStructure: SearchQueryStructure.typedTags([c.typedTag]),
          ),
        ]);
        await pumpRouter(tester);

        await tester.tap(find.text('Cats'));
        await settle(tester);
        await settle(tester);

        expect(openedUri!.path, '/search');
        expect(openedUri!.queryParameters['query'], 'cat dog');
        expect(openedUri!.queryParameters['tags'], isNull);
        expect(openedUri!.queryParameters['query_type'], 'simple');
      },
    );
  }

  testWidgets(
    'keeps the card unread and stays on the page when mark-read fails',
    (tester) async {
      initialize();
      await harness.seed([topicFixture()]);
      await pumpRouter(tester);
      harness.box.failWrites = true;
      await tester.tap(find.text('Cats'));
      await settle(tester);
      expect((await harness.repository.getById('cats'))!.unreadCount, 1);
      expect(find.byType(FollowingTopicsPage), findsOneWidget);
      expect(
        find.text('Could not mark this search as read. Try again.'),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 5));
    },
  );

  testWidgets(
    'editing the name to blank restores the query label without changing unread',
    (tester) async {
      initialize();
      await harness.seed([topicFixture()]);
      await pump(tester);
      await choose(tester, 'Edit');
      expect(
        tester
            .widget<TextField>(
              find.widgetWithText(TextField, 'Name (optional)'),
            )
            .controller!
            .text,
        'Cats',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Name (optional)'),
        '   ',
      );
      await tester.tap(find.text('Save'));
      await drain(tester);
      await settle(tester);
      expect(find.text('Cats'), findsNothing);
      expect(find.text('cat  rating:safe order:score'), findsOneWidget);
      expect((await harness.repository.getById('cats'))!.unreadCount, 1);
      expect(harness.requests, isEmpty);
    },
  );

  testWidgets(
    'move up and down order Home across profiles without changing owners',
    (tester) async {
      initialize();
      await harness.seed([
        topicFixture(),
        topicFixture(
          id: 'dogs',
          name: 'Dogs',
          query: 'dog',
          profileId: '00000000-0000-4000-8000-000000000063',
        ),
      ]);
      await pump(tester);
      await choose(tester, 'Move down');
      expect(
        tester.getTopLeft(find.text('Dogs')).dy,
        lessThan(tester.getTopLeft(find.text('Cats')).dy),
      );
      expect((await harness.repository.getOrganization()).homeSearchIds, [
        'dogs',
        'cats',
      ]);
      expect(
        (await harness.repository.getById('dogs'))!.profileId,
        '00000000-0000-4000-8000-000000000063',
      );
      await choose(tester, 'Move up');
      expect((await harness.repository.getOrganization()).homeSearchIds, [
        'cats',
        'dogs',
      ]);
    },
  );

  testWidgets(
    'Unfollow removes immediately and offers Undo',
    (tester) async {
      initialize();
      await harness.seed([topicFixture()]);
      await pump(tester);
      await choose(tester, 'Unfollow');
      await settle(tester);
      expect(find.text('Cats'), findsNothing);
      expect(find.text('No topics yet'), findsOneWidget);
      expect(await harness.repository.getAll(), isEmpty);
      expect(find.text('Undo'), findsOneWidget);
      await tester.tap(find.text('Undo'));
      await settle(tester);
      expect(find.text('Cats'), findsOneWidget);
      expect(await harness.repository.getAll(), hasLength(1));
      await tester.pump(const Duration(seconds: 5));
    },
  );

  testWidgets('refreshes one card and displays its running state', (
    tester,
  ) async {
    initialize();
    harness.refreshGate = Completer<void>();
    await harness.seed([
      topicFixture(query: 'cat'),
      topicFixture(
        id: 'other',
        profileId: '00000000-0000-4000-8000-000000000063',
        name: 'Other',
      ),
    ]);
    await pump(tester);
    await choose(tester, 'Refresh');
    expect(find.text('Refreshing…'), findsOneWidget);
    expect(harness.requests.map((request) => request.profileId), [
      '00000000-0000-4000-8000-00000000000c',
    ]);
    harness.refreshGate!.complete();
    await settle(tester);
    expect(find.text('Refreshing…'), findsNothing);
  });

  testWidgets(
    'Refresh All visits both owners and remains disabled while a batch runs',
    (tester) async {
      initialize();
      harness.refreshGate = Completer<void>();
      await harness.seed([
        topicFixture(checked: false, query: 'cat'),
        topicFixture(
          id: 'other',
          profileId: '00000000-0000-4000-8000-000000000063',
          name: 'Other',
          query: 'dog',
          checked: false,
        ),
      ]);
      await pump(tester);
      await choosePageAction(tester, 'Refresh All');
      expect(harness.requests.map((r) => r.profileId), [
        '00000000-0000-4000-8000-00000000000c',
      ]);
      await openPageMenu(tester);
      expect(refreshAllItem(tester).enabled, isFalse);
      await tester.tapAt(const Offset(1, 1));
      await settle(tester);
      harness.container
          .read(selectedTestProfileProvider.notifier)
          .select(otherTestProfile);
      await pump(tester);
      await openPageMenu(tester);
      expect(refreshAllItem(tester).enabled, isFalse);
      await tester.tapAt(const Offset(1, 1));
      await settle(tester);
      harness.refreshGate!.complete();
      await settle(tester);
      await drain(tester);
      expect(harness.requests.map((r) => r.profileId), [
        '00000000-0000-4000-8000-00000000000c',
        '00000000-0000-4000-8000-000000000063',
      ]);
      await openPageMenu(tester);
      expect(refreshAllItem(tester).enabled, isTrue);
      expect(
        (await harness.repository.getById('other'))!.lastSuccessfulCheckAt,
        isNotNull,
      );
    },
  );

  testWidgets(
    'a completed mark-read does not navigate after the page is disposed',
    (tester) async {
      initialize();
      await harness.seed([topicFixture()]);
      await pumpRouter(tester);
      harness.box.writeGate = Completer<void>();
      await tester.tap(find.text('Cats'));
      await settle(tester);
      harness.router.go('/');
      await settle(tester);
      harness.box.writeGate!.complete();
      await settle(tester);
      expect(harness.router.routeInformationProvider.value.uri.path, '/');
      expect(tester.takeException(), isNull);
    },
  );
}
