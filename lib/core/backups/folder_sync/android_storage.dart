import 'dart:typed_data';

import 'package:flutter/services.dart';

import 'storage.dart';

/// Uses persisted SAF document-tree grants; content URIs never become paths.
final class AndroidFolderSyncStorage implements FolderSyncStorage {
  AndroidFolderSyncStorage(
    this.location, {
    this.channel = const MethodChannel('boorusama/folder_sync'),
  }) {
    final uri = Uri.tryParse(location);
    if (uri == null ||
        uri.scheme != 'content' ||
        uri.host.isEmpty ||
        uri.pathSegments.length != 2 ||
        uri.pathSegments.first != 'tree') {
      throw const FormatException(
        'A persisted document-tree grant is required',
      );
    }
  }
  final String location;
  final MethodChannel channel;
  Future<T?> _call<T>(
    String method,
    String path, [
    Map<String, Object?> args = const {},
  ]) {
    if (!isSafeSyncPath(path, root: true)) {
      throw const FormatException('Unsafe sync path');
    }
    return channel.invokeMethod<T>(method, {
      'location': location,
      'path': path,
      ...args,
    });
  }

  @override
  Future<List<String>> list(String path) async {
    final names = await _call<List<dynamic>>('list', path);
    if (names == null ||
        names.toSet().length != names.length ||
        names.length > folderSyncMaxEntries ||
        names.any(
          (name) =>
              name is! String || name.contains('/') || !isSafeSyncPath(name),
        )) {
      throw const FormatException('Invalid SAF directory listing');
    }
    return names.cast<String>();
  }

  @override
  Future<Uint8List?> read(
    String path, {
    int maxBytes = folderSyncMaxBytes,
  }) async {
    if (maxBytes < 0 || maxBytes > folderSyncMaxBytes) {
      throw ArgumentError.value(maxBytes);
    }
    final bytes = await _call<Uint8List>('read', path, {'maxBytes': maxBytes});
    if (bytes != null && bytes.length > maxBytes) {
      throw const FormatException('SAF read exceeds limit');
    }
    return bytes;
  }

  @override
  Future<void> writeImmutable(String path, Uint8List bytes) async {
    if (bytes.length > folderSyncMaxBytes) {
      throw const FormatException('SAF write exceeds limit');
    }
    if (await _call<bool>('writeImmutable', path, {'bytes': bytes}) != true) {
      throw StateError('SAF publication failed');
    }
  }

  @override
  Future<void> deleteOwnedRevision(String path, {required String owner}) async {
    if (!isOwnedSyncRevisionPath(path, owner)) {
      throw const FormatException('Unsafe retention path');
    }
    if (await _call<bool>('deleteOwnedRevision', path, {'owner': owner}) !=
        true) {
      throw StateError('SAF retention failed');
    }
  }
}
