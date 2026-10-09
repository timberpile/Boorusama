import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'export_filename.dart';

final androidExportSaveServiceProvider = Provider<AndroidExportSaveService>(
  (ref) => const AndroidExportSaveService(),
);

class AndroidExportSaveService {
  const AndroidExportSaveService();

  static const _channel = MethodChannel('boorusama/export_save');

  Future<bool> save(String source, {String? fileName}) async {
    if (fileName != null && normalizedExportFileName(fileName) != fileName) {
      throw ArgumentError.value(fileName, 'fileName', 'Invalid export file name');
    }
    final directory = await FilePicker.getDirectoryPath(
      androidSafOptions: const AndroidSAFOptions(
        accessMode: AndroidSAFAccessMode.readWrite,
        persistGrant: false,
      ),
    );
    if (directory == null) return false;
    final saved = await _channel.invokeMethod<String>('saveToDirectory', {
      'source': source,
      'directory': directory,
      if (fileName != null) 'fileName': fileName,
    });
    if (saved == null) {
      throw PlatformException(code: 'export_save_failed');
    }
    return true;
  }
}
