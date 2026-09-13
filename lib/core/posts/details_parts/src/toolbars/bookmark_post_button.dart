// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:like_button/like_button.dart';
import 'package:material_symbols_icons/symbols.dart';

// Project imports:
import '../../../../bookmarks/providers.dart';
import '../../../../bookmarks/types.dart';
import '../../../../bookmarks/widgets.dart';
import '../../../../configs/config/providers.dart';
import '../../../../configs/config/types.dart';
import '../../../../themes/theme/types.dart';
import '../../../post/types.dart';

class BookmarkPostButton extends ConsumerWidget {
  const BookmarkPostButton({
    required this.post,
    required this.config,
    super.key,
  });

  final Post post;
  final BooruConfigAuth config;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookmarkStateAsync = ref.watch(bookmarkProvider);
    final library = bookmarkStateAsync.valueOrNull;
    final uniqueId = BookmarkUniqueId.fromPost(post, config.booruIdHint);
    final presentation = library == null
        ? null
        : selectBookmarkMembershipPresentation(library, uniqueId);
    final activeGroupId = library?.activeTarget.groupId;
    final isBookmarked = presentation?.isInActiveTarget ?? false;
    final activeLabel = activeGroupId == null
        ? context.t.bookmark.groups.ungrouped
        : library?.groupsById[activeGroupId]?.name ??
              context.t.bookmark.groups.ungrouped;
    final isLoading = bookmarkStateAsync.isLoading;

    return KurumiTooltip(
      message: isBookmarked
          ? context.t.post.detail.remove_from_bookmark
          : context.t.post.detail.add_to_bookmark,
      padding: const EdgeInsets.all(8),
      child: GestureDetector(
        onLongPressStart: isLoading
            ? null
            : (details) => showAnchoredBookmarkGroupPicker(
                context,
                ref: ref,
                config: config,
                post: post,
                position: details.globalPosition,
              ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              splashRadius: 16,
              onPressed: isLoading
                  ? null
                  : () async {
                      if (presentation?.activeTargetUnavailable ?? false) {
                        await showBookmarkGroupPicker(
                          context,
                          ref: ref,
                          config: config,
                          post: post,
                        );
                        return;
                      }
                      await ref.toggleBookmarkTarget(post, config, context);
                    },
              icon: Badge(
                isLabelVisible: presentation?.showNamedGroupCount ?? false,
                label: Text('${presentation?.namedGroupCount ?? 0}'),
                child: CustomPaint(
                  size: const Size(32, 24),
                  painter: BookmarkWithDropdownIconPainter(
                    color: isBookmarked
                        ? context.colors.upvoteColor
                        : IconTheme.of(context).color ?? Colors.grey,
                    fill: isBookmarked,
                  ),
                ),
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 100),
              child: Text(
                activeLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BookmarkPostLikeButtonButton extends ConsumerWidget {
  const BookmarkPostLikeButtonButton({
    required this.post,
    super.key,
  });

  final Post post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booruConfig = ref.watchConfigAuth;
    final bookmarkStateAsync = ref.watch(bookmarkProvider);
    final library = bookmarkStateAsync.valueOrNull;
    final uniqueId = BookmarkUniqueId.fromPost(post, booruConfig.booruIdHint);
    final bookmark = library?.bookmarksByUniqueId[uniqueId];
    final groupId = library?.activeTarget.groupId;
    final memberships = library?.membershipsFor(uniqueId) ?? const <String>{};
    final isBookmarked = groupId == null
        ? bookmark != null && memberships.isEmpty
        : memberships.contains(groupId);
    final isLoading = bookmarkStateAsync.isLoading;

    return LikeButton(
      isLiked: isBookmarked,
      onTap: isLoading
          ? null
          : (isLiked) async {
              await ref.toggleBookmarkTarget(post, booruConfig, context);
              return Future.value(!isLiked);
            },
      likeBuilder: (isLiked) {
        return Icon(
          isLiked ? Symbols.bookmark : Symbols.bookmark,
          color: isLiked
              ? context.colors.upvoteColor
              : context.extendedColorScheme.onSurfaceContainerOverlay,
          fill: isLiked ? 1 : 0,
        );
      },
    );
  }
}

extension BookmarkPostX on WidgetRef {
  void toggleBookmark(Post post) {
    final booruConfig = readConfigAuth;
    read(bookmarkProvider).whenOrNull(
      data: (bookmarkState) {
        final isBookmarked = bookmarkState.isBookmarked(
          post,
          booruConfig.booruIdHint,
        );

        if (isBookmarked) {
          bookmarks.removeBookmarkWithToast(
            BookmarkUniqueId.fromPost(post, booruConfig.booruIdHint),
          );
        } else {
          bookmarks.addBookmarkWithToast(
            booruConfig,
            post,
          );
        }
      },
    );
  }

  Future<void> toggleBookmarkTarget(
    Post post,
    BooruConfigAuth config,
    BuildContext context,
  ) async {
    final library = read(bookmarkProvider).valueOrNull;
    if (library == null) return;
    final uniqueId = BookmarkUniqueId.fromPost(post, config.booruIdHint);
    final bookmark = library.bookmarksByUniqueId[uniqueId];
    final groupId = library.activeTarget.groupId;
    if (groupId == null) {
      if (bookmark != null && library.membershipsFor(uniqueId).isEmpty) {
        return bookmarks.removeBookmark(
          bookmark,
          onSuccess: () => Kurumi.showSuccessToast(
            context,
            context.t.bookmark.removed,
          ),
          onError: () => Kurumi.showErrorToast(
            context,
            context.t.bookmark.failed_to_remove,
          ),
        );
      }
      return bookmarks.addBookmarkWithToast(config, post);
    }
    if (bookmark != null &&
        library.membershipsFor(uniqueId).contains(groupId)) {
      return bookmarks.removeFromGroup(
        [bookmark],
        groupId,
        deleteWhenMembershipBecomesEmpty: true,
        onSuccess: () => Kurumi.showSuccessToast(
          context,
          context.t.bookmark.removed,
        ),
        onError: () => Kurumi.showErrorToast(
          context,
          context.t.bookmark.groups.failed_to_remove_from_group,
        ),
      );
    }
    if (bookmark != null) {
      return bookmarks.addExistingBookmarkToGroup(
        bookmark,
        groupId,
        onSuccess: () => Kurumi.showSuccessToast(
          context,
          context.t.bookmark.added,
        ),
        onError: () => Kurumi.showErrorToast(
          context,
          context.t.bookmark.groups.failed_to_add_to_group,
        ),
      );
    }
    return bookmarks.addBookmarkToGroup(
      config,
      post,
      groupId,
      onSuccess: () => Kurumi.showSuccessToast(
        context,
        context.t.bookmark.added,
      ),
      onError: () => Kurumi.showErrorToast(
        context,
        context.t.bookmark.groups.failed_to_add_to_group,
      ),
    );
  }
}

class BookmarkWithDropdownIconPainter extends CustomPainter {
  const BookmarkWithDropdownIconPainter({
    required this.color,
    required this.fill,
  });

  final Color color;
  final bool fill;

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    const centerX = 9.0;
    final bookmarkPaint = Paint()
      ..color = color
      ..style = fill ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(centerX - 6.5, centerY - 9)
      ..lineTo(centerX + 6.5, centerY - 9)
      ..lineTo(centerX + 6.5, centerY + 9)
      ..lineTo(centerX, centerY + 5)
      ..lineTo(centerX - 6.5, centerY + 9)
      ..close();
    canvas.drawPath(path, bookmarkPaint);
    final arrowPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawLine(const Offset(22, 10), const Offset(26, 14), arrowPaint)
      ..drawLine(const Offset(30, 10), const Offset(26, 14), arrowPaint);
  }

  @override
  bool shouldRepaint(covariant BookmarkWithDropdownIconPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.fill != fill;
}
