import 'package:foundation/performance.dart';

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'image_cache_checkpoint.dart';

class ImageCacheEntry {
  ImageCacheEntry({
    required this.key,
    required this.filename,
    required this.size,
    required this.use,
  });
  final String key;
  final String filename;
  final int size;
  int use;
  Map<String, Object> toJson() => {
    'key': key,
    'file': filename,
    'size': size,
    'use': use,
  };
  static ImageCacheEntry? fromJson(Object? value) {
    if (value
        case {
          'key': final String key,
          'file': final String filename,
          'size': final int size,
          'use': final int use,
        }
        when key.isNotEmpty &&
            p.basename(key) == key &&
            !key.contains('\\') &&
            p.basename(filename) == filename &&
            !filename.contains('\\') &&
            key != '.' &&
            key != '..' &&
            (filename == key || filename.startsWith('$key.generation_')) &&
            size > 0 &&
            use >= 0) {
      return ImageCacheEntry(
        key: key,
        filename: filename,
        size: size,
        use: use,
      );
    }
    return null;
  }
}

/// Ordered journal plus atomic checkpoints. Contents contain hashed keys only.
/// The owner must serialize load, mutations and checkpoint calls through completion.
class ImageCacheIndex {
  ImageCacheIndex(
    this.directory, {
    ImageCacheCheckpointWriter checkpointWriter =
        writeImageCacheCheckpointInBackground,
  }) : _checkpointWriter = checkpointWriter;
  final Directory directory;
  final ImageCacheCheckpointWriter _checkpointWriter;
  final entries = <String, ImageCacheEntry>{};
  int revision = 0;
  var _records = 0;
  File get _checkpoint => File(p.join(directory.path, 'checkpoint.json'));
  File get _journal => File(p.join(directory.path, 'journal.jsonl'));

  Future<bool> load() async {
    var valid = false;
    try {
      await directory.create(recursive: true);
      final data = jsonDecode(await _checkpoint.readAsString());
      if (data case {
        'version': 1,
        'revision': final int rev,
        'entries': final List values,
      } when rev >= 0) {
        revision = rev;
        for (final value in values) {
          final entry = ImageCacheEntry.fromJson(value);
          if (entry == null || entries.containsKey(entry.key)) {
            throw const FormatException('Invalid image cache checkpoint');
          }
          entries[entry.key] = entry;
        }
        valid = true;
      }
    } on Object {
      entries.clear();
    }
    if (!valid) return false;
    try {
      for (final line in await _journal.readAsLines()) {
        try {
          final event = jsonDecode(line);
          if (event case {
            'revision': final int rev,
            'key': final String key,
          } when rev > revision) {
            if (event['entry'] == null) {
              entries.remove(key);
            } else if (ImageCacheEntry.fromJson(event['entry'])
                case final entry? when entry.key == key) {
              entries[key] = entry;
            } else {
              break;
            }
            revision = rev;
            _records++;
          } else if (event is! Map ||
              event['revision'] is! int ||
              event['key'] is! String) {
            break;
          }
        } on Object {
          // Only a fully written prefix is authoritative.
          break;
        }
      }
    } on FileSystemException {
      // A checkpoint alone is a complete valid index.
    }
    return true;
  }

  Future<void> put(ImageCacheEntry entry) async {
    entries[entry.key] = entry;
    await _append(entry.key, entry.toJson());
  }

  Future<void> remove(String key) async {
    entries.remove(key);
    await _append(key, null);
  }

  Future<void> _append(String key, Map<String, Object>? entry) async {
    await performanceRecorder.measureAsync(
      PerfOperation.cacheJournalAppend,
      () async {
        await directory.create(recursive: true);
        await _journal.writeAsString(
          '${jsonEncode({'revision': ++revision, 'key': key, 'entry': entry})}\n',
          mode: FileMode.append,
          flush: true,
        );
      },
    );
    if (++_records >= 128) await checkpoint();
  }

  Future<void> checkpoint() async {
    final span = performanceRecorder.begin(
      PerfOperation.cacheCheckpoint,
      PerfSpanKind.asyncWall,
      items: entries.length,
    );
    final staged = File('${_checkpoint.path}.partial');
    var failed = false;
    try {
      await directory.create(recursive: true);
      final snapshot = performanceRecorder.measureSync(
        PerfOperation.cacheCheckpointSnapshot,
        () => (
          stagedPath: staged.path,
          revision: revision,
          entries: List<ImageCacheCheckpointEntry>.unmodifiable(
            entries.values.map(
              (entry) => (
                key: entry.key,
                filename: entry.filename,
                size: entry.size,
                use: entry.use,
              ),
            ),
          ),
        ),
        items: entries.length,
      );
      await performanceRecorder.measureAsync(
        PerfOperation.cacheCheckpointWorker,
        () => performanceRecorder.measureSync(
          PerfOperation.cacheCheckpointDispatch,
          () => _checkpointWriter(snapshot),
          items: snapshot.entries.length,
        ),
        items: snapshot.entries.length,
      );
      // Remain in the owner's current queue slot throughout the worker await.
      // Releasing/re-entering it here would lose later journal entries or deadlock.
      await performanceRecorder.measureAsync(
        PerfOperation.cacheCheckpointPublish,
        () async {
          await staged.rename(_checkpoint.path);
          await _journal.writeAsString('', flush: true);
        },
      );
      _records = 0;
    } catch (_) {
      failed = true;
      // A failed attempt must leave the authoritative checkpoint/journal alone.
      // Cleanup is best effort and must not mask the original failure.
      try {
        if (await staged.exists()) await staged.delete();
      } on FileSystemException {
        // An interrupted partial is ignored on load and overwritten on retry.
      }
      rethrow;
    } finally {
      span.finish(failed: failed);
    }
  }
}
