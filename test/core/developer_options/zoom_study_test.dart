import 'package:boorusama/core/developer_options/types.dart';
import 'package:boorusama/core/developer_options/zoom_study.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('boorusama/performance_diagnostics');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('Zoom Study is disabled by default and preserves other options', () {
    expect(DeveloperOptions.defaults.zoomStudyEnabled, isFalse);
    final enabled = DeveloperOptions.defaults.copyWith(zoomStudyEnabled: true);
    expect(enabled.zoomStudyEnabled, isTrue);
    expect(enabled.automaticMediaLoadingEnabled, isTrue);
    expect(enabled.copyWith(zoomStudyEnabled: false).zoomStudyEnabled, isFalse);
  });

  test('export filename is UTC, timestamped and Android-safe', () {
    expect(
      zoomStudyFileName(DateTime.utc(2026, 11, 5, 18, 7, 9, 23)),
      'boorusama-zoom-study-20261105T180709023Z.json',
    );
  });

  test('stored observations decode without discarding ordering', () {
    final records = decodeZoomStudyRecords(
      '[{"preferred_zoom":2.0},{"preferred_zoom":3.4}]',
    );
    expect(records.map((row) => row['preferred_zoom']), [2.0, 3.4]);
    expect(decodeZoomStudyRecords(null), isEmpty);
    expect(() => decodeZoomStudyRecords('{}'), throwsFormatException);
    expect(() => decodeZoomStudyRecords('[null]'), throwsFormatException);
  });

  test('exports zoom observations through the Android Downloads channel', () async {
    MethodCall? call;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (request) async {
          call = request;
          return '/storage/emulated/0/Download/boorusama-zoom-study.json';
        });

    final result = await const ZoomStudyExport().save(
      contents: '{"schema_version":1,"observations":[]}',
      fileName: 'boorusama-zoom-study-20261105T180709023Z.json',
    );

    expect(call?.method, 'saveZoomStudy');
    expect(call?.arguments, {
      'contents': '{"schema_version":1,"observations":[]}',
      'fileName': 'boorusama-zoom-study-20261105T180709023Z.json',
    });
    expect(result, contains('/Download/'));
  });

  test('reports a failed native export instead of claiming success', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => null);

    await expectLater(
      const ZoomStudyExport().save(contents: '{}', fileName: 'name.json'),
      throwsA(
        isA<PlatformException>().having(
          (error) => error.code,
          'code',
          'diagnostic_export_failed',
        ),
      ),
    );
  });
}
