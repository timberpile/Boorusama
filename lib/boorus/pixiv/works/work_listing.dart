import 'package:booru_clients/pixiv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/material.dart';

import '../../../core/configs/config/types.dart';
import '../../../core/content/content_access_provider.dart';
import '../../../core/content/groups/group_source_provider.dart';
import '../../../core/content/widgets/native_content_grid.dart';
import '../../../core/content/groups/group_visibility.dart';
import '../../../core/posts/listing/types.dart';
import '../../../core/settings/providers.dart';
import 'work_mapper.dart';
import 'work_source.dart';
import '../posts/types.dart';
import '../../../core/posts/rating/types.dart';

/// Native endpoints provide one Work envelope per card; compatibility Post
/// repositories and cached Following records keep their existing projections.
class PixivWorkGrid extends ConsumerWidget {
  const PixivWorkGrid({
    required this.config,
    required this.fetchPage,
    required this.queryIdentity,
    this.header,
    this.sliverHeaders = const [],
    this.initialPage = 1,
    this.pageMode,
    super.key,
  });
  final BooruConfig config;
  final Future<PixivIllustListResult> Function(int page) fetchPage;
  final Object queryIdentity;
  final Widget? header;
  final List<Widget> sliverHeaders;
  final int initialPage;
  final PageMode? pageMode;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(contentProfileAccessProvider(config.id));
    if (access == null) return const Center(child: CircularProgressIndicator());
    final source =
        ref.watch(contentGroupSourceProvider(access.key)) as PixivWorkSource;
    return NativeContentGrid(
      access: access,
      queryIdentity: queryIdentity,
      initialPage: initialPage,
      pageMode: pageMode ?? ref.watch(imageListingSettingsProvider).pageMode,
      allowPageModeChange: pageMode == null,
      header: header,
      sliverHeaders: sliverHeaders,
      onRefresh: source.invalidateAll,
      fetchPage: (page) async {
        final result = await fetchPage(page);
        final blacklist = ref
            .read(contentEffectiveBlacklistProvider(config.id))
            .requireValue;
        if (!identical(
          ref.read(contentAccessContextProvider(access.key)),
          access,
        ))
          throw StateError('Pixiv Work listing access changed');
        final visible = PixivIllustListResult(
          hasMore: result.hasMore,
          illusts: [
            for (final dto in result.illusts)
              if (groupAllowsRating(
                    config,
                    Rating.parse(pixivWorkVisibility(dto).rating),
                  ) &&
                  groupTagsPassBlacklist(
                    pixivWorkTags(dto),
                    blacklist,
                    rating: Rating.parse(pixivWorkVisibility(dto).rating),
                    sourceId: dto.id,
                    sourceUrl: access.baseUrl.toString(),
                  ))
                dto,
          ],
        );
        for (final dto in visible.illusts) {
          if (pixivWorkIsVisible(dto) &&
              PixivIllustType.parse(dto.type) != PixivIllustType.ugoira)
            source.seedWork(dto);
        }
        return NativeContentPage(
          entries: pixivWorkListingEntries(visible, access: access),
          hasMore: result.hasMore,
          rawCount: result.illusts.length,
        );
      },
    );
  }
}
