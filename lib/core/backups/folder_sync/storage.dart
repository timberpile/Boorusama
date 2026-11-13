import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../../foundation/filesystem/publish_file.dart' as atomic;
import 'limits.dart';

export 'limits.dart';

bool isSafeSyncPath(String path, {bool root = false}) =>
    (root && path.isEmpty) ||
    (path.length <= 512 &&
        path.split('/').length <= 8 &&
        path.split('/').every((segment) =>
          RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9._-]{0,127}$').hasMatch(segment) &&
          segment != '.' && segment != '..'));

bool isOwnedSyncRevisionPath(String path, String owner) {
  if (!isSafeSyncPath(path) || owner != owner.toLowerCase() ||
      !Uuid.isValidUUID(fromString: owner)) {
    return false;
  }
  final parts = path.split('/');
  if (parts.length < 4 || parts[0] != 'devices' || parts[1] != owner) return false;
  final String file;
  if (parts.length == 4 && parts[2] == 'catalog') {
    file = parts[3];
  } else if (parts.length == 6 && parts[2] == 'collections' &&
      const {'bookmarks', 'following_topics'}.contains(parts[3]) &&
      parts[4] == parts[4].toLowerCase() &&
      Uuid.isValidUUID(fromString: parts[4])) {
    file = parts[5];
  } else {
    return false;
  }
  if (!RegExp(r'^[1-9][0-9]{0,15}\.(?:json|bsexport)$').hasMatch(file) ||
      (parts[2] == 'catalog' && !file.endsWith('.json'))) {
    return false;
  }
  final revision = int.tryParse(file.split('.').first);
  return revision != null && revision <= folderSyncMaxSequence;
}

abstract interface class FolderSyncStorage {
  Future<List<String>> list(String path);
  Future<Uint8List?> read(String path, {int maxBytes = folderSyncMaxBytes});

  /// Existing immutable bytes are accepted only when byte-for-byte identical.
  Future<void> writeImmutable(String path, Uint8List bytes);
  Future<void> deleteOwnedRevision(String path, {required String owner});
}

/// Mounted desktop/filesystem directories only. Android SAF needs its own
/// persisted-permission adapter; a content URI is deliberately not a path.
final class DirectoryFolderSyncStorage implements FolderSyncStorage {
  DirectoryFolderSyncStorage(String directory) : root = _root(directory);
  final Directory root;

  static Directory _root(String directory) {
    if (directory.trim().isEmpty || directory.contains('://')) {
      throw ArgumentError.value(directory, 'directory', 'Expected filesystem directory');
    }
    return Directory(p.join(directory, folderSyncRoot));
  }

  Future<String> _path(String relative, {bool createParents = false}) async {
    if (!isSafeSyncPath(relative, root: true)) {
      throw const FormatException('Unsafe sync path');
    }
    final parts = relative.isEmpty ? <String>[] : relative.split('/');
    var current = root.path;
    // Reject existing links in the shared namespace. This is not a sandbox
    // against a hostile process concurrently replacing filesystem ancestors.
    for (final segment in <String>['', ...parts]) {
      if (segment.isNotEmpty) current = p.join(current, segment);
      if (await FileSystemEntity.type(current, followLinks: false) ==
          FileSystemEntityType.link) {
        throw const FormatException('Sync links are unsupported');
      }
    }
    final target = p.joinAll([root.path, ...parts]);
    if (createParents) await Directory(p.dirname(target)).create(recursive: true);
    return target;
  }

  @override
  Future<List<String>> list(String path) async {
    final directory = Directory(await _path(path));
    if (!await directory.exists()) return const [];
    final names = <String>[];
    var scanned = 0;
    await for (final entry in directory.list(followLinks: false)) {
      if (++scanned > folderSyncMaxEntries) {
        throw const FormatException('Sync directory exceeds entry limit');
      }
      if (entry is Link) continue;
      final name = p.basename(entry.path);
      if (isSafeSyncPath(name)) names.add(name);
    }
    return names..sort();
  }

  @override
  Future<Uint8List?> read(String path, {int maxBytes = folderSyncMaxBytes}) async {
    if (maxBytes < 0 || maxBytes > folderSyncMaxBytes) {
      throw ArgumentError.value(maxBytes, 'maxBytes');
    }
    final file = File(await _path(path));
    if (!await file.exists()) return null;
    if (await file.length() > maxBytes) {
      throw const FormatException('Sync file exceeds byte limit');
    }
    final bytes = BytesBuilder(copy: false);
    // Enforce the cap while reading too: an external writer can grow a file
    // after stat, so an unbounded readAsBytes followed by a check is insufficient.
    await for (final chunk in file.openRead()) {
      if (bytes.length + chunk.length > maxBytes) {
        throw const FormatException('Sync file changed size');
      }
      bytes.add(chunk);
    }
    return bytes.takeBytes();
  }

  @override
  Future<void> deleteOwnedRevision(String path, {required String owner}) async {
    if (!isOwnedSyncRevisionPath(path, owner)) {
      throw const FormatException('Unsafe retention path');
    }
    final file = File(await _path(path));
    if (await file.exists()) await file.delete();
  }

  @override
  Future<void> writeImmutable(String path, Uint8List bytes) async {
    if (!isSafeSyncPath(path) || bytes.length > folderSyncMaxBytes) {
      throw const FormatException('Invalid sync publication');
    }
    final captured = Uint8List.fromList(bytes);
    final destination = File(await _path(path, createParents: true));
    if (await destination.exists()) {
      final existing = await read(path);
      if (existing == null || !_same(existing, captured)) {
        throw StateError('Immutable sync path already exists');
      }
      return;
    }
    final scratch = File('${destination.path}.${const Uuid().v4()}.partial');
    try {
      await scratch.writeAsBytes(captured, flush: true);
      if (!atomic.publishFileIfAbsent(scratch.path, destination.path)) {
        final existing = await read(path);
        if (existing == null || !_same(existing, captured)) {
          throw StateError('Concurrent sync publication');
        }
      }
    } finally {
      if (await scratch.exists()) await scratch.delete();
    }
  }
}

bool _same(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
