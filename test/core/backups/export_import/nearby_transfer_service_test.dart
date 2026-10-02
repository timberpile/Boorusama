import 'dart:convert';
import 'dart:io';

import 'package:boorusama/core/backups/export_import/export/export_service.dart';
import 'package:boorusama/core/backups/export_import/models/export_selection.dart';
import 'package:boorusama/core/backups/export_import/nearby/nearby_transfer_service.dart';
import 'package:boorusama/core/backups/export_import/package/export_package_reader.dart';
import 'package:boorusama/core/backups/export_import/package/export_package_writer.dart';
import 'package:boorusama/core/backups/export_import/sources/export_import_source.dart';
import 'package:boorusama/foundation/filesystem.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('nearby_export_');
  });

  tearDown(() => directory.delete(recursive: true));

  test('nearby transfer creates one full credential-bearing package', () async {
    final sources = [_Source('profiles'), _Source('bookmarks')];
    final service = NearbyExportService(
      exportService: ExportService(
        sources: () => sources,
        writer: const ExportPackageWriter(fs: IoFileSystem()),
        appVersion: '1.0.0',
      ),
      catalog: NearbyExportCatalog([
        for (final source in sources) source.selectionDescriptor,
      ]),
      fs: const IoFileSystem(),
    );

    final package = await service.createFullPackage();
    final staged = await const ExportPackageReader(
      fs: IoFileSystem(),
    ).stage(package.path);
    addTearDown(staged.dispose);

    expect(staged.manifest.containsCredentials, isTrue);
    expect(staged.manifest.preset, ExportSelectionMode.full);
    expect(staged.manifest.sources.map((source) => source.id), [
      'profiles',
      'bookmarks',
    ]);
    expect(
      sources.map((source) => source.credentialsIncluded),
      everyElement(isTrue),
    );

    await package.dispose();
    expect(File(package.path).existsSync(), isFalse);
  });
}

final class _Source implements ExportImportSource {
  _Source(this.id);

  @override
  final String id;
  bool? credentialsIncluded;

  @override
  int get priority => 0;

  @override
  int get schemaVersion => 1;

  @override
  ExportSelectionDescriptor get selectionDescriptor =>
      ExportSelectionDescriptor.leaf(id: id);

  @override
  Future<ExportSourceSnapshot> capture(ExportSourceRequest request) async {
    credentialsIncluded = request.includeCredentials;
    return ExportSourceSnapshot.json(
      sourceId: id,
      schemaVersion: schemaVersion,
      json: jsonEncode({'id': id}),
    );
  }
}
