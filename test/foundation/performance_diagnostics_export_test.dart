import 'package:boorusama/foundation/performance/performance_diagnostics.dart';
import 'package:boorusama/foundation/performance/performance_diagnostics_export.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('boorusama/performance_diagnostics');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('uses a deterministic safe name for an unspecified local build', () {
    expect(
      performanceDiagnosticsFileName(
        DateTime.utc(2026, 10, 13, 8, 9, 10, 11),
      ),
      'boorusama-performance-debug-20261013T080910011Z-'
      'unknown.json',
    );
  });

  test(
    'sends report contents and its generated name to Android storage',
    () async {
      MethodCall? request;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            request = call;
            return '/storage/emulated/0/Download/Dev/diagnostics/report.json';
          });

      final path = await const PerformanceDiagnosticsExport().save(
        contents: '{"schema_version":1}',
        fileName:
            'boorusama-performance-debug-20261013T080910011Z-'
            '12345678.json',
      );

      expect(request?.method, 'save');
      expect(request?.arguments, {
        'contents': '{"schema_version":1}',
        'fileName':
            'boorusama-performance-debug-20261013T080910011Z-'
            '12345678.json',
      });
      expect(path, '/storage/emulated/0/Download/Dev/diagnostics/report.json');
    },
  );

  test('treats an empty native result as a failed export', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => null);

    await expectLater(
      const PerformanceDiagnosticsExport().save(
        contents: '{}',
        fileName:
            'boorusama-performance-release-20261013T080910011Z-'
            '12345678.json',
      ),
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
