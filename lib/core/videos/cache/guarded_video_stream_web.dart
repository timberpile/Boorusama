import 'package:dio/dio.dart';

final class GuardedVideoStream {
  Stream<void> get failures => const Stream.empty();
  Uri get uri => throw UnsupportedError('Guarded native video is unavailable');
  static Future<GuardedVideoStream> open({
    required Dio transport,
    required String upstream,
    required Map<String, String> headers,
    required bool Function() isCurrent,
    required CancelToken cancellation,
  }) async => throw UnsupportedError('Guarded native video is unavailable');
  Future<void> close() async {}
}
