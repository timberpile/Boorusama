import 'package:dio/dio.dart';

/// App transport metadata is intentionally a neutral key, so standalone
/// clients do not depend on the application's coordinator implementation.
bool isDataRequestInterruption(Object error) =>
    error is DioException &&
    (error.type == DioExceptionType.cancel ||
        error.requestOptions.extra['boorusama.request.cooldown'] != null);
