import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../foundation/filesystem.dart';
import '../../../configs/manage/providers.dart';
import '../../../settings/providers.dart';

final gifSaveServiceProvider = Provider<GifSaveService>(
  (ref) => GifSaveService(
    resolveDirectory: () async {
      final profile = ref
          .read(currentReadOnlyBooruConfigDownloadProvider)
          .location;
      final global = ref.read(settingsProvider).downloadPath;
      final configured = profile != null && profile.isNotEmpty
          ? profile
          : global;
      if (configured != null && configured.isNotEmpty) return configured;
      final directory = await ref.read(appFileSystemProvider).getDownloadPath();
      if (directory == null) {
        throw const FileSystemException('Download folder unavailable');
      }
      return directory;
    },
  ),
  dependencies: [currentReadOnlyBooruConfigDownloadProvider, settingsProvider],
);

class GifSaveService {
  const GifSaveService({required this.resolveDirectory});
  final Future<String> Function() resolveDirectory;
  static const _channel = MethodChannel('boorusama/gif_save');

  Future<bool> save(String path, String fileName) async =>
      await _channel.invokeMethod<bool>('saveToDirectory', {
        'source': path,
        'name': fileName,
        'directory': await resolveDirectory(),
      }) ??
      false;
}
