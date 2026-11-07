import 'package:boorusama/core/bookmarks/src/services/bookmark_hierarchy_conversion.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_group.dart';
import 'package:boorusama/core/groups/folder_tree.dart';
import 'package:test/test.dart';

const defaultId = defaultBookmarkGroupId;
const groupId = '10000000-0000-4000-8000-000000000001';
const folderId = '20000000-0000-4000-8000-000000000002';
const childFolderId = '30000000-0000-4000-8000-000000000003';

BookmarkGroup legacyGroup(
  String id, {
  String? folder,
  Set<int> bookmarks = const {},
  Map<int, DateTime> addedAt = const {},
  int position = 0,
  String? name,
}) => BookmarkGroup(
  id: id,
  name: name ?? (id == defaultId ? 'Default' : id),
  folderId: folder,
  position: position,
  bookmarkIds: bookmarks,
  addedAt: addedAt,
);

void main() {
  group('BookmarkHierarchyConversion', () {
    test('moves legacy group folder references into parentGroupId', () {
      final addedAt = DateTime.utc(2025, 2, 3, 4, 5, 6);
      final result = BookmarkHierarchyConversion.convert(
        groups: [
          legacyGroup(defaultId, bookmarks: {1}),
          legacyGroup(
            groupId,
            folder: folderId,
            bookmarks: {2, 99_001},
            addedAt: {2: addedAt},
          ),
        ],
        folders: [
          const CollectionFolder(id: folderId, name: 'Folder'),
        ],
      );

      final defaultGroup = result.groups.singleWhere((g) => g.id == defaultId);
      final converted = result.groups.singleWhere((g) => g.id == groupId);
      expect(defaultGroup.parentGroupId, isNull);
      expect(defaultGroup.folderId, isNull);
      expect(converted.id, groupId);
      expect(converted.parentGroupId, folderId);
      expect(converted.folderId, isNull);
      expect(converted.bookmarkIds, {2, 99_001});
      expect(converted.addedAt, {2: addedAt});
    });

    test('converts empty folders and retains duplicate display names', () {
      final result = BookmarkHierarchyConversion.convert(
        groups: [legacyGroup(groupId, name: 'Shared')],
        folders: [
          const CollectionFolder(id: folderId, name: 'Shared'),
        ],
      );

      final convertedFolder = result.groups.singleWhere(
        (g) => g.id == folderId,
      );
      expect(convertedFolder.name, 'Shared');
      expect(convertedFolder.bookmarkIds, isEmpty);
      expect(convertedFolder.parentGroupId, isNull);
      expect(convertedFolder.folderId, isNull);
      expect(result.groups.map((g) => g.name), contains('Shared'));
      expect(result.groups.where((g) => g.name == 'Shared'), hasLength(2));
    });

    test(
      'remaps a colliding folder ID consistently through its descendants',
      () {
        final first = BookmarkHierarchyConversion.convert(
          groups: [legacyGroup(folderId)],
          folders: [
            const CollectionFolder(id: folderId, name: 'Former folder'),
            const CollectionFolder(
              id: childFolderId,
              name: 'Child',
              parentId: folderId,
            ),
          ],
        );
        final second = BookmarkHierarchyConversion.convert(
          groups: [legacyGroup(folderId)],
          folders: [
            const CollectionFolder(id: folderId, name: 'Former folder'),
            const CollectionFolder(
              id: childFolderId,
              name: 'Child',
              parentId: folderId,
            ),
          ],
        );

        final mappedFolderId = first.folderIdMapping[folderId]!;
        expect(mappedFolderId, isNot(folderId));
        expect(second.folderIdMapping, first.folderIdMapping);
        expect(first.groups.map((g) => g.id), contains(folderId));
        final child = first.groups.singleWhere((g) => g.id == childFolderId);
        expect(child.parentGroupId, mappedFolderId);
        expect(
          first.groups.singleWhere((g) => g.id == mappedFolderId).name,
          'Former folder',
        );
      },
    );

    test(
      'reuses a supplied collision mapping and rejects invalid mappings',
      () {
        const remapped = '40000000-0000-4000-8000-000000000004';
        final folders = [
          const CollectionFolder(id: folderId, name: 'Former folder'),
        ];
        final result = BookmarkHierarchyConversion.convert(
          groups: [legacyGroup(folderId)],
          folders: folders,
          folderIdMapping: {folderId: remapped},
        );
        expect(result.folderIdMapping[folderId], remapped);
        expect(result.groups.map((g) => g.id), contains(remapped));

        expect(
          () => BookmarkHierarchyConversion.convert(
            groups: [legacyGroup(folderId)],
            folders: folders,
            folderIdMapping: {folderId: folderId},
          ),
          throwsFormatException,
        );
        expect(
          () => BookmarkHierarchyConversion.convert(
            groups: [legacyGroup(folderId)],
            folders: folders,
            folderIdMapping: {folderId: remapped, childFolderId: remapped},
          ),
          throwsFormatException,
        );
        expect(
          () => BookmarkHierarchyConversion.convert(
            groups: [legacyGroup(folderId)],
            folders: folders,
            folderIdMapping: {childFolderId: remapped},
          ),
          throwsFormatException,
        );
      },
    );

    test('rejects invalid group or folder placement inputs', () {
      expect(
        () => BookmarkHierarchyConversion.convert(
          groups: [legacyGroup(defaultId, folder: folderId)],
          folders: [
            const CollectionFolder(id: folderId, name: 'Parent'),
          ],
        ),
        throwsFormatException,
      );
      expect(
        () => BookmarkHierarchyConversion.convert(
          groups: [legacyGroup(groupId, folder: 'missing')],
          folders: const [],
        ),
        throwsFormatException,
      );
      expect(
        () => BookmarkHierarchyConversion.convert(
          groups: const [],
          folders: [
            const CollectionFolder(
              id: folderId,
              name: 'Cycle A',
              parentId: childFolderId,
            ),
            const CollectionFolder(
              id: childFolderId,
              name: 'Cycle B',
              parentId: folderId,
            ),
          ],
        ),
        throwsFormatException,
      );
    });

    test('uses deterministic ordering when sibling positions collide', () {
      final first = BookmarkHierarchyConversion.convert(
        groups: [legacyGroup(groupId, position: 4)],
        folders: [
          const CollectionFolder(id: folderId, name: 'Folder', position: 4),
        ],
      );
      final second = BookmarkHierarchyConversion.convert(
        groups: [legacyGroup(groupId, position: 4)],
        folders: [
          const CollectionFolder(id: folderId, name: 'Folder', position: 4),
        ],
      );

      expect(
        first.groups.map((g) => (g.id, g.position)),
        second.groups.map((g) => (g.id, g.position)),
      );
    });
  });
}
