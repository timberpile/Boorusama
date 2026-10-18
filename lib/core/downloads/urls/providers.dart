// Flutter imports:
import 'package:flutter/widgets.dart';

// Package imports:
import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';

// Project imports:
import '../../boorus/engine/providers.dart';
import '../../configs/config/types.dart';
import '../../posts/post/types.dart';
import 'types.dart';

final downloadFileUrlExtractorProvider =
    Provider.family<DownloadFileUrlExtractor, BooruConfigAuth>(
      (ref, config) {
        final repo = ref
            .watch(booruEngineRegistryProvider)
            .getRepository(config.booruType);

        final downloadFileUrlExtractor = repo?.downloadFileUrlExtractor(config);

        if (downloadFileUrlExtractor != null) {
          return downloadFileUrlExtractor;
        }

        return const UrlInsidePostExtractor();
      },
    );

final downloadSourceProvider =
    Provider.family<DownloadSourceProvider?, BooruConfigAuth>(
      (ref, config) {
        final repo = ref
            .watch(booruEngineRegistryProvider)
            .getRepository(config.booruType);

        final downloadSourceProvider = repo?.downloadSource(config);

        return downloadSourceProvider;
      },
    );

final class DefaultDownloadSource implements DownloadSourceProvider {
  const DefaultDownloadSource();

  @override
  List<DownloadSource> getDownloadSources(BuildContext context, Post post) {
    return [
      if (post.thumbnailImageUrl.isNotEmpty)
        DownloadSource(
          url: post.thumbnailImageUrl,
          quality: 'preview',
          name: context.t.settings.download.qualities.preview,
        ),
      if (post.sampleImageUrl.isNotEmpty)
        DownloadSource(
          url: post.sampleImageUrl,
          quality: 'sample',
          name: context.t.settings.download.qualities.sample,
        ),
      if (post.originalImageUrl.isNotEmpty)
        DownloadSource(
          url: post.originalImageUrl,
          quality: 'original',
          name: context.t.settings.download.qualities.original,
        ),
    ];
  }
}

final class UrlInsidePostExtractor implements DownloadFileUrlExtractor {
  const UrlInsidePostExtractor();

  @override
  Future<DownloadUrlData?> getDownloadFileUrl({
    required Post post,
    required String quality,
  }) async {
    final videoQualities = {
      if (post.videoUrl == post.originalImageUrl) 'original',
      if (post.videoUrl == post.sampleImageUrl) 'sample',
      if (post.videoUrl == post.thumbnailImageUrl) 'preview',
    };
    final videoQuality = videoQualities.length == 1
        ? videoQualities.single
        : 'custom';
    final urls = [
      (post.originalImageUrl, 'original'),
      if (post.isVideo)
        (post.videoUrl, videoQuality)
      else
        (post.sampleImageUrl, 'sample'),
      (post.thumbnailImageUrl, 'preview'),
    ];

    final selected = switch (quality) {
      'original' => urls.firstWhereOrNull((e) => e.$1.isNotEmpty),
      'sample' => urls.skip(1).firstWhereOrNull((e) => e.$1.isNotEmpty),
      'preview' => (post.thumbnailImageUrl, 'preview'),
      _ => urls.firstWhereOrNull((e) => e.$1.isNotEmpty),
    };

    return selected != null
        ? DownloadUrlData.urlOnly(
            selected.$1,
            resolvedQuality: selected.$2,
          )
        : null;
  }
}
