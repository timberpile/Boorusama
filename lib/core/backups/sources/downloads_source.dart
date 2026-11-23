// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

// Project imports:
import '../../../foundation/filesystem.dart';
import '../../bulk_downloads/providers.dart';
import '../widgets/backup_restore_tile.dart';
import 'sqlite_import_contract.dart';
import 'sqlite_source.dart';

class DownloadsBackupSource extends SqliteBackupSource {
  DownloadsBackupSource(Ref ref)
    : super(
        id: 'downloads',
        importContract: SqliteImportContract.downloads,
        priority: 4,
        ref: ref,
        dbPathGetter: () => getDownloadsDbPath(ref.read(appFileSystemProvider)),
        dbFileName: kDownloadDbName,
        onImportComplete: () =>
            ref.invalidate(internalDownloadRepositoryProvider),
        initializeDatabase: SqliteImportContract.downloads.initializeDatabase,
      );

  @override
  String get displayName => 'Downloads';

  @override
  Widget buildTile(BuildContext context) {
    return DefaultBackupTile(
      source: this,
      title: 'Bulk downloads',
      icon: Symbols.folder_zip,
      fileExtensions: const ['db'],
      forceAnyFileType: true,
    );
  }
}
