import 'package:flutter/services.dart';

class PerformanceDiagnosticsExport {
  const PerformanceDiagnosticsExport();

  static const _channel = MethodChannel(
    'boorusama/performance_diagnostics',
  );

  Future<String> save({
    required String contents,
    required String fileName,
  }) async {
    final path = await _channel.invokeMethod<String>('save', {
      'contents': contents,
      'fileName': fileName,
    });
    if (path == null) {
      throw PlatformException(code: 'diagnostic_export_failed');
    }
    return path;
  }
}
