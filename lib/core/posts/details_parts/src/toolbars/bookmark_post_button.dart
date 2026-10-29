// Dart imports:
import 'dart:async';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

// Project imports:
import '../../../../bookmarks/src/data/bookmark_convert.dart';
import '../../../../bookmarks/src/providers/bookmark_button_state_provider.dart';
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
    this.menuItem = false,
    super.key,
  });

  final Post post;
  final BooruConfigAuth config;
  final bool menuItem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uniqueId = bookmarkIdentityForPost(post, config.booruIdHint);
    final state = ref.watch(bookmarkButtonStateProvider(uniqueId));
    final presentation = state.presentation;
    final isBookmarked = presentation?.isBookmarked ?? false;
    if (menuItem) {
      return KurumiPopupMenuItem(
        title: Text(context.t.bookmark.groups.selector),
        icon: Icon(
          Symbols.bookmark,
          color: isBookmarked ? context.colors.upvoteColor : null,
          fill: isBookmarked ? 1 : 0,
        ),
        onTap: state.isLoading ? null : () => showBookmarkGroupPicker(
          context,
          config: config,
          post: post,
        ),
      );
    }
    return BookmarkGroupPickerAnchor(
      config: config,
      post: post,
      builder: (context, showPicker) => IconButton(
        tooltip: context.t.bookmark.groups.selector,
        splashRadius: 16,
        onPressed: state.isLoading ? null : showPicker,
        icon: Semantics(
          label: context.t.bookmark.groups.selector,
          value: (presentation?.namedGroupCount ?? 0) > 1
              ? '${presentation!.namedGroupCount}'
              : null,
          excludeSemantics: true,
          child: Badge(
            isLabelVisible: (presentation?.namedGroupCount ?? 0) > 1,
            label: Text('${presentation?.namedGroupCount ?? 0}'),
            child: Icon(
              Symbols.bookmark,
              color: isBookmarked ? context.colors.upvoteColor : null,
              fill: isBookmarked ? 1 : 0,
            ),
          ),
        ),
      ),
    );
  }
}

class BookmarkPostLikeButtonButton extends ConsumerWidget {
  const BookmarkPostLikeButtonButton({required this.post, super.key});
  final Post post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watchConfigAuth;
    final uniqueId = bookmarkIdentityForPost(post, config.booruIdHint);
    final state = ref.watch(bookmarkButtonStateProvider(uniqueId));
    final presentation = state.presentation;
    return BookmarkGroupPickerAnchor(
      config: config,
      post: post,
      builder: (context, showPicker) => GestureDetector(
        // Consume a held pointer instead of opening the picker on release.
        onLongPress: () {},
        excludeFromSemantics: true,
        child: KurumiTooltip(
          message: context.t.bookmark.groups.selector,
          child: KurumiLikeButton(
            isLiked: presentation?.isBookmarked ?? false,
            controlled: true,
            enabled: !state.isLoading,
            onTap: (_) async {
              showPicker();
              return null;
            },
            builder: (isLiked) => Semantics(
              label: context.t.bookmark.groups.selector,
              value: (presentation?.namedGroupCount ?? 0) > 1
                  ? '${presentation!.namedGroupCount}'
                  : null,
              excludeSemantics: true,
              child: Badge(
                isLabelVisible: (presentation?.namedGroupCount ?? 0) > 1,
                label: Text('${presentation?.namedGroupCount ?? 0}'),
                child: Icon(
                  Symbols.bookmark,
                  color: isLiked
                      ? context.colors.upvoteColor
                      : context.extendedColorScheme.onSurfaceContainerOverlay,
                  fill: isLiked ? 1 : 0,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

extension BookmarkPostX on WidgetRef {
  void toggleBookmark(Post post) {
    final booruConfig = readConfigAuth;
    final context = read(appNavigationProvider).navigatorKey.currentContext;
    if (context != null && context.mounted) {
      unawaited(
        showBookmarkGroupPicker(context, config: booruConfig, post: post),
      );
    }
  }
}
