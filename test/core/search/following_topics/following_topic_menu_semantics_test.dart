import 'dart:typed_data';
import 'dart:ui' show SemanticsAction;

import 'package:boorusama/core/backups/folder_sync/protocol.dart';
import 'package:boorusama/core/backups/folder_sync/providers.dart';
import 'package:boorusama/core/backups/folder_sync/service.dart';
import 'package:boorusama/core/search/following_topics/src/widgets/following_topic_card.dart';
import 'package:boorusama/core/search/following_topics/src/widgets/following_topic_folder_card.dart';
import 'package:boorusama/core/search/following_topics/src/widgets/following_topic_sync_menu.dart';
import 'package:boorusama/core/search/following_topics/types.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

void main() {
  for (final received in [false, true]) {
    for (final host in ['standalone', 'topic', 'folder']) {
      testWidgets(
        '$host Following menu exposes popup semantic actions in a nested navigator (received=$received)',
        (tester) async {
          final semantics = tester.ensureSemantics();
          final service = received
              ? await tester.runAsync(_receivedService)
              : null;
          final container = ProviderContainer(
            overrides: [
              if (service != null)
                folderSyncServiceProvider.overrideWithValue(service),
            ],
          );
          if (service != null) container.read(folderSyncServiceProvider);
          try {
            await ensureI18nInitialized('en-US');
            await tester.binding.setSurfaceSize(const Size(360, 800));
            addTearDown(() => tester.binding.setSurfaceSize(null));
            FollowingTopicAction? selected;
            final topic = FollowingTopic.create(
              id: 'topic',
              profileId: 'profile',
              query: 'cat',
              name: 'Topic',
              position: 0,
              createdAt: DateTime.utc(2026),
            );
            await tester.pumpWidget(
              BooruLocalization(
                child: UncontrolledProviderScope(
                  container: container,
                  child: MaterialApp(
                    home: Navigator(
                      onGenerateRoute: (_) => MaterialPageRoute<void>(
                        builder: (_) => Scaffold(
                          appBar: AppBar(title: const Text('Following')),
                          body: ListView(
                            children: [
                              if (host == 'folder')
                                FollowingTopicFolderCard(
                                  name: 'Folder',
                                  localId: 'folder',
                                  itemCount: 1,
                                  newPostCount: 0,
                                  previews: const [],
                                  lastPostAt: null,
                                  hasBaseline: false,
                                  refreshing: false,
                                  canRefresh: true,
                                  showMoveActions: false,
                                  canMoveUp: false,
                                  canMoveDown: false,
                                  onOpen: () {},
                                  onAction: (action) => selected = action,
                                )
                              else if (host == 'topic')
                                FollowingTopicCard(
                                  topic: topic,
                                  config: null,
                                  refreshing: false,
                                  onOpen: () {},
                                  onAction: (action) => selected = action,
                                )
                              else
                                Align(
                                  alignment: Alignment.topRight,
                                  child: FollowingTopicSyncMenu(
                                    localId: topic.id,
                                    entries: const [
                                      PopupMenuItem(
                                        value: FollowingTopicAction.refresh,
                                        child: Text('Refresh'),
                                      ),
                                      PopupMenuItem(
                                        value: FollowingTopicAction.edit,
                                        child: Text('Edit'),
                                      ),
                                    ],
                                    onAction: (action) => selected = action,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            final strings = tester
                .element(find.byType(FollowingTopicSyncMenu))
                .t;
            final editLabel = !received && host == 'folder'
                ? strings.following_topics.edit_folder
                : strings.generic.action.edit;
            final syncLabel = received
                ? strings.folder_sync.manage
                : strings.folder_sync.publish;
            final button = find.byType(KurumiPopupMenuButton);
            expect(tester.getSize(button), const Size(48, 48));
            await tester.tap(button);
            await tester.pumpAndSettle();
            expect(find.text(editLabel), findsOneWidget);
            expect(find.text(syncLabel), findsOneWidget);
            final accessible = tester.semantics
                .simulatedAccessibilityTraversal();
            expect(
              accessible,
              contains(isSemantics(label: editLabel, hasTapAction: true)),
            );
            expect(
              accessible,
              contains(isSemantics(label: syncLabel, hasTapAction: true)),
            );
            final refresh = find.semantics.byLabel('Refresh').evaluate().single;
            refresh.owner!.performAction(refresh.id, SemanticsAction.tap);
            await tester.pumpAndSettle();
            expect(selected, FollowingTopicAction.refresh);
            expect(find.text(editLabel), findsNothing);
            expect(tester.takeException(), isNull);
          } finally {
            await tester.pumpWidget(const SizedBox.shrink());
            container.dispose();
            if (service != null) await tester.runAsync(service.dispose);
            semantics.dispose();
          }
        },
      );
    }
  }
}

Future<FolderSyncService> _receivedService() async {
  final metadata = _Metadata();
  FolderSyncService create() => FolderSyncService(
    metadata: metadata,
    port: _UnusedPort(),
    storageFor: (_) =>
        throw StateError('Semantic inspection must not access shared storage'),
  );
  final initial = create();
  await initial.initialize();
  await initial.dispose();
  metadata.value['subscriptions'] = {
    for (final id in ['topic', 'folder'])
      'publisher/$id': {
        'kind': 'following_topics',
        'localId': id,
        'state': 'ready',
        'changed': false,
        'unseen': <String>[],
      },
  };
  final service = create();
  await service.initialize();
  return service;
}

class _Metadata implements FolderSyncMetadataStore {
  Map<String, dynamic> value = {};
  @override
  Future<Map<String, dynamic>> load() async => value;
  @override
  Future<void> save(Map<String, dynamic> data) async {
    value = data;
  }
}

class _UnusedPort implements SyncCollectionPort {
  @override
  Future<List<SyncSourceCollection>> sources() => throw UnimplementedError();
  @override
  Future<SyncCapturedCollection> capture(SyncSourceCollection source) =>
      throw UnimplementedError();
  @override
  Future<SyncAppliedCollection?> inspect(String kind, String localId) =>
      throw UnimplementedError();
  @override
  Future<SyncAppliedCollection> apply({
    required SyncRevision revision,
    required Uint8List bytes,
    required String localId,
    required String name,
    String? parentId,
  }) => throw UnimplementedError();
}
