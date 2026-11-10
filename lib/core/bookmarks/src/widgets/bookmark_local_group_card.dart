import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

import '../../../configs/config/types.dart';
import '../../../configs/manage/providers.dart';
import '../../../posts/listing/providers.dart';
import '../../../posts/listing/src/widgets/post_grid_item.dart';
import '../providers/pool_bookmark_provider.dart';
import '../../../posts/listing/types.dart';
import '../../../settings/providers.dart';
import '../types/bookmark.dart';
import '../types/bookmark_group.dart';
import '../types/pool_bookmark.dart';
import 'bookmark_pool_card.dart';

/// A locally saved Group with its own direct Bookmark members.
final class BookmarkLocalGroupCard extends StatelessWidget {
  const BookmarkLocalGroupCard({
    required this.title,
    required this.previews,
    required this.group,
    required this.onTap,
    required this.onRename,
    required this.onDuplicate,
    required this.onDelete,
    this.pools = const [],
    this.selected = false,
    this.onSelect,
    this.onMove,
    super.key,
  });

  final bool selected;
  final VoidCallback? onSelect;
  final VoidCallback? onMove;
  final String title;
  final List<PostBookmark> previews;
  final List<CollectionBookmark> pools;
  final BookmarkGroup? group;
  final VoidCallback? onTap;
  final VoidCallback? onRename;
  final VoidCallback? onDuplicate;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(12);
    final hasActions =
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
                      child: BookmarkGroupPreviewGrid(
                        previews: previews,
                        additionalPreviews: [
                          for (final pool in pools)
                            BookmarkPoolCoverImage(pool: pool),
                        ],
                        itemBuilder: (_, bookmark) =>
                            _BookmarkGroupPreviewImage(bookmark: bookmark),
                      ),
                    ),
                    const Positioned.fill(
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
                    Positioned(
                      top: 8,
                      left: 8,
                      right: hasActions ? 52 : 8,
                      bottom: selected ? 40 : 8,
                      child: IgnorePointer(
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

  @override
  Widget build(BuildContext context) {
    Widget cell(int index) => index < previews.length
        ? itemBuilder(context, previews[index])
        : index - previews.length < additionalPreviews.length
        ? additionalPreviews[index - previews.length]
        : const SizedBox.expand();
    return Padding(
      padding: const EdgeInsets.all(2),
      child: Column(
        children: [
          for (var row = 0; row < 2; row++) ...[
            if (row > 0) const SizedBox(height: 2),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: cell(row * 2)),
                  const SizedBox(width: 2),
                  Expanded(child: cell(row * 2 + 1)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String bookmarkGroupPreviewUrl(
  PostBookmark bookmark, {
  bool autoplayGif = true,
}) {
  if (bookmark.isVideo) return bookmark.thumbnailUrl;
  final isGif = _bookmarkGroupPreviewIsGif(bookmark);
  if (autoplayGif || !isGif) return bookmark.sampleUrl;

  // Never fetch an animation just to display its first frame. Extensionless
  // and potentially animated WebP/AVIF variants are not proven static posters.
  for (final url in [bookmark.thumbnailUrl, bookmark.sampleUrl]) {
    if (url.isEmpty || url == bookmark.originalUrl) continue;
    final path = Uri.tryParse(url)?.path.toLowerCase() ?? '';
    if (['.jpg', '.jpeg', '.png', '.bmp'].any(path.endsWith)) return url;
  }
  return '';
}

bool _bookmarkGroupPreviewIsGif(PostBookmark bookmark) =>
    bookmark.post.isGif ||
    (bookmark.format ?? '').toLowerCase().replaceFirst('.', '') == 'gif' ||
    [bookmark.sampleUrl, bookmark.originalUrl].any(
      (url) => Uri.tryParse(url)?.path.toLowerCase().endsWith('.gif') ?? false,
    );

class _BookmarkGroupPreviewImage extends ConsumerWidget {
  const _BookmarkGroupPreviewImage({required this.bookmark});

  final PostBookmark bookmark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(imageListingSettingsProvider);
    final autoplayGif =
        settings.animatedPostsDefaultState ==
        AnimatedPostsDefaultState.autoplay;
    final isGif = _bookmarkGroupPreviewIsGif(bookmark);
    final preview = bookmarkGroupPreviewUrl(bookmark, autoplayGif: autoplayGif);
    if (isGif && preview.isEmpty) {
      return const SizedBox.expand();
    }
    final profile = resolveBookmarkOriginProfile(
      bookmark.post.origin,
      ref.watch(booruConfigProvider),
    );
    if (profile == null) return const SizedBox.expand();
    final config = profile.auth;
    // Preserve the established GIF sample/poster contract while static source
    // thumbnails use the same quality and fallback policy as the timeline.
    final media = isGif
        ? GridThumbnailMedia(url: preview, aspectRatio: null)
        : ref
              .watch(gridThumbnailUrlGeneratorProvider(config))
              .resolve(
                bookmark.post,
                settings: ref.watch(gridThumbnailSettingsProvider(config)),
              );
    return PostGridImage(
      media: media,
      config: config,
      forceCover: true,
      fit: BoxFit.cover,
      borderRadius: BorderRadius.zero,
    );
  }
}
