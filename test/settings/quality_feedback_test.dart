import 'package:boorusama/boorus/nozomi/nozomi_repository.dart';
import 'package:boorusama/boorus/danbooru/posts/post/types.dart';
import 'package:boorusama/boorus/danbooru/posts/post/src/danbooru_post_codec.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/posts/details/types.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:boorusama/boorus/danbooru/posts/listing/src/grid_thumbnail_url.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/images/types.dart';
import 'package:boorusama/core/posts/listing/types.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/rating/types.dart';
import 'package:boorusama/core/posts/sources/types.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final legacyCases = [
    (value: 0, expected: 2),
    (value: 1, expected: 2),
    (value: 2, expected: 2),
    (value: 3, expected: 4),
    (value: 4, expected: 4),
    (value: 'automatic', expected: 2),
    (value: 'low', expected: 2),
    (value: 'high', expected: 2),
    (value: 'original', expected: 4),
    (value: 'highest', expected: 4),
    (value: '0', expected: 2),
    (value: '1', expected: 2),
    (value: '2', expected: 2),
    (value: '3', expected: 4),
    (value: '4', expected: 4),
  ];
  for (final c in legacyCases) {
    test('legacy post preset ${c.value} becomes a supported viewer tier', () {
      final settings = Settings.fromJson({
        ...Settings.defaultSettings.toJson(),
        'postQuality': c.value,
        'imageQuality': 3,
        'imageQualityInFullView': 1,
      });
      expect(settings.viewer.toJson()['postQuality'], c.expected);
      expect(settings.listing.imageQuality, ImageQuality.original);
      expect(settings.imageQualityInFullView, ImageQuality.low);
    });
  }

  test(
    'migrated Original preset uses sample while an explicit Original override survives',
    () {
      final viewer = ImageViewerSettings.fromJson(const {'postQuality': 3});
      final resolver = DefaultMediaUrlResolver(postQuality: viewer.postQuality);
      const common = BooruConfigViewer(
        imageDetaisQuality: null,
        videoQuality: null,
        viewerNotesFetchBehavior: null,
        settings: null,
      );
      const original = BooruConfigViewer(
        imageDetaisQuality: 'original',
        videoQuality: null,
        viewerNotesFetchBehavior: null,
        settings: null,
      );
      expect(resolver.resolveMediaUrl(_post(), common), 'sample');
      expect(resolver.resolveMediaAspectRatio(_post(), common), 0.5);
      expect(resolver.resolveMediaUrl(_post(), original), 'original');
      expect(resolver.resolveMediaAspectRatio(_post(), original), 0.75);
    },
  );

  test(
    'stored native variants resolve the same after a snapshot roundtrip',
    () {
      final snapshot = const StoredPostCodec().encode(_post(variants: true));
      final result = const StoredPostCodec().decode(
        StoredPostSnapshot.fromJson(snapshot.toJson()),
      );
      final decoded = switch (result) {
        StoredPostDecodeSuccess(:final post) => post,
        _ => throw StateError('snapshot did not decode'),
      };
      expect(
        const DanbooruGridThumbnailUrlGenerator()
            .resolve(
              decoded,
              settings: _settings(GridSize.large, ImageQuality.automatic),
            )
            .url,
        'sample',
      );
      expect(
        const DanbooruGridThumbnailUrlGenerator()
            .resolve(
              decoded,
              settings: _settings(GridSize.tiny, ImageQuality.automatic),
            )
            .url,
        '180',
      );
    },
  );

  for (final size in GridSize.values) {
    test(
      'Nozomi automatic ${size.name} keeps role and placeholder geometry paired',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final native = container.read(
          Provider((ref) => NozomiRepository(ref: ref)),
        );
        final generator = native.gridThumbnailUrlGenerator(
          BooruConfig.defaultConfig(
            booruType: BooruType.nozomi,
            url: 'https://nozomi.la',
            customDownloadFileNameFormat: null,
          ).auth,
        );

        final settings = _settings(size, ImageQuality.automatic);
        final media = generator.resolve(_post(), settings: settings);
        final small = size == GridSize.micro || size == GridSize.tiny;
        expect(media.url, small ? 'thumbnail' : 'sample');
        expect(media.aspectRatio, small ? 1 : 0.5);
        expect(
          generator.resolveLoadingPlaceholderAspectRatio(settings: settings),
          small ? 1 : null,
        );
      },
    );
  }
  final sizes = [
    (size: GridSize.large, generic: 'sample', danbooru: 'sample'),
    (size: GridSize.normal, generic: 'sample', danbooru: '720'),
    (size: GridSize.small, generic: 'sample', danbooru: '720'),
    (size: GridSize.tiny, generic: 'thumbnail', danbooru: '180'),
    (size: GridSize.micro, generic: 'thumbnail', danbooru: '180'),
  ];
  for (final c in sizes) {
    test('automatic ${c.size.name} grid chooses the configured size tier', () {
      final settings = _settings(c.size, ImageQuality.automatic);
      final generic = const DefaultGridThumbnailUrlGenerator().resolve(
        _post(),
        settings: settings,
      );
      expect(generic.url, c.generic);
      expect(generic.aspectRatio, c.generic == 'thumbnail' ? 1 : 0.5);
      final native = const DanbooruGridThumbnailUrlGenerator().resolve(
        _post(variants: true),
        settings: settings,
      );
      expect(native.url, c.danbooru);
    });
  }

  for (final size in GridSize.values) {
    test(
      'Danbooru automatic GIF animates an eligible original at ${size.name}',
      () {
        const expected = 'sample';
        const generator = DanbooruGridThumbnailUrlGenerator();
        expect(
          generator
              .resolve(
                _post(variants: true, format: 'gif', fileSize: 1),
                settings: GridThumbnailSettings(
                  imageQuality: ImageQuality.automatic,
                  animatedPostsDefaultState: AnimatedPostsDefaultState.autoplay,
                  gridSize: size,
                ),
              )
              .url,
          expected,
        );
      },
    );
  }
  test('variantless cached posts use the common sample at automatic Large', () {
    expect(
      const DanbooruGridThumbnailUrlGenerator()
          .resolve(
            _post(),
            settings: _settings(GridSize.large, ImageQuality.automatic),
          )
          .url,
      'sample',
    );
  });
  test('historical thumbnail Original keeps its stored representation', () {
    final media = const DefaultGridThumbnailUrlGenerator().resolve(
      _post(),
      settings: _settings(GridSize.large, ImageQuality.original),
    );
    expect(media.url, 'original');
    expect(media.aspectRatio, 0.75);
  });
  test('highest thumbnail chooses sample pixels with their aspect ratio', () {
    final media = const DefaultGridThumbnailUrlGenerator().resolve(
      _post(),
      settings: _settings(GridSize.large, ImageQuality.highest),
    );
    expect(media.url, 'sample');
    expect(media.aspectRatio, 0.5);
    expect(media.placeholderUrl, 'thumbnail');
  });
  for (final state in AnimatedPostsDefaultState.values) {
    for (final size in GridSize.values) {
      test('automatic GIF keeps ${state.name} at ${size.name}', () {
        final media = const DefaultGridThumbnailUrlGenerator().resolve(
          _post(format: 'gif', fileSize: 1),
          settings: GridThumbnailSettings(
            imageQuality: ImageQuality.automatic,
            animatedPostsDefaultState: state,
            gridSize: size,
          ),
        );
        expect(
          media.url,
          state == AnimatedPostsDefaultState.autoplay ? 'sample' : 'thumbnail',
        );
      });
    }
  }

  for (final state in AnimatedPostsDefaultState.values) {
    for (final bytes in [0, -1, maxAutoplayGridGifBytes + 1, 1024]) {
      if (state == AnimatedPostsDefaultState.autoplay && bytes == 1024)
        continue;
      for (final quality in ImageQuality.values) {
        for (final size in GridSize.values) {
          test(
            'static GIF ${state.name} $bytes ${quality.name} ${size.name}',
            () {
              final expected = switch (quality) {
                ImageQuality.low =>
                  size == GridSize.micro || size == GridSize.tiny
                      ? '180'
                      : '360',
                ImageQuality.automatic || ImageQuality.high =>
                  size == GridSize.micro
                      ? '180'
                      : size == GridSize.tiny
                      ? '360'
                      : '720',
                ImageQuality.highest => size == GridSize.micro ? '360' : '720',
                ImageQuality.original => '720',
              };
              expect(
                const DanbooruGridThumbnailUrlGenerator()
                    .resolve(
                      _post(variants: true, format: 'gif', fileSize: bytes),
                      settings: GridThumbnailSettings(
                        imageQuality: quality,
                        animatedPostsDefaultState: state,
                        gridSize: size,
                      ),
                    )
                    .url,
                expected,
              );
            },
          );
        }
      }
    }
  }

  for (final fileSize in [0, -1, maxAutoplayGridGifBytes + 1]) {
    test(
      'a transcoded GIF sample cannot bypass original-size guard $fileSize',
      () {
        final gif = _nativeGif(fileSize: fileSize);
        for (final quality in ImageQuality.values) {
          for (final generator in [
            const DefaultGridThumbnailUrlGenerator(),
            const DanbooruGridThumbnailUrlGenerator(),
          ]) {
            expect(
              generator.resolve(gif, settings: _gifSettings(quality)).url,
              gif.thumbnailImageUrl,
            );
          }
        }
      },
    );
  }

  for (final sample in [
    '',
    'https://site.test/sample.webm',
    'https://site.test/sample.mp4',
    'https://site.test/sample.jpg',
  ]) {
    test(
      'eligible GIF uses its original when image sample is unavailable ($sample)',
      () {
        final gif = _nativeGif(
          fileSize: maxAutoplayGridGifBytes,
          sample: sample,
        );
        for (final generator in [
          const DefaultGridThumbnailUrlGenerator(),
          const DanbooruGridThumbnailUrlGenerator(),
        ]) {
          for (final quality in [
            ImageQuality.automatic,
            ImageQuality.highest,
          ]) {
            final media = generator.resolve(
              gif,
              settings: _gifSettings(quality),
            );
            expect(media.url, gif.originalImageUrl);
            expect(media.aspectRatio, gif.effectiveOriginalAspectRatio);
            expect(
              generator
                  .resolve(
                    gif,
                    settings: _gifSettings(
                      quality,
                      state: AnimatedPostsDefaultState.static,
                    ),
                  )
                  .url,
              gif.thumbnailImageUrl,
            );
          }
        }
      },
    );
  }

  test('GIF autoplay accepts the exact 5 MiB boundary', () {
    final generic = const DefaultGridThumbnailUrlGenerator().resolve(
      _post(format: 'gif', fileSize: maxAutoplayGridGifBytes),
      settings: _gifSettings(ImageQuality.highest),
    );
    expect(generic.url, 'sample');

    final danbooru = const DanbooruGridThumbnailUrlGenerator().resolve(
      _post(
        variants: true,
        format: 'gif',
        fileSize: maxAutoplayGridGifBytes,
      ),
      settings: _gifSettings(ImageQuality.highest),
    );
    expect(danbooru.url, 'sample');
  });

  for (final fileSize in [0, -1, maxAutoplayGridGifBytes + 1]) {
    test('GIF autoplay rejects unsafe original size $fileSize', () {
      for (final quality in ImageQuality.values) {
        final settings = _gifSettings(quality);
        expect(
          const DefaultGridThumbnailUrlGenerator()
              .resolve(
                _post(format: 'gif', fileSize: fileSize),
                settings: settings,
              )
              .url,
          'thumbnail',
        );
        expect(
          const DanbooruGridThumbnailUrlGenerator()
              .resolve(
                _post(variants: true, format: 'gif', fileSize: fileSize),
                settings: settings,
              )
              .url,
          quality == ImageQuality.low ? '360' : '720',
        );
      }
    });
  }

  test('disabled GIF autoplay stays static even at Highest quality', () {
    final settings = _gifSettings(
      ImageQuality.highest,
      state: AnimatedPostsDefaultState.static,
    );
    expect(
      const DefaultGridThumbnailUrlGenerator()
          .resolve(
            _post(format: 'gif', fileSize: 1),
            settings: settings,
          )
          .url,
      'thumbnail',
    );
    expect(
      const DanbooruGridThumbnailUrlGenerator()
          .resolve(
            _post(variants: true, format: 'gif', fileSize: 1),
            settings: settings,
          )
          .url,
      '720',
    );
  });
}

GridThumbnailSettings _settings(GridSize size, ImageQuality quality) =>
    GridThumbnailSettings(
      imageQuality: quality,
      animatedPostsDefaultState: AnimatedPostsDefaultState.static,
      gridSize: size,
    );

GridThumbnailSettings _gifSettings(
  ImageQuality quality, {
  AnimatedPostsDefaultState state = AnimatedPostsDefaultState.autoplay,
}) => GridThumbnailSettings(
  imageQuality: quality,
  animatedPostsDefaultState: state,
  gridSize: GridSize.large,
);

Post _post({
  bool variants = false,
  String format = 'jpg',
  int fileSize = 0,
}) => Post(
  origin: PostOrigin.forBooruType(BooruType.danbooru),
  core: PostCoreData(
    id: 1,
    thumbnailImageUrl: 'thumbnail',
    sampleImageUrl: 'sample',
    originalImageUrl: 'original',
    videoUrl: '',
    videoThumbnailUrl: 'poster',
    width: 100,
    height: 200,
    format: format,
    md5: '',
    fileSize: fileSize,
    duration: 0,
    tags: const {},
    rating: Rating.general,
    hasComment: false,
    isTranslated: false,
    hasParentOrChildren: false,
    source: PostSource.none(),
    score: 0,
    thumbnailAspectRatio: 1,
    sampleAspectRatio: 0.5,
    originalAspectRatio: 0.75,
    mediaVariants: variants
        ? const {
            '180x180': '180',
            '360x360': '360',
            '720x720': '720',
            'sample': 'sample',
          }
        : null,
  ),
  booruData: const LegacyPostData(typeKey: 'fixture', custom: {}),
);

Post _nativeGif({
  required int fileSize,
  String sample = 'https://site.test/sample.webm',
}) => danbooruPostFromRecord(
  DanbooruPostRecord.empty().copyWith(
    format: 'gif',
    fileSize: fileSize,
    sampleImageUrl: sample,
    originalImageUrl: 'https://site.test/original.gif',
    width: 100,
    height: 200,
  ),
  PostOrigin.forBooruType(BooruType.danbooru),
);
