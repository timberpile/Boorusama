import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

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
class ImageCacheIndex {
  ImageCacheIndex(this.directory);
  final Directory directory;
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
    await directory.create(recursive: true);
    await _journal.writeAsString(
      '${jsonEncode({'revision': ++revision, 'key': key, 'entry': entry})}\n',
      mode: FileMode.append,
      flush: true,
    );
    if (++_records >= 128) await checkpoint();
  }

  Future<void> checkpoint() async {
    await directory.create(recursive: true);
    final staged = File('${_checkpoint.path}.partial');
    await staged.writeAsString(
      jsonEncode({
        'version': 1,
        'revision': revision,
        'entries': entries.values.map((e) => e.toJson()).toList(),
      }),
      flush: true,
    );
    await staged.rename(_checkpoint.path);
    await _journal.writeAsString('', flush: true);
    _records = 0;
  }
}
