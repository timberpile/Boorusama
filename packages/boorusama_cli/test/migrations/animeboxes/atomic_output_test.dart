import 'dart:io';
import 'dart:convert';

import 'package:boorusama_cli/src/migrations/animeboxes/atomic_output.dart';
import 'package:test/test.dart';

void main() {
  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'boorusama-animeboxes-atomic-',
    );
  });

  tearDown(() async {
    if (temporaryDirectory.existsSync()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('atomically writes one final file without a temp sibling', () async {
    final target = File('${temporaryDirectory.path}/normalized.json');

    await const AtomicMigrationOutput().writeFile(
      target: target,
      contents: 'complete',
    );

    expect(await target.readAsString(), 'complete');
    expect(await _temporarySiblings(temporaryDirectory), isEmpty);
  });

  test('leaves an existing file byte-for-byte unchanged', () async {
    final target = File('${temporaryDirectory.path}/normalized.json');
    await target.writeAsString('original');

    await expectLater(
      const AtomicMigrationOutput().writeFile(
        target: target,
        contents: 'replacement',
      ),
      throwsA(isA<AtomicMigrationOutputException>()),
    );

    expect(await target.readAsString(), 'original');
    expect(await _temporarySiblings(temporaryDirectory), isEmpty);
  });

  test('rejects a missing parent without creating a final file', () async {
    final target = File(
      '${temporaryDirectory.path}/missing/normalized.json',
    );

    await expectLater(
      const AtomicMigrationOutput().writeFile(
        target: target,
        contents: 'complete',
      ),
      throwsA(isA<AtomicMigrationOutputException>()),
    );

    expect(target.existsSync(), isFalse);
    expect(await _temporarySiblings(temporaryDirectory), isEmpty);
  });

  test(
    'atomically writes the package and report without a temp sibling',
    () async {
      final target = Directory('${temporaryDirectory.path}/artifacts');
      final files = _artifacts();

      await const AtomicMigrationOutput().writeDirectory(
        target: target,
        files: files,
      );

      expect(
        await target
            .list()
            .map((entity) => entity.uri.pathSegments.last)
            .toList(),
        unorderedEquals(AtomicMigrationOutput.artifactNames),
      );
      for (final entry in files.entries) {
        expect(
          await File('${target.path}/${entry.key}').readAsBytes(),
          entry.value,
        );
      }
      expect(await _temporarySiblings(temporaryDirectory), isEmpty);
    },
  );

  test('leaves an existing directory byte-for-byte unchanged', () async {
    final target = await Directory(
      '${temporaryDirectory.path}/artifacts',
    ).create();
    final marker = File('${target.path}/keep.txt');
    await marker.writeAsString('original');

    await expectLater(
      const AtomicMigrationOutput().writeDirectory(
        target: target,
        files: _artifacts(),
      ),
      throwsA(isA<AtomicMigrationOutputException>()),
    );

    expect(await marker.readAsString(), 'original');
    expect(await target.list().length, 1);
    expect(await _temporarySiblings(temporaryDirectory), isEmpty);
  });

  test('rejects an invalid artifact filename before any write', () async {
    final target = Directory('${temporaryDirectory.path}/artifacts');
    final files = _artifacts()..['../escape.json'] = utf8.encode('secret');

    await expectLater(
      const AtomicMigrationOutput().writeDirectory(
        target: target,
        files: files,
      ),
      throwsA(isA<AtomicMigrationOutputException>()),
    );

    expect(target.existsSync(), isFalse);
    expect(await _temporarySiblings(temporaryDirectory), isEmpty);
    expect(
      File('${temporaryDirectory.parent.path}/escape.json').existsSync(),
      isFalse,
    );
  });
}

Map<String, List<int>> _artifacts() => {
  AtomicMigrationOutput.packageFilename: [0, 255, 42],
  AtomicMigrationOutput.reportFilename: utf8.encode('report'),
};

Future<List<FileSystemEntity>> _temporarySiblings(Directory directory) =>
    directory
        .list()
        .where((entity) => entity.uri.pathSegments.last.contains('.tmp.'))
        .toList();
