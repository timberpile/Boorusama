import 'package:boorusama/core/backups/export_import/export/export_flow_notifier.dart';
import 'package:boorusama/core/backups/export_import/models/export_selection.dart';
import 'package:boorusama/core/backups/export_import/sources/export_import_source.dart';
import 'package:boorusama/core/backups/export_import/import/import_item_labels.dart';
import 'package:boorusama/core/backups/sources/bookmark_backup_data.dart';
import 'package:boorusama/core/backups/export_import/sources/export_selection_ids.dart';
import 'package:boorusama/core/backups/export_import/import/import_source_integrity_validator.dart';
import 'package:boorusama/core/backups/sources/providers.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_group.dart';
import 'package:boorusama/core/debug/src/logging/app_logger.dart';
import 'package:boorusama/foundation/loggers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const rootId = '11111111-1111-4111-8111-111111111111';
  const childId = '22222222-2222-4222-8222-222222222222';
  const rootNodeId = 'group:$rootId';
  const childNodeId = 'group:$childId';

  final parentPost = PostBookmark.empty.copyWith(
    id: 1,
    originalUrl: 'https://example.com/parent.jpg',
  );
  final childPost = PostBookmark.empty.copyWith(
    id: 2,
    originalUrl: 'https://example.com/child.jpg',
  );

  final hierarchy = BookmarkBackupData.unified(
    records: [parentPost, childPost],
    groups: [
      BookmarkGroupBackup(
        id: rootId,
        name: 'Parent with direct member',
        bookmarkIds: [parentPost.id],
      ),
      BookmarkGroupBackup(
        id: childId,
        name: 'Child',
        parentGroupId: rootId,
        bookmarkIds: [childPost.id],
      ),
    ],
  );

  ExportSelectionDescriptor descriptorFor(BookmarkBackupData data) =>
      ExportSelectionDescriptor.collection(
        id: 'bookmarks',
        children: bookmarkExportNodes(data),
      );

  test(
    'deselecting a selected child preserves the parent direct Group item',
    () {
      final descriptor = descriptorFor(hierarchy);
      final container = ProviderContainer(
        overrides: [
          loggerProvider.overrideWithValue(AppLogger()),
          exportImportSourcesProvider.overrideWithValue([
            _BookmarkSource(descriptor),
          ]),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(exportFlowProvider.notifier)
        ..useCustomExport();

      final parentNode = descriptor.findNode(rootNodeId)!;
      final childNode = descriptor.findNode(childNodeId)!;
      expect(parentNode.isCollection, isTrue);
      expect(parentNode.children.single.id, childNodeId);

      notifier.toggleNode(descriptor, parentNode);
      expect(
        container
            .read(exportFlowProvider)
            .nodes['bookmarks']!
            .resolve(descriptor),
        {rootNodeId, childNodeId},
      );

      notifier.toggleNode(descriptor, childNode);

      final partialSelection = container
          .read(exportFlowProvider)
          .nodes['bookmarks'];
      expect(partialSelection?.resolve(descriptor), {rootNodeId});
      expect(partialSelection!.childIds, {'group-direct:$rootId'});
      final scoped = buildBookmarkBackupData(
        records: hierarchy.records,
        groups: [
          for (final group in hierarchy.groups)
            BookmarkGroup(
              id: group.id!,
              name: group.name,
              bookmarkIds: group.bookmarkIds.toSet(),
              parentGroupId: group.parentGroupId,
            ),
        ],
        scope: BookmarkExportScope.selected(
          groupIds: const [],
          directGroupIds: partialSelection.childIds
              .map(ExportSelectionIds.bookmarkGroupDirectId)
              .whereType<String>(),
        ),
      );
      expect(scoped.records.map((record) => record.id), [parentPost.id]);
      expect(scoped.groups.map((group) => group.id), [rootId]);
      expect(
        const ImportSourceIntegrityValidator().validate(
          sourceId: 'bookmarks',
          packageSchemaVersion: 10,
          supportedSchemaVersion: 10,
          selection: partialSelection,
          itemRecommendations: const {},
          data: scoped,
        ),
        isEmpty,
      );
      expect(
        ExportNodeSelection.fromJson(partialSelection.toJson())
            .resolve(descriptor),
        {rootNodeId},
      );
    },
  );

  test('deep selection traversal and equality stay iterative', () {
    final rows = [
      for (var i = 0; i < 10000; i++)
        BookmarkGroupBackup(
          id: 'node-$i',
          name: 'Node $i',
          bookmarkIds: const [],
          parentGroupId: i == 0 ? null : 'node-${i - 1}',
        ),
    ];
    final data = BookmarkBackupData.unified(records: const [], groups: rows);
    final first = descriptorFor(data).rootNodes.single;
    final second = descriptorFor(data).rootNodes.single;
    expect(first.allIds, hasLength(10000));
    expect(first.find('group:node-9999'), isNotNull);
    expect(first == second, isTrue);
    expect(first.hashCode, second.hashCode);
  });

  test('empty group remains a selectable node in the export tree', () {
    const emptyGroupId = '33333333-3333-4333-8333-333333333333';
    final descriptor = descriptorFor(
      BookmarkBackupData.unified(
        records: const <Bookmark>[],
        groups: const [
          BookmarkGroupBackup(
            id: emptyGroupId,
            name: 'Empty group',
            bookmarkIds: [],
          ),
        ],
      ),
    );

    expect(descriptor.children, hasLength(1));
    expect(descriptor.children.single.id, 'group:$emptyGroupId');
    expect(descriptor.children.single.isCollection, isFalse);
  });
}

class _BookmarkSource implements ExportImportSource {
  const _BookmarkSource(this.selectionDescriptor);

  @override
  final ExportSelectionDescriptor selectionDescriptor;

  @override
  String get id => 'bookmarks';

  @override
  int get priority => 0;

  @override
  int get schemaVersion => 10;

  @override
  Future<ExportSourceSnapshot> capture(ExportSourceRequest request) =>
      throw UnimplementedError();
}
