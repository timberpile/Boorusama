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
    final bookmark = library?.bookmarksByUniqueId[uniqueId];
    final memberships = library?.membershipsFor(uniqueId) ?? const <String>{};
    final activeGroupId = library?.activeTarget.groupId;
    final isBookmarked = activeGroupId == null
        ? bookmark != null && memberships.isEmpty
        : memberships.contains(activeGroupId);
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
                  : () => ref.toggleBookmarkTarget(post, config),
              icon: Badge(
                isLabelVisible: memberships.isNotEmpty,
                label: Text('${memberships.length}'),
                child: Icon(
                  Symbols.bookmark,
                  fill: isBookmarked ? 1 : 0,
                  color: isBookmarked ? context.colors.upvoteColor : null,
                ),
              ),
            ),
            if (activeGroupId != null)
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
              await ref.toggleBookmarkTarget(post, booruConfig);
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
  ) async {
    final library = read(bookmarkProvider).valueOrNull;
    if (library == null) return;
    final uniqueId = BookmarkUniqueId.fromPost(post, config.booruIdHint);
    final bookmark = library.bookmarksByUniqueId[uniqueId];
    final groupId = library.activeTarget.groupId;
    if (groupId == null) {
      if (bookmark != null && library.membershipsFor(uniqueId).isEmpty) {
        return bookmarks.removeBookmark(bookmark);
      }
      return bookmarks.addBookmark(config, post);
    }
    if (bookmark != null &&
        library.membershipsFor(uniqueId).contains(groupId)) {
      return bookmarks.removeFromGroup(
        [bookmark],
        groupId,
        deleteWhenMembershipBecomesEmpty: true,
      );
    }
    if (bookmark != null) {
      return bookmarks.addExistingBookmarkToGroup(bookmark, groupId);
    }
    return bookmarks.addBookmarkToGroup(config, post, groupId);
  }
}
