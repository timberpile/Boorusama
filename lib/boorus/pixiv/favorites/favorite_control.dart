import 'dart:async';

import 'package:booru_clients/pixiv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

import '../../../core/configs/config/providers.dart';
import '../../../core/configs/config/types.dart';
import '../../../core/content/content_access_provider.dart';
import '../../../core/content/content_media_access.dart';
import '../../../core/content/types.dart';
import '../../../core/navigation/destination_activity.dart';
import '../../../core/posts/details/src/types/inherited_post.dart';
import '../../../core/posts/details/src/types/post_details.dart';
import '../../../core/posts/details/src/widgets/post_details_page_view_scope.dart';
import '../../../core/posts/details_parts/src/toolbars/simple_post_action_toolbar.dart';
import '../../../core/posts/details_parts/src/toolbars/customizable_post_toolbar.dart';
import '../../../core/posts/favorites/src/widgets/favorite_action.dart';
import '../../../core/posts/favorites/widgets.dart';
import '../../../core/widgets/adaptive_button_row.dart';
import '../posts/types.dart';
import 'favorite_state.dart';

class PixivFavoriteControl extends ConsumerStatefulWidget {
  const PixivFavoriteControl({
    required this.illustId,
    this.access,
    this.compact = false,
    this.restricted = false,
    this.isOwnerCurrent,
    this.builder,
    super.key,
  });

  final int illustId;
  final ContentAccessContext? access;
  final bool compact;
  final bool restricted;
  final bool Function()? isOwnerCurrent;
  final Widget Function(BuildContext context, List<ButtonData> actions)?
  builder;

  @override
  ConsumerState<PixivFavoriteControl> createState() =>
      _PixivFavoriteControlState();
}

class _PixivFavoriteControlState extends ConsumerState<PixivFavoriteControl> {
  final _anchor = AnchorController();

  @override
  void dispose() {
    _anchor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watchConfig;
    final scopeKey = ref.watch(currentContentAccessKeyProvider);
    final explicitAccess = widget.access;
    final access =
        explicitAccess ??
        (scopeKey == null
            ? ref.watch(contentProfileAccessProvider(config.id))
            : ref.watch(contentAccessContextProvider(scopeKey)));
    final profileId = access?.key.profileId;
    final illustId = widget.illustId;
    final builder = widget.builder;
    if (profileId == null || illustId <= 0 || widget.restricted) {
      return builder?.call(context, const []) ?? const SizedBox.shrink();
    }

    final provider = pixivFavoriteStateProvider(profileId);
    final actor = ref.watch(provider.select((value) => value.actor));
    if (actor == null ||
        access!.key.authEpoch != actor.authEpoch ||
        access.config?.auth != actor.auth) {
      return builder?.call(context, const []) ?? const SizedBox.shrink();
    }
    final entry = ref.watch(provider.select((value) => value.entry(illustId)));
    final notifier = ref.watch(provider.notifier);
    final route = ModalRoute.of(context);
    final active = NavigationActivity.of(context) && (route?.isCurrent ?? true);
    bool isCurrent() =>
        mounted &&
        widget.illustId == illustId &&
        !widget.restricted &&
        widget.access?.key == explicitAccess?.key &&
        (explicitAccess != null ||
            (ref.readConfig.id == profileId &&
                ref.readConfig.auth == actor.auth &&
                ref.read(currentContentAccessKeyProvider) == scopeKey)) &&
        NavigationActivity.of(context) &&
        (route?.isCurrent ?? true) &&
        ref.read(provider).actor == actor &&
        (ref
                .read(contentAccessContextProvider(access.key))
                ?.hasSameAuthorization(access) ??
            false);
    final isActionCurrent = widget.isOwnerCurrent ?? isCurrent;

    final detail = entry.detail;
    final needsLookup =
        detail == null ||
        (detail.isBookmarked &&
            detail.visibility == null &&
            !entry.visibilityChecked);
    if (active &&
        !widget.compact &&
        !entry.pending &&
        !entry.checkingStatus &&
        !entry.lookupFailed &&
        needsLookup) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (isCurrent()) {
          unawaited(
            runFavoriteAction(
              context,
              () => notifier.lookup(actor, illustId, isCurrent: isCurrent),
              isCurrent: isCurrent,
            ),
          );
        }
      });
    }

    final strings = context.t.pixiv.favorites;
    final visibility = context.t.pixiv.explore.follow_restrict;
    final isFaved =
        (widget.compact ? null : entry.pendingFavorite) ??
        detail?.isBookmarked ??
        entry.lastKnownFavorite;
    final favorited = isFaved ?? false;
    final knownVisibility = switch (detail?.visibility) {
      PixivBookmarkVisibility.public => visibility.public,
      PixivBookmarkVisibility.private => visibility.private,
      null => null,
    };
    final title = entry.lookupFailed
        ? strings.check_status
        : switch ((isFaved, knownVisibility)) {
            (true, final known?) => strings.with_visibility(
              action: context.t.post.action.unfavorite,
              visibility: known,
            ),
            (true, null) => context.t.post.action.unfavorite,
            _ => context.t.post.action.favorite,
          };
    final enabled = active && !entry.pending;
    final canChoose = enabled && !entry.lookupFailed && !favorited;
    final canInspectVisibility =
        enabled && !entry.lookupFailed && favorited && knownVisibility != null;
    Future<void> change(PixivBookmarkVisibility? value) => notifier.setFavorite(
      actor,
      illustId,
      addVisibility: value,
      isCurrent: isActionCurrent,
    );
    void choose(PixivBookmarkVisibility value) {
      if (isCurrent()) {
        unawaited(
          runFavoriteAction(
            context,
            () => change(value),
            isCurrent: isActionCurrent,
          ),
        );
      }
    }

    final icon = Icon(favorited ? Icons.favorite : Icons.favorite_border);
    final onLongPress = canChoose || canInspectVisibility ? _anchor.show : null;
    final retryStatus = entry.lookupFailed
        ? () => notifier.lookup(
            actor,
            illustId,
            isCurrent: isCurrent,
            retry: true,
          )
        : null;
    final trigger = FavoritePostButton(
      isFaved: isFaved,
      isAuthorized: true,
      enabled: enabled,
      tooltip: title,
      isCurrent: isActionCurrent,
      addFavorite: () => change(PixivBookmarkVisibility.public),
      removeFavorite: () => change(null),
      checkStatus:
          retryStatus ??
          (isFaved == null
              ? () => change(PixivBookmarkVisibility.public)
              : null),
      onLongPress: onLongPress,
    );
    final button = KurumiAnchor(
      controller: _anchor,
      constrainToViewport: true,
      overlayBuilder: (context) => Container(
        padding: const EdgeInsets.all(8),
        constraints: popupMenuViewportConstraints(context),
        child: SingleChildScrollView(
          primary: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (knownVisibility != null)
                KurumiPopupMenuItem(title: Text(knownVisibility), onTap: null)
              else ...[
                KurumiPopupMenuItem(
                  title: Text(strings.add_public),
                  onTap: canChoose
                      ? () => choose(PixivBookmarkVisibility.public)
                      : null,
                ),
                KurumiPopupMenuItem(
                  title: Text(strings.add_private),
                  onTap: canChoose
                      ? () => choose(PixivBookmarkVisibility.private)
                      : null,
                ),
              ],
            ],
          ),
        ),
      ),
      child: widget.compact
          ? KurumiTooltip(
              message: title,
              child: GestureDetector(
                onLongPress: onLongPress,
                child: QuickFavoriteButton(
                  isFaved: favorited,
                  isCurrent: isCurrent,
                  enabled: enabled,
                  controlled: true,
                  onFavToggle: (liked) =>
                      retryStatus?.call() ??
                      change(liked ? PixivBookmarkVisibility.public : null),
                ),
              ),
            )
          : trigger,
    );
    return builder?.call(context, [
          ViewerToolbarButtonData(
            action: ViewerToolbarAction.favorite,
            required: true,
            widget: button,
            title: title,
            icon: icon,
            enabled: enabled,
            onTap: enabled ? trigger.action(context) : null,
            menuBuilder: (_, close) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                KurumiPopupMenuItem(
                  title: Text(canChoose ? strings.add_public : title),
                  icon: icon,
                  onTap: enabled
                      ? () {
                          close();
                          trigger.action(context)?.call();
                        }
                      : null,
                ),
                if (canChoose)
                  KurumiPopupMenuItem(
                    title: Text(strings.add_private),
                    icon: const Icon(Icons.lock_outline),
                    onTap: () {
                      close();
                      choose(PixivBookmarkVisibility.private);
                    },
                  ),
              ],
            ),
            legacyMenuActions: [
              if (canChoose)
                ButtonData(
                  widget: const SizedBox.shrink(),
                  title: strings.add_private,
                  icon: const Icon(Icons.lock_outline),
                  placement: ButtonPlacement.menuOnly,
                  onTap: () => choose(PixivBookmarkVisibility.private),
                ),
            ],
          ),
        ]) ??
        button;
  }
}

class PixivPostFavoriteToolbar extends StatelessWidget {
  const PixivPostFavoriteToolbar({super.key});

  @override
  Widget build(BuildContext context) {
    final post = InheritedPost.maybeOf<Post>(context);
    if (post == null) return const SliverToBoxAdapter();
    Widget buildRow(BuildContext context, List<ButtonData> actions) =>
        SimplePostActionToolbar<Post>(
          post: post,
          maxVisibleButtons: 5,
          onStartSlideshow: PostDetailsPageViewScope.of(context).startSlideshow,
          favoriteButton: null,
          favoriteActions: actions,
        );
    final artwork = post.pixivData;
    final groupActions = PostActionToolbarScope.maybeOf(context)
        ?.buildGroupFavoriteActions;
    final toolbar =
        groupActions?.call(buildRow) ??
        PixivFavoriteControl(
          key: ValueKey(artwork?.illustId),
          illustId: artwork?.illustId ?? 0,
          restricted: artwork?.isRestricted ?? true,
          builder: buildRow,
        );
    final current = PostDetails.maybeOf<Post>(context)?.controller.currentPost;
    return SliverToBoxAdapter(
      child: current == null
          ? toolbar
          : ValueListenableBuilder(
              valueListenable: current,
              child: toolbar,
              builder: (context, activePost, child) => NavigationActivity(
                active:
                    NavigationActivity.of(context) &&
                    activePost.id == post.id &&
                    activePost.origin == post.origin,
                selectionChromeActive: NavigationActivity.selectionChromeOf(
                  context,
                ),
                child: child!,
              ),
            ),
    );
  }
}
