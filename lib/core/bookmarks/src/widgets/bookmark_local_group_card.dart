import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

import '../../../configs/manage/providers.dart';
import '../../../configs/config/types.dart';
import '../../../images/booru_image.dart';
import '../../../posts/listing/types.dart';
import '../../../settings/providers.dart';
import '../types/bookmark.dart';
import '../types/bookmark_group.dart';
import '../types/pool_bookmark.dart';
import '../providers/pool_bookmark_provider.dart';
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
  Widget build(BuildContext context) => GridView.builder(
    physics: const NeverScrollableScrollPhysics(),
    padding: const EdgeInsets.all(2),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      crossAxisSpacing: 2,
      mainAxisSpacing: 2,
    ),
    itemCount: 4,
    itemBuilder: (context, index) => index < previews.length
        ? itemBuilder(context, previews[index])
        : index - previews.length < additionalPreviews.length
        ? additionalPreviews[index - previews.length]
        : const SizedBox.shrink(),
  );
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

class _BookmarkGroupPreviewImage extends ConsumerWidget {
  const _BookmarkGroupPreviewImage({required this.bookmark});

  final PostBookmark bookmark;

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
    if (imageUrl.isEmpty) return const SizedBox.expand();
    final imageConfig = resolveBookmarkOriginProfile(
      bookmark.post.origin,
      ref.watch(booruConfigProvider),
    );
    if (imageConfig == null) return const SizedBox.expand();
    return BooruImage(
      imageUrl: imageUrl,
      config: imageConfig.auth,
      fit: BoxFit.cover,
      placeholderWidget: const SizedBox.expand(),
    );
  }
}
