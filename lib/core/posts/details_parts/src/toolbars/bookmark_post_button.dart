// Dart imports:
import 'dart:async';

// Flutter imports:
import 'package:flutter/rendering.dart' show OverflowBoxFit;

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:like_button/like_button.dart';
import 'package:material_symbols_icons/symbols.dart';

// Project imports:
import '../../../../bookmarks/providers.dart';
import '../../../../bookmarks/src/data/bookmark_convert.dart';
import '../../../../bookmarks/src/widgets/bookmark_group_label.dart';
import '../../../../bookmarks/widgets.dart';
import '../../../../configs/config/providers.dart';
import '../../../../configs/config/types.dart';
import '../../../../router.dart';
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
    final uniqueId = bookmarkIdentityForPost(post, config.booruIdHint);
    final presentation = library == null
        ? null
        : selectBookmarkMembershipPresentation(library, uniqueId);
    final activeGroupId = library?.activeTarget.groupId;
    final isBookmarked = presentation?.isInActiveTarget ?? false;
    final groupLabels = library == null
        ? const <String, String>{}
        : bookmarkGroupLabels(library.groups);
    final activeLabel = activeGroupId == null
        ? context.t.bookmark.groups.ungrouped
        : groupLabels[activeGroupId] ?? context.t.bookmark.groups.ungrouped;
    final isLoading = bookmarkStateAsync.isLoading;
    final actionLabel = isBookmarked
        ? context.t.bookmark.groups.remove_from(name: activeLabel)
        : context.t.bookmark.groups.add_to(name: activeLabel);

    return KurumiTooltip(
      message: actionLabel,
      padding: const EdgeInsets.all(8),
      child: GestureDetector(
        onLongPressStart: isLoading
            ? null
            : (details) => showAnchoredBookmarkGroupPicker(
                context,
                config: config,
                post: post,
                position: details.globalPosition,
              ),
        child: Column(
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
            OverflowBox(
              fit: OverflowBoxFit.deferToChild,
              minWidth: 112,
              maxWidth: 112,
              child: Text(
                activeLabel,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Kurumi.themeOf(context).textTheme.labelSmall,
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
    final uniqueId = bookmarkIdentityForPost(post, booruConfig.booruIdHint);
    final bookmark = library?.bookmarksByUniqueId[uniqueId];
    final groupId = library?.activeTarget.groupId;
    final memberships = library?.membershipsFor(uniqueId) ?? const <String>{};
    final isBookmarked = groupId == null
        ? bookmark != null && memberships.isEmpty
        : memberships.contains(groupId);
    final showCount =
        memberships.isNotEmpty &&
        (groupId == null ||
            !memberships.contains(groupId) ||
            memberships.length > 1);
    final isLoading = bookmarkStateAsync.isLoading;

    return GestureDetector(
      onLongPressStart: isLoading
          ? null
          : (details) => showAnchoredBookmarkGroupPicker(
              context,
              config: booruConfig,
              post: post,
              position: details.globalPosition,
            ),
      child: LikeButton(
        isLiked: isBookmarked,
        onTap: isLoading
            ? null
            : (isLiked) async {
                final outcome = await ref.toggleBookmarkTarget(
                  post,
                  booruConfig,
                  context,
                );
                return switch (outcome) {
                  BookmarkToggleOutcome.added => true,
                  BookmarkToggleOutcome.removed => false,
                  _ => isLiked,
                };
              },
        likeBuilder: (isLiked) => Badge(
          isLabelVisible: showCount,
          label: Text('${memberships.length}'),
          child: Icon(
            Symbols.bookmark,
            color: isLiked
                ? context.colors.upvoteColor
                : context.extendedColorScheme.onSurfaceContainerOverlay,
            fill: isLiked ? 1 : 0,
          ),
        ),
      ),
    );
  }
}

extension BookmarkPostX on WidgetRef {
  void toggleBookmark(Post post) {
    final booruConfig = readConfigAuth;
    final context = navigatorKey.currentContext;
    if (context != null && context.mounted) {
      unawaited(toggleBookmarkTarget(post, booruConfig, context));
    }
  }

  Future<BookmarkToggleOutcome> toggleBookmarkTarget(
    Post post,
    BooruConfigAuth config,
    BuildContext context,
  ) async {
    final outcome = await read(bookmarkProvider.notifier).togglePostTarget(
      config,
      post,
    );
    if (!context.mounted) return outcome;
    switch (outcome) {
      case BookmarkToggleOutcome.added:
        Kurumi.showSuccessToast(context, context.t.bookmark.added);
      case BookmarkToggleOutcome.removed:
        Kurumi.showSuccessToast(context, context.t.bookmark.removed);
      case BookmarkToggleOutcome.unavailable:
        await showBookmarkGroupPicker(context, config: config, post: post);
      case BookmarkToggleOutcome.failed:
        Kurumi.showErrorToast(context, context.t.bookmark.failed_to_add);
    }
    return outcome;
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
