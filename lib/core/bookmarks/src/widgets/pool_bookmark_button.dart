import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../configs/config/providers.dart';
import '../../../configs/config/types.dart';
import '../../../posts/post/types.dart';
import '../providers/bookmark_provider.dart';
import '../types/pool_bookmark_capability.dart';
import 'bookmark_group_picker.dart';

class PoolBookmarkButton extends ConsumerWidget {
  const PoolBookmarkButton({required this.pool, super.key});
  final RemoteBookmarkPool pool;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watchConfig;
    final library = ref.watch(bookmarkProvider).valueOrNull;
    final saved = library?.pools
        .where(
          (p) =>
              !p.isRelated &&
              p.referenceId == pool.id &&
              p.origin.booruType == config.auth.booruType &&
              p.origin.sourceHost == normalizePostSourceHost(config.url),
        )
        .firstOrNull;
    final isBookmarked = saved?.groupIds.isNotEmpty ?? false;
    return BookmarkGroupPickerAnchor(
      request: RemotePoolBookmarkPickerRequest(config: config, pool: pool),
      builder: (context, show) => KurumiTooltip(
        message: context.t.bookmark.groups.selector,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onLongPress: library == null ? null : show,
          child: IconButton(
            onPressed: library == null ? null : show,
            icon: Badge(
              isLabelVisible: saved != null && saved.groupIds.length > 1,
              label: Text('${saved?.groupIds.length ?? 0}'),
              child: Icon(Symbols.bookmark, fill: isBookmarked ? 1 : 0),
            ),
          ),
        ),
      ),
    );
  }
}
