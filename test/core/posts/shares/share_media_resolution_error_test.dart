import 'package:boorusama/core/downloads/urls/types.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/shares/src/share_media_preparation.dart';
import 'package:boorusama/core/posts/shares/src/share_media_url_resolution.dart';
import 'package:boorusama/core/posts/shares/src/share_payloads.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boorusama/foundation/loggers.dart';
import 'package:boorusama/core/debug/src/logging/app_logger.dart';

import '../../../bulk_downloads/common.dart';

void main() {
  test(
    'Original resolution retains the cause and its source stack safely',
    () async {
      final request = RequestOptions(
        path: 'https://private-host/private-query',
      );
      final cause = DioException(
        requestOptions: request,
        type: DioExceptionType.badResponse,
        response: Response(requestOptions: request, statusCode: 503),
        message: 'private-message',
      );
      final stack = StackTrace.fromString(
        '#0 resolve (package:boorusama/resolver.dart:12:3)',
      );
      try {
        await resolveShareMediaUrl(
          payload: const SharePayload(
            id: SharePayloadId.original,
            value: 'https://site.test/preview.jpg',
            canCopy: false,
            canShare: true,
          ),
          post: dummyPost(
            id: 42,
            originalImageUrl: 'https://site.test/preview.jpg',
          ),
          extractor: _FailingExtractor(cause, stack),
        );
        fail('Expected resolution to fail');
      } on ShareMediaException catch (error) {
        expect(error.failure, ShareMediaFailure.network);
        expect(error.cause, same(cause));
        expect(
          error.stackTrace.toString(),
          contains('package:boorusama/resolver.dart:12:3'),
        );
        final logger = AppLogger()
          ..handledError(
            'Media Share',
            'prepare_media:network',
            error: error.cause!,
            stackTrace: error.stackTrace,
          );
        expect(logger.dump(), contains('http_status=503'));
        expect(logger.dump(), contains('package:boorusama/resolver.dart:12:3'));
        expect(logger.dump(), isNot(contains('private-')));
      }
    },
  );
  test(
    'an authentication rejection while resolving Original is reported',
    () async {
      await expectLater(
        resolveShareMediaUrl(
          payload: const SharePayload(
            id: SharePayloadId.original,
            value: 'https://site.test/preview.jpg',
            canCopy: false,
            canShare: true,
          ),
          post: dummyPost(
            id: 42,
            originalImageUrl: 'https://site.test/preview.jpg',
          ),
          extractor: const _RejectedExtractor(),
        ),
        throwsA(
          isA<ShareMediaException>().having(
            (error) => error.failure,
            'failure',
            ShareMediaFailure.authentication,
          ),
        ),
      );
    },
  );
}

class _FailingExtractor implements DownloadFileUrlExtractor {
  _FailingExtractor(this.cause, this.stack);
  final Object cause;
  final StackTrace stack;

  @override
  Future<DownloadUrlData?> getDownloadFileUrl({
    required Post post,
    required String quality,
  }) async => Error.throwWithStackTrace(cause, stack);
}

class _RejectedExtractor implements DownloadFileUrlExtractor {
  const _RejectedExtractor();

  @override
  Future<DownloadUrlData?> getDownloadFileUrl({
    required Post post,
    required String quality,
  }) async => throw DioException(
    requestOptions: RequestOptions(path: 'https://site.test/original'),
    response: Response(
      requestOptions: RequestOptions(path: 'https://site.test/original'),
      statusCode: 403,
    ),
  );
}
