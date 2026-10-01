import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:boorusama_cli/src/command/animeboxes_command.dart';
import 'package:boorusama_cli/src/migrations/animeboxes/atomic_output.dart';
import 'package:boorusama_cli/src/migrations/animeboxes/document_codec.dart';
import 'package:test/test.dart';

void main() {
  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'boorusama-animeboxes-command-',
    );
  });

  tearDown(() async {
    if (temporaryDirectory.existsSync()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('help exposes the two exact migration command forms', () {
    final harness = _Harness();
    final command = harness.command;

    expect(
      command.subcommands['normalize']!.invocation,
      'boorusama animeboxes normalize --input <csv> --output <normalized.json>',
    );
    expect(
      command.subcommands['export']!.invocation,
      'boorusama animeboxes export --input <normalized.json> --output-dir <directory>',
    );
    expect(harness.runner.usage, contains('animeboxes'));
  });

  test('normalize creates only a complete normalized document', () async {
    final harness = _Harness();
    final input = await _writeInput(temporaryDirectory, _completeFixture());
    final output = File('${temporaryDirectory.path}/normalized.json');

    final exitCode = await harness.runner.run([
      'animeboxes',
      'normalize',
      '--input',
      input.path,
      '--output',
      output.path,
    ]);

    expect(exitCode, 0);
    final document = const AnimeBoxesDocumentCodec().decode(
      await output.readAsString(),
    );
    expect(document.bookmarks, hasLength(1));
    expect(document.pinnedSearchFolders.single.searches, hasLength(1));
    expect(
      await temporaryDirectory.list().map((entity) => entity.path).toList(),
      unorderedEquals([input.path, output.path]),
    );
    expect(harness.errors, isEmpty);
  });

  test('export creates all four deterministic artifacts', () async {
    final harness = _Harness();
    final input = await _writeInput(temporaryDirectory, _completeFixture());
    final normalized = File('${temporaryDirectory.path}/normalized.json');
    final output = Directory('${temporaryDirectory.path}/artifacts');
    await harness.runner.run([
      'animeboxes',
      'normalize',
      '--input',
      input.path,
      '--output',
      normalized.path,
    ]);

    final exitCode = await harness.runner.run([
      'animeboxes',
      'export',
      '--input',
      normalized.path,
      '--output-dir',
      output.path,
    ]);

    expect(exitCode, 0);
    expect(
      await output
          .list()
          .map((entity) => entity.uri.pathSegments.last)
          .toList(),
      unorderedEquals(AtomicMigrationOutput.artifactNames),
    );
    expect(harness.errors, isEmpty);
  });

  test(
    'invalid source returns nonzero without a final file or secret',
    () async {
      const secret = 'fixture-invalid-secret-never-report';
      final harness = _Harness();
      final input = await _writeInput(
        temporaryDirectory,
        _completeFixture().replaceFirst(
          'https://cdn.example/sample-42.jpg',
          secret,
        ),
      );
      final output = File('${temporaryDirectory.path}/normalized.json');

      final exitCode = await harness.runner.run([
        'animeboxes',
        'normalize',
        '--input',
        input.path,
        '--output',
        output.path,
      ]);

      expect(exitCode, isNot(0));
      expect(output.existsSync(), isFalse);
      expect(
        [...harness.output, ...harness.errors].join('\n'),
        isNot(contains(secret)),
      );
      expect(
        await temporaryDirectory
            .list()
            .where((entity) => entity.path.contains('.tmp.'))
            .isEmpty,
        isTrue,
      );
    },
  );

  test('existing export directory is rejected without changing it', () async {
    final harness = _Harness();
    final input = await _writeInput(temporaryDirectory, _completeFixture());
    final normalized = File('${temporaryDirectory.path}/normalized.json');
    await harness.runner.run([
      'animeboxes',
      'normalize',
      '--input',
      input.path,
      '--output',
      normalized.path,
    ]);
    final output = await Directory(
      '${temporaryDirectory.path}/artifacts',
    ).create();
    final marker = File('${output.path}/keep.txt');
    await marker.writeAsString('unchanged');

    final exitCode = await harness.runner.run([
      'animeboxes',
      'export',
      '--input',
      normalized.path,
      '--output-dir',
      output.path,
    ]);

    expect(exitCode, isNot(0));
    expect(await marker.readAsString(), 'unchanged');
    expect(await output.list().length, 1);
  });

  test('two runs are byte-identical and never expose source secrets', () async {
    final harness = _Harness();
    final input = await _writeInput(temporaryDirectory, _completeFixture());
    final normalized = [
      File('${temporaryDirectory.path}/normalized-one.json'),
      File('${temporaryDirectory.path}/normalized-two.json'),
    ];
    final outputs = [
      Directory('${temporaryDirectory.path}/artifacts-one'),
      Directory('${temporaryDirectory.path}/artifacts-two'),
    ];

    for (var index = 0; index < 2; index++) {
      expect(
        await harness.runner.run([
          'animeboxes',
          'normalize',
          '--input',
          input.path,
          '--output',
          normalized[index].path,
        ]),
        0,
      );
      expect(
        await harness.runner.run([
          'animeboxes',
          'export',
          '--input',
          normalized[index].path,
          '--output-dir',
          outputs[index].path,
        ]),
        0,
      );
    }

    expect(
      await normalized[0].readAsBytes(),
      await normalized[1].readAsBytes(),
    );
    for (final filename in AtomicMigrationOutput.artifactNames) {
      expect(
        await File('${outputs[0].path}/$filename').readAsBytes(),
        await File('${outputs[1].path}/$filename').readAsBytes(),
      );
    }
    final emitted = StringBuffer(
      [...harness.output, ...harness.errors].join('\n'),
    );
    for (final file in [
      ...normalized,
      for (final directory in outputs)
        ...(await directory.list().toList()).whereType<File>(),
    ]) {
      emitted.write(await file.readAsString());
    }
    for (final secret in [
      'fixture-user-never-serialize',
      'fixture-password-never-serialize',
      'fixture-key-never-serialize',
      'fixture-api-key-never-serialize',
    ]) {
      expect(emitted.toString(), isNot(contains(secret)));
    }
    expect(await _temporaryEntities(temporaryDirectory), isEmpty);
  });

  test('invalid normalized input leaves no artifact directory', () async {
    const secret = 'fixture-normalized-secret-never-report';
    final harness = _Harness();
    final input = File('${temporaryDirectory.path}/normalized.json');
    await input.writeAsString(
      '{"schema":"boorusama.animeboxes.normalized","version":1,"password":"$secret"}',
    );
    final output = Directory('${temporaryDirectory.path}/artifacts');

    final exitCode = await harness.runner.run([
      'animeboxes',
      'export',
      '--input',
      input.path,
      '--output-dir',
      output.path,
    ]);

    expect(exitCode, isNot(0));
    expect(output.existsSync(), isFalse);
    expect(
      [...harness.output, ...harness.errors].join('\n'),
      isNot(contains(secret)),
    );
    expect(await _temporaryEntities(temporaryDirectory), isEmpty);
  });
}

final class _Harness {
  _Harness() {
    command = AnimeBoxesCommand(output: output.add, errorOutput: errors.add);
    runner.addCommand(command);
  }

  final output = <String>[];
  final errors = <String>[];
  late final AnimeBoxesCommand command;
  final runner = CommandRunner<int>('boorusama', 'Boorusama development tool.');
}

Future<File> _writeInput(Directory directory, String contents) async {
  final file = File('${directory.path}/source.csv');
  await file.writeAsString(contents);
  return file;
}

String _completeFixture() => File(
  'test/migrations/animeboxes/fixtures/complete.csv',
).readAsStringSync();

Future<List<FileSystemEntity>> _temporaryEntities(Directory directory) =>
    directory
        .list(recursive: true)
        .where((entity) => entity.path.contains('.tmp.'))
        .toList();
