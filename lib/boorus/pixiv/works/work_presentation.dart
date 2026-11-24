import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import '../../../core/configs/config/types.dart';

import '../../../core/boorus/booru/types.dart';
import '../../../core/content/content_access_provider.dart';
import '../../../core/content/groups/group_capability.dart';
import '../../../core/content/groups/group_visibility.dart';
import '../../../core/content/types.dart';
import '../../../core/posts/pools/group_summary_card.dart';
import '../../../core/posts/pools/pool_grid_item.dart';
import '../../../core/posts/rating/types.dart';
import '../../../core/http/client/coordination.dart';
import '../../../core/widgets/adaptive_button_row.dart';
import '../client_provider.dart';
import '../configs/extra_data.dart';
import '../favorites/favorite_control.dart';
import '../favorites/favorite_state.dart';
import 'work_source.dart';
import 'work_mapper.dart';
import 'bookmark_actions.dart';
import 'work_timeline.dart';
import '../../../core/posts/details/src/widgets/group_viewer_scope.dart';

BooruGroupCapability createPixivGroupCapability(Ref _) => BooruGroupCapability(
  engine: BooruType.pixiv,
  keyCodec: const BooruContentKeyCodec(BooruType.pixiv),
  createSource: (ref, access) {
    final auth = access.config!.auth;
    final client = ref.read(pixivClientProvider(auth));
    final canObserveFavorites = pixivAuthenticatedUserId(auth) != null;
    return PixivWorkSource(
      access: access,
      blacklist: Set.unmodifiable(
        ref
            .read(
              contentEffectiveBlacklistProvider(access.key.profileId!),
            )
            .requireValue,
      ),
      fetchWork: (id) async {
        final request = ApiRequestContext.current();
        final favorites = canObserveFavorites
            ? ref.read(
                pixivFavoriteStateProvider(access.key.profileId!).notifier,
              )
            : null;
        final read = favorites?.beginRead(auth, access.key.authEpoch);
        final dto = await client.getIllustDetail(illustId: id);
        if (read != null &&
            dto != null &&
            dto.id == id &&
            pixivWorkIsVisible(dto) &&
            !(request.cancelToken?.isCancelled ?? false) &&
            (request.canAdmit?.call() ?? true)) {
          favorites!.observe(read, [dto]);
        }
        return dto;
      },
    );
  },
  presentation: const PixivWorkPresentation(),
);

class PixivWorkPresentation
    implements
        BooruGroupPresentation,
        BooruMediaGroupFavoritePresentation,
        BooruMediaGroupBookmarkPresentation,
        BooruScopedGroupBookmarkPresentation,
        BooruGroupSelectionPresentation,
        BooruGroupKindPresentation {
  const PixivWorkPresentation();

  @override
  Widget buildFavoriteActions(
    ContentAccessContext access,
    ContentGroupSummary summary, {
    required bool detailsVerified,
    required bool Function() isCurrent,
    required FavoriteActionRowBuilder builder,
  }) => Consumer(
    builder: (context, ref, _) {
      final id = pixivWorkIllustId(summary.reference);
      final config = access.config;
      if (id == null || config == null || access.key.profileId == null) {
        return builder(context, const []);
      }
      var allowed = detailsVerified;
      if (!detailsVerified) {
        final blacklist = ref
            .watch(contentEffectiveBlacklistProvider(config.id))
            .asData
            ?.value;
        final rating = Rating.parse(summary.cover?.visibility?.rating);
        allowed =
            blacklist != null &&
            groupAllowsRating(config, rating) &&
            groupTagsPassBlacklist(
              summary.previewTags,
              blacklist,
              rating: rating,
              sourceId: id,
              sourceUrl: access.baseUrl.toString(),
            );
      }
      return PixivFavoriteControl(
        key: ValueKey((access.key, id)),
        access: access,
        illustId: id,
        restricted: !allowed,
        isOwnerCurrent: isCurrent,
        builder: builder,
      );
    },
  );

  @override
  List<Widget> buildSelectionActions(
    BuildContext context,
    List<GroupBookmarkPresentationData> groups,
  ) => [
    PixivSelectedWorksBookmarkButton(groups: groups),
  ];

  @override
  String kindLabel(BuildContext context, ContentGroupSummary summary) =>
      context.t.content_viewer.work;

  @override
  Widget buildBookmarkButton(
    BuildContext context,
    GroupBookmarkPresentationData data,
  ) => PixivWorkBookmarkButton(
    key: ValueKey((data.summary.reference.identity, data.access.key)),
    data: data,
  );

  @override
  Widget buildScopedBookmarkButton(
    BuildContext context,
    GroupBookmarkPresentationData data, {
    required bool wholeGroup,
  }) => PixivScopedBookmarkButton(data: data, wholeGroup: wholeGroup);

  @override
  List<ButtonData> buildBookmarkMenuButtons(
    BuildContext context,
    GroupBookmarkPresentationData data,
  ) => const [];

  @override
  Widget wrapBookmarkMenu(
    BuildContext context,
    GroupBookmarkPresentationData data,
    Widget child,
  ) => PixivWorkBookmarkContextMenu(data: data, child: child);

  @override
  bool supports(ContentGroupSummary summary) =>
      summary.reference.engine == BooruType.pixiv &&
      summary.reference.sourceKey.startsWith('work:');

  @override
  GroupLayout layoutFor(ContentGroupSummary summary) => GroupLayout.mediaPager;

  @override
  String memberLabel(BuildContext context, ContentGroupSummary summary) =>
      context.t.content_viewer.pages;

  @override
  Widget buildCard(BuildContext context, ContentGroupSummary summary) =>
      GroupSummaryCard(summary: summary, kind: PoolGridItemKind.collection);

  // Media-pager Groups compose into the shared viewer rather than opening
  // another fullscreen viewer through this legacy standalone details hook.
  @override
  Widget buildDetails(BuildContext context, ContentGroupDetails details) =>
      switch (GroupViewerScope.maybeEntryOf(context)) {
        final entry? => PixivWorkTimeline(entry: entry),
        _ => const SizedBox.shrink(),
      };
}
