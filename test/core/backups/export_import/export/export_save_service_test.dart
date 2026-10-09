import 'package:boorusama/core/backups/export_import/export/export_save_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('boorusama/export_save');
  late FilePickerPlatform original;
  late _Picker picker;
  setUp(() {
    original = FilePickerPlatform.instance;
    picker = _Picker();
    FilePickerPlatform.instance = picker;
  });
  tearDown(() {
    FilePickerPlatform.instance = original;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'saves to a granted document URI without reading export into memory',
    () async {
      MethodCall? request;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            request = call;
            return 'content://provider/document/export';
          });
      expect(
        await const AndroidExportSaveService().save('/cache/file.bsexport'),
        true,
      );
      expect(request?.method, 'saveToDirectory');
      expect(request?.arguments, {
        'source': '/cache/file.bsexport',
        'directory': 'content://provider/tree/folder',
      });
      expect(picker.options?.accessMode, AndroidSAFAccessMode.readWrite);
      expect(picker.options?.persistGrant, false);
    },
  );

  test('sends the chosen file name to the native SAF writer', () async {
    MethodCall? request;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          request = call;
          return 'content://provider/document/custom-export';
        });

    expect(
      await const AndroidExportSaveService().save(
        '/cache/file.bsexport',
        fileName: 'My bookmarks.bsexport',
      ),
      true,
    );
    expect(request?.method, 'saveToDirectory');
    expect(request?.arguments, {
      'source': '/cache/file.bsexport',
      'directory': 'content://provider/tree/folder',
      'fileName': 'My bookmarks.bsexport',
    });
  });

  test('invalid file names are rejected before opening the picker', () async {
    await expectLater(
      const AndroidExportSaveService().save(
        '/cache/file.bsexport',
        fileName: '../invalid.bsexport',
      ),
      throwsArgumentError,
    );
    expect(picker.options, isNull);
  });

  test('canceling folder selection does not request a write', () async {
    picker.path = null;
    var writes = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async {
          writes++;
          return 'content://provider/document/export';
        });
    expect(
      await const AndroidExportSaveService().save('/cache/file.bsexport'),
      false,
    );
    expect(writes, 0);
  });

  test(
    'native write errors propagate without reporting a successful save',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            (_) => Future<Object?>.error(
              PlatformException(code: 'export_save_failed'),
            ),
          );
      await expectLater(
        const AndroidExportSaveService().save('/cache/file.bsexport'),
        throwsA(isA<PlatformException>()),
      );
    },
  );
}

class _Picker extends FilePickerPlatform {
  String? path = 'content://provider/tree/folder';
  AndroidSAFOptions? options;

  @override
  Future<String?> getDirectoryPath({
    String? dialogTitle,
    bool lockParentWindow = false,
    String? initialDirectory,
    AndroidSAFOptions? androidSafOptions,
  }) async {
    options = androidSafOptions;
    return path;
  }
}
