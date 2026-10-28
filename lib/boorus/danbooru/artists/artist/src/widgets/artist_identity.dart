import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../../../core/bulk_downloads/routes.dart';
import '../../../../../../core/configs/config/providers.dart';
import '../../../../../../core/images/booru_image.dart';
import '../../../../../../core/posts/filter/types.dart';
import '../../../../../../core/posts/listing/providers.dart';
import '../../../../../../core/posts/post/types.dart';
import '../../../../../../core/search/following_topics/src/widgets/topic_follow_control.dart';
import '../../../../../../foundation/clipboard.dart';

// Route-owned so changing sort or responsive panes cannot replace the snapshot.
class ArtistBannerSnapshot extends ChangeNotifier {
  ArtistBannerSnapshot({this.fetchStillImages, this.isUsableImage});

  Future<List<Post>> Function(int page)? fetchStillImages;
  bool Function(Post post)? isUsableImage;
  PostGridController<Post>? _controller;
  Post? post;
  var newest = true;
  Map<String, bool> _filters = {};
  var _generation = 0;
  var _searching = false;
  var _searched = false;
  var _fromLookup = false;
  var _disposed = false;

  bool _canUse(Post post) =>
      !post.isAnimated &&
      !{'zip', '.zip', 'swf', '.swf'}.contains(post.format.toLowerCase()) &&
      !post.tags.contains('animated') &&
      (isUsableImage?.call(post) ?? post.thumbnailImageUrl.isNotEmpty);

  void _invalidateLookup() {
    _generation++;
    _searching = false;
    _searched = false;
    _fromLookup = false;
  }

  void attach(PostGridController<Post> controller) {
    if (_controller == controller) return;
    _controller?.removeListener(_update);
    _controller?.activeFilters.removeListener(_filtersChanged);
    _invalidateLookup();
    _controller = controller;
    controller.addListener(_update);
    controller.activeFilters.addListener(_filtersChanged);
  }

  void _filtersChanged() {
    // A retained newest image may be absent from Popular. Recheck visibility
    // when the filter policy changes instead of keeping an unchecked image.
    if (_controller!.refreshing) return;
    final filters = _controller!.activeFilters.value;
    if (!mapEquals(filters, _filters)) {
      _invalidateLookup();
      post = null;
      notifyListeners();
    }
    _filters = Map.of(filters);
  }

  void _update() {
    final controller = _controller!;
    if (controller.refreshing) {
      _invalidateLookup();
      return;
    }
    _filters = Map.of(controller.activeFilters.value);
    final previous = post;
    if (newest) {
      // Filtered items already respect hidden posts and blacklist settings.
      post = _fromLookup ? post : controller.items.where(_canUse).firstOrNull;
    } else if (post != null &&
        controller.allItems.any((p) => p.id == post!.id) &&
        !controller.items.any((p) => p.id == post!.id)) {
      post = null;
    }
    if (previous != post) notifyListeners();
    if (post == null && controller.allItems.isNotEmpty) {
      unawaited(_findStillImage());
    }
  }

  Future<void> _findStillImage() async {
    final fetch = fetchStillImages;
    final controller = _controller;
    if (fetch == null || controller == null || _searching || _searched) return;
    _searching = true;
    final generation = _generation;
    bool current() => !_disposed && generation == _generation;
    try {
      final hiddenUrls =
          await controller.blacklistedUrlsFetcher?.call() ?? const <String>{};
      if (!current()) return;
      final hiddenTags = {
        for (final tag in controller.blacklistedTags ?? const <String>{})
          if (controller.activeFilters.value[tag] ?? true) tag,
      };
      for (var page = 1; current(); page++) {
        final candidates = await fetch(page);
        if (!current()) return;
        if (candidates.isEmpty) break;
        final candidate = filterTags(candidates, hiddenTags)
            .where(_canUse)
            .where((post) => !hiddenUrls.contains(post.originalImageUrl))
            .firstOrNull;
        if (candidate != null) {
          post = candidate;
          _fromLookup = true;
          notifyListeners();
          break;
        }
      }
    } catch (_) {
      // Decorative lookup failures keep the themed fallback and grid intact.
    } finally {
      if (current()) {
        _searching = false;
        _searched = true;
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _controller?.removeListener(_update);
    _controller?.activeFilters.removeListener(_filtersChanged);
    super.dispose();
  }
}

class ArtistIdentity extends ConsumerWidget {
  const ArtistIdentity({
    required this.artistName,
    required this.banner,
    super.key,
  });

  final String artistName;
  final ArtistBannerSnapshot banner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Kurumi.themeOf(context);
    final colors = theme.colorScheme;
    final padding = MediaQuery.paddingOf(context);
    final top = padding.top;
    return Column(
      children: [
        SizedBox(
          height: 168 + top,
          child: Stack(
            children: [
              SizedBox(
                height: 124 + top,
                width: double.infinity,
                child: ColoredBox(
                  color: colors.surfaceContainerHighest,
                  child: ClipRect(
                    child: ListenableBuilder(
                      listenable: banner,
                      builder: (context, _) {
                        final post = banner.post;
                        if (post == null || post.isVideo || post.isGif) {
                          return const SizedBox.expand();
                        }
                        final auth = ref.watchConfigAuth;
                        final media = ref
                            .watch(gridThumbnailUrlGeneratorProvider(auth))
                            .resolve(
                              post,
                              settings: ref.watch(
                                gridThumbnailSettingsProvider(auth),
                              ),
                            );
                        if (media.url.isEmpty) return const SizedBox.expand();
                        return ExcludeSemantics(
                          child: IgnorePointer(
                            child: ImageFiltered(
                              imageFilter: ImageFilter.blur(
                                sigmaX: 12,
                                sigmaY: 12,
                              ),
                              child: BooruImage(
                                imageUrl: media.url,
                                config: auth,
                                forceCover: true,
                                borderRadius: BorderRadius.zero,
                                errorWidget: ColoredBox(
                                  color: colors.surfaceContainerHighest,
                                ),
                                placeholderWidget: ColoredBox(
                                  color: colors.surfaceContainerHighest,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 124 + top,
                child: const IgnorePointer(
                  child: ColoredBox(color: Colors.black26),
                ),
              ),
              Positioned(
                top: top + 4,
                left: padding.left + 8,
                right: padding.right + 8,
                child: Row(
                  children: [
                    Material(
                      color: colors.surface.withValues(alpha: .85),
                      shape: const CircleBorder(),
                      child: BackButton(color: colors.onSurface),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: FollowTopicButton(
                          query: artistName,
                          compact: true,
                          showCount: false,
                        ),
                      ),
                    ),
                    KurumiPopupMenuButton(
                      semanticLabel: context.t.generic.action.more,
                      items: [
                        KurumiPopupMenuItem(
                          title: Text(context.t.sideMenu.bulk_download),
                          icon: const Icon(Symbols.download),
                          onTap: () => goToBulkDownloadPage(context, [
                            artistName,
                          ], ref: ref),
                        ),
                        KurumiPopupMenuItem(
                          title: Text(context.t.artist_page.copy_artist_tag),
                          icon: const Icon(Symbols.content_copy),
                          onTap: () => AppClipboard.copyWithDefaultToast(
                            context,
                            artistName,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 86 + top,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    width: 82,
                    height: 82,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.surfaceContainerHighest,
                      border: Border.all(color: colors.surface, width: 3),
                    ),
                    child: Icon(
                      Symbols.person,
                      size: 38,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Text(
            artistName.replaceAll('_', ' '),
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
