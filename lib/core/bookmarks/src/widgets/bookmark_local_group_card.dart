import 'bookmark_access_placeholder.dart';
import '../../../backups/folder_sync/widgets.dart';
import '../../../backups/folder_sync/providers.dart';
import '../providers/bookmark_cover_failures.dart';
import '../../../configs/manage/providers.dart';
import '../../../posts/post/types.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

import '../../../configs/manage/widgets.dart';
import '../../../content/content_access_provider.dart';
import '../../../configs/config/types.dart';
import '../../../images/booru_image.dart';
import '../../../posts/listing/types.dart';
import '../../../settings/providers.dart';
import '../types/bookmark.dart';
import '../types/bookmark_group.dart';
import '../types/pool_bookmark.dart';
import '../types/content_group_bookmark.dart';
import 'bookmark_pool_card.dart';
import 'bookmark_native_group_card.dart';
import '../../../content/types.dart';

/// A locally saved Group with its own direct Bookmark members.
final class BookmarkLocalGroupCard extends ConsumerWidget {
  const BookmarkLocalGroupCard({
    required this.title,
    required this.previews,
    required this.group,
    required this.onTap,
    required this.onRename,
    required this.onDuplicate,
    required this.onDelete,
    this.pools = const [],
    this.nativeGroups = const [],
    this.selected = false,
    this.onSelect,
    this.onMove,
    this.hasChildren = false,
    super.key,
  });

  final bool selected;
  final bool hasChildren;
  final VoidCallback? onSelect;
  final VoidCallback? onMove;
  final String title;
  final List<PostBookmark> previews;
  final List<CollectionBookmark> pools;
  final List<ContentGroupBookmark> nativeGroups;
  final BookmarkGroup? group;
  final VoidCallback? onTap;
  final VoidCallback? onRename;
  final VoidCallback? onDuplicate;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.exists(folderSyncServiceProvider))
      ref.watch(folderSyncStateProvider);
    final mirror =
        group != null &&
        ref.exists(folderSyncServiceProvider) &&
        (ref.read(folderSyncServiceProvider).snapshot['subscriptions']
                    as Map<String, dynamic>? ??
                {})
            .values
            .any(
              (value) =>
                  value['kind'] == 'bookmarks' && value['localId'] == group!.id,
            );
    final borderRadius = BorderRadius.circular(12);
    final hasActions =
        group != null ||
        onMove != null ||
        onRename != null ||
        onDuplicate != null ||
        onDelete != null;
    return Semantics(
      enabled: onTap != null,
      child: Opacity(
        opacity: onTap == null ? .38 : 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(
              color: Kurumi.themeOf(context).colorScheme.outlineVariant,
            ),
            borderRadius: borderRadius,
          ),
          child: ClipRRect(
            borderRadius: borderRadius,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                onLongPress: onSelect,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: _BookmarkGroupCover(
                        previews: previews,
                        pools: pools,
                        nativeGroups: nativeGroups,
                      ),
                    ),
                    const Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Color(0x99000000),
                                Color(0x66000000),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      left: 8,
                      right: hasActions ? 52 : 8,
                      bottom: selected ? 40 : 8,
                      child: DefaultTextStyle(
                        style: Kurumi.themeOf(context).textTheme.titleMedium!
                            .copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              shadows: const [Shadow(blurRadius: 4)],
                            ),
                        child: KurumiFittedText(
                          Text(title),
                          alignment: AlignmentDirectional.topStart,
                        ),
                      ),
                    ),
                    if (group != null)
                      Positioned(
                        bottom: 8,
                        left: 8,
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            if (hasChildren)
                              const Icon(
                                Icons.folder_outlined,
                                color: Colors.white,
                              ),
                            CollectionSyncIndicator(
                              kind: 'bookmarks',
                              localId: group!.id,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    if (group != null && !selected)
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: CollectionSyncIndicator(
                          kind: 'bookmarks',
                          localId: group!.id,
                          numericOnly: true,
                        ),
                      ),
                    if (selected)
                      const Positioned(
                        bottom: 8,
                        right: 8,
                        child: Icon(
                          Icons.check_circle,
                          color: Colors.white,
                        ),
                      ),
                    if (hasActions)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: KurumiPopupMenuButton(
                          semanticLabel: context.t.generic.action.more,
                          icon: const Icon(
                            Icons.more_vert,
                            color: Colors.white,
                          ),
                          items: [
                            if (group != null)
                              KurumiPopupMenuItem(
                                title: Text(
                                  collectionSyncActionLabel(
                                    context,
                                    ref,
                                    kind: 'bookmarks',
                                    localId: group!.id,
                                  ),
                                ),
                                icon: Icon(
                                  mirror ? Icons.sync : Icons.upload_outlined,
                                ),
                                onTap: () => openFolderSyncForCollection(
                                  context,
                                  kind: 'bookmarks',
                                  localId: group!.id,
                                ),
                              ),
                            if (onMove != null)
                              KurumiPopupMenuItem(
                                title: Text(context.t.folders.move),
                                icon: const Icon(
                                  Icons.drive_file_move_outline,
                                ),
                                onTap: onMove,
                              ),
                            if (onRename != null)
                              KurumiPopupMenuItem(
                                title: Text(context.t.bookmark.groups.rename),
                                icon: const Icon(Icons.edit_outlined),
                                onTap: onRename,
                              ),
                            if (onDuplicate != null)
                              KurumiPopupMenuItem(
                                title: Text(
                                  context.t.bookmark.groups.duplicate,
                                ),
                                icon: const Icon(Icons.copy),
                                onTap: onDuplicate,
                              ),
                            if (onDelete != null)
                              KurumiPopupMenuItem(
                                title: Text(context.t.bookmark.groups.delete),
                                icon: const Icon(Icons.delete_outline),
                                onTap: onDelete,
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class BookmarkGroupPreviewGrid extends StatelessWidget {
  const BookmarkGroupPreviewGrid({
    required this.previews,
    required this.itemBuilder,
    this.additionalPreviews = const [],
    super.key,
  });

  final List<PostBookmark> previews;
  final List<Widget> additionalPreviews;
  final Widget Function(BuildContext context, PostBookmark bookmark)
  itemBuilder;

  Widget _tile(BuildContext context, int index) => index < previews.length
      ? itemBuilder(context, previews[index])
      : index - previews.length < additionalPreviews.length
      ? additionalPreviews[index - previews.length]
      : const SizedBox.expand();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(2),
    child: Column(
      children: [
        for (var row = 0; row < 2; row++) ...[
          if (row > 0) const SizedBox(height: 2),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _tile(context, row * 2)),
                const SizedBox(width: 2),
                Expanded(child: _tile(context, row * 2 + 1)),
              ],
            ),
          ),
        ],
      ],
    ),
  );
}

class _BookmarkGroupCover extends ConsumerStatefulWidget {
  const _BookmarkGroupCover({
    required this.previews,
    required this.pools,
    required this.nativeGroups,
  });
  final List<PostBookmark> previews;
  final List<CollectionBookmark> pools;
  final List<ContentGroupBookmark> nativeGroups;
  @override
  ConsumerState<_BookmarkGroupCover> createState() =>
      _BookmarkGroupCoverState();
}

class _BookmarkGroupCoverState extends ConsumerState<_BookmarkGroupCover> {
  final _slots = <int?>[0, 1, 2, 3];
  int _next = 4;
  final _failedNative = <int>{};
  void _reset() {
    _slots.setAll(0, [0, 1, 2, 3]);
    _next = 4;
    _failedNative.clear();
  }

  @override
  void didUpdateWidget(_BookmarkGroupCover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.previews, widget.previews) ||
        !identical(oldWidget.nativeGroups, widget.nativeGroups))
      _reset();
  }

  void _retry() {
    final origins = {
      ...widget.previews.take(12).map((b) => b.post.origin),
      ...widget.nativeGroups.take(12).map(nativeBookmarkGroupOrigin),
    };
    for (final origin in origins) {
      final key = ref.read(contentAccessForOriginProvider(origin))?.key;
      if (key != null)
        ref.read(bookmarkCoverFailuresProvider.notifier).retry(key);
      retryBookmarkPolicy(ref, origin);
    }
    setState(_reset);
  }

  Widget _nativePreview(ContentGroupBookmark bookmark) =>
      BookmarkNativeGroupCover(
        key: ValueKey(('native-cover', bookmark.id)),
        bookmark: bookmark,
        onFailed: () {
          if (mounted && !_failedNative.contains(bookmark.id)) {
            setState(() => _failedNative.add(bookmark.id));
          }
        },
      );

  @override
  Widget build(BuildContext context) {
    final candidates = widget.previews.take(12).toList();
    for (final origin in candidates.map((b) => b.post.origin).toSet()) {
      ref.listen(contentAccessForOriginProvider(origin), (previous, next) {
        if (next != null && previous?.key != next.key) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(_reset);
          });
        }
      });
    }
    var poolIndex = 0;
    var nativeIndex = 0;
    final native = widget.nativeGroups
        .take(12)
        .where((record) => !_failedNative.contains(record.id))
        .toList();
    for (final bookmark in widget.nativeGroups.take(12)) {
      ref.listen(
        contentAccessForReferenceProvider(
          ContentAccessRequest(
            reference: bookmark.reference,
            profileIdHint: bookmark.sourceProfileHint,
          ),
        ),
        (previous, next) {
          if (next != null && previous?.key != next.key) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(_reset);
            });
          }
        },
      );
    }
    final failed =
        _slots.any((index) => index == null) || _failedNative.isNotEmpty;
    return Stack(
      children: [
        Positioned.fill(
          child: BookmarkGroupPreviewGrid(
            previews: const [],
            additionalPreviews: [
              for (var slot = 0; slot < 4; slot++)
                if (_slots[slot] case final index?
                    when index < candidates.length)
                  _BookmarkGroupPreviewImage(
                    key: ValueKey((slot, candidates[index].id)),
                    bookmark: candidates[index],
                    onFailed: () {
                      if (!mounted || _slots[slot] != index) return;
                      setState(() {
                        _slots[slot] = _next < candidates.length
                            ? _next++
                            : null;
                      });
                    },
                  )
                else if (poolIndex < widget.pools.length)
                  BookmarkPoolCoverImage(pool: widget.pools[poolIndex++])
                else if (nativeIndex < native.length)
                  _nativePreview(native[nativeIndex++])
                else
                  const SizedBox.expand(),
            ],
            itemBuilder: (_, _) => const SizedBox.expand(),
          ),
        ),
        if (failed)
          Positioned(
            right: 4,
            bottom: 4,
            child: IconButton(
              tooltip: context.t.generic.action.retry,
              onPressed: _retry,
              style: IconButton.styleFrom(
                backgroundColor: Colors.black54,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.refresh),
            ),
          ),
      ],
    );
  }
}

/// A terminal image outcome reports once after layout, never during build.
class _CoverFailure extends StatefulWidget {
  const _CoverFailure({required this.onFailed});
  final VoidCallback onFailed;
  @override
  State<_CoverFailure> createState() => _CoverFailureState();
}

class _CoverFailureState extends State<_CoverFailure> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onFailed();
    });
  }

  @override
  Widget build(BuildContext context) => const Icon(Icons.bookmarks_outlined);
}

String bookmarkGroupPreviewUrl(
  PostBookmark bookmark, {
  bool autoplayGif = true,
}) {
  if (bookmark.isVideo) return bookmark.thumbnailUrl;
  final isGif =
      bookmark.post.isGif ||
      (bookmark.format ?? '').toLowerCase().replaceFirst('.', '') == 'gif' ||
      [bookmark.sampleUrl, bookmark.originalUrl].any(
        (url) =>
            Uri.tryParse(url)?.path.toLowerCase().endsWith('.gif') ?? false,
      );
  if (!isGif)
    return bookmark.thumbnailUrl.isNotEmpty
        ? bookmark.thumbnailUrl
        : bookmark.sampleUrl;
  if (autoplayGif) return bookmark.sampleUrl;

  // Never fetch an animation just to display its first frame. Extensionless
  // and potentially animated WebP/AVIF variants are not proven static posters.
  for (final url in [bookmark.thumbnailUrl, bookmark.sampleUrl]) {
    if (url.isEmpty || url == bookmark.originalUrl) continue;
    final path = Uri.tryParse(url)?.path.toLowerCase() ?? '';
    if (['.jpg', '.jpeg', '.png', '.bmp'].any(path.endsWith)) return url;
  }
  return '';
}

class _BookmarkGroupPreviewImage extends ConsumerWidget {
  const _BookmarkGroupPreviewImage({
    required this.bookmark,
    required this.onFailed,
    super.key,
  });

  final PostBookmark bookmark;
  final VoidCallback onFailed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final autoplayGif = ref.watch(
      settingsProvider.select(
        (settings) =>
            settings.listing.animatedPostsDefaultState ==
            AnimatedPostsDefaultState.autoplay,
      ),
    );
    final imageUrl = bookmarkGroupPreviewUrl(
      bookmark,
      autoplayGif: autoplayGif,
    );
    if (imageUrl.isEmpty) return const Icon(Icons.bookmarks_outlined);
    final access = ref.watch(
      contentAccessForOriginProvider(bookmark.post.origin),
    );
    final imageConfig = access?.config;
    if (imageConfig == null) {
      final resolution = const PostOriginResolver().resolve(
        bookmark.post.origin,
        ref.watch(booruConfigProvider),
        allowProfileHintFallback: true,
      );
      if (resolution case ResolvedPostOrigin(:final config)) {
        if (ref.watch(contentEffectivePolicyProvider(config.id)).hasError)
          return _CoverFailure(onFailed: onFailed);
      }
      return BookmarkAccessPlaceholder(origin: bookmark.post.origin);
    }
    final visible = ref.watch(
      contentPostVisibilityProvider((access: access!.key, post: bookmark.post)),
    );
    if (visible.valueOrNull == false) return _CoverFailure(onFailed: onFailed);
    if (visible.valueOrNull != true)
      return BookmarkAccessPlaceholder(origin: bookmark.post.origin);
    final sample = bookmark.isVideo || (!autoplayGif && bookmark.post.isGif)
        ? ''
        : bookmark.sampleUrl;
    final cachedRendition = ref.watch(
      bookmarkCoverCachedRenditionProvider((
        access: access.key,
        primary: imageUrl,
        sample: sample,
      )),
    );
    if (cachedRendition.isLoading) return const SizedBox.expand();
    final selectedUrl = cachedRendition.valueOrNull ?? imageUrl;
    if ((ref.watch(bookmarkCoverFailuresProvider)[access.key]?.length ?? 0) >=
        4) {
      final cached = ref.watch(
        bookmarkCoverCachedProvider((access: access.key, url: selectedUrl)),
      );
      if (cached.hasError || cached.valueOrNull == false)
        return _CoverFailure(onFailed: onFailed);
      if (cached.valueOrNull != true)
        return const SizedBox.expand(
          child: Center(child: Icon(Icons.bookmarks_outlined)),
        );
    }
    return CurrentBooruConfigScope(
      config: imageConfig,
      accessKey: access.key,
      requireAccess: true,
      bookmarkId: bookmark.id,
      child: BooruImage(
        imageUrl: selectedUrl,
        config: imageConfig.auth,
        fit: BoxFit.cover,
        errorWidget: _CoverFailure(
          onFailed: () {
            ref
                .read(bookmarkCoverFailuresProvider.notifier)
                .record(access.key, bookmark.id);
            onFailed();
          },
        ),
      ),
    );
  }
}
