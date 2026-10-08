import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'types.dart';

class AutoBackupRepositoryAndroid implements AutoBackupRepository {
  const AutoBackupRepositoryAndroid({
    this.temporaryDirectory = getTemporaryDirectory,
  });

  final Future<Directory> Function() temporaryDirectory;

  static const channel = MethodChannel('boorusama/auto_backup');

  static bool isTree(String? location) {
    final uri = location == null ? null : Uri.tryParse(location);
    return uri != null &&
        uri.scheme == 'content' &&
        uri.host.isNotEmpty &&
        uri.pathSegments.length == 2 &&
        uri.pathSegments.first == 'tree' &&
        uri.pathSegments.last.isNotEmpty;
  }

  static Future<String?> pickDirectory() =>
      channel.invokeMethod<String>('pickDirectory');

  static Future<String?> directoryDisplayPath(String location) async {
    if (!isTree(location)) return location;

    final uri = Uri.parse(location);
    // Only the external-storage provider defines IDs as volume:relative/path.
    // Other providers can use opaque IDs; ask them for the folder name instead.
    if (uri.host == 'com.android.externalstorage.documents') {
      final documentId = uri.pathSegments.last;
      final separator = documentId.indexOf(':');
      if (separator > 0 && separator < documentId.length - 1) {
        final volume = documentId.substring(0, separator);
        final path = documentId.substring(separator + 1);
        return volume == 'primary' ? path : '$volume/$path';
      }
    }

    try {
      final name = await channel.invokeMethod<String>('directoryDisplayName', {
        'location': location,
      });
      return name == null || name.trim().isEmpty ? null : name;
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  Future<T> _call<T>(
    String method,
    String location, [
    Map<String, Object?> extra = const {},
  ]) async {
    final value = await channel.invokeMethod<T>(method, {
      'location': location,
      ...extra,
    });
    if (value == null) throw PlatformException(code: 'backup_storage_failed');
    return value;
  }

  @override
  Future<String> getBackupDirectoryPath(String? userSelectedPath) async {
    if (!isTree(userSelectedPath)) {
      throw PlatformException(code: 'backup_folder_access_required');
    }
    await _call<bool>('prepare', userSelectedPath!);
    return userSelectedPath;
  }

  @override
  Future<AutoBackupManifest> loadManifest(String directory) async {
    final content = await _call<String>('readManifest', directory);
    return AutoBackupManifest.fromJson(
      jsonDecode(content) as Map<String, dynamic>,
    );
  }

  @override
  Future<void> saveManifest(
    String directory,
    AutoBackupManifest manifest,
  ) async {
    await _call<bool>('writeManifest', directory, {
      'content': jsonEncode(manifest.toJson()),
    });
  }

  @override
  Future<List<String>> listBackupFiles(String directory) async =>
      (await _call<List<Object?>>('list', directory)).cast<String>();

  @override
  Future<bool> fileExists(String location) => _call<bool>('exists', location);

  @override
  Future<int> getFileSize(String location) => _call<int>('size', location);

  @override
  Future<void> deleteFile(String location) async {
    await _call<bool>('delete', location);
  }

  @override
  Future<String> writeBackup(
    String destination,
    Future<String> Function(String outputPath) createPackage,
  ) async {
    final cache = await temporaryDirectory();
    final staging = await Directory(cache.path).createTemp('auto_backup_');
    try {
      final source = await createPackage(
        p.join(staging.path, p.basename(destination)),
      );
      await _call<bool>('writeBackup', destination, {'source': source});
      return destination;
    } finally {
      await staging.delete(recursive: true);
    }
  }
}
