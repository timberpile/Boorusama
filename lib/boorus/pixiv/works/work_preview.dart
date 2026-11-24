import 'package:booru_clients/pixiv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';
import 'package:sliver_tools/sliver_tools.dart';

import '../../../core/boorus/booru/types.dart';
import '../../../core/configs/config/types.dart';
import '../../../core/content/content_access_provider.dart';
import '../../../core/content/content_media_access.dart';
import '../../../core/content/types.dart';
import '../../../core/images/booru_image.dart';
import '../../../core/navigation/destination_activity.dart';
import '../../../core/posts/details/routes.dart';
import '../../../core/posts/details/src/types/viewer_entry.dart';
import '../../../core/posts/details/types.dart';
import '../../../core/posts/details_parts/widgets.dart';
import '../../../core/posts/listing/widgets.dart';
import '../../../core/posts/pools/pool_grid_item.dart';
import '../../../core/widgets/booru_visibility_detector.dart';
import '../posts/types.dart';
import 'work_mapper.dart';

ContentAccessContext? watchPixivPreviewAccess(WidgetRef ref) {
  final key = ref.watch(currentContentAccessKeyProvider);
  if (key == null || key.engine != BooruType.pixiv || key.profileId == null) {
    return null;
  }
  final access = ref.watch(contentAccessContextProvider(key));
  return (access?.config?.auth.apiKey?.isNotEmpty ?? false) ? access : null;
}

PixivPostData? pixivPreviewPostData(
  BuildContext context,
  ContentAccessContext access,
) {
  final post = InheritedPost.maybeOf<Post>(context);
  if (post == null ||
      post.origin.booruType != access.key.engine ||
      post.origin.sourceHost != access.key.siteNamespace ||
      (post.origin.profileIdHint != null &&
          post.origin.profileIdHint != access.key.profileId)) {
    return null;
  }
  return post.pixivData;
}

class PixivWorksPreview<T> extends ConsumerStatefulWidget {
  const PixivWorksPreview({
    required this.access,
    required this.provider,
    required this.listing,
    required this.title,
    required this.onShowAll,
    this.subtitle,
    super.key,
  });

  final ContentAccessContext access;
  final AutoDisposeFutureProvider<T> provider;
  final PixivIllustListResult Function(T) listing;
  final String title;
  final String? subtitle;
  final void Function(WidgetRef, T) onShowAll;

  @override
  ConsumerState<PixivWorksPreview<T>> createState() =>
      _PixivWorksPreviewState<T>();
}

class _PixivWorksPreviewState<T> extends ConsumerState<PixivWorksPreview<T>> {
  final _visibility = VisibilityController();
  final _visibilityKey = UniqueKey();
  var _requested = false;
  static const _limit = BatchedPreview(artistUploaderPreviewPostLimit);

  @override
  void dispose() {
    _visibility.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active =
        NavigationActivity.of(context) &&
        (ModalRoute.isCurrentOf(context) ?? true);
    return MultiSliver(
      children: [
        SliverToBoxAdapter(
          child: BooruVisibilityDetector(
            childKey: _visibilityKey,
            controller: _visibility,
          ),
        ),
        ListenableBuilder(
          listenable: _visibility,
          builder: (context, _) {
            if (!_requested && (!_visibility.isVisible || !active)) {
              return const SliverToBoxAdapter();
            }
            _requested = true;
            final provider = widget.provider;
            return Consumer(
              builder: (context, ref, _) => ref
                  .watch(provider)
                  .when(
                    data: (page) => _buildPreview(context, page),
                    loading: () => const SliverPreviewPostGridPlaceholder(
                      limit: _limit,
                    ),
                    error: (_, _) => SliverToBoxAdapter(
                      child: TextButton(
                        onPressed: () => ref.invalidate(provider),
                        child: Text(
                          '${widget.subtitle ?? widget.title} · '
                          '${context.t.generic.action.retry}',
                        ),
                      ),
                    ),
                  ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPreview(BuildContext context, T page) {
    final access = widget.access;
    final listing = widget.listing(page);
    final entries = pixivWorkListingEntries(listing, access: access);
    if (entries.isEmpty && !listing.hasMore) {
      return const SliverToBoxAdapter();
    }
    void openTimeline() {
      if (!_canNavigate()) return;
      widget.onShowAll(ref, page);
    }

    return SliverDetailsPostList(
      title: widget.title,
      subtitle: widget.subtitle,
      onTap: openTimeline,
      child: BatchedDetailsPreviewGrid(
        limit: _limit,
        itemCount: entries.length,
        onShowAll: openTimeline,
        builder: (context, index) {
          final entry = entries[index];
          return switch (entry) {
            GroupContentEntry(:final summary) => Semantics(
              label: summary.title,
              child: PoolGridItem(
                category: context.t.content_viewer.work,
                name: null,
                total: summary.memberCount,
                image: summary.cover == null
                    ? const Icon(Icons.image_not_supported_outlined)
                    : BooruImage(
                        config: access.config!.auth,
                        imageUrl: summary.cover!.thumbnail.toString(),
                        fit: BoxFit.cover,
                        forceCover: true,
                      ),
                onTap: () =>
                    _open(entries, index, summary.cover?.sample?.toString()),
              ),
            ),
            PostContentEntry(:final post) => PostGridItem(
              post: post,
              index: index,
              useHero: false,
              multiSelectEnabled: false,
              selectionEnabled: false,
              config: access.config!.auth,
              onTap: (media) => _open(entries, index, media.url),
            ),
          };
        },
      ),
    );
  }

  bool _canNavigate() =>
      mounted &&
      NavigationActivity.of(context) &&
      (ModalRoute.isCurrentOf(context) ?? true) &&
      (ref
              .read(contentAccessContextProvider(widget.access.key))
              ?.hasSameAuthorization(widget.access) ??
          false);

  void _open(List<ContentEntry> entries, int index, String? thumbnail) {
    if (!_canNavigate()) return;
    final config = widget.access.config!;
    final source = ViewerSourceBinding(config);
    goToPostDetailsPageCore<Post>(
      ref: ref,
      posts: [
        for (final entry in entries)
          if (entry case PostContentEntry(:final post)) post,
      ],
      initialIndex: index,
      hero: false,
      initialThumbnailUrl: thumbnail,
      config: config,
      entries: [
        for (final entry in entries)
          switch (entry) {
            GroupContentEntry(:final summary) => GroupViewerEntry(
              summary: summary,
              occurrenceId: Object(),
              source: source,
            ),
            PostContentEntry(:final post) => PostViewerEntry(
              post: post,
              occurrenceId: Object(),
              source: source,
            ),
          },
      ],
    );
  }
}
