import 'package:booru_clients/pixiv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import '../../../core/configs/config/types.dart';
import '../../../core/http/client/coordination.dart';
import '../../../core/content/content_access_provider.dart';
import '../../../core/content/groups/group_source_provider.dart';
import '../../../core/content/widgets/native_content_grid.dart';
import '../../../core/content/groups/group_visibility.dart';
import '../../../core/posts/listing/types.dart';
import '../../../core/settings/providers.dart';
import 'work_mapper.dart';
import 'work_source.dart';
import '../posts/types.dart';
import '../posts/query.dart';

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
    this.initialScrollPosition,
    this.pageMode,
    super.key,
  });
  final BooruConfig config;
  final Future<PixivIllustListResult> Function(int page) fetchPage;
  final Object queryIdentity;
  final Widget? header;
  final List<Widget> sliverHeaders;
  final int initialPage;
  final int? initialScrollPosition;
  final PageMode? pageMode;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(contentProfileAccessProvider(config.id));
    if (access == null) return const Center(child: CircularProgressIndicator());
    // Source loss can reach the subscription before the access-driven rebuild.
    // Observe it as async state; page requests retain their normal error UI.
    ref.watch(contentGroupSourceStateProvider(access.key));
    final effectiveMode =
        pageMode ?? ref.watch(imageListingSettingsProvider).pageMode;
    return NativeContentGrid(
      // A route/query or actor change also cancels any pending anchor animation.
      key: ValueKey((
        access.key,
        queryIdentity,
        initialPage,
        initialScrollPosition,
        effectiveMode,
      )),
      access: access,
      queryIdentity: queryIdentity,
      groupLabel: (context, _) => context.t.content_viewer.work,
      counterLabel: (context, n) => context.t.content_viewer.work_counter(n: n),
      initialPage: initialPage,
      pageMode: effectiveMode,
      initialScrollPosition: initialScrollPosition,
      allowPageModeChange: pageMode == null,
      header: header,
      sliverHeaders: sliverHeaders,
      fetchPage: (page) async {
        final request = ApiRequestContext.current();
        final source =
            ref.read(contentGroupSourceProvider(access.key)) as PixivWorkSource;
        final result = await fetchPage(page);
        final blacklist = ref
            .read(contentEffectiveBlacklistProvider(config.id))
            .requireValue;
        if ((request.cancelToken?.isCancelled ?? false) ||
            !(request.canStart?.call() ?? true) ||
            !(request.canAdmit?.call() ?? true) ||
            !identical(
              ref.read(contentAccessContextProvider(access.key)),
              access,
            )) {
          throw StateError('Pixiv Work listing access changed');
        }
        final visible = PixivIllustListResult(
          hasMore: result.hasMore,
          illusts: [
            for (final dto in result.illusts)
              if (groupAllowsRating(
                    config,
                    pixivWorkRating(dto),
                  ) &&
                  groupTagsPassBlacklist(
                    pixivWorkTags(dto),
                    blacklist,
                    rating: pixivWorkRating(dto),
                    sourceId: dto.id,
                    sourceUrl: access.baseUrl.toString(),
                  ))
                dto,
          ],
        );
        for (final dto in visible.illusts) {
          if (pixivWorkIsVisible(dto) &&
              PixivIllustType.parse(dto.type) != PixivIllustType.ugoira) {
            source.seedWork(dto, replaceExisting: true);
          }
        }
        final legacyPageCounts = pixivWorkLegacyPageCounts(visible.illusts);
        return NativeContentPage(
          indexForPosition: (position) =>
              pixivWorkIndexForPagePosition(legacyPageCounts, position),
          entries: pixivWorkListingEntries(visible, access: access),
          hasMore: result.hasMore,
          rawCount: result.illusts.length,
        );
      },
    );
  }
}

/// All native query entry points use the same genuine artwork endpoint.
Future<PixivIllustListResult> fetchPixivWorkPage(
  PixivClient client,
  PixivQuery query,
  int page,
) => switch (query) {
  PixivQuery(userId: final id?) => client.getUserIllusts(
    userId: id,
    page: page,
  ),
  PixivQuery(text: final text?) => client.searchIllust(word: text, page: page),
  _ => client.getRanking(mode: PixivRankingMode.day, page: page),
};
