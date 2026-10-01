// Dart imports:
import 'dart:convert';
import 'dart:io';

// Package imports:
import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:boorusama/core/backups/export_import/package/export_package_writer.dart';
import 'package:boorusama/foundation/filesystem.dart';

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('bsexport_writer_');
  });

  tearDown(() => directory.delete(recursive: true));

  test(
    'writes checksummed parts and atomically publishes a bsexport',
    () async {
      const writer = ExportPackageWriter(fs: IoFileSystem());
      final path = await writer.write(
        ExportPackageBuild(
          createdAt: DateTime.utc(2026, 10),
          appVersion: '1.2.3',
          sources: [
            ExportPackageSourceBuild(
              id: 'bookmarks',
              schemaVersion: 3,
              parts: [
                ExportPackagePartBuild(
                  path: 'sources/bookmarks/data.json',
                  write: (path) => File(path).writeAsString('{"ok":true}'),
                ),
              ],
            ),
          ],
        ),
        '${directory.path}/shared',
      );

      expect(path, endsWith('.bsexport'));
      expect(File(path).existsSync(), isTrue);
      expect(File('$path.tmp').existsSync(), isFalse);

      final input = InputFileStream(path);
      final archive = ZipDecoder().decodeStream(input);
      final manifest =
          jsonDecode(
                utf8.decode(archive.find('manifest.json')!.readBytes()!),
              )
              as Map<String, dynamic>;
      final part =
          ((manifest['sources'] as List).single as Map)['parts'] as List;
      expect((part.single as Map)['byteLength'], 11);
      expect((part.single as Map)['sha256'], hasLength(64));
      await archive.clear();
      await input.close();
    },
  );

  test('does not publish a package when a source part fails', () async {
    final output = '${directory.path}/failed.bsexport';
    const writer = ExportPackageWriter(fs: IoFileSystem());

    await expectLater(
      writer.write(
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
                  write: (_) => throw StateError('capture failed'),
                ),
              ],
            ),
          ],
        ),
        output,
      ),
      throwsStateError,
    );

    expect(File(output).existsSync(), isFalse);
    expect(File('$output.tmp').existsSync(), isFalse);
  });
}
