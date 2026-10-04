import 'package:boorusama/boorus/e621/downloads/providers.dart';
import 'package:boorusama/boorus/e621/posts/types.dart';
import 'package:boorusama/core/downloads/urls/providers.dart';
import 'package:boorusama/core/downloads/urls/types.dart';
import 'package:boorusama/core/posts/shares/src/share_media_url_resolution.dart';
import 'package:boorusama/core/posts/shares/src/share_media_preparation.dart';
import 'package:boorusama/core/posts/shares/src/share_payloads.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../bulk_downloads/common.dart';

void main() {
  final post = dummyPost(
    id: 42,
    originalImageUrl: 'https://site.test/preview.jpg',
  );

  test('Original resolves the download extractor URL and cookie', () async {
    final result = await resolveShareMediaUrl(
      payload: const SharePayload(
        id: SharePayloadId.original,
        value: 'https://site.test/preview.jpg',
        canCopy: false,
        canShare: true,
      ),
      post: post,
      extractor: const _Extractor(
        DownloadUrlData(
          url: 'https://site.test/full.png',
          cookie: 'session=private',
        ),
      ),
    );

    expect(result.url, 'https://site.test/full.png');
    expect(result.cookie, 'session=private');
  });

  test(
    'Image retains the viewer URL without resolving a download URL',
    () async {
      final result = await resolveShareMediaUrl(
        payload: const SharePayload(
          id: SharePayloadId.image,
          value: 'https://site.test/sample.webp',
          canCopy: true,
          canShare: true,
        ),
        post: post,
        extractor: const _Extractor(null),
      );

      expect(result.url, 'https://site.test/sample.webp');
      expect(result.cookie, isNull);
    },
  );

  test('Original rejects generic sample and thumbnail fallback', () async {
    final previewOnlyPost = dummyPost(
      id: 43,
      sampleImageUrl: 'https://site.test/sample.jpg',
      thumbnailImageUrl: 'https://site.test/thumb.jpg',
    );

    await expectLater(
      resolveShareMediaUrl(
        payload: const SharePayload(
          id: SharePayloadId.original,
          value: null,
          deferred: true,
          canCopy: false,
          canShare: true,
        ),
        post: previewOnlyPost,
        extractor: const UrlInsidePostExtractor(),
      ),
      throwsA(
        isA<ShareMediaException>().having(
          (error) => error.failure,
          'failure',
          ShareMediaFailure.unavailable,
        ),
      ),
    );
  });

  test(
    'explicit exact extractor resolves Original without a stored URL',
    () async {
      final previewOnlyPost = dummyPost(
        id: 44,
        sampleImageUrl: 'https://site.test/sample.jpg',
      );

      final result = await resolveShareMediaUrl(
        payload: const SharePayload(
          id: SharePayloadId.original,
          value: null,
          deferred: true,
          canCopy: false,
          canShare: true,
        ),
        post: previewOnlyPost,
        extractor: const _ExactExtractor(
          DownloadUrlData.urlOnly('https://site.test/full.jpg'),
        ),
      );

      expect(result.url, 'https://site.test/full.jpg');
    },
  );

  test('preview-only video cannot resolve a shareable video link', () async {
    final previewOnlyPost = dummyPost(
      id: 45,
      format: 'mp4',
      thumbnailImageUrl: 'https://site.test/thumb.jpg',
      sampleImageUrl: 'https://site.test/preview.jpg',
    );

    expect(
      hasExactVideoSource(previewOnlyPost, const UrlInsidePostExtractor()),
      isFalse,
    );
    await expectLater(
      resolveShareMediaUrl(
        payload: const SharePayload(
          id: SharePayloadId.video,
          value: null,
          deferred: true,
          canCopy: true,
          canShare: true,
        ),
        post: previewOnlyPost,
        extractor: const UrlInsidePostExtractor(),
      ),
      throwsA(
        isA<ShareMediaException>().having(
          (error) => error.failure,
          'failure',
          ShareMediaFailure.unavailable,
        ),
      ),
    );
  });

  test(
    'explicit video extractor keeps a lazy video source available',
    () async {
      final lazyPost = dummyPost(
        id: 46,
        format: 'mp4',
        thumbnailImageUrl: 'https://site.test/thumb.jpg',
      );
      const extractor = _ExactVideoExtractor(
        DownloadUrlData.urlOnly('https://site.test/exact.mp4'),
      );

      expect(hasExactVideoSource(lazyPost, extractor), isTrue);
      final result = await resolveShareMediaUrl(
        payload: const SharePayload(
          id: SharePayloadId.video,
          value: null,
          deferred: true,
          canCopy: true,
          canShare: true,
        ),
        post: lazyPost,
        extractor: extractor,
      );

      expect(result.url, 'https://site.test/exact.mp4');
    },
  );

  test(
    'default video resolution ignores an image original when a direct video exists',
    () async {
      final videoPost = dummyPost(
        id: 47,
        format: 'mp4',
        originalImageUrl: 'https://site.test/poster.jpg',
        videoUrl: 'https://site.test/direct.mp4',
      );

      final result = await resolveShareMediaUrl(
        payload: const SharePayload(
          id: SharePayloadId.video,
          value: 'https://site.test/direct.mp4',
          canCopy: true,
          canShare: true,
        ),
        post: videoPost,
        extractor: const UrlInsidePostExtractor(),
      );

      expect(result.url, 'https://site.test/direct.mp4');
    },
  );

  test(
    'default extractor accepts a proven original also stored as sample',
    () async {
      final videoPost = dummyPost(
        id: 51,
        format: 'mp4',
        originalImageUrl: 'https://site.test/full.mp4',
        sampleImageUrl: 'https://site.test/full.mp4',
        thumbnailImageUrl: 'https://site.test/thumb.jpg',
      );
      const extractor = UrlInsidePostExtractor();

      expect(hasExactVideoSource(videoPost, extractor), isTrue);
      final result = await resolveShareMediaUrl(
        payload: const SharePayload(
          id: SharePayloadId.video,
          value: null,
          deferred: true,
          canCopy: true,
          canShare: true,
        ),
        post: videoPost,
        extractor: extractor,
      );

      expect(result.url, 'https://site.test/full.mp4');
    },
  );

  test(
    'exact extractor still rejects a distinct sample video fallback',
    () async {
      final previewOnlyPost = dummyPost(
        id: 52,
        format: 'mp4',
        sampleImageUrl: 'https://site.test/sample.mp4',
        thumbnailImageUrl: 'https://site.test/thumb.jpg',
      );

      await expectLater(
        resolveShareMediaUrl(
          payload: const SharePayload(
            id: SharePayloadId.video,
            value: null,
            deferred: true,
            canCopy: true,
            canShare: true,
          ),
          post: previewOnlyPost,
          extractor: const _ExactVideoExtractor(
            DownloadUrlData.urlOnly('https://site.test/sample.mp4'),
          ),
        ),
        throwsA(
          isA<ShareMediaException>().having(
            (error) => error.failure,
            'failure',
            ShareMediaFailure.unavailable,
          ),
        ),
      );
    },
  );
  for (final testCase in [
    (name: 'image URL', url: 'https://site.test/preview.jpg'),
    (name: 'archive URL', url: 'https://site.test/archive.zip'),
  ]) {
    test('rejects a direct ${testCase.name} as Video media', () async {
      final invalidPost = dummyPost(
        id: 48,
        format: 'mp4',
        videoUrl: testCase.url,
      );

      expect(
        hasExactVideoSource(invalidPost, const UrlInsidePostExtractor()),
        isFalse,
      );
      await expectLater(
        resolveShareMediaUrl(
          payload: SharePayload(
            id: SharePayloadId.video,
            value: testCase.url,
            canCopy: true,
            canShare: true,
          ),
          post: invalidPost,
          extractor: const UrlInsidePostExtractor(),
        ),
        throwsA(
          isA<ShareMediaException>().having(
            (error) => error.failure,
            'failure',
            ShareMediaFailure.unavailable,
          ),
        ),
      );
    });
  }

  test('explicit extractor rejects an archive instead of a video', () async {
    final videoPost = dummyPost(id: 49, format: 'mp4');
    await expectLater(
      resolveShareMediaUrl(
        payload: const SharePayload(
          id: SharePayloadId.video,
          value: null,
          deferred: true,
          canCopy: true,
          canShare: true,
        ),
        post: videoPost,
        extractor: const _ExactVideoExtractor(
          DownloadUrlData.urlOnly('https://site.test/archive.zip'),
        ),
      ),
      throwsA(
        isA<ShareMediaException>().having(
          (error) => error.failure,
          'failure',
          ShareMediaFailure.unavailable,
        ),
      ),
    );
  });

  test(
    'E621 exact original remains usable when also stored as sample',
    () async {
      final videoPost =
          dummyPost(
            id: 50,
            format: 'mp4',
            originalImageUrl: 'https://site.test/full.mp4',
            sampleImageUrl: 'https://site.test/full.mp4',
            thumbnailImageUrl: 'https://site.test/thumb.jpg',
          ).copyWith(
            booruData: const E621PostData(
              generalTags: {},
              metaTags: {},
              speciesTags: {},
              invalidTags: {},
              loreTags: {},
              upScore: 0,
              downScore: 0,
              favCount: 0,
              isFavorited: false,
              sources: [],
              description: '',
              videoVariants: [
                E621VideoVariantData(
                  type: E621VideoVariantType.original,
                  url: 'https://site.test/full.mp4',
                  size: 0,
                  width: 0,
                  height: 0,
                  codec: '',
                  fps: 0,
                ),
              ],
            ),
          );
      const extractor = E621DownloadFileUrlExtractor();

      expect(hasExactVideoSource(videoPost, extractor), isTrue);
      final result = await resolveShareMediaUrl(
        payload: const SharePayload(
          id: SharePayloadId.video,
          value: null,
          deferred: true,
          canCopy: true,
          canShare: true,
        ),
        post: videoPost,
        extractor: extractor,
      );

      expect(result.url, 'https://site.test/full.mp4');
    },
  );
}

class _Extractor implements DownloadFileUrlExtractor {
  const _Extractor(this.result);

  final DownloadUrlData? result;

  @override
  Future<DownloadUrlData?> getDownloadFileUrl({
    required Post post,
    required String quality,
  }) async {
    if (quality != 'original') throw StateError('Unexpected quality');
    return result;
  }
}

class _ExactExtractor extends _Extractor implements ExactOriginalUrlExtractor {
  const _ExactExtractor(super.result);

  @override
  bool canResolveExactOriginal(Post post) => true;
}

class _ExactVideoExtractor extends _Extractor
    implements ExactVideoUrlExtractor {
  const _ExactVideoExtractor(super.result);

  @override
  bool canResolveExactVideo(Post post) => true;
}
