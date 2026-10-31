import '../../../../boorus/engine/providers.dart';
import '../../../../configs/manage/widgets.dart';
import 'post_grid_item.dart';
import '../../../../configs/manage/providers.dart';
import '../../../../configs/config/types.dart';
import '../../../../bookmarks/src/data/bookmark_convert.dart';
import '../../../../bookmarks/src/providers/bookmark_button_state_provider.dart';
import '../types/post_action_snapshot.dart';
import 'post_actions.dart';
import '../types/post_search_actions.dart';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';
import 'package:kurumi/kurumi.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:selection_mode/selection_mode.dart';

// Project imports:
import '../../../../../../core/widgets/widgets.dart';
import '../../../../bookmarks/widgets.dart';
import '../../../../configs/config/providers.dart';
import '../../../post/types.dart';
import 'post_grid_controller.dart';

class DefaultMultiSelectionActions<T extends Post> extends ConsumerWidget {
  const DefaultMultiSelectionActions({
    required this.postController,
    super.key,
    this.extraActions,
    this.onBulkDownload,
    this.bookmark = true,
  });

  final PostGridController<T> postController;
  final bool bookmark;
  final Future<void> Function(List<T> selectedPosts)? onBulkDownload;
  final List<Widget> Function(List<T> selectedPosts)? extraActions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = SelectionMode.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([controller, postController]),
      builder: (context, _) {
        final selectedPosts = List<T>.unmodifiable(
          postController.refreshing
              ? <T>[]
              : controller.selectedFrom(postController.items.toList()).toList(),
        );
        if (selectedPosts.isEmpty) return const SizedBox.shrink();
        final snapshot = PostActionSnapshot(
          selectedPosts,
          ref.watch(booruConfigProvider),
        );
        final actions = _PostActionsBar(
          snapshot: snapshot,
          bookmark: bookmark,
          onBulkDownload: onBulkDownload == null
              ? null
              : () => onBulkDownload!(selectedPosts),
          extraActions: extraActions?.call(selectedPosts) ?? const [],
        );
        final config = snapshot.commonConfig;
        return config == null
            ? actions
            : CurrentBooruConfigScope(config: config, child: actions);
      },
    );
  }
}

class _PostActionsBar extends ConsumerWidget {
  const _PostActionsBar({
    required this.snapshot,
    required this.bookmark,
    required this.extraActions,
    this.onBulkDownload,
  });
  final PostActionSnapshot snapshot;
  final bool bookmark;
  final List<Widget> extraActions;
  final Future<void> Function()? onBulkDownload;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = postActionDefinitions(
      context,
      ref,
      snapshot,
      downloadOverride: snapshot.isSingle ? null : onBulkDownload,
    );
    final singlePost = snapshot.isSingle ? snapshot.posts.single : null;
    // An unresolved stored post may still be bookmarked locally, but must not
    // inherit credentials from whichever unrelated Browse account is active.
    final bookmarkAuth = snapshot.commonConfig?.auth ?? BooruConfig.empty.auth;
    final bookmarkState =
        singlePost == null || !bookmark || !snapshot.canBookmark
        ? null
        : ref.watch(
            bookmarkButtonStateProvider(
              bookmarkIdentityForPost(singlePost, bookmarkAuth.booruIdHint),
            ),
          );
    final bookmarkPresentation = bookmarkState?.presentation;
    final membershipCount = bookmarkPresentation?.namedGroupCount ?? 0;
    VoidCallback? showBookmarkPicker;
    final searchActions = PostSearchActionsScope.maybeOf(context);
    final presentation = singlePost == null
        ? null
        : ref.watch(
            booruPostPresentationProvider(
              PostPresentationRequest(
                origin: singlePost.origin,
                data: singlePost.booruData,
              ),
            ),
          );
    return MultiSelectionActionBar(
      children: [
        for (final action in actions.where(
          (a) =>
              a.id == PostActionId.download ||
              a.id == PostActionId.favorite ||
              a.id == PostActionId.unfavorite,
        ))
          MultiSelectButton(
            primary: true,
            name: action.label,
            icon: Icon(action.icon),
            onPressed: action.enabled ? () => action.execute() : null,
          ),
        if (bookmark && snapshot.canBookmark)
          if (singlePost != null)
            MultiSelectButton(
              key: const Key('selection-single-bookmark'),
              decorate: (context, child) => BookmarkGroupPickerAnchor(
                key: ValueKey((singlePost.origin, singlePost.id, bookmarkAuth)),
                config: bookmarkAuth,
                post: singlePost,
                builder: (context, showPicker) {
                  showBookmarkPicker = showPicker;
                  return child;
                },
              ),
              primary: true,
              name: context.t.post.action.bookmark,
              icon: Badge(
                isLabelVisible: membershipCount > 1,
                label: Text('$membershipCount'),
                child: Icon(
                  Symbols.bookmark,
                  fill: (bookmarkPresentation?.isBookmarked ?? false) ? 1 : 0,
                ),
              ),
              onPressed: bookmarkState?.isLoading == true
                  ? null
                  : () {
                      if (!snapshot.accountsMatch(
                        ref.read(booruConfigProvider),
                      )) {
                        Kurumi.showErrorToast(
                          context,
                          context.t.post.action.operation_failed,
                        );
                        return;
                      }
                      showBookmarkPicker?.call();
                    },
            )
          else
            MultiSelectPopupButton(
              key: const Key('selection-batch-bookmarks'),
              name: context.t.post.action.bookmark,
              enabled: true,
              icon: const Icon(Symbols.bookmark_add),
              items: [
                BookmarkMultiSelectionMenu(
                  posts: snapshot.posts,
                  config: ref.watchConfigAuth,
                  onCompleted: () async {},
                ),
              ],
            ),
        for (final action in actions.where(
          (a) =>
              a.id != PostActionId.download &&
              a.id != PostActionId.favorite &&
              a.id != PostActionId.unfavorite,
        ))
          MultiSelectButton(
            menuOnly: !(snapshot.isSingle && action.id == PostActionId.share),
            name: action.label,
            icon: Icon(action.icon),
            onPressed: action.enabled ? () => action.execute() : null,
          ),
        if (singlePost != null &&
            searchActions != null &&
            searchActions.availableFor(singlePost, snapshot.commonConfig?.id))
          MultiSelectPopupButton(
            name: context.t.post.action.modify_search,
            wrapLabel: true,
            enabled: true,
            icon: const Icon(Icons.manage_search),
            items: [
              for (final direction in PostIdSearchDirection.values)
                KurumiPopupMenuItem(
                  title: Text(switch (direction) {
                    PostIdSearchDirection.fromHere =>
                      context.t.post.action.posts_from_here,
                    PostIdSearchDirection.untilHere =>
                      context.t.post.action.posts_until_here,
                  }),
                  onTap: () {
                    final selection = SelectionMode.of(context);
                    final feedback = Navigator.of(
                      context,
                      rootNavigator: true,
                    ).context;
                    if (searchActions.apply(singlePost, direction)) {
                      selection.disable();
                    } else if (feedback.mounted) {
                      Kurumi.showErrorToast(
                        feedback,
                        context.t.post.action.operation_failed,
                      );
                    }
                  },
                ),
            ],
          ),
        ...extraActions,
        if (singlePost != null &&
            presentation is BooruPostSingleActionsPresentation &&
            presentation!.supports(singlePost.booruData))
          ...(presentation as BooruPostSingleActionsPresentation)
              .buildSingleSelectionActions(context, ref: ref, post: singlePost),
      ],
    );
  }
}
