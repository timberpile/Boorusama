import 'package:boorusama/core/backups/export_import/import/collection_import_action.dart';
import 'package:boorusama/core/backups/export_import/models/import_action.dart';
import 'package:boorusama/core/backups/sources/bookmark_backup_codec.dart';
import 'package:boorusama/core/backups/sources/bookmark_backup_data.dart';
import 'package:boorusama/core/backups/sources/pinned_search_backup_codec.dart';
import 'package:boorusama/core/backups/sources/pinned_search_backup_data.dart';
import 'package:boorusama/core/backups/sources/pinned_search_import_service.dart';
import 'package:boorusama/core/backups/sources/search_backup_profile.dart';
import 'package:boorusama/core/backups/types.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/groups/folder_tree.dart';
import 'package:boorusama/core/search/subscriptions/src/data/hive/search_subscription_repository_hive.dart';
import 'package:boorusama/core/search/subscriptions/types.dart';
import 'package:flutter_test/flutter_test.dart';
import '../search/subscriptions/subscription_test_utils.dart';

String _id(int n) => '00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';
final _profile = BooruConfig.fromJson({
  ...BooruConfig.empty.toJson(),
  'id': _id(30),
  'booruIdHint': BooruType.danbooru.id,
  'url': 'https://example.test',
  'name': 'Profile',
});
final _reference = BackupProfileReference(
  id: _id(30),
  booruType: 'danbooru',
  url: 'https://example.test',
  name: 'Profile',
);
ExportDataPayload _payload(
  String source,
  int version,
  List<dynamic> rows, {
  Map<String, dynamic> extra = const {},
}) => ExportDataPayload(
  version: version,
  exportDate: null,
  exportVersion: null,
  data: rows,
  extraFields: {'source': source, ...extra},
);
PinnedSearchBackupData _nested() => PinnedSearchBackupData(
  records: [
    PinnedSearchBackupRecord(
      id: _id(1),
      name: 'One',
      query: 'cat',
      position: 0,
      profile: _reference,
      folderId: _id(12),
      folderPosition: 0,
    ),
    PinnedSearchBackupRecord(
      id: _id(2),
      name: 'Two',
      query: 'dog',
      position: 1,
      profile: _reference,
      folderId: _id(12),
      folderPosition: 1,
    ),
  ],
  folders: [
    PinnedSearchFolderBackupRecord(
      id: _id(10),
      name: 'Literal // root',
      position: 0,
      searchIds: [],
    ),
    PinnedSearchFolderBackupRecord(
      id: _id(11),
      name: 'Middle',
      parentId: _id(10),
      position: 0,
      searchIds: [],
    ),
    PinnedSearchFolderBackupRecord(
      id: _id(12),
      name: 'Leaf',
      parentId: _id(11),
      position: 0,
      searchIds: [_id(1), _id(2)],
    ),
    PinnedSearchFolderBackupRecord(
      id: _id(13),
      name: 'Empty',
      parentId: _id(11),
      position: 1,
      searchIds: [],
    ),
  ],
);

class _FailOnceFolders extends MemoryBox<dynamic> {
  bool failNextWrite = false;
  @override
  Future<void> put(dynamic key, dynamic value) async {
    await super.put(key, value);
    if (failNextWrite) {
      failNextWrite = false;
      throw StateError('Injected organization failure');
    }
  }
}

void main() {
  test(
    'flat pin imports retain exported Home order after existing local pins',
    () async {
      final repository = memorySubscriptionRepository();
      final local = await repository.create(
        profileId: _id(30),
        query: 'local',
        name: null,
      );
      final records = _nested().records;
      await PinnedSearchImportService(repository: repository).apply(
        PinnedSearchBackupData(
          records: records,
          homeSearchIds: [_id(2), _id(1)],
        ),
        profiles: [_profile],
      );
      expect((await repository.getOrganization()).homeSearchIds, [
        local.id,
        _id(2),
        _id(1),
      ]);
    },
  );
  test(
    'version-2 pin backups store leaf placements and restore exact nested and empty folders',
    () async {
      final codec = PinnedSearchBackupCodec();
      final original = _nested();
      final encoded = codec.encode(original);
      expect(
        encoded
            .where((r) => r['kind'] == 'folder')
            .every((r) => !r.containsKey('searchIds')),
        isTrue,
      );
      final parsed = codec.parse(_payload('pinned_searches', 2, encoded));
      expect(parsed, original);
      final repository = memorySubscriptionRepository();
      await PinnedSearchImportService(
        repository: repository,
      ).replace(parsed, profiles: [_profile]);
      final saved = await repository.getOrganization();
      expect(saved.folders.map((f) => f.id), original.folders.map((f) => f.id));
      expect(saved.tree.path(_id(13)), 'Literal // root / Middle / Empty');
      expect(saved.recursiveIds(_id(10)), [_id(1), _id(2)]);
      expect(saved.homeSearchIds, isEmpty);
    },
  );
  test(
    'ordinary pin copies reconstruct paths once and preserve existing cached state and placement',
    () async {
      final repository = memorySubscriptionRepository();
      final existing = await repository.create(
        profileId: _id(30),
        query: 'cat',
        name: 'Local',
        id: _id(1),
      );
      await repository.recordRefreshFailure(
        existing.id,
        expectedCreatedAt: existing.createdAt,
        attemptedAt: DateTime.utc(2026),
        kind: SearchRefreshErrorKind.network,
      );
      final before = await repository.getById(existing.id);
      final service = PinnedSearchImportService(repository: repository);
      await service.apply(_nested(), profiles: [_profile]);
      final organization = await repository.getOrganization();
      expect(await repository.getById(existing.id), before);
      expect(organization.homeSearchIds, [existing.id]);
      expect(
        organization.folders.where((f) => f.parentId == null).single.name,
        'Imported Searches',
      );
      final leaf = organization.folders.singleWhere((f) => f.name == 'Leaf');
      expect(leaf.searchIds, [_id(2)]);
      expect(
        organization.tree.path(leaf.id),
        'Imported Searches / Literal // root / Middle / Leaf',
      );
      expect(
        organization.folders
            .map((f) => f.id)
            .toSet()
            .intersection(_nested().folders.map((f) => f.id).toSet()),
        isEmpty,
      );
      await service.apply(_nested(), profiles: [_profile]);
      expect(await repository.getOrganization(), organization);
    },
  );
  test(
    'explicit folder Copy can retain empty branches without moving reused searches',
    () async {
      final repository = memorySubscriptionRepository();
      final existing = await repository.create(
        profileId: _id(30),
        query: 'cat',
        name: null,
        id: _id(1),
      );
      await PinnedSearchImportService(repository: repository).apply(
        _nested(),
        profiles: [_profile],
        recordActions: {_id(2): ImportAction.skip},
        folderActions: {
          _id(13): CollectionImportAction(
            itemId: _id(13),
            action: ImportAction.copy,
          ),
        },
      );
      final saved = await repository.getOrganization();
      expect(saved.homeSearchIds, [existing.id]);
      expect(
        saved.folders.singleWhere((f) => f.name == 'Empty').searchIds,
        isEmpty,
      );
      expect(saved.folders.map((f) => f.name), [
        'Imported Searches',
        'Literal // root',
        'Middle',
        'Empty',
      ]);
    },
  );
  test(
    'failed pin import restores organization and removes newly created subscriptions',
    () async {
      final storage = _FailOnceFolders();
      final repository = HiveSearchSubscriptionRepository(
        box: MemorySubscriptionBox(),
        organizationBox: storage,
      );
      final existing = await repository.create(
        profileId: _id(30),
        query: 'local',
        name: null,
      );
      final before = await repository.getOrganization();
      storage.failNextWrite = true;
      await expectLater(
        PinnedSearchImportService(
          repository: repository,
        ).apply(_nested(), profiles: [_profile]),
        throwsStateError,
      );
      expect(await repository.getAll(), [existing]);
      expect(await repository.getOrganization(), before);
    },
  );
  test(
    'selective pin export keeps empty-folder ancestors and excludes sibling searches',
    () {
      final selected = filterPinnedSearchBackupData(
        _nested(),
        PinnedSearchExportScope.selected(
          searchIds: [],
          folderIds: [_id(13)],
          includeHome: false,
        ),
      );
      expect(selected.records, isEmpty);
      expect(selected.folders.map((f) => f.id), [_id(10), _id(11), _id(13)]);
      final parsed = PinnedSearchBackupCodec().parse(
        _payload(
          'pinned_searches',
          2,
          PinnedSearchBackupCodec().encode(selected),
        ),
      );
      expect(parsed, selected);
    },
  );
  test(
    'bookmark version-5 round trip preserves empty nesting without a groups field',
    () {
      final folders = [
        CollectionFolder(id: _id(10), name: 'Root'),
        CollectionFolder(id: _id(11), name: 'Empty', parentId: _id(10)),
      ];
      final parsed = BookmarkBackupCodec().parse(
        _payload(
          'bookmarks',
          5,
          [],
          extra: {'folders': folders.map((f) => f.toJson()).toList()},
        ),
      );
      expect(parsed.folders, folders);
      expect(parsed.groups, isEmpty);
      final group = BookmarkGroupBackup(
        id: _id(1),
        name: 'Literal // group',
        bookmarkIds: [],
        folderId: _id(11),
        position: 3,
      );
      final data = BookmarkBackupData(
        bookmarks: [],
        groups: [group],
        folders: folders,
      );
      expect(
        BookmarkBackupCodec().parse(
          _payload('bookmarks', 5, [], extra: data.extraFields),
        ),
        data,
      );
    },
  );
  test(
    'malformed or cyclic backup relationships fail with the public format exception before import',
    () {
      final codec = BookmarkBackupCodec();
      for (final folders in [
        [
          {'id': 'not-a-uuid', 'name': 'Root', 'parentId': null, 'position': 0},
        ],
        [
          {'id': _id(10), 'name': 'Root', 'parentId': _id(10), 'position': 0},
        ],
      ]) {
        expect(
          () => codec.parse(
            _payload('bookmarks', 5, [], extra: {'folders': folders}),
          ),
          throwsA(isA<InvalidBackupFormatException>()),
        );
      }
      for (final placement in [
        {'folderId': 1, 'position': 0},
        {'folderId': null, 'position': 'bad'},
      ]) {
        expect(
          () => codec.parse(
            _payload(
              'bookmarks',
              5,
              [],
              extra: {
                'groups': [
                  {
                    'id': _id(1),
                    'name': 'Group',
                    'bookmarkIds': <int>[],
                    ...placement,
                  },
                ],
              },
            ),
          ),
          throwsA(isA<InvalidBackupFormatException>()),
        );
      }
      final pinned = PinnedSearchBackupCodec();
      final encoded = pinned.encode(_nested());
      (encoded.first as Map)['parentId'] = _id(12);
      expect(
        () => pinned.parse(_payload('pinned_searches', 2, encoded)),
        throwsA(isA<InvalidBackupFormatException>()),
      );
    },
  );
}
