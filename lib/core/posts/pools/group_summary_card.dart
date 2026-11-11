import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../configs/config/providers.dart';
import '../../content/types.dart';
import '../details/routes.dart';
import '../details/src/types/viewer_entry.dart';
import '../post/types.dart';
import 'pool_grid_item.dart';

/// Native metadata cards do not resolve all members to manufacture a cover.
/// Saved covers continue through BookmarkPoolCoverImage's policy-aware resolver.
class GroupSummaryCard extends ConsumerWidget {
  const GroupSummaryCard({
    required this.summary,
    required this.kind,
    super.key,
  });
  final ContentGroupSummary summary;
  final PoolGridItemKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) => PoolGridItem(
    name: summary.title,
    total: summary.memberCount,
    kind: kind,
    image: const Center(child: Icon(Symbols.photo_library)),
    onTap: () {
      final config = ref.readConfig;
      final reference = summary.reference;
      final origin = PostOrigin.fromSource(
        booruType: reference.engine,
        booruId: reference.engine.id,
        source: reference.site.toString(),
      );
      final bound = ViewerSourceBinding(config);
      final source =
          referenceForBoundGroup(
                origin: origin,
                sourceKey: reference.sourceKey,
                source: bound,
              ) ==
              reference
          ? (config.anonymousReadScope == null
                ? bound
                : ViewerSourceBinding.publicRead(origin))
          : null;
      goToPostDetailsPageCore<Post>(
        ref: ref,
        posts: const [],
        initialIndex: 0,
        initialThumbnailUrl: null,
        config: source == null ? null : config,
        hero: false,
        entries: [
          GroupViewerEntry(
            summary: summary,
            occurrenceId: Object(),
            source: source,
          ),
        ],
      );
    },
  );
}
