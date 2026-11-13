import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import '../../../core/configs/config/types.dart';

import '../../../core/boorus/booru/types.dart';
import '../../../core/content/content_access_provider.dart';
import '../../../core/content/groups/group_capability.dart';
import '../../../core/content/types.dart';
import '../../../core/posts/pools/group_summary_card.dart';
import '../../../core/posts/pools/pool_grid_item.dart';
import '../../../core/widgets/adaptive_button_row.dart';
import '../client_provider.dart';
import 'work_source.dart';
import 'bookmark_actions.dart';

BooruGroupCapability createPixivGroupCapability(Ref _) => BooruGroupCapability(
  engine: BooruType.pixiv,
  keyCodec: const BooruContentKeyCodec(BooruType.pixiv),
  createSource: (ref, access) {
    final client = ref.read(pixivClientProvider(access.config!.auth));
    return PixivWorkSource(
      access: access,
      blacklist: Set.unmodifiable(
        ref
            .read(
              contentEffectiveBlacklistProvider(access.key.profileId!),
            )
            .requireValue,
      ),
      fetchWork: (id) => client.getIllustDetail(illustId: id),
    );
  },
  presentation: const PixivWorkPresentation(),
);

class PixivWorkPresentation
    implements
        BooruGroupPresentation,
        BooruMediaGroupBookmarkPresentation,
        BooruGroupKindPresentation {
  const PixivWorkPresentation();

  @override
  String kindLabel(BuildContext context, ContentGroupSummary summary) =>
      context.t.content_viewer.work;

  @override
  Widget buildBookmarkButton(
    BuildContext context,
    GroupBookmarkPresentationData data,
  ) => PixivWorkBookmarkButton(data: data);

  @override
  List<ButtonData> buildBookmarkMenuButtons(
    BuildContext context,
    GroupBookmarkPresentationData data,
  ) => pixivWorkBookmarkMenuButtons(context, data);

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
      Text(details.summary.title ?? '');
}
