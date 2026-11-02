import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../../../core/bookmarks/src/types/pool_bookmark_capability.dart';
import '../../../../../../core/bookmarks/src/widgets/pool_bookmark_button.dart';
import '../../../../../../core/bulk_downloads/routes.dart';
import '../../../../../../core/posts/details/src/widgets/viewer_entry_navigation_header.dart';
import '../../../../../../core/search/search/routes.dart';

class PoolGalleryHeader extends ConsumerWidget {
  const PoolGalleryHeader({required this.pool, super.key});

  final RemoteBookmarkPool pool;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ViewerEntryNavigationHeader(actions: poolGalleryActions(ref, pool));
}

List<Widget> poolGalleryActions(WidgetRef ref, RemoteBookmarkPool pool) => [
  PoolBookmarkButton(pool: pool),
  IconButton(
    tooltip: ref.context.t.generic.action.search,
    icon: const Icon(Symbols.search),
    onPressed: () => goToSearchPage(ref, tag: 'pool:${pool.id}'),
  ),
  IconButton(
    tooltip: ref.context.t.download.download,
    icon: const Icon(Symbols.download),
    onPressed: () => goToBulkDownloadPage(
      ref.context,
      ['pool:${pool.id}'],
      ref: ref,
    ),
  ),
];
