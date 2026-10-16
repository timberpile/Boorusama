import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:cache_manager/cache_manager.dart';
import 'package:cache_manager/src/image_cache_checkpoint.dart';
import 'package:cache_manager/src/image_cache_index.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory root;
  late Directory directory;
  late File checkpoint;
  late File journal;
  late File staged;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('checkpoint-worker-');
    directory = await Directory(p.join(root.path, 'cacheimage-index')).create();
    checkpoint = File(p.join(directory.path, 'checkpoint.json'));
    journal = File(p.join(directory.path, 'journal.jsonl'));
    staged = File('${checkpoint.path}.partial');
  });

  tearDown(() async {
    await root.delete(recursive: true);
  });

  ImageCacheEntry entry(String key, int use) => ImageCacheEntry(
    key: key,
    filename: key,
    size: 4,
    use: use,
  );

  ImageCacheCheckpointSnapshot snapshot(ImageCacheIndex index) => (
    stagedPath: staged.path,
    revision: index.revision,
    entries: [
      for (final e in index.entries.values)
        (key: e.key, filename: e.filename, size: e.size, use: e.use),
    ],
  );

  Future<ImageCacheIndex> seeded() async {
    final index = ImageCacheIndex(directory);
    await index.checkpoint();
    await index.put(entry('A', 1));
    await index.put(entry('B', 2));
    return index;
  }

  test(
    'writes compatible UTF-8 JSON in an isolate without caller IO overrides',
    () async {
      final data = (
        stagedPath: staged.path,
        revision: 42,
        entries: <ImageCacheCheckpointEntry>[
          (key: '日本語', filename: '日本語', size: 9, use: 8),
        ],
      );
      // This throws if file creation accidentally moves back to the caller isolate.
      await IOOverrides.runZoned(
        () => writeImageCacheCheckpointInBackground(data),
        createFile: (_) => throw StateError('File work ran on caller isolate'),
      );
      expect(
        await staged.readAsBytes(),
        utf8.encode(
          jsonEncode({
            'version': 1,
            'revision': 42,
            'entries': [
              {'key': '日本語', 'file': '日本語', 'size': 9, 'use': 8},
            ],
          }),
        ),
      );
      expect(await checkpoint.exists(), isFalse);
      expect(await journal.exists(), isFalse);
    },
  );

  test('checkpoints exactly every 128 successful journal records', () async {
    var writes = 0;
    final index = ImageCacheIndex(
      directory,
      checkpointWriter: (data) async {
        writes++;
        await writeImageCacheCheckpointInBackground(data);
      },
    );
    await index.checkpoint();
    for (var i = 1; i <= 127; i++) {
      await index.put(entry('A', i));
    }
    expect(writes, 1);
    expect(await journal.readAsLines(), hasLength(127));
    await index.put(entry('A', 128));
    expect(writes, 2);
    expect(jsonDecode(await checkpoint.readAsString())['revision'], 128);
    expect(await journal.readAsString(), isEmpty);
    for (var i = 129; i <= 256; i++) {
      await index.put(entry('A', i));
    }
    expect(writes, 3);
    expect(await journal.readAsString(), isEmpty);
  });

  test('freezes mutable entry values before awaiting the worker', () async {
    final started = Completer<ImageCacheCheckpointSnapshot>();
    final release = Completer<void>();
    final index = ImageCacheIndex(
      directory,
      checkpointWriter: (data) async {
        started.complete(data);
        await release.future;
        await writeImageCacheCheckpointInBackground(data);
      },
    );
    final original = entry('A', 3);
    index.entries['A'] = original;
    index.revision = 17;
    final pending = index.checkpoint();
    try {
      final captured = await started.future;
      original.use = 99;
      expect(captured.entries.single.use, 3);
      expect(() => captured.entries.clear(), throwsUnsupportedError);
    } finally {
      release.complete();
      await pending;
    }
    final loaded = ImageCacheIndex(directory);
    expect(await loaded.load(), isTrue);
    expect(loaded.revision, 17);
    expect(loaded.entries['A']!.use, 3);
  });

  test(
    'a worker file error preserves the previous checkpoint and journal',
    () async {
      final index = await seeded();
      final beforeCheckpoint = await checkpoint.readAsBytes();
      final beforeJournal = await journal.readAsBytes();
      await Directory(staged.path).create();
      await expectLater(
        index.checkpoint(),
        throwsA(isA<FileSystemException>()),
      );
      expect(await checkpoint.readAsBytes(), beforeCheckpoint);
      expect(await journal.readAsBytes(), beforeJournal);
      final recovered = ImageCacheIndex(directory);
      expect(await recovered.load(), isTrue);
      expect(recovered.entries.keys, containsAll(['A', 'B']));
      await Directory(staged.path).delete();
      await index.checkpoint();
      expect(await journal.readAsString(), isEmpty);
    },
  );

  test(
    'a failed rename leaves the old checkpoint and journal authoritative',
    () async {
      final index = await seeded();
      final beforeCheckpoint = await checkpoint.readAsBytes();
      final beforeJournal = await journal.readAsBytes();
      final files = {
        checkpoint.path: checkpoint,
        journal.path: journal,
        staged.path: _FailingFile(staged, failRename: true),
      };
      await expectLater(
        IOOverrides.runZoned(
          index.checkpoint,
          createFile: (path) => files[path]!,
        ),
        throwsA(isA<FileSystemException>()),
      );
      expect(await checkpoint.readAsBytes(), beforeCheckpoint);
      expect(await journal.readAsBytes(), beforeJournal);
      expect(await staged.exists(), isFalse);
      final recovered = ImageCacheIndex(directory);
      expect(await recovered.load(), isTrue);
      expect(recovered.entries.keys, containsAll(['A', 'B']));
    },
  );

  test(
    'failed truncation preserves a recoverable new checkpoint with old journal',
    () async {
      final index = await seeded();
      final beforeJournal = await journal.readAsBytes();
      final files = {
        checkpoint.path: checkpoint,
        journal.path: _FailingFile(journal, failTruncate: true),
        staged.path: staged,
      };
      await expectLater(
        IOOverrides.runZoned(
          index.checkpoint,
          createFile: (path) => files[path]!,
        ),
        throwsA(isA<FileSystemException>()),
      );
      expect(jsonDecode(await checkpoint.readAsString())['revision'], 2);
      expect(await journal.readAsBytes(), beforeJournal);
      final recovered = ImageCacheIndex(directory);
      expect(await recovered.load(), isTrue);
      expect(recovered.revision, 2);
      expect(recovered.entries['B']!.use, 2);
      await index.checkpoint();
      expect(await journal.readAsString(), isEmpty);
    },
  );

  for (final publish in [false, true]) {
    test(
      'recovers a process stop ${publish ? 'after' : 'before'} checkpoint publication',
      () async {
        final index = await seeded();
        await writeImageCacheCheckpointInBackground(snapshot(index));
        if (publish) await staged.rename(checkpoint.path);
        // No dispose/checkpoint: retain exactly this interrupted on-disk state.
        final recovered = ImageCacheIndex(directory);
        expect(await recovered.load(), isTrue);
        expect(recovered.revision, 2);
        expect(recovered.entries['A']!.use, 1);
        expect(recovered.entries['B']!.use, 2);
        await recovered.put(entry('B', 7));
        await recovered.remove('A');
        final secondRestart = ImageCacheIndex(directory);
        expect(await secondRestart.load(), isTrue);
        expect(secondRestart.revision, 4);
        expect(secondRestart.entries.keys, ['B']);
        expect(secondRestart.entries['B']!.use, 7);
      },
    );
  }

  test('queued cache changes cannot overtake a checkpoint worker', () async {
    final started = Completer<void>();
    final release = Completer<void>();
    var hold = false;
    final manager = DefaultImageCacheManager(
      maxBytes: 8,
      cacheRootPathProvider: () => root.path,
      checkpointWriter: (data) async {
        if (hold) {
          started.complete();
          await release.future;
        }
        await writeImageCacheCheckpointInBackground(data);
      },
    );
    Future<void>? checkpointing;
    Future<void>? nextTouch;
    Future<void>? nextClear;
    try {
      await manager.saveFile('A', Uint8List.fromList([1, 1, 1, 1]));
      await manager.saveFile('B', Uint8List.fromList([2, 2, 2, 2]));
      for (var i = 0; i < 125; i++) {
        await manager.touch('A');
      }
      hold = true;
      checkpointing = manager.touch('A');
      await started.future;
      var touched = false;
      var cleared = false;
      nextTouch = manager.touch('B').then<void>((_) {
        touched = true;
      });
      nextClear = manager.clearCache('A').then<void>((_) {
        cleared = true;
      });
      await Future<void>.delayed(Duration.zero);
      expect(touched, isFalse);
      expect(cleared, isFalse);
      expect(await journal.readAsLines(), hasLength(128));
      hold = false;
      release.complete();
      await Future.wait([checkpointing, nextTouch, nextClear]);
      final recovered = ImageCacheIndex(directory);
      expect(await recovered.load(), isTrue);
      expect(recovered.revision, 130);
      expect(recovered.entries.keys, ['B']);
      expect(await journal.readAsLines(), hasLength(2));
    } finally {
      hold = false;
      if (!release.isCompleted) release.complete();
      await Future.wait([?checkpointing, ?nextTouch, ?nextClear]);
      await manager.dispose();
    }
  });

  for (final (failureIndex, failure) in <Object>[
    const FileSystemException('Injected write failure'),
    ImageCacheCheckpointWorkerException(
      IsolateSpawnException('Injected spawn failure'),
    ),
    ImageCacheCheckpointWorkerException(
      RemoteError('Injected worker exit', ''),
    ),
  ].indexed) {
    test(
      'keeps images readable and retries ${failure.runtimeType} case $failureIndex without caller encoding',
      () async {
        var fail = true;
        var attempts = 0;
        final manager = DefaultImageCacheManager(
          cacheRootPathProvider: () => root.path,
          checkpointWriter: (data) async {
            attempts++;
            if (fail) throw failure;
            await writeImageCacheCheckpointInBackground(data);
          },
        );
        try {
          final payload = await Directory('${root.path}/cacheimage').create();
          await File('${payload.path}/A').writeAsBytes([1, 2, 3]);
          expect(await manager.getCachedFileBytes('A'), [1, 2, 3]);
          expect(attempts, greaterThan(0));
          expect(await checkpoint.exists(), isFalse);
          fail = false;
          await manager.touch('A');
          final recovered = ImageCacheIndex(directory);
          expect(await recovered.load(), isTrue);
          expect(recovered.entries.keys, ['A']);
        } finally {
          fail = false;
          await manager.dispose();
        }
      },
    );
  }

  test(
    'does not disguise programming errors as optional worker failures',
    () async {
      final manager = DefaultImageCacheManager(
        cacheRootPathProvider: () => root.path,
        checkpointWriter: (_) => throw StateError('Injected programming error'),
      );
      await expectLater(manager.touch('A'), throwsStateError);
    },
  );
}

class _FailingFile extends Fake implements File {
  _FailingFile(
    this.delegate, {
    this.failRename = false,
    this.failTruncate = false,
  });

  final File delegate;
  final bool failRename;
  final bool failTruncate;

  @override
  String get path => delegate.path;

  @override
  Future<bool> exists() => delegate.exists();

  @override
  Future<FileSystemEntity> delete({bool recursive = false}) =>
      delegate.delete(recursive: recursive);

  @override
  Future<File> rename(String newPath) {
    if (failRename) throw FileSystemException('Injected rename failure', path);
    return delegate.rename(newPath);
  }

  @override
  Future<File> writeAsString(
    String contents, {
    FileMode mode = FileMode.write,
    Encoding encoding = utf8,
    bool flush = false,
  }) {
    if (failTruncate && mode == FileMode.write) {
      throw FileSystemException('Injected truncation failure', path);
    }
    return delegate.writeAsString(
      contents,
      mode: mode,
      encoding: encoding,
      flush: flush,
    );
  }
}
