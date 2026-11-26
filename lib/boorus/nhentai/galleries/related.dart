import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';
import 'package:sliver_tools/sliver_tools.dart';

import '../../../core/configs/config/types.dart';
import '../../../core/content/content_access_provider.dart';
import '../../../core/content/groups/group_source_provider.dart';
import '../../../core/content/types.dart';
import '../../../core/images/booru_image.dart';
import '../../../core/navigation/destination_activity.dart';
import '../../../core/posts/details/src/providers/media_group_provider.dart';
import '../../../core/posts/details/src/widgets/group_viewer_scope.dart';
import '../../../core/posts/details/types.dart' show BatchedPreview;
import '../../../core/posts/details_parts/widgets.dart';
import '../../../core/posts/pools/pool_grid_item.dart';
import '../client_provider.dart';
import '../favorites/control.dart';
import 'listing.dart';
import 'mapper.dart';
import 'open.dart';

final nhentaiRelatedGalleriesProvider = FutureProvider.autoDispose
    .family<List<ContentGroupSummary>, (ContentAccessKey, int)>(
      (ref, query) async {
        final (access, id) = query;
        final token = CancelToken();
        ref.onDispose(token.cancel);
        final sourceReady = ref.watch(
          contentGroupSourceStateProvider(access).future,
        );
        final initialListing = ref.watch(nhentaiGalleryListingProvider(access));
        if (initialListing == null) await sourceReady;
        if (token.isCancelled) throw StateError('Gallery source unavailable');
        final listing =
            initialListing ?? ref.read(nhentaiGalleryListingProvider(access));
        if (listing == null) throw StateError('Gallery source unavailable');
        final client = ref.watch(
          nhentaiClientProvider(listing.source.access.config!.auth),
        );
        final galleries = await client.getRelatedGalleries(
          id,
          cancelToken: token,
        );
        return listing.project(
          galleries.where((gallery) => gallery.id != id),
          cancelToken: token,
        );
      },
      dependencies: [
        nhentaiGalleryListingProvider,
        contentGroupSourceStateProvider,
      ],
    );

typedef _RelatedKey = (ContentAccessKey, int);

/// The outer viewer owns completed results across page and Gallery changes.
class NhentaiRelatedGalleryCache {
  NhentaiRelatedGalleryCache(this._owner);

  final WidgetRef _owner;
  final _galleries = <_RelatedKey, List<ContentGroupSummary>>{};
  final _access =
      <ContentAccessKey, ProviderSubscription<ContentAccessContext?>>{};

  List<ContentGroupSummary>? _get(_RelatedKey key) => _galleries[key];

  void _retain(_RelatedKey key, List<ContentGroupSummary> galleries) {
    final (access, _) = key;
    if (_owner.read(contentAccessContextProvider(access)) == null) return;
    _access.putIfAbsent(
      access,
      () => _owner.listenManual(
        contentAccessContextProvider(access),
        (_, current) {
          if (current != null) return;
          _galleries.removeWhere((key, _) => key.$1 == access);
          _access.remove(access)?.close();
        },
      ),
    );
    _galleries.putIfAbsent(key, () => List.unmodifiable(galleries));
  }

  void dispose() {
    for (final subscription in _access.values) {
      subscription.close();
    }
    _access.clear();
    _galleries.clear();
  }
}

class NhentaiRelatedGalleryWindow extends ConsumerWidget {
  const NhentaiRelatedGalleryWindow({
    required this.access,
    required this.galleryId,
    required this.cache,
    required this.prepare,
    required this.child,
    super.key,
  });

  final ContentAccessContext access;
  final int galleryId;
  final NhentaiRelatedGalleryCache cache;
  final bool prepare;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (access.key, galleryId);
    if (prepare && cache._get(key) == null) {
      _watchRelated(ref, key, cache);
    }
    return _NhentaiRelatedGalleryScope(
      access: access,
      galleryId: galleryId,
      cache: cache,
      child: child,
    );
  }
}

class _NhentaiRelatedGalleryScope extends InheritedWidget {
  const _NhentaiRelatedGalleryScope({
    required this.access,
    required this.galleryId,
    required this.cache,
    required super.child,
  });

  final ContentAccessContext access;
  final int galleryId;
  final NhentaiRelatedGalleryCache cache;

  @override
  bool updateShouldNotify(_NhentaiRelatedGalleryScope oldWidget) =>
      access != oldWidget.access ||
      galleryId != oldWidget.galleryId ||
      cache != oldWidget.cache;
}

AsyncValue<List<ContentGroupSummary>> _watchRelated(
  WidgetRef ref,
  _RelatedKey key,
  NhentaiRelatedGalleryCache? cache,
) {
  final provider = nhentaiRelatedGalleriesProvider(key);
  if (cache != null) {
    ref.listen(provider, (_, state) {
      if (state.asData?.value case final galleries?) {
        cache._retain(key, galleries);
      }
    });
  }
  final state = ref.watch(provider);
  if (cache != null) {
    if (state.asData?.value case final galleries?) {
      cache._retain(key, galleries);
    }
  }
  return state;
}

class NhentaiRelatedGalleries extends ConsumerWidget {
  const NhentaiRelatedGalleries({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = GroupViewerScope.maybeEntryOf(context);
    if (entry == null) return const SliverToBoxAdapter();
    final window = context
        .dependOnInheritedWidgetOfExactType<_NhentaiRelatedGalleryScope>();
    final access =
        window?.access ?? ref.watch(mediaGroupProvider(entry)).access;
    if (access == null) return const SliverToBoxAdapter();
    final id =
        window?.galleryId ?? nhentaiIdFromReference(entry.summary.reference);
    final key = (access.key, id);
    final cache = window?.cache;
    if (cache?._get(key) case final galleries?) {
      return _preview(context, ref, access, galleries);
    }
    if (!NavigationActivity.of(context) ||
        !(ModalRoute.isCurrentOf(context) ?? true)) {
      return const SliverToBoxAdapter();
    }
    return _watchRelated(ref, key, cache).when(
      data: (galleries) => _preview(context, ref, access, galleries),
      loading: () => const SliverPreviewPostGridPlaceholder(itemCount: 5),
      error: (_, _) => SliverToBoxAdapter(
        child: ListTile(
          title: Text(context.t.nhentai.more_like_this),
          trailing: TextButton(
            onPressed: () =>
                ref.invalidate(nhentaiRelatedGalleriesProvider(key)),
            child: Text(context.t.generic.action.retry),
          ),
        ),
      ),
    );
  }

  Widget _preview(
    BuildContext context,
    WidgetRef ref,
    ContentAccessContext access,
    List<ContentGroupSummary> galleries,
  ) {
    if (galleries.isEmpty) return const SliverToBoxAdapter();
    final title = context.t.nhentai.more_like_this;
    return MultiSliver(
      children: [
        SliverToBoxAdapter(
          child: ListTile(
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
        BatchedDetailsPreviewGrid(
          itemCount: galleries.length,
          limit: BatchedPreview(galleries.length),
          builder: (context, index) {
            final gallery = galleries[index];
            return PoolGridItem(
              name: gallery.title,
              total: gallery.memberCount,
              showKindIcon: false,
              trailingAction: NhentaiGalleryQuickFavorite(
                access: access,
                galleryId: nhentaiIdFromReference(gallery.reference),
              ),
              image: switch (gallery.cover) {
                final cover? => BooruImage(
                  config: access.config!.auth,
                  imageUrl: cover.thumbnail.toString(),
                  fit: BoxFit.cover,
                ),
                _ => const Icon(Icons.image_not_supported_outlined),
              },
              onTap: () {
                if (NavigationActivity.of(context) &&
                    (ModalRoute.isCurrentOf(context) ?? true) &&
                    ref.read(contentAccessContextProvider(access.key)) !=
                        null) {
                  openNhentaiGalleries(ref, access, galleries, index);
                }
              },
            );
          },
        ),
      ],
    );
  }
}
