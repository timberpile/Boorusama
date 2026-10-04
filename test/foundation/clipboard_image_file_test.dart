import 'dart:io';

import 'package:boorusama/foundation/clipboard.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('image file copy hands its encoded bytes and MIME to Android', () async {
    final directory = await Directory.systemTemp.createTemp(
      'clipboard-file-test-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/image.webp');
    const encoded = <int>[0x52, 0x49, 0x46, 0x46, 0x00, 0x00, 0x00, 0x00];
    await file.writeAsBytes(encoded);
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    List<int>? handedBytes;
    String? handedMime;
    messenger.setMockMethodCallHandler(
      const MethodChannel('boorusama/image_clipboard'),
      (call) async {
        expect(call.method, 'copyImageFile');
        final arguments = call.arguments as Map<Object?, Object?>;
        handedBytes = await File(arguments['path']! as String).readAsBytes();
        handedMime = arguments['mimeType'] as String?;
        return null;
      },
    );
    addTearDown(
      () => messenger.setMockMethodCallHandler(
        const MethodChannel('boorusama/image_clipboard'),
        null,
      ),
    );

    await AppClipboard.copyImageFile(file.path, 'image/webp');

    expect(handedBytes, encoded);
    expect(handedMime, 'image/webp');
  });
}
