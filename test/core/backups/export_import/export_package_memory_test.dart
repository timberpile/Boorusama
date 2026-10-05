// Dart imports:
import 'dart:io';
import 'dart:math';

// Package imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:boorusama/core/backups/export_import/package/export_package_reader.dart';
import 'package:boorusama/core/backups/export_import/package/export_package_writer.dart';
import 'package:boorusama/foundation/filesystem.dart';

void main() {
  test('round trips a large part through file streams', () async {
    final directory = await Directory.systemTemp.createTemp('bsexport_large_');
    addTearDown(() => directory.delete(recursive: true));
    const bytes = 50 * 1024 * 1024;
    const writer = ExportPackageWriter(fs: IoFileSystem());
    final output = await writer.write(
      ExportPackageBuild(
        createdAt: DateTime.utc(2026),
        appVersion: '1',
        sources: [
          ExportPackageSourceBuild(
            id: 'bookmarks',
            schemaVersion: 3,
            parts: [
              ExportPackagePartBuild(
                path: 'sources/bookmarks/data.json',
                write: (path) async {
                  final sink = File(path).openWrite();
                  final random = Random(1);
                  final chunk = List<int>.generate(
                    1024 * 1024,
                    (_) => random.nextInt(256),
                    growable: false,
                  );
                  for (var i = 0; i < 50; i++) {
                    sink.add(chunk);
                  }
                  await sink.close();
                },
              ),
            ],
          ),
        ],
      ),
      '${directory.path}/large.bsexport',
    );

    final staged = await const ExportPackageReader(
      fs: IoFileSystem(),
    ).stage(output);
    addTearDown(staged.dispose);
    expect(
      File(staged.pathFor('sources/bookmarks/data.json')).lengthSync(),
      bytes,
    );
  }, timeout: const Timeout(Duration(minutes: 2)));
}
