import 'package:dio/dio.dart';
import 'package:flutter/services.dart';

import 'gif_export_contract.dart';

/// Keeps the Android process and CPU available for one user-started conversion.
/// The editor still owns cancellation, source leases, and the completed result.
class GifBackgroundExecution {
  GifBackgroundExecution({required this.title, required this.cancelLabel});

  final String title;
  final String cancelLabel;
  static const _channel = MethodChannel('boorusama/gif_background');
  static var _nextJob = 0;
  int? _job;

  Future<void> start(CancelToken token) async {
    final job = ++_nextJob;
    _job = job;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'cancel' && call.arguments == job && _job == job) {
        token.cancel();
      }
    });
    try {
      await _channel.invokeMethod<void>('start', {
        'job': job,
        'title': title,
        'cancelLabel': cancelLabel,
      });
    } catch (error) {
      throw GifConversionException(
        GifConversionFailure.encoderUnavailable,
        cause: error,
        stage: GifConversionStage.encoding,
      );
    }
  }

  Future<void> stop() async {
    final job = _job;
    if (job == null) return;
    try {
      await _channel.invokeMethod<void>('stop', job);
    } finally {
      _job = null;
      _channel.setMethodCallHandler(null);
    }
  }
}
