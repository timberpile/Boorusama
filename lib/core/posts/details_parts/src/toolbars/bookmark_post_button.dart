// Dart imports:
import 'dart:math';

// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

// Project imports:
import '../../../../bookmarks/providers.dart';
import '../../../../bookmarks/types.dart';
import '../../../../bookmarks/src/widgets/bookmark_active_target_badge.dart';
import '../../../../bookmarks/src/widgets/bookmark_group_name_dialog.dart';
import '../../../../configs/config/providers.dart';
import '../../../../configs/config/types.dart';
import '../../../../themes/theme/types.dart';
import '../../../post/types.dart';

class BookmarkPostButton extends StatelessWidget {
  const BookmarkPostButton({
    required this.post,
    required this.config,
    super.key,
  });

  final Post post;
  final BooruConfigAuth config;

  @override
  Widget build(BuildContext context) => BookmarkGroupToggleButton(
    post: post,
    config: config,
  );
}

class BookmarkPostLikeButtonButton extends ConsumerWidget {
  const BookmarkPostLikeButtonButton({
    required this.post,
    super.key,
  });

  final Post post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BookmarkGroupToggleButton(
      post: post,
      config: ref.watchConfigAuth,
      small: true,
    );
  }
}

class BookmarkGroupToggleButton extends ConsumerStatefulWidget {
  const BookmarkGroupToggleButton({
    required this.post,
    required this.config,
    super.key,
    this.small = false,
  });

  final Post post;
  final BooruConfigAuth config;
  final bool small;

  @override
  ConsumerState<BookmarkGroupToggleButton> createState() =>
      _BookmarkGroupToggleButtonState();
}

class _BookmarkGroupToggleButtonState
    extends ConsumerState<BookmarkGroupToggleButton> {
  final _controller = AnchorController();
  NavigatorState? _pendingCreateNavigator;

  Post get post => widget.post;
  BooruConfigAuth get config => widget.config;
  bool get small => widget.small;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final bookmarkStateAsync = ref.watch(bookmarkProvider);
    final state = bookmarkStateAsync.valueOrNull;
    final groups = ref.watch(bookmarkGroupsProvider).valueOrNull ?? const [];
    final target = ref.watch(effectiveActiveBookmarkGroupIdProvider);
    final bookmarkId = BookmarkUniqueId.fromPost(post, config.booruIdHint);
    final isBookmarked = state?.bookmarks.contains(bookmarkId) ?? false;
    final groupIds = state?.memberships[bookmarkId] ?? const <int>{};
    final inTarget = target == kUngroupedBookmarkGroupId
        ? isBookmarked && groupIds.isEmpty
        : groupIds.contains(target);
    final isGroupedBookmark = isBookmarked && groupIds.isNotEmpty;
    final targetUnavailable =
        target == kUngroupedBookmarkGroupId && isGroupedBookmark;
    final namedGroupCount = groupIds.length;
    final showCount =
        namedGroupCount > 0 &&
        (target == kUngroupedBookmarkGroupId ||
            !groupIds.contains(target) ||
            namedGroupCount > 1);
    final targetName = _targetName(context, target, groups);
    final tooltip = targetUnavailable
        ? context.t.bookmark.groups.selector
        : inTarget
        ? context.t.bookmark.groups.remove_from_target(target: targetName)
        : context.t.bookmark.groups.add_to_target(target: targetName);

    Future<void> onTap() async {
      if (bookmarkStateAsync.isLoading) return;

      if (targetUnavailable) {
        _controller.show();
        return;
      }

      if (target == kUngroupedBookmarkGroupId) {
        if (!isBookmarked) {
          await ref.bookmarks.addBookmarkWithToast(config, post);
        } else if (groupIds.isEmpty) {
          await ref.bookmarks.deleteBookmarkWithToast(bookmarkId);
        } else {
          Kurumi.showErrorToast(
            context,
            context.t.bookmark.groups.grouped_remove_warning,
          );
        }
        return;
      }

      if (inTarget) {
        await ref.bookmarks.removeFromGroupAndDeleteIfLast(
          bookmarkId,
          target,
          onSuccess: () {
            if (context.mounted) {
              Kurumi.showSuccessToast(context, context.t.bookmark.removed);
            }
          },
          onError: () => Kurumi.showErrorToast(
            context,
            context.t.bookmark.groups.failed_to_remove_from_group,
          ),
        );
      } else if (isBookmarked) {
        await ref.bookmarks.addBookmarkIdToGroup(
          bookmarkId,
          target,
          onSuccess: () {
            if (context.mounted) {
              Kurumi.showSuccessToast(context, context.t.bookmark.added);
            }
          },
          onError: () => Kurumi.showErrorToast(
            context,
            context.t.bookmark.groups.failed_to_add_to_group,
          ),
        );
      } else {
        await ref.bookmarks.addBookmarkToGroup(
          config,
          post,
          target,
          onSuccess: () {
            if (context.mounted) {
              Kurumi.showSuccessToast(context, context.t.bookmark.added);
            }
          },
          onError: () => Kurumi.showErrorToast(
            context,
            context.t.bookmark.groups.failed_to_add_to_group,
          ),
        );
      }
    }

    void onLongPress() => _controller.show();

    final iconColor = inTarget
        ? context.colors.upvoteColor
        : context.extendedColorScheme.onSurfaceContainerOverlay;
    final iconWidth = small ? 32.0 : 48.0;
    final bookmarkCenterX = small ? 8.0 : 16.0;
    final iconCanvas = SizedBox(
      width: iconWidth,
      height: 24,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: BookmarkWithDropdownIconPainter(
                color: iconColor,
                fill: inTarget,
                bookmarkCenterX: bookmarkCenterX,
              ),
            ),
          ),
          if (showCount)
            Positioned(
              left: bookmarkCenterX + 4,
              top: -6,
              child: _GroupCountBadge(count: namedGroupCount),
            ),
        ],
      ),
    );
    final icon = small
        ? iconCanvas
        : SizedBox(
            width: 48,
            height: 48,
            child: Center(child: iconCanvas),
          );

    final button = small
        ? Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              onLongPress: onLongPress,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: icon,
              ),
            ),
          )
        : LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.hasBoundedWidth
                  ? constraints.maxWidth
                  : 72.0;
              final bookmarkGlyphCenter = width - 21.5 < 32
                  ? width - 21.5
                  : 32.0;
              final iconLeft = bookmarkGlyphCenter - 16;

              return SizedBox(
                width: width,
                height: 48,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      top: 0,
                      left: iconLeft,
                      width: 48,
                      height: 48,
                      child: IconButton(
                        iconSize: 48,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                          width: 48,
                          height: 48,
                        ),
                        splashRadius: 16,
                        onPressed: onTap,
                        onLongPress: onLongPress,
                        icon: icon,
                      ),
                    ),
                    Positioned(
                      top: 36,
                      left: bookmarkGlyphCenter - 32,
                      width: 64,
                      height: 12,
                      child: IgnorePointer(
                        child: Text(
                          targetName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                fontSize:
                                    (Theme.of(
                                          context,
                                        ).textTheme.labelSmall?.fontSize ??
                                        11) *
                                    0.7,
                              ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );

    final buttonWithTooltip = KurumiTooltip(
      message: tooltip,
      padding: const EdgeInsets.all(8),
      child: button,
    );

    return KurumiAnchor(
      controller: _controller,
      onHide: _handlePopupHide,
      overlayBuilder: (overlayContext) => Consumer(
        builder: (popupContext, popupRef, child) {
          final popupState = popupRef.watch(bookmarkProvider).valueOrNull;
          final popupGroups =
              popupRef.watch(bookmarkGroupsProvider).valueOrNull ?? const [];
          final popupTarget = popupRef.watch(
            effectiveActiveBookmarkGroupIdProvider,
          );
          final popupBookmarkId = BookmarkUniqueId.fromPost(
            post,
            config.booruIdHint,
          );
          final popupIsBookmarked =
              popupState?.bookmarks.contains(popupBookmarkId) ?? false;
          final popupGroupIds =
              popupState?.memberships[popupBookmarkId] ?? const <int>{};

          return _buildGroupPickerPopup(
            popupContext,
            popupRef,
            groups: popupGroups,
            target: popupTarget,
            isBookmarked: popupIsBookmarked,
            groupIds: popupGroupIds,
          );
        },
      ),
      child: buttonWithTooltip,
    );
  }

  Widget _buildGroupPickerPopup(
    BuildContext context,
    WidgetRef ref, {
    required List<BookmarkGroup> groups,
    required int target,
    required bool isBookmarked,
    required Set<int> groupIds,
  }) {
    final isGroupedBookmark = isBookmarked && groupIds.isNotEmpty;
    final navigator = Navigator.of(context, rootNavigator: true);
    final items = <Widget>[];

    if (!isGroupedBookmark) {
      items.add(
        KurumiPopupMenuItem(
          icon: Icon(
            Symbols.bookmark,
            fill: isBookmarked && groupIds.isEmpty ? 1 : 0,
          ),
          title: Text(context.t.bookmark.groups.ungrouped),
          trailing: target == kUngroupedBookmarkGroupId
              ? const BookmarkActiveTargetBadge()
              : null,
          onTap: () => _applyTarget(
            navigator.context,
            ref,
            kUngroupedBookmarkGroupId,
            isBookmarked: isBookmarked,
            groupIds: groupIds,
          ),
        ),
      );
    }

    items.addAll(
      groups.map(
        (group) => KurumiPopupMenuItem(
          icon: Icon(
            Symbols.bookmarks,
            fill: groupIds.contains(group.id) ? 1 : 0,
          ),
          title: Text(
            group.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: group.id == target
              ? const BookmarkActiveTargetBadge()
              : null,
          onTap: () => _applyTarget(
            navigator.context,
            ref,
            group.id,
            isBookmarked: isBookmarked,
            groupIds: groupIds,
          ),
        ),
      ),
    );

    items.add(const Divider());
    items.add(
      KurumiPopupMenuItem(
        icon: const Icon(Symbols.create_new_folder),
        title: Text(context.t.bookmark.groups.create_new),
        onTap: () {
          _pendingCreateNavigator = navigator;
        },
      ),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      constraints: BoxConstraints(
        maxWidth: min(MediaQuery.widthOf(context), 240),
        maxHeight: MediaQuery.heightOf(context) * 0.6,
      ),
      child: ListView(
        shrinkWrap: true,
        children: items,
      ),
    );
  }

  void _handlePopupHide() {
    final navigator = _pendingCreateNavigator;
    _pendingCreateNavigator = null;
    if (navigator?.mounted ?? false) {
      _createGroupAndAdd(navigator!.context, ref);
    }
  }

  Future<void> _applyTarget(
    BuildContext context,
    WidgetRef ref,
    int groupId, {
    required bool isBookmarked,
    required Set<int> groupIds,
  }) async {
    await setActiveBookmarkGroupId(ref, groupId);
    final bookmarkId = BookmarkUniqueId.fromPost(post, config.booruIdHint);

    if (groupId == kUngroupedBookmarkGroupId) {
      if (isBookmarked && groupIds.isNotEmpty) return;

      if (!isBookmarked) {
        await ref.bookmarks.addBookmarkWithToast(config, post);
      } else if (groupIds.isEmpty) {
        await ref.bookmarks.deleteBookmarkWithToast(bookmarkId);
      } else {
        if (!context.mounted) return;
        Kurumi.showErrorToast(
          context,
          context.t.bookmark.groups.grouped_remove_warning,
        );
      }
      return;
    }

    if (groupIds.contains(groupId)) {
      await ref.bookmarks.removeFromGroupAndDeleteIfLast(
        bookmarkId,
        groupId,
        onSuccess: () {
          if (context.mounted) {
            Kurumi.showSuccessToast(context, context.t.bookmark.removed);
          }
        },
      );
    } else if (isBookmarked) {
      await ref.bookmarks.addBookmarkIdToGroup(
        bookmarkId,
        groupId,
        onSuccess: () {
          if (context.mounted) {
            Kurumi.showSuccessToast(context, context.t.bookmark.added);
          }
        },
      );
    } else {
      await ref.bookmarks.addBookmarkToGroup(
        config,
        post,
        groupId,
        onSuccess: () {
          if (context.mounted) {
            Kurumi.showSuccessToast(context, context.t.bookmark.added);
          }
        },
      );
    }
  }

  Future<void> _createGroupAndAdd(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final name = await showBookmarkGroupNameDialog(
      context,
      title: context.t.bookmark.groups.create,
      saveLabel: context.t.generic.action.create,
      cancelLabel: context.t.generic.action.cancel,
      hintText: context.t.bookmark.groups.name,
    );
    if (name == null) return;

    try {
      final group = await (await ref.read(
        bookmarkGroupRepoProvider.future,
      )).createGroup(name);
      await setActiveBookmarkGroupId(ref, group.id);
      await ref.bookmarks.addBookmarkToGroup(
        config,
        post,
        group.id,
        onSuccess: () {
          if (context.mounted) {
            Kurumi.showSuccessToast(context, context.t.bookmark.added);
          }
        },
      );
      refreshBookmarkGroupProviders(ref);
    } catch (error) {
      if (context.mounted) Kurumi.showErrorToast(context, error.toString());
    }
  }

  String _targetName(
    BuildContext context,
    int target,
    List<BookmarkGroup> groups,
  ) {
    if (target == kUngroupedBookmarkGroupId) {
      return context.t.bookmark.groups.ungrouped;
    }
    for (final group in groups) {
      if (group.id == target) return group.name;
    }
    return context.t.bookmark.groups.ungrouped;
  }
}

class BookmarkWithDropdownIconPainter extends CustomPainter {
  const BookmarkWithDropdownIconPainter({
    required this.color,
    required this.fill,
    required this.bookmarkCenterX,
  });

  final Color color;
  final bool fill;
  final double bookmarkCenterX;

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;

    const iconHalfWidth = 6.5;
    const iconCenterGap = 5.0;
    const chevronWidth = 10.0;
    final iconCenterX = bookmarkCenterX;

    final bookmarkPaint = Paint()
      ..color = color
      ..style = fill ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final bookmarkPath = Path()
      ..moveTo(iconCenterX - iconHalfWidth, centerY - 9)
      ..lineTo(iconCenterX + iconHalfWidth, centerY - 9)
      ..lineTo(iconCenterX + iconHalfWidth, centerY + 9)
      ..lineTo(iconCenterX, centerY + 5)
      ..lineTo(iconCenterX - iconHalfWidth, centerY + 9)
      ..close();
    canvas.drawPath(bookmarkPath, bookmarkPaint);

    final dropdownPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.75
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final chevronX =
        iconCenterX + iconHalfWidth + iconCenterGap + (chevronWidth / 2);
    const chevronHalfWidth = 4.0;
    const chevronHeight = 2.0;
    canvas
      ..drawLine(
        Offset(chevronX - chevronHalfWidth, centerY - chevronHeight),
        Offset(chevronX, centerY + chevronHeight),
        dropdownPaint,
      )
      ..drawLine(
        Offset(chevronX + chevronHalfWidth, centerY - chevronHeight),
        Offset(chevronX, centerY + chevronHeight),
        dropdownPaint,
      );
  }

  @override
  bool shouldRepaint(covariant BookmarkWithDropdownIconPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.fill != fill ||
      oldDelegate.bookmarkCenterX != bookmarkCenterX;
}

class _GroupCountBadge extends StatelessWidget {
  const _GroupCountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
      padding: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$count',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onPrimary,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

extension BookmarkPostX on WidgetRef {
  void toggleBookmark(Post post) {
    final booruConfig = readConfigAuth;
    final context = this.context;
    read(bookmarkProvider).whenOrNull(
      data: (bookmarkState) {
        final bookmarkId = BookmarkUniqueId.fromPost(
          post,
          booruConfig.booruIdHint,
        );
        final target = read(effectiveActiveBookmarkGroupIdProvider);
        final groupIds = bookmarkState.groupIdsFor(
          post,
          booruConfig.booruIdHint,
        );
        final isBookmarked = bookmarkState.isBookmarked(
          post,
          booruConfig.booruIdHint,
        );

        if (target == kUngroupedBookmarkGroupId) {
          if (!isBookmarked) {
            bookmarks.addBookmarkWithToast(booruConfig, post);
          } else if (groupIds.isEmpty) {
            bookmarks.deleteBookmarkWithToast(bookmarkId);
          }
        } else if (groupIds.contains(target)) {
          bookmarks.removeFromGroupAndDeleteIfLast(
            bookmarkId,
            target,
            onSuccess: () {
              if (context.mounted) {
                Kurumi.showSuccessToast(context, context.t.bookmark.removed);
              }
            },
          );
        } else if (isBookmarked) {
          bookmarks.addBookmarkIdToGroup(
            bookmarkId,
            target,
            onSuccess: () {
              if (context.mounted) {
                Kurumi.showSuccessToast(context, context.t.bookmark.added);
              }
            },
          );
        } else {
          bookmarks.addBookmarkToGroup(
            booruConfig,
            post,
            target,
            onSuccess: () {
              if (context.mounted) {
                Kurumi.showSuccessToast(context, context.t.bookmark.added);
              }
            },
          );
        }
      },
    );
  }
}
