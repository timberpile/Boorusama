import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../../foundation/filesystem/publish_file.dart' as atomic;

const folderSyncRoot = 'BoorusamaSync/v1';
const folderSyncMaxBytes = 32 * 1024 * 1024;
const folderSyncMaxEntries = 4096;

bool isSafeSyncPath(String path, {bool root = false}) =>
    (root && path.isEmpty) ||
    (path.length <= 512 &&
        path.split('/').length <= 8 &&
        path
            .split('/')
            .every(
              (segment) =>
                  RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9._-]{0,127}$')
                      .hasMatch(segment) &&
                  segment != '.' &&
                  segment != '..',
            ));

bool isOwnedSyncRevisionPath(String path, String owner) {
  if (!isSafeSyncPath(path) ||
      owner != owner.toLowerCase() ||
      !Uuid.isValidUUID(fromString: owner))
    return false;
  final parts = path.split('/');
  if (parts.length < 4 || parts[0] != 'devices' || parts[1] != owner)
    return false;
  final String file;
  if (parts.length == 4 && parts[2] == 'catalog')
    file = parts[3];
  else if (parts.length == 6 &&
      parts[2] == 'collections' &&
      const {'bookmarks', 'following_topics'}.contains(parts[3]) &&
      parts[4] == parts[4].toLowerCase() &&
      Uuid.isValidUUID(fromString: parts[4]))
    file = parts[5];
  else
    return false;
  if (!RegExp(r'^[1-9][0-9]{0,15}\.(?:json|bsexport)$').hasMatch(file) ||
      (parts[2] == 'catalog' && !file.endsWith('.json')))
    return false;
  final revision = int.tryParse(file.split('.').first);
  return revision != null && revision <= 9007199254740991;
}

abstract interface class FolderSyncStorage {
  Future<List<String>> list(String path);
  Future<Uint8List?> read(String path, {int maxBytes = folderSyncMaxBytes});

  /// Existing immutable bytes are accepted only when byte-for-byte identical.
  Future<void> writeImmutable(String path, Uint8List bytes);
  Future<void> deleteOwnedRevision(String path, {required String owner});
}

final class DirectoryFolderSyncStorage implements FolderSyncStorage {
  DirectoryFolderSyncStorage(String directory)
    : root = Directory(p.join(directory, folderSyncRoot));
  final Directory root;

  Future<String> _path(String relative, {bool createParents = false}) async {
    if (!isSafeSyncPath(relative, root: true)) {
      throw const FormatException('Unsafe sync path');
    }
    final parts = relative.isEmpty ? <String>[] : relative.split('/');
    var current = root.path;
    // Resolve every existing ancestor; a shared folder may contain hostile links.
    for (final segment in <String>['', ...parts]) {
      if (segment.isNotEmpty) current = p.join(current, segment);
      final type = await FileSystemEntity.type(current, followLinks: false);
      if (type == FileSystemEntityType.link) {
        throw const FormatException('Sync links are unsupported');
      }
    }
    final target = p.joinAll([root.path, ...parts]);
    if (createParents) {
      await Directory(p.dirname(target)).create(recursive: true);
    }
    return target;
  }

  @override
  Future<List<String>> list(String path) async {
    final directory = Directory(await _path(path));
    if (!await directory.exists()) return const [];
    final names = <String>[];
    await for (final entry in directory.list(followLinks: false)) {
      if (entry is Link) continue;
      final name = p.basename(entry.path);
      if (isSafeSyncPath(name)) names.add(name);
      if (names.length > folderSyncMaxEntries) {
        throw const FormatException('Sync directory exceeds entry limit');
      }
    }
    return names..sort();
  }

  @override
  Future<Uint8List?> read(
    String path, {
    int maxBytes = folderSyncMaxBytes,
  }) async {
    final file = File(await _path(path));
    if (!await file.exists()) return null;
    if (await file.length() > maxBytes) {
      throw const FormatException('Sync file exceeds byte limit');
    }
    final bytes = await file.readAsBytes();
    if (bytes.length > maxBytes) {
      throw const FormatException('Sync file changed size');
    }
    return bytes;
  }

  @override
  Future<void> deleteOwnedRevision(String path, {required String owner}) async {
    if (!isOwnedSyncRevisionPath(path, owner))
      throw const FormatException('Unsafe retention path');
    final file = File(await _path(path));
    if (await file.exists()) await file.delete();
  }

  @override
  Future<void> writeImmutable(String path, Uint8List bytes) async {
    if (bytes.length > folderSyncMaxBytes) {
      throw const FormatException('Sync payload too large');
    }
    final destination = File(await _path(path, createParents: true));
    if (await destination.exists()) {
      final existing = await read(path);
      if (!_same(existing!, bytes)) {
        throw StateError('Immutable sync path already exists');
      }
      return;
    }
    final scratch = File(
      '${destination.path}.${DateTime.now().microsecondsSinceEpoch}.partial',
    );
    try {
      await scratch.writeAsBytes(bytes, flush: true);
      if (!atomic.publishFileIfAbsent(scratch.path, destination.path)) {
        final existing = await read(path);
        if (existing == null || !_same(existing, bytes)) {
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

final class AndroidFolderSyncStorage implements FolderSyncStorage {
  const AndroidFolderSyncStorage(this.tree);
  final String tree;
  static const channel = MethodChannel('boorusama/folder_sync');

  Map<String, Object> _arguments(String path) {
    if (!isSafeSyncPath(path, root: true)) {
      throw const FormatException('Unsafe sync path');
    }
    return {'tree': tree, 'path': path};
  }

  @override
  Future<List<String>> list(String path) async =>
      (await channel.invokeListMethod<String>('list', _arguments(path))) ??
      const [];
  @override
  Future<Uint8List?> read(String path, {int maxBytes = folderSyncMaxBytes}) =>
      channel.invokeMethod<Uint8List>('read', {
        ..._arguments(path),
        'maxBytes': maxBytes,
      });
  @override
  Future<void> deleteOwnedRevision(String path, {required String owner}) async {
    if (!isOwnedSyncRevisionPath(path, owner))
      throw const FormatException('Unsafe retention path');
    await channel.invokeMethod<void>('deleteOwnedRevision', {
      ..._arguments(path),
      'owner': owner,
    });
  }

  @override
  Future<void> writeImmutable(String path, Uint8List bytes) async {
    if (bytes.length > folderSyncMaxBytes) {
      throw const FormatException('Sync payload too large');
    }
    await channel.invokeMethod<void>('write', {
      ..._arguments(path),
      'bytes': bytes,
    });
  }
}
