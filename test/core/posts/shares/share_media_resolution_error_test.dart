import 'package:boorusama/core/downloads/urls/types.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/shares/src/share_media_preparation.dart';
import 'package:boorusama/core/posts/shares/src/share_media_url_resolution.dart';
import 'package:boorusama/core/posts/shares/src/share_payloads.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../bulk_downloads/common.dart';

void main() {
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
