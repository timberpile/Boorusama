import 'dart:typed_data';

import 'package:flutter/services.dart';

import 'storage.dart';

/// Uses persisted SAF document-tree grants; content URIs never become paths.
final class AndroidMiteMiteStorage implements MiteMiteStorage {
  AndroidMiteMiteStorage(
    this.location, {
    this.channel = const MethodChannel('boorusama/mitemite'),
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
  static Future<String> privateDataDirectory({
    MethodChannel channel = const MethodChannel('boorusama/mitemite'),
  }) async {
    final value = await channel.invokeMethod<Object?>('privateDataDirectory');
    if (value is! String ||
        !value.startsWith('/') ||
        value.contains('\u0000')) {
      throw const FormatException('Private sync storage is unavailable');
    }
    return value;
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
        names.length > miteMiteMaxEntries ||
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
    int maxBytes = miteMiteMaxBytes,
  }) async {
    if (maxBytes < 0 || maxBytes > miteMiteMaxBytes) {
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
    if (bytes.length > miteMiteMaxBytes) {
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
