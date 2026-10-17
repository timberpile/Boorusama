// Flutter imports:
import 'package:flutter/widgets.dart';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';

// Project imports:
import '../../../core/configs/config/types.dart';
import '../../../core/downloads/filename/types.dart';
import '../../../core/downloads/urls/types.dart';
import '../posts/types.dart';
import '../tag_summary/repo.dart';
import '../tags/providers.dart';

final moebooruDownloadFilenameGeneratorProvider =
    Provider.family<DownloadFilenameGenerator, BooruConfigAuth>((ref, config) {
      return DownloadFileNameBuilder<Post>(
        defaultFileNameFormat: kDefaultCustomDownloadFileNameFormat,
        defaultBulkDownloadFileNameFormat: kDefaultCustomDownloadFileNameFormat,
        sampleData: kDanbooruPostSamples,
        preload: (posts, config, cancelToken) async {
          await ref
              .read(moebooruTagSummaryRepoProvider(config))
              .getTagSummaries();
        },
        tokenHandlers: [
          WidthTokenHandler(),
          HeightTokenHandler(),
          AspectRatioTokenHandler(),
          MPixelsTokenHandler(),
        ],
        asyncTokenHandlers: [
          AsyncTokenHandler(
            ClassicTagsTokenResolver(
              tagExtractor: ref.watch(moebooruTagExtractorProvider(config)),
            ),
          ),
        ],
      );
    });

final class MoebooruDownloadSource implements DownloadSourceProvider {
  const MoebooruDownloadSource();

  @override
  List<DownloadSource> getDownloadSources(BuildContext context, Post post) {
    return [
      if (post.thumbnailImageUrl.isNotEmpty)
        DownloadSource(
          url: post.thumbnailImageUrl,
          quality: 'preview',
          name: context.t.settings.download.qualities.preview,
        ),
      if (post case final Post moePost when moePost.largeImageUrl.isNotEmpty)
        DownloadSource(
          url: moePost.largeImageUrl,
          quality: 'large',
          name: context.t.settings.download.qualities.large,
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
