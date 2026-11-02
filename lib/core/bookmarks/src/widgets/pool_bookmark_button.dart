import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../configs/config/providers.dart';
import '../../../configs/config/types.dart';
import '../../../configs/manage/providers.dart';
import '../../../posts/post/types.dart';
import '../providers/bookmark_provider.dart';
import '../types/pool_bookmark_capability.dart';
import 'bookmark_group_picker.dart';

class PoolBookmarkButton extends ConsumerStatefulWidget {
  const PoolBookmarkButton({required this.pool, super.key});
  final RemoteBookmarkPool pool;

  @override
  ConsumerState<PoolBookmarkButton> createState() => _PoolBookmarkButtonState();
}

class _PoolBookmarkButtonState extends ConsumerState<PoolBookmarkButton> {
  var _pickerOpen = false;

  @override
  Widget build(BuildContext context) {
    final config = ref.watchConfig;
    final library = ref.watch(bookmarkProvider).valueOrNull;
    final saved = library?.pools
        .where(
          (p) =>
              p.poolId == widget.pool.id &&
              p.origin.booruType == config.auth.booruType &&
              p.origin.sourceHost == normalizePostSourceHost(config.url),
        )
        .firstOrNull;
    final isBookmarked = saved?.groupIds.isNotEmpty ?? false;
    return KurumiTooltip(
      message: context.t.bookmark.groups.selector,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onLongPress: _pickerOpen || library == null ? null : _perform,
        child: IconButton(
          onPressed: _pickerOpen || library == null ? null : _perform,
          icon: Badge(
            isLabelVisible: saved != null && saved.groupIds.length > 1,
            label: Text('${saved?.groupIds.length ?? 0}'),
            child: Icon(Symbols.bookmark, fill: isBookmarked ? 1 : 0),
          ),
        ),
      ),
    );
  }

  Future<void> _perform() async {
    if (_pickerOpen) return;
    final config = ref.readConfig;
    final pool = widget.pool;
    final library = ref.read(bookmarkProvider).valueOrNull;
    if (library == null) return;
    setState(() => _pickerOpen = true);
    try {
      if (!ref.read(booruConfigProvider).contains(config)) {
        throw StateError('Pool profile changed');
      }
      final existing = library.pools
          .where(
            (p) =>
                p.poolId == pool.id &&
                p.origin.booruType == config.auth.booruType &&
                p.origin.sourceHost == normalizePostSourceHost(config.url),
          )
          .firstOrNull;
      await showDialog<void>(
        context: context,
        builder: (_) => existing != null
            ? BookmarkGroupPicker.pool(config: config.auth, pool: existing)
            : BookmarkGroupPicker.remotePool(config: config, pool: pool),
      );
    } catch (_) {
      if (mounted) {
        Kurumi.showErrorToast(
          context,
          context.t.bookmark.groups.operation_failed,
        );
      }
    } finally {
      if (mounted) setState(() => _pickerOpen = false);
    }
  }
}
