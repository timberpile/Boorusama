import 'dart:convert';

import '../../../../foundation/clipboard.dart';
import '../../../../foundation/filesystem.dart';

const kExportClipboardPrefix = 'BOORUSAMA-EXPORT:1\n';
const kExportClipboardMaxEncodedBytes = 1024 * 1024;

abstract interface class ExportClipboardPort {
  Future<void> write(String value);
  Future<bool> containsExport();
  Future<String?> read();
}

final class AppExportClipboardPort implements ExportClipboardPort {
  const AppExportClipboardPort();

  @override
  Future<bool> containsExport() => AppClipboard.containsExport();

  @override
  Future<String?> read() => AppClipboard.pasteExport();

  @override
  Future<void> write(String value) => AppClipboard.copyExport(value);
}

final class ExportClipboardService {
  const ExportClipboardService({required this.fs, required this.clipboard});

  final AppFileSystem fs;
  final ExportClipboardPort clipboard;

  Future<bool> canCopy(
    String packagePath, {
    required bool containsCredentials,
  }) async {
    if (containsCredentials) return false;
    final bytes = await fs.fileSize(packagePath);
    final encodedLength =
        ((bytes + 2) ~/ 3) * 4 + kExportClipboardPrefix.length;
    return encodedLength <= kExportClipboardMaxEncodedBytes;
  }

  Future<void> copy(
    String packagePath, {
    required bool containsCredentials,
  }) async {
    if (!await canCopy(
      packagePath,
      containsCredentials: containsCredentials,
    )) {
      throw StateError('Export cannot be copied to the clipboard');
    }
    final encoded = base64Encode(await fs.readBytes(packagePath));
    await clipboard.write('$kExportClipboardPrefix$encoded');
  }

  Future<bool> detect() => clipboard.containsExport();

  Future<String> importToTemporaryFile() async {
    final value = await clipboard.read();
    if (value == null || !value.startsWith(kExportClipboardPrefix)) {
      throw const FormatException('Clipboard does not contain an export');
    }
    final encoded = value.substring(kExportClipboardPrefix.length).trim();
    if (encoded.length + kExportClipboardPrefix.length >
        kExportClipboardMaxEncodedBytes) {
      throw const FormatException('Clipboard export is too large');
    }
    final bytes = base64Decode(encoded);
    final directory = await fs.createTempDirectory('boorusama_clipboard_');
    final path = '$directory/clipboard.bsexport';
    await fs.writeBytes(path, bytes);
    return path;
  }
}
