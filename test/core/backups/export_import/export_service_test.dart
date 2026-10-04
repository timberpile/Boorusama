// Dart imports:
import 'dart:convert';
import 'dart:io';

// Package imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:boorusama/core/backups/export_import/export/export_service.dart';
import 'package:boorusama/core/backups/export_import/models/export_selection.dart';
import 'package:boorusama/core/backups/export_import/models/import_action.dart';
import 'package:boorusama/core/backups/export_import/package/export_package_reader.dart';
import 'package:boorusama/core/backups/export_import/package/export_package_writer.dart';
import 'package:boorusama/core/backups/export_import/sources/export_import_source.dart';
import 'package:boorusama/core/backups/export_import/sources/export_selection_ids.dart';
import 'package:boorusama/core/backups/sources/following_feed_backup_data.dart';
import 'package:boorusama/core/backups/sources/pinned_search_backup_data.dart';
import 'package:boorusama/core/backups/sources/search_backup_profile.dart';
import 'package:boorusama/core/backups/types/backup_registry.dart';
import 'package:boorusama/foundation/filesystem.dart';

void main() {
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('export_service_');
  });
  tearDown(() => directory.delete(recursive: true));

  test(
    'full export resolves every current source and enables credentials',
    () async {
      final registry = BackupRegistry()
        ..registerDescriptor(const ExportSelectionDescriptor.leaf(id: 'first'));
      final sources = <ExportImportSource>[_FakeSource('first')];
      final selection = ExportSelection.full(registry);
      sources.add(_FakeSource('later'));
      registry.registerDescriptor(
        const ExportSelectionDescriptor.leaf(id: 'later'),
      );
      final service = ExportService(
        sources: () => sources,
        writer: const ExportPackageWriter(fs: IoFileSystem()),
        appVersion: '1',
      );

      final path = await service.createPackage(
        ExportRequest(
          selection: selection,
          outputPath: '${directory.path}/full',
        ),
      );
      final staged = await const ExportPackageReader(
        fs: IoFileSystem(),
      ).stage(path);
      addTearDown(staged.dispose);

      expect(staged.manifest.sources.map((source) => source.id), {
        'first',
        'later',
      });
      expect(staged.manifest.format, 'boorusama-export');
      expect(staged.manifest.exportId, isNotEmpty);
      expect(staged.manifest.preset, ExportSelectionMode.full);
      expect(staged.manifest.containsCredentials, isTrue);
      for (final source in staged.manifest.sources) {
        expect(source.selection, ExportNodeSelection.all(source.id));
      }
      for (final source in sources.cast<_FakeSource>()) {
        expect(source.lastRequest!.includeCredentials, isTrue);
      }
    },
  );

  test('custom export records exact selections and recommendations', () async {
    final service = ExportService(
      sources: () => [_FakeSource('bookmarks')],
      writer: const ExportPackageWriter(fs: IoFileSystem()),
      appVersion: '1',
    );
    const selection = ExportNodeSelection.explicit('bookmarks', {'group-a'});

    final path = await service.createPackage(
      ExportRequest(
        selection: ExportSelection.custom(const {'bookmarks': selection}),
        outputPath: '${directory.path}/custom',
        recommendedActions: const {'bookmarks': ImportAction.merge},
        itemRecommendedActions: const {
          'bookmarks': {
            'group-a': ImportAction.update,
            'group-b': ImportAction.merge,
          },
        },
      ),
    );
    final staged = await const ExportPackageReader(
      fs: IoFileSystem(),
    ).stage(path);
    addTearDown(staged.dispose);

    expect(staged.manifest.preset, ExportSelectionMode.custom);
    expect(staged.manifest.containsCredentials, isFalse);
    expect(staged.manifest.sources.single.selection, selection);
    expect(
      staged.manifest.sources.single.recommendedAction,
      ImportAction.merge,
    );
    expect(staged.manifest.sources.single.itemRecommendedActions, const {
      'group-a': ImportAction.update,
      'group-b': ImportAction.merge,
    });
  });

  test('a source failure publishes no package', () async {
    final source = _FakeSource('broken', fail: true);
    final service = ExportService(
      sources: () => [source],
      writer: const ExportPackageWriter(fs: IoFileSystem()),
      appVersion: '1',
    );
    final output = '${directory.path}/failed.bsexport';

    await expectLater(
      service.createPackage(
        ExportRequest(
          selection: ExportSelection.custom(const {
            'broken': ExportNodeSelection.leaf('broken'),
          }),
          outputPath: output,
        ),
      ),
      throwsStateError,
    );
    expect(File(output).existsSync(), isFalse);
  });

  test('explicit pinned search folders include their current children', () {
    final data = PinnedSearchBackupData(
      records: [_pinned('one'), _pinned('two'), _pinned('three')],
      folders: const [
        PinnedSearchFolderBackupRecord(
          id: 'folder',
          name: 'Folder',
          position: 0,
          searchIds: ['one', 'two'],
        ),
      ],
      homeSearchIds: const ['three'],
    );

    final result = filterPinnedSearchBackupData(
      data,
      PinnedSearchExportScope.selected(
        searchIds: const ['three'],
        folderIds: const ['folder'],
        includeHome: false,
      ),
    );

    expect(result.records.map((record) => record.id), ['one', 'two', 'three']);
    expect(result.folders.single.searchIds, ['one', 'two']);
    expect(result.homeSearchIds, ['three']);
  });

  test('selected searches retain only their containing folder structure', () {
    final data = PinnedSearchBackupData(
      records: [_pinned('one'), _pinned('two'), _pinned('home')],
      folders: const [
        PinnedSearchFolderBackupRecord(
          id: 'folder',
          name: 'Folder',
          position: 0,
          searchIds: ['one', 'two'],
        ),
      ],
      homeSearchIds: const ['home'],
    );

    final result = filterPinnedSearchBackupData(
      data,
      PinnedSearchExportScope.selected(
        searchIds: const ['two'],
        folderIds: const [],
        includeHome: false,
      ),
    );

    expect(result.records.map((record) => record.id), ['two']);
    expect(result.folders, const [
      PinnedSearchFolderBackupRecord(
        id: 'folder',
        name: 'Folder',
        position: 0,
        searchIds: ['two'],
      ),
    ]);
    expect(result.homeSearchIds, isEmpty);
  });

  test(
    'Home selection follows current members while explicit searches do not',
    () {
      final data = PinnedSearchBackupData(
        records: [_pinned('one'), _pinned('two'), _pinned('stale-safe')],
        homeSearchIds: const ['one', 'two'],
      );

      final dynamicHome = filterPinnedSearchBackupData(
        data,
        PinnedSearchExportScope.selected(
          searchIds: const [],
          folderIds: const [],
          includeHome: true,
        ),
      );
      final explicitHomeMember = filterPinnedSearchBackupData(
        data,
        PinnedSearchExportScope.selected(
          searchIds: const ['one', 'missing'],
          folderIds: const ['missing'],
          includeHome: false,
        ),
      );

      expect(dynamicHome.records.map((record) => record.id), ['one', 'two']);
      expect(dynamicHome.homeSearchIds, ['one', 'two']);
      expect(explicitHomeMember.records.map((record) => record.id), ['one']);
      expect(explicitHomeMember.homeSearchIds, ['one']);
      expect(explicitHomeMember.folders, isEmpty);
    },
  );

  test('explicit following feed selection excludes every other feed', () {
    final data = FollowingFeedBackupData(
      feeds: [_feed('one'), _feed('two')],
    );

    final result = filterFollowingFeedBackupData(
      data,
      FollowingFeedExportScope.selected(const ['two']),
    );

    expect(result.feeds.map((feed) => feed.id), ['two']);
  });

  test('selection child identities round trip without ambiguous prefixes', () {
    expect(
      ExportSelectionIds.bookmarkGroupId(
        ExportSelectionIds.bookmarkGroup('group-id'),
      ),
      'group-id',
    );
    expect(
      ExportSelectionIds.pinnedSearchFolderId(
        ExportSelectionIds.pinnedSearchFolder('folder-id'),
      ),
      'folder-id',
    );
    expect(
      ExportSelectionIds.profileId(
        ExportSelectionIds.profile('00000000-0000-4000-8000-00000000002a'),
      ),
      '00000000-0000-4000-8000-00000000002a',
    );
    expect(ExportSelectionIds.pinnedSearchHome, 'home');
    expect(ExportSelectionIds.profileId('search:42'), isNull);
  });
}

const _profile = BackupProfileReference(
  id: '00000000-0000-4000-8000-000000000001',
  booruType: 'gelbooruV2',
  url: 'https://example.com',
  name: 'Example',
);

PinnedSearchBackupRecord _pinned(String id) => PinnedSearchBackupRecord(
  id: id,
  name: id,
  query: id,
  position: 0,
  profile: _profile,
);

FollowingFeedBackupRecord _feed(String id) => FollowingFeedBackupRecord(
  id: id,
  name: id,
  position: 0,
  queries: const ['tag'],
  profile: _profile,
);

final class _FakeSource implements ExportImportSource {
  _FakeSource(this.id, {this.fail = false});

  @override
  final String id;
  final bool fail;
  ExportSourceRequest? lastRequest;

  @override
  int get priority => 0;

  @override
  int get schemaVersion => 1;

  @override
  ExportSelectionDescriptor get selectionDescriptor =>
      ExportSelectionDescriptor.leaf(id: id);

  @override
  Future<ExportSourceSnapshot> capture(ExportSourceRequest request) async {
    lastRequest = request;
    if (fail) throw StateError('capture failed');
    return ExportSourceSnapshot.json(
      sourceId: id,
      schemaVersion: schemaVersion,
      json: jsonEncode({'credentials': request.includeCredentials}),
    );
  }
}
