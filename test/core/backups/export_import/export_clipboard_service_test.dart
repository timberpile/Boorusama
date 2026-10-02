import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:boorusama/core/backups/export_import/clipboard/export_clipboard_service.dart';
import 'package:boorusama/foundation/filesystem.dart';

void main() {
  late Directory directory;
  const fs = IoFileSystem();
  late _MemoryClipboard clipboard;
  late ExportClipboardService service;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('export_clipboard_');
    clipboard = _MemoryClipboard();
    service = ExportClipboardService(fs: fs, clipboard: clipboard);
  });
  tearDown(() => directory.delete(recursive: true));

  test('clipboard Base64 round trips the exact bsexport bytes', () async {
    final source = '${directory.path}/source.bsexport';
    await fs.writeBytes(source, Uint8List.fromList([0, 1, 2, 250, 255]));

    await service.copy(source, containsCredentials: false);
    final restored = await service.importToTemporaryFile();

    expect(await fs.readBytes(restored.path), await fs.readBytes(source));
    expect(clipboard.value, startsWith(kExportClipboardPrefix));
    await restored.dispose();
    expect(await fs.directoryExists(restored.directoryPath), isFalse);
  });

  test(
    'detection checks metadata without reading the clipboard payload',
    () async {
      clipboard.detected = true;

      expect(await service.detect(), isTrue);
      expect(clipboard.readCount, 0);
    },
  );

  test(
    'credentials and encoded payloads over one MiB cannot be copied',
    () async {
      final small = '${directory.path}/small.bsexport';
      final large = '${directory.path}/large.bsexport';
      await fs.writeBytes(small, Uint8List(4));
      await fs.writeBytes(large, Uint8List(800000));

      expect(await service.canCopy(small, containsCredentials: true), isFalse);
      expect(await service.canCopy(large, containsCredentials: false), isFalse);
    },
  );
}

final class _MemoryClipboard implements ExportClipboardPort {
  String? value;
  var detected = false;
  var readCount = 0;

  @override
  Future<bool> containsExport() async => detected;

  @override
  Future<String?> read() async {
    readCount++;
    return value;
  }

  @override
  Future<void> write(String value) async {
    this.value = value;
    detected = true;
  }
}
