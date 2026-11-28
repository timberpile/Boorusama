// Shared-directory checks must not block the UI isolate; keep async I/O.
// ignore_for_file: avoid_slow_async_io

import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../../foundation/filesystem/publish_file.dart' as atomic;
import 'limits.dart';

export 'limits.dart';

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
      !Uuid.isValidUUID(fromString: owner)) {
    return false;
  }
  final parts = path.split('/');
  if (parts.length < 4 || parts[0] != 'devices' || parts[1] != owner) {
    return false;
  }
  if (parts.length >= 7 &&
      parts[2] == 'collections' &&
      parts[3] == 'bookmarks' &&
      parts[4] == parts[4].toLowerCase() &&
      Uuid.isValidUUID(fromString: parts[4])) {
    if (parts.length == 7 && parts[5] == 'manifests') {
      return _validSyncNumber(parts[6].split('.').first) &&
          parts[6].endsWith('.json') &&
          parts[6].split('.').length == 2;
    }
    if (parts.length == 8 && parts[5] == 'chunks') {
      return _validSyncNumber(parts[6]) &&
          RegExp(
            r'^[0-9a-f]{2}-(?:0|[1-9][0-9]{0,3})-[0-9a-f]{64}\.ndjson\.gz$',
          ).hasMatch(parts[7]);
    }
  }
  final String file;
  if (parts.length == 4 && parts[2] == 'catalog') {
    file = parts[3];
  } else if (parts.length == 6 &&
      parts[2] == 'collections' &&
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
  return revision != null && revision <= miteMiteMaxSequence;
}

bool _validSyncNumber(String value) =>
    RegExp(r'^[1-9][0-9]{0,15}$').hasMatch(value) &&
    int.parse(value) <= miteMiteMaxSequence;

bool isOwnedSyncDirectoryPath(String path, String owner) =>
    path == 'devices/$owner'
    ? isOwnedSyncRevisionPath('$path/catalog/1.json', owner)
    : switch (path.split('/').length) {
        5 => isOwnedSyncRevisionPath('$path/1.json', owner),
        7 => isOwnedSyncRevisionPath('$path/00-0-${'0' * 64}.ndjson.gz', owner),
        _ => false,
      };

abstract interface class MiteMiteStorage {
  Future<List<String>> list(String path);
  Future<Uint8List?> read(String path, {int maxBytes = miteMiteMaxBytes});

  /// Existing immutable bytes are accepted only when byte-for-byte identical.
  Future<void> writeImmutable(String path, Uint8List bytes);
  Future<void> deleteOwnedRevision(String path, {required String owner});

  /// The caller authorizes retiring a complete owned device or collection.
  Future<void> deleteOwnedDirectory(String path, {required String owner});
}

/// File transport keeps large Bookmark archives out of Dart and SAF byte arrays.
abstract interface class MiteMitePayloadStorage implements MiteMiteStorage {
  /// Verify the named payload and optionally copy it to a new private file.
  Future<bool> copyPayload(
    String path, {
    String? destination,
    required int length,
    required String sha256,
  });

  /// Publish a private file immutably only when its length and hash match.
  Future<void> writePayload(
    String path, {
    required String sourcePath,
    required int length,
    required String sha256,
  });
}

void validateMiteMitePayload(String path, int length, String sha256) {
  final parts = path.split('/');
  if (parts.length != 6 ||
      parts[3] != 'bookmarks' ||
      !path.endsWith('.bsexport') ||
      !isOwnedSyncRevisionPath(path, parts[1]) ||
      length <= 0 ||
      length > miteMiteMaxBookmarkArchiveBytes ||
      !RegExp(r'^[0-9a-f]{64}$').hasMatch(sha256)) {
    throw const FormatException('Invalid Bookmark revision file');
  }
}

Future<bool> copyMiteMitePayloadFromStorage(
  MiteMiteStorage storage,
  String path, {
  String? destination,
  required int length,
  required String sha256,
}) async {
  validateMiteMitePayload(path, length, sha256);
  if (storage case final MiteMitePayloadStorage files) {
    return files.copyPayload(
      path,
      destination: destination,
      length: length,
      sha256: sha256,
    );
  }
  if (length > miteMiteMaxBytes) {
    throw UnsupportedError('Storage does not support large Bookmark files');
  }
  final bytes = await storage.read(path, maxBytes: length);
  if (bytes == null) return false;
  if (bytes.length != length ||
      crypto.sha256.convert(bytes).toString() != sha256) {
    throw const FormatException('Sync payload verification failed');
  }
  if (destination != null) {
    final file = await File(destination).create(exclusive: true);
    try {
      await file.writeAsBytes(bytes, flush: true);
    } catch (_) {
      await file.delete();
      rethrow;
    }
  }
  return true;
}

Future<void> writeMiteMitePayloadToStorage(
  MiteMiteStorage storage,
  String path, {
  required String sourcePath,
  required int length,
  required String sha256,
}) async {
  validateMiteMitePayload(path, length, sha256);
  if (storage case final MiteMitePayloadStorage files) {
    return files.writePayload(
      path,
      sourcePath: sourcePath,
      length: length,
      sha256: sha256,
    );
  }
  if (length > miteMiteMaxBytes) {
    throw UnsupportedError('Storage does not support large Bookmark files');
  }
  final bytes = BytesBuilder(copy: false);
  await _verifyFilePayload(File(sourcePath), length, sha256, (chunk) async {
    bytes.add(chunk);
  });
  await storage.writeImmutable(path, bytes.takeBytes());
}

Future<void> _verifyFilePayload(
  File file,
  int length,
  String sha256, [
  Future<void> Function(List<int>)? onChunk,
]) async {
  if (await file.length() != length) {
    throw const FormatException('Sync payload verification failed');
  }
  var count = 0;
  Stream<List<int>> boundedChunks() async* {
    await for (final chunk in file.openRead()) {
      count += chunk.length;
      if (count > length) {
        throw const FormatException('Sync payload verification failed');
      }
      await onChunk?.call(chunk);
      yield chunk;
    }
  }

  final digest = await crypto.sha256.bind(boundedChunks()).single;
  if (count != length || digest.toString() != sha256) {
    throw const FormatException('Sync payload verification failed');
  }
}

Future<void> _copyVerifiedFilePayload(
  File source,
  File destination,
  int length,
  String sha256,
) async {
  await destination.create(exclusive: true);
  try {
    final sink = await destination.open(mode: FileMode.writeOnly);
    try {
      await _verifyFilePayload(source, length, sha256, (chunk) async {
        await sink.writeFrom(chunk);
      });
      await sink.flush();
    } finally {
      await sink.close();
    }
  } catch (_) {
    await destination.delete();
    rethrow;
  }
}

/// Mounted desktop/filesystem directories only. Android SAF needs its own
/// persisted-permission adapter; a content URI is deliberately not a path.
final class DirectoryMiteMiteStorage implements MiteMitePayloadStorage {
  DirectoryMiteMiteStorage(String directory) : root = _root(directory);
  final Directory root;

  static Directory _root(String directory) {
    if (directory.trim().isEmpty || directory.contains('://')) {
      throw ArgumentError.value(
        directory,
        'directory',
        'Expected filesystem directory',
      );
    }
    return Directory(p.join(directory, miteMiteRoot));
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
    var scanned = 0;
    await for (final entry in directory.list(followLinks: false)) {
      if (++scanned > miteMiteMaxEntries) {
        throw const FormatException('Sync directory exceeds entry limit');
      }
      if (entry is Link) continue;
      final name = p.basename(entry.path);
      if (isSafeSyncPath(name)) names.add(name);
    }
    return names..sort();
  }

  @override
  Future<Uint8List?> read(
    String path, {
    int maxBytes = miteMiteMaxBytes,
  }) async {
    if (maxBytes < 0 || maxBytes > miteMiteMaxBytes) {
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
  Future<bool> copyPayload(
    String path, {
    String? destination,
    required int length,
    required String sha256,
  }) async {
    validateMiteMitePayload(path, length, sha256);
    final source = File(await _path(path));
    if (!await source.exists()) return false;
    if (destination == null) {
      await _verifyFilePayload(source, length, sha256);
    } else {
      await _copyVerifiedFilePayload(source, File(destination), length, sha256);
    }
    return true;
  }

  @override
  Future<void> writePayload(
    String path, {
    required String sourcePath,
    required int length,
    required String sha256,
  }) async {
    validateMiteMitePayload(path, length, sha256);
    final source = File(sourcePath);
    final destination = File(await _path(path, createParents: true));
    if (await destination.exists()) {
      await _verifyFilePayload(source, length, sha256);
      await _verifyFilePayload(destination, length, sha256);
      return;
    }
    final scratch = File('${destination.path}.${const Uuid().v4()}.partial');
    await _copyVerifiedFilePayload(source, scratch, length, sha256);
    try {
      if (!await atomic.publishFileIfAbsentAsync(
        scratch.path,
        destination.path,
      )) {
        await _verifyFilePayload(destination, length, sha256);
      }
    } finally {
      if (await scratch.exists()) await scratch.delete();
    }
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
  Future<void> deleteOwnedDirectory(
    String path, {
    required String owner,
  }) async {
    if (!isOwnedSyncDirectoryPath(path, owner)) {
      throw const FormatException('Unsafe sync cleanup path');
    }
    final directory = Directory(await _path(path));
    final type = await FileSystemEntity.type(
      directory.path,
      followLinks: false,
    );
    if (type == FileSystemEntityType.notFound) return;
    if (type != FileSystemEntityType.directory) {
      throw const FormatException('Expected a sync directory');
    }
    if (path.split('/').length == 7) {
      // Do not recurse through an unexpected document at a chunk path.
      await directory.delete();
      return;
    }
    try {
      await directory.delete(recursive: true);
    } on FileSystemException {
      if (await FileSystemEntity.type(directory.path, followLinks: false) !=
          FileSystemEntityType.notFound) {
        rethrow;
      }
    }
  }

  @override
  Future<void> writeImmutable(String path, Uint8List bytes) async {
    if (!isSafeSyncPath(path) || bytes.length > miteMiteMaxBytes) {
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
      if (!await atomic.publishFileIfAbsentAsync(
        scratch.path,
        destination.path,
      )) {
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
