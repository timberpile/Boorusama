import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:boorusama/core/local_media/local_media_library.dart';
import 'package:boorusama/core/local_media/local_media_models.dart';
import 'package:boorusama/core/local_media/local_media_reference.dart';
import 'package:boorusama/core/posts/rating/types.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Directory root;
  late LocalMediaLibrary library;
  LocalMediaFaultPoint? fault;
  final png = Uint8List.fromList([
    137,
    80,
    78,
    71,
    13,
    10,
    26,
    10,
    1,
    2,
    3,
    4,
    5,
    6,
    7,
    8,
  ]);
  final reference = LocalMediaReference.parse(sha256.convert(png).toString());

  Future<LocalMediaLibrary> open() => LocalMediaLibrary.open(
    root,
    onFault: (point) {
      if (fault == point) throw StateError(point.name);
    },
  );

  Future<LocalMediaProbe> inspect(File staged, LocalMediaFormat format) async {
    expect(format, LocalMediaFormat.png);
    expect(await staged.readAsBytes(), png);
    return (width: 1, height: 2, durationMs: null);
  }

  Future<LocalMediaImportResult> import({
    Iterable<LocalMediaTag> tags = const [],
    LocalMediaImportBudget? budget,
    LocalMediaCancellation? cancellation,
    Stream<Uint8List>? stream,
    LocalMediaInspector? inspector,
  }) => library.import(
    stream ?? Stream.fromIterable([png.sublist(0, 4), png.sublist(4)]),
    inspect: inspector ?? inspect,
    cancellation: cancellation ?? LocalMediaCancellation(),
    budget: budget ?? LocalMediaImportBudget(),
    tags: tags,
    clock: () => DateTime.utc(2026),
  );

  File managed() => File(
    p.join(
      root.path,
      'media',
      reference.shard,
      '${reference.sha256}.png',
    ),
  );

  Future<void> reopen() async {
    await library.close();
    fault = null;
    library = await open();
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('boorusama_local_media_test');
    fault = null;
    library = await open();
  });

  tearDown(() async {
    await library.close();
    await root.delete(recursive: true);
  });

  test('hashes the original, indexes searchable tags and deduplicates concurrent imports', () async {
    final results = await Future.wait([
      import(
        tags: [(name: 'Example Character', category: 'character')],
      ),
      import(tags: [(name: 'duplicate', category: 'general')]),
    ]);
    expect(results, [
      LocalMediaImportResult.imported,
      LocalMediaImportResult.duplicate,
    ]);
    final file = await library.resolve(reference);
    expect(file?.path, managed().path);
    expect(await file!.readAsBytes(), png);
    final item = library.find(reference)!;
    expect(item.md5, md5.convert(png).toString());
    expect(item.tags.single, (
      name: 'example_character',
      category: 'character',
    ));
    expect(library.list(query: 'example_character -duplicate'), hasLength(1));
    expect(library.list(query: '-example_character'), isEmpty);
    await library.edit(
      reference,
      tags: [(name: 'new', category: 'artist')],
      rating: Rating.general,
    );
    await reopen();
    expect(library.list(query: 'new').single.rating, Rating.general);
    expect(library.list(query: 'example_character'), isEmpty);
    expect(library.find(reference)!.id, item.id);
    expect(managed().readAsBytesSync(), png);
  });

  test(
    'filters by rating and format before pagination and sorts local media',
    () async {
      await import(tags: [(name: 'character', category: 'character')]);
      await library.edit(
        reference,
        tags: [(name: 'character', category: 'character')],
        rating: Rating.general,
      );
      final gif = Uint8List.fromList('GIF89a123'.codeUnits);
      final gifReference = LocalMediaReference.parse(
        sha256.convert(gif).toString(),
      );
      await import(
        stream: Stream.value(gif),
        inspector: (_, _) async => (width: 1, height: 1, durationMs: null),
        tags: [(name: 'character', category: 'character')],
      );
      expect(
        library
            .list(query: 'character rating:g filetype:png', limit: 1)
            .single
            .reference,
        reference,
      );
      expect(
        library.list(query: 'rating:unknown -filetype:png').single.reference,
        gifReference,
      );
      expect(library.list(query: 'filetype:unknown'), isEmpty);
      expect(
        library.list(query: 'order:newest', limit: 1).single.reference,
        gifReference,
      );
      expect(
        library.list(query: 'order:oldest', limit: 1).single.reference,
        reference,
      );
      expect(
        library.list(query: 'order:largest', limit: 1).single.reference,
        reference,
      );
      expect(
        library.list(query: 'order:smallest', limit: 1).single.reference,
        gifReference,
      );
    },
  );

  test(
    'suggests stored tags and counts eligible files within the query',
    () async {
      const character = (name: 'example_character', category: 'character');
      const prefix = (name: 'example', category: 'general');
      const solo = (name: 'solo', category: 'general');
      await import(tags: [character, prefix, solo]);
      await library.edit(
        reference,
        tags: [character, prefix, solo],
        rating: Rating.general,
      );
      await import(
        stream: Stream.value(Uint8List.fromList('GIF89a123'.codeUnits)),
        inspector: (_, _) async => (width: 1, height: 1, durationMs: null),
        tags: [character],
      );
      expect(library.suggestTags('Example Cha').single, (
        name: 'example_character',
        category: 'character',
        count: 2,
      ));
      expect(
        library.suggestTags('example').map((tag) => tag.name),
        ['example', 'example_character'],
      );
      expect(
        library
            .suggestTags('-example_character', query: 'rating:g')
            .single
            .count,
        1,
      );
      expect(
        library.suggestTags('exam', query: '-solo filetype:gif').single.count,
        1,
      );
      expect(library.suggestTags('nonexistent'), isEmpty);
      await library.delete(reference);
      expect(library.suggestTags('example').single.count, 1);
      expect(library.suggestTags('solo'), isEmpty);
    },
  );

  test(
    'storage usage drops after clearing managed files and metadata',
    () async {
      await import(tags: [(name: 'kept', category: 'artist')]);
      final usage = await library.storageUsage();
      expect(usage.items, 1);
      expect(usage.bytes, greaterThan(png.length));
      await library.clear();
      await reopen();
      final cleared = await library.storageUsage();
      expect(cleared.items, 0);
      expect(cleared.bytes, lessThan(usage.bytes));
      expect(library.list(query: 'kept'), isEmpty);
      expect(managed().existsSync(), isFalse);
    },
  );

  test(
    'removes names from a review library while preserving media and tags',
    () async {
      await import(tags: [(name: 'kept', category: 'artist')]);
      final id = library.find(reference)!.id;
      await library.close();
      final database = sqlite3.open(p.join(root.path, 'library.db'));
      database.execute('ALTER TABLE media ADD COLUMN original_name TEXT');
      database.execute("UPDATE media SET original_name = 'discarded-name.png'");
      database.userVersion = 1;
      database.close();

      library = await open();
      final check = sqlite3.open(p.join(root.path, 'library.db'));
      try {
        expect(check.userVersion, LocalMediaLibrary.schemaVersion);
        expect(
          check.select('PRAGMA table_info(media)').map((row) => row['name']),
          isNot(contains('original_name')),
        );
      } finally {
        check.close();
      }
      expect(library.find(reference)!.id, id);
      expect(library.list(query: 'kept').single.tags.single.category, 'artist');
      expect(await managed().readAsBytes(), png);
    },
  );

  test(
    'rejects unsupported bytes, decoder failures and exhausted batch budgets',
    () async {
      await expectLater(
        import(stream: Stream.value(Uint8List(20))),
        throwsA(isA<LocalMediaUnsupported>()),
      );
      await expectLater(
        import(inspector: (_, _) async => throw const LocalMediaUnsupported()),
        throwsA(isA<LocalMediaUnsupported>()),
      );
      await expectLater(
        import(budget: LocalMediaImportBudget(maxBytes: 4)),
        throwsA(isA<LocalMediaLimit>()),
      );
      expect(library.list(), isEmpty);
      expect(managed().existsSync(), isFalse);
      expect(
        await Directory(p.join(root.path, 'staging')).list().isEmpty,
        isTrue,
      );
    },
  );

  test(
    'cancellation discards the current stage while retaining completed files',
    () async {
      await import();
      final cancellation = LocalMediaCancellation();
      final probeEntered = Completer<void>();
      final releaseProbe = Completer<void>();
      final other = Uint8List.fromList([...png, 9]);
      final importing = import(
        stream: Stream.value(other),
        cancellation: cancellation,
        inspector: (_, _) async {
          probeEntered.complete();
          await releaseProbe.future;
          return (width: 1, height: 2, durationMs: null);
        },
      );
      final check = expectLater(importing, throwsA(isA<LocalMediaCancelled>()));
      await probeEntered.future;
      cancellation.cancel();
      releaseProbe.complete();
      await check;
      expect(library.list().single.reference, reference);
      expect(
        await Directory(p.join(root.path, 'staging')).list().isEmpty,
        isTrue,
      );
    },
  );

  test(
    'failed install before database commit is recovered on reopen',
    () async {
      fault = LocalMediaFaultPoint.importPublished;
      await expectLater(import(), throwsStateError);
      expect(managed().existsSync(), isTrue);
      await reopen();
      expect(library.list(), isEmpty);
      expect(managed().existsSync(), isFalse);
      expect(await import(), LocalMediaImportResult.imported);
    },
  );

  test('restart preserves bytes after the import commit', () async {
    fault = LocalMediaFaultPoint.committed;
    await expectLater(import(), throwsStateError);
    await reopen();
    expect(library.find(reference), isNotNull);
    expect(managed().readAsBytesSync(), png);
  });

  test(
    'restart rolls back uncommitted deletion and completes committed deletion',
    () async {
      await import();
      fault = LocalMediaFaultPoint.deletionStaged;
      await expectLater(library.delete(reference), throwsStateError);
      expect(managed().existsSync(), isFalse);
      await reopen();
      expect(library.find(reference), isNotNull);
      expect(managed().existsSync(), isTrue);
      fault = LocalMediaFaultPoint.committed;
      await expectLater(library.delete(reference), throwsStateError);
      await reopen();
      expect(library.find(reference), isNull);
      expect(managed().existsSync(), isFalse);
      expect(
        await Directory(p.join(root.path, 'staging')).list().isEmpty,
        isTrue,
      );
    },
  );

  test('reimport repairs same-size damage without metadata loss', () async {
    await import(tags: [(name: 'keep', category: 'general')]);
    final changed = Uint8List.fromList(png)..[15] = 99;
    await managed().writeAsBytes(changed);
    expect(await import(), LocalMediaImportResult.repaired);
    expect(managed().readAsBytesSync(), png);
    expect(library.find(reference)!.tags.single.name, 'keep');
  });

  test('a corrupt database does not reset the managed file', () async {
    await import();
    await library.close();
    final database = File(p.join(root.path, 'library.db'));
    final original = database.readAsBytesSync();
    try {
      database.writeAsBytesSync([1, 2, 3], flush: true);
      await expectLater(open(), throwsA(isA<Exception>()));
      expect(managed().readAsBytesSync(), png);
      expect(database.readAsBytesSync(), [1, 2, 3]);
    } finally {
      database.writeAsBytesSync(original, flush: true);
      library = await open();
    }
  });
}
