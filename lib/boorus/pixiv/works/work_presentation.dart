import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import '../../../core/boorus/booru/types.dart';
import '../../../core/configs/config/types.dart';
import '../../../core/content/capabilities.dart';
import '../../../core/content/types.dart';
import '../../../core/content/content_access_provider.dart';
import '../../../core/posts/details/src/widgets/media_group_viewer.dart';
import '../../../core/posts/pools/group_summary_card.dart';
import '../../../core/posts/pools/pool_grid_item.dart';
import '../client_provider.dart';
import 'work_source.dart';

BooruGroupCapability createPixivGroupCapability(Ref ref) =>
    BooruGroupCapability(
      engine: BooruType.pixiv,
      keyCodec: const BooruContentKeyCodec(BooruType.pixiv),
      createSource: (access) {
        final client = ref.read(pixivClientProvider(access.config!.auth));
        return PixivWorkSource(
          access: access,
          blacklist: Set.unmodifiable(
            ref
                .read(contentEffectiveBlacklistProvider(access.key.profileId!))
                .requireValue,
          ),
          fetchWork: (id) => client.getIllustDetail(illustId: id),
        );
      },
      presentation: const PixivWorkPresentation(),
    );

class PixivWorkPresentation implements BooruGroupPresentation {
  const PixivWorkPresentation();
  @override
  bool supports(ContentGroupSummary summary) =>
      summary.reference.engine == BooruType.pixiv &&
      summary.reference.sourceKey.startsWith('work:');
  @override
  GroupLayout layoutFor(ContentGroupSummary summary) => GroupLayout.mediaPager;
  @override
  String memberLabel(BuildContext context, ContentGroupSummary summary) =>
      context.t.artist_page.posts;
  @override
  Widget buildCard(BuildContext context, ContentGroupSummary summary) =>
      GroupSummaryCard(summary: summary, kind: PoolGridItemKind.collection);
  @override
  Widget buildDetails(BuildContext context, ContentGroupDetails details) =>
      MediaGroupViewer(details: details);
}
