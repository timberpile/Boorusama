import 'package:boorusama/core/groups/folder_tree.dart';
import 'package:boorusama/core/search/following_topics/src/data/hive/following_topic_repository_hive.dart';
import 'package:boorusama/core/search/following_topics/providers.dart';
import 'package:boorusama/core/search/following_topics/types.dart';
import 'package:boorusama/core/search/following_topics/src/types/following_mirror_state.dart';
import 'package:boorusama/core/search/following_topics/src/pages/following_topics_page.dart';
import 'package:boorusama/core/search/following_topics/src/widgets/following_topic_card.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/material.dart';

import 'following_topic_test_utils.dart';

String uid(int n) =>
    '${n.toString().padLeft(8, '0')}-1111-4111-8111-111111111111';
FollowingTopic item(int id, int day, int position) => FollowingTopic.create(
  id: uid(id),
  profileId: testProfile.id,
  query: 'match$id',
  name: 'Match $id',
  position: position,
  createdAt: DateTime.utc(2020, 1, day),
);

void main() {
  for (final nested in [false, true]) {
    testWidgets(
      'filtered final projection sorts dates and restores manual nested=$nested',
      (tester) async {
        tester.view.physicalSize = const Size(320, 1800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final harness = FollowingTopicHarness();
        addTearDown(harness.dispose);
        await harness.seed([item(1, 3, 0), item(2, 1, 1)]);
        final notifier = harness.container.read(
          followingTopicsProvider.notifier,
        );
        String? folderId;
        String? reorderedFolder;
        if (nested) {
          final parent = await notifier.createSharedFolder('Parent');
          final child = await notifier.createSharedFolder(
            'Child',
            parentId: parent.id,
          );
          await notifier.moveFolderItems(
            searchIds: {uid(1), uid(2)},
            destination: child.id,
          );
          folderId = parent.id;
          reorderedFolder = child.id;
        }
        await notifier.reorderSharedTopics(reorderedFolder, 0, 1);
        if ((await harness.repository.getOrganization())
                .directIds(reorderedFolder)
                .first !=
            uid(2)) {
          await notifier.reorderSharedTopics(reorderedFolder, 0, 1);
        }
        expect(
          (await harness.repository.getOrganization()).directIds(
            reorderedFolder,
          ),
          [uid(2), uid(1)],
        );
        final before = await harness.repository.getOrganization();
        final stored = await harness.repository.getAll();
        await harness.pump(tester, FollowingTopicsPage(folderId: folderId));
        await tester.tap(find.byTooltip('Search'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'match');
        await tester.pumpAndSettle();
        Future<void> expectSort(
          FollowingTopicSort sort,
          List<String> ids,
        ) async {
          await harness.container
              .read(followingTopicSortProvider.notifier)
              .select(sort);
          await tester.pumpAndSettle();
          expect(harness.container.read(followingTopicSortProvider), sort);
          expect(
            tester
                .widgetList<FollowingTopicCard>(find.byType(FollowingTopicCard))
                .map((w) => w.topic.id),
            ids,
          );
        }

        await expectSort(FollowingTopicSort.manual, [uid(2), uid(1)]);
        await expectSort(FollowingTopicSort.addedNewest, [uid(1), uid(2)]);
        tester
            .widget<DropdownButton<String?>>(
              find.byType(DropdownButton<String?>),
            )
            .onChanged!(testProfile.id);
        await tester.pumpAndSettle();
        await expectSort(FollowingTopicSort.manual, [uid(2), uid(1)]);
        await expectSort(FollowingTopicSort.addedNewest, [uid(1), uid(2)]);
        await expectSort(FollowingTopicSort.nameAsc, [uid(1), uid(2)]);
        await expectSort(FollowingTopicSort.manual, [uid(2), uid(1)]);
        expect(await harness.repository.getOrganization(), before);
        expect(
          (await harness.repository.getAll()).map(
            (t) => (t.id, t.position, t.createdAt),
          ),
          stored.map((t) => (t.id, t.position, t.createdAt)),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('direct subscriptions sort inside each publisher section', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final harness = FollowingTopicHarness();
    addTearDown(harness.dispose);
    await harness.seed([item(1, 3, 0), item(2, 1, 1)]);
    final before = await (harness.repository as HiveFollowingTopicRepository)
        .readMirrorSnapshot();
    final topics = [
      item(10, 1, 0),
      item(11, 3, 1),
      item(20, 1, 0),
      item(21, 3, 1),
    ];
    final folders = [
      for (final p in [1, 2])
        TopicFolder(
          id: uid(100 + p),
          name: 'Source $p',
          nameScope: followingFolderNameScope(uid(200 + p), null),
        ),
    ];
    final owners = <String, FollowingMirrorOwner>{};
    for (final p in [1, 2]) {
      final publisher = uid(200 + p);
      final folder = folders[p - 1];
      owners[folder.id] = FollowingMirrorOwner(
        publisher: publisher,
        source: uid(300 + p),
        kind: FollowingMirrorKind.folder,
        revision: 1,
        payloadDigest: 'a' * 64,
        descriptorDigest: 'b' * 64,
        definitionDigest: followingDefinitionDigest(
          kind: FollowingMirrorKind.folder,
          parentSource: null,
          position: 0,
          folder: folder,
          children: [
            FollowingDefinitionChild(
              source: uid(401 + p * 10),
              kind: FollowingMirrorKind.topic,
              position: 1,
            ),
          ],
        ),
      );
      for (final i in [0, 1]) {
        final topic = topics[(p - 1) * 2 + i];
        final parent = i == 1 ? uid(300 + p) : null;
        owners[topic.id] = FollowingMirrorOwner(
          publisher: publisher,
          source: uid(400 + p * 10 + i),
          kind: FollowingMirrorKind.topic,
          revision: 1,
          parentSource: parent,
          position: i,
          payloadDigest: 'a' * 64,
          descriptorDigest: 'b' * 64,
          definitionDigest: followingDefinitionDigest(
            kind: FollowingMirrorKind.topic,
            parentSource: parent,
            position: i,
            topic: topic,
          ),
        );
      }
    }
    await harness.seed([item(1, 3, 0), item(2, 1, 1), ...topics]);
    await harness.repository.replaceOrganization(
      TopicOrganization(
        folders: folders,
        placements: [
          ...before.organization.placements,
          for (final p in [1, 2]) ...[
            FolderPlacement(itemId: topics[(p - 1) * 2].id, position: p + 1),
            FolderPlacement(
              itemId: topics[(p - 1) * 2 + 1].id,
              folderId: folders[p - 1].id,
              position: 0,
            ),
          ],
        ],
      ),
    );
    // Seed canonical received definitions; the UI test exercises their projection,
    // while journal/mutation behavior is covered by the mirror storage suite.
    await harness.organizationBox.put(
      'search:sync_mirrors',
      FollowingMirrorState(
        epoch: 1,
        owners: owners,
        subscriptions: {
          for (final p in [1, 2])
            uid(200 + p): {
              for (final i in [0, 1]) uid(400 + p * 10 + i),
            },
        },
      ).toJson(),
    );
    await harness.container
        .read(followingTopicsProvider.notifier)
        .reloadFromStorage();
    final stored = await (harness.repository as HiveFollowingTopicRepository)
        .readMirrorSnapshot();
    await harness.pump(tester, const FollowingTopicsPage());
    for (final sort in [
      FollowingTopicSort.addedNewest,
      FollowingTopicSort.manual,
    ]) {
      await harness.container
          .read(followingTopicSortProvider.notifier)
          .select(sort);
      await tester.pumpAndSettle();
      final newest = sort == FollowingTopicSort.addedNewest;
      final ids = tester
          .widgetList<FollowingTopicCard>(find.byType(FollowingTopicCard))
          .map((w) => w.topic.id)
          .toList();
      expect(ids, [
        if (sort == FollowingTopicSort.manual)
          ...stored.organization.homeSearchIds.where(
            (id) => id == uid(1) || id == uid(2),
          )
        else ...[
          uid(1),
          uid(2),
        ],
        if (newest) ...[
          uid(11),
          uid(10),
          uid(21),
          uid(20),
        ] else ...[
          uid(10),
          uid(11),
          uid(20),
          uid(21),
        ],
      ]);
    }
    final after = await (harness.repository as HiveFollowingTopicRepository)
        .readMirrorSnapshot();
    expect(after.organization, stored.organization);
    expect(after.mirrors, stored.mirrors);
    expect(
      after.topics.map((t) => (t.id, t.position, t.createdAt)),
      stored.topics.map((t) => (t.id, t.position, t.createdAt)),
    );
    expect(tester.takeException(), isNull);
  });
}
