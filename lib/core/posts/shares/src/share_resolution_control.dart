import 'package:dio/dio.dart';

import 'share_media_preparation.dart';

void checkShareCancellation(CancelToken? cancelToken) {
  if (cancelToken?.isCancelled ?? false) {
    throw const ShareMediaException(ShareMediaFailure.cancelled);
  }
}

Future<T> awaitShareOrCancellation<T>(
  Future<T> operation,
  CancelToken? cancelToken,
) {
  checkShareCancellation(cancelToken);
  if (cancelToken == null) return operation;
  return Future.any([
    operation,
    cancelToken.whenCancel.then<T>(
      (_) => throw const ShareMediaException(ShareMediaFailure.cancelled),
    ),
  ]);
}
