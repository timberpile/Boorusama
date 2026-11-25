import 'package:flutter/rendering.dart' show RenderAbstractViewport, RenderBox;

import '../../../blacklists/providers.dart';
import '../../../content/content_media_access.dart';
import '../../../content/types.dart';
import '../../../navigation/destination_activity.dart';
import '../../../local_media/local_media_reference.dart';
import '../../../local_media/local_media_thumbnail.dart';
import '../providers/native_work_mosaic_cover.dart';
import '../providers/pool_bookmark_provider.dart';
import '../providers/bookmark_read_access.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

import '../../../configs/manage/widgets.dart';
import '../../../configs/config/types.dart';
import '../../../posts/listing/providers.dart';
import '../../../posts/listing/src/widgets/post_grid_item.dart';
import '../../../posts/listing/types.dart';
import '../../../settings/providers.dart';
import '../types/bookmark.dart';
import '../types/bookmark_grid_entry.dart';
import '../types/pool_bookmark.dart';
import 'bookmark_pool_card.dart';
import 'bookmark_group_viewer_entry.dart';
import 'bookmark_native_group_card.dart';
import '../types/content_group_bookmark.dart';

/// A locally saved Group with its own direct Bookmark members.
final class BookmarkLocalGroupCard extends ConsumerStatefulWidget {
  const BookmarkLocalGroupCard({
    required this.title,
    required this.mosaicCandidates,
    required this.onTap,
    required this.onRename,
    required this.onDuplicate,
    required this.onDelete,
    this.selected = false,
    this.onSelect,
    this.onMove,
    this.syncActions = const [],
    this.syncIndicator,
    this.readOnly = false,
    this.unseenCount = 0,
    super.key,
  });

  final List<Widget> syncActions;
  final Widget? syncIndicator;
  final bool readOnly;
  final int unseenCount;
  final bool selected;
  final VoidCallback? onSelect;
  final VoidCallback? onMove;
  final String title;
  final List<BookmarkGridEntry> mosaicCandidates;
  final VoidCallback? onTap;
  final VoidCallback? onRename;
  final VoidCallback? onDuplicate;
  final VoidCallback? onDelete;

  @override
  ConsumerState<BookmarkLocalGroupCard> createState() =>
      _BookmarkLocalGroupCardState();
}

class _BookmarkLocalGroupCardState
    extends ConsumerState<BookmarkLocalGroupCard> {
  final _cardFocus = FocusNode();
  final _menuFocus = FocusNode();
  ScrollPosition? _position;
  var _visibilityQueued = false;
  var _visible = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final position = Scrollable.maybeOf(context)?.position;
    if (_position != position) {
      _position?.removeListener(_checkVisibility);
      _position = position;
      _position?.addListener(_checkVisibility);
    }
    _checkVisibility();
  }

  void _checkVisibility() {
    if (_visibilityQueued) return;
    _visibilityQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _visibilityQueued = false;
      if (!mounted) return;
      final box = context.findRenderObject();
      if (box is! RenderBox || !box.hasSize) return;
      final Object? viewport = RenderAbstractViewport.maybeOf(box);
      final visible = viewport is RenderBox && viewport.hasSize
          ? (box.localToGlobal(Offset.zero, ancestor: viewport) & box.size)
                .overlaps(Offset.zero & viewport.size)
          : (box.localToGlobal(Offset.zero) & box.size).overlaps(
              Offset.zero & MediaQuery.sizeOf(context),
            );
      if (_visible != visible) setState(() => _visible = visible);
    });
  }

  @override
  void dispose() {
    _cardFocus.dispose();
    _menuFocus.dispose();
    _position?.removeListener(_checkVisibility);
    super.dispose();
  }

  bool _allowsCoverUrl(BooruConfig config, String url) {
    if (url.isEmpty) return false;
    final source = config.anonymousReadScope?.source;
    final uri = Uri.tryParse(url);
    return source == null || (uri != null && source.allowsMedia(uri));
  }

  Widget? _postCover(PostBookmark bookmark) {
    if (bookmark.post.booruData case LocalMediaPostData(:final reference)) {
      return LocalMediaThumbnail(reference: reference);
    }
    final settings = ref.watch(imageListingSettingsProvider);
    final autoplayGif =
        settings.animatedPostsDefaultState ==
        AnimatedPostsDefaultState.autoplay;
    final isGif = _bookmarkGroupPreviewIsGif(bookmark);
    final preview = bookmarkGroupPreviewUrl(bookmark, autoplayGif: autoplayGif);
    if (isGif && preview.isEmpty) {
      return null;
    }
    final access = ref.watch(
      bookmarkReadAccessProvider(BookmarkReaderRequest(bookmark.post.origin)),
    );
    final profile = access?.config;
    if (access == null || profile == null) return null;
    final config = profile.auth;
    if (!watchContentMediaAccess(
      ref,
      config,
      key: access.key,
      post: bookmark.post,
    ).allowed) {
      return null;
    }
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
    final urls = [
      media.url,
      ?media.fallbackUrl,
      ...media.fallbackUrls,
      ?media.placeholderUrl,
    ];
    if (!urls.any((url) => _allowsCoverUrl(profile, url))) return null;
    return CurrentBooruConfigScope(
      config: profile,
      accessKey: access.key,
      requireAccess: true,
      bookmarkId: bookmark.id,
      child: PostGridImage(
        post: bookmark.post,
        media: media,
        config: config,
        forceCover: true,
        fit: BoxFit.cover,
        borderRadius: BorderRadius.zero,
      ),
    );
  }

  ContentAccessContext? _poolAccess(CollectionBookmark pool) {
    final reference = bookmarkGroupReference(
      pool,
      ref.watch(bookmarkReadProfilesProvider),
    );
    return reference == null
        ? null
        : ref.watch(
            bookmarkReadAccessProvider(
              BookmarkReaderRequest.reference(reference),
            ),
          );
  }

  Widget? _poolCover(CollectionBookmark pool) =>
      ref.watch(storedBookmarkPoolCoverEligibleProvider(pool))
      ? BookmarkPoolCoverImage(pool: pool, allowBackfill: false)
      : null;

  Widget? _nativeCover(
    ContentGroupBookmark bookmark,
    GroupCover? cover,
    BooruConfig? config,
  ) {
    if (cover == null || config == null) return null;
    final blacklist = ref.watch(blacklistTagsProvider(config.filter));
    if (blacklist.isLoading ||
        !blacklist.hasValue ||
        blacklist.hasError ||
        !nativeGroupCoverAllowed(cover, config, blacklist.requireValue) ||
        ![cover.thumbnail, ?cover.sample].any(
          (url) => _allowsCoverUrl(config, url.toString()),
        )) {
      return null;
    }
    return BookmarkNativeGroupCover(bookmark: bookmark, recoveredCover: cover);
  }

  List<Widget> _mosaicCells({required bool canRepair}) {
    final cells = <Widget>[];
    // Check missing covers only while they could outrank a displayed cover.
    // A pending or failed lookup consumes its type's repair slot for this card.
    var canRepairPool = canRepair;
    var canRepairWork = canRepair;
    for (final entry in widget.mosaicCandidates) {
      if (cells.length == 4) break;
      Widget? cover;
      switch (entry) {
        case BookmarkPostEntry(:final bookmark):
          cover = _postCover(bookmark);
        case BookmarkPoolEntry(:final pool):
          cover = _poolCover(pool);
          if (cover == null &&
              canRepairPool &&
              pool.needsCoverFacts &&
              pool.groupIds.isNotEmpty &&
              ref.watch(storedBookmarkPoolCoverProvider(pool)) == null) {
            final config = _poolAccess(pool)?.config;
            if (config != null) {
              canRepairPool = false;
              final repaired = ref
                  .watch(missingPoolCoverProvider((config, pool)))
                  .asData
                  ?.value;
              if (repaired != null) cover = _poolCover(repaired);
            }
          }
        case BookmarkNativeGroupEntry(:final bookmark):
          final access = ref.watch(
            bookmarkReadAccessProvider(
              BookmarkReaderRequest.reference(bookmark.reference),
            ),
          );
          final saved = ref.watch(nativeWorkSavedCoverProvider(bookmark));
          cover = _nativeCover(bookmark, saved, access?.config);
          if (cover == null &&
              canRepairWork &&
              access != null &&
              needsNativeWorkCover(bookmark) &&
              saved?.visibility?.tagCoverage != MetadataCoverage.complete) {
            canRepairWork = false;
            final repaired = ref
                .watch(missingNativeWorkCoverProvider((bookmark, access.key)))
                .asData
                ?.value;
            cover = _nativeCover(bookmark, repaired, access.config);
          }
      }
      if (cover != null) {
        cells.add(KeyedSubtree(key: ValueKey(entry.key), child: cover));
      }
    }
    return cells;
  }

  @override
  Widget build(BuildContext context) {
    _checkVisibility();
    final BookmarkLocalGroupCard(
      :title,
      :onTap,
      :onRename,
      :onDuplicate,
      :onDelete,
      :selected,
      :onSelect,
      :onMove,
      :syncActions,
      :syncIndicator,
      :unseenCount,
    ) = widget;
    final canRepair =
        _visible &&
        TickerMode.valuesOf(context).enabled &&
        NavigationActivity.of(context) &&
        (ModalRoute.of(context)?.isCurrent ?? true);
    final cells = _mosaicCells(canRepair: canRepair);
    final borderRadius = BorderRadius.circular(12);
    final hasActions =
        onMove != null ||
        onRename != null ||
        onDuplicate != null ||
        onDelete != null ||
        syncActions.isNotEmpty;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent || !hasActions) {
          return KeyEventResult.ignored;
        }
        // The small menu sits inside the card's larger focus rectangle, so
        // geometric arrow traversal cannot reliably enter it on its own.
        if (_cardFocus.hasPrimaryFocus &&
            event.logicalKey == LogicalKeyboardKey.arrowRight) {
          _menuFocus.requestFocus();
          return KeyEventResult.handled;
        }
        if (_menuFocus.hasPrimaryFocus &&
            event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          _cardFocus.requestFocus();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Semantics(
        label: widget.readOnly ? context.t.mitemite.received_group : null,
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
                  focusNode: _cardFocus,
                  onTap: onTap,
                  onLongPress: onSelect,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: BookmarkGroupPreviewGrid(cells: cells),
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
                            style: Kurumi.themeOf(context)
                                .textTheme
                                .titleMedium!
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
                      if (syncIndicator != null)
                        Positioned(bottom: 8, left: 8, child: syncIndicator),
                      if (!selected && unseenCount > 0)
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: _UnseenCountBadge(count: unseenCount),
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
                            focusNode: _menuFocus,
                            semanticLabel: context.t.generic.action.more,
                            icon: const Icon(
                              Icons.more_vert,
                              color: Colors.white,
                            ),
                            items: [
                              ...syncActions,
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
                                  title: Text(
                                    context.t.bookmark.groups.rename,
                                  ),
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
                                  title: Text(
                                    context.t.bookmark.groups.delete,
                                  ),
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
      ),
    );
  }
}

class BookmarkGroupPreviewGrid extends StatelessWidget {
  const BookmarkGroupPreviewGrid({required this.cells, super.key});

  final List<Widget> cells;

  @override
  Widget build(BuildContext context) {
    Widget cell(int index) =>
        index < cells.length ? cells[index] : const SizedBox.expand();
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
  if (bookmark.post.requiresDetailLookup) return bookmark.thumbnailUrl;
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

class _UnseenCountBadge extends StatelessWidget {
  const _UnseenCountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(context).style
        .copyWith(color: Colors.white);
    final label = '$count';
    final metrics = TextPainter(
      text: TextSpan(text: label, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final diameter = metrics.height + 4;
    metrics.dispose();
    return Container(
      constraints: BoxConstraints(minWidth: diameter),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: ShapeDecoration(
        color: Kurumi.themeOf(context).colorScheme.primary,
        shape: const StadiumBorder(),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        semanticsLabel: context.t.mitemite.unseen_posts(count: count),
        style: style,
      ),
    );
  }
}
