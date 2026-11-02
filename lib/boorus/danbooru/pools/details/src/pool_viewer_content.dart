import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import '../../../../../core/configs/config/providers.dart';
import '../../../../../core/configs/config/types.dart';
import '../../../../../core/posts/details/src/types/viewer_entry.dart';
import '../../../client_provider.dart';
import '../../pool/src/data/parser.dart';
import '../../pool/types.dart';
import 'pool_detail_page.dart';
import '../../../../../core/posts/details/src/widgets/viewer_entry_navigation_header.dart';
import 'widgets/pool_gallery_header.dart';

final viewerPoolProvider = FutureProvider.autoDispose
    .family<DanbooruPool, (BooruConfig, int)>((ref, request) async {
      final (config, id) = request;
      final cancellation = CancelToken();
      ref.onDispose(cancellation.cancel);
      final dto = await ref
          .read(danbooruClientProvider(config.auth))
          .getPool(id, cancelToken: cancellation);
      final pool = poolDtoToDanbooruPool(dto);
      if (pool == null || pool.id != id) throw StateError('Pool unavailable');
      return pool;
    });

class DanbooruPoolViewerContent extends ConsumerWidget {
  const DanbooruPoolViewerContent({required this.entry, super.key});
  final PoolViewerEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final request = (ref.watchConfig, entry.pool.id);
    return ref
        .watch(viewerPoolProvider(request))
        .when(
          data: (pool) => PoolDetailContent(
            pool: pool,
            embedded: true,
            storageId: entry.occurrenceId,
          ),
          loading: () => ViewerEntryNavigationStatus(
            actions: poolGalleryActions(ref, entry.pool),
            child: const CircularProgressIndicator(),
          ),
          error: (_, _) => ViewerEntryNavigationStatus(
            actions: poolGalleryActions(ref, entry.pool),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(context.t.bookmark.pool_unavailable),
                TextButton(
                  onPressed: () => ref.invalidate(viewerPoolProvider(request)),
                  child: Text(context.t.generic.action.retry),
                ),
              ],
            ),
          ),
        );
  }
}
