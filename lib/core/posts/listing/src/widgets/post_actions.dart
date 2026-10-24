import '../../../cross_profile_lookup/page.dart';
import '../../../favorites/providers.dart';
import '../../../favorites/src/types/types.dart';
import '../../../favorites/src/widgets/favorite_action.dart';
import '../../../../images/providers.dart';
import '../../../../downloads/filename/providers.dart';
import '../../../shares/providers.dart';
import '../../../../boorus/engine/providers.dart';
import '../../../post/types.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

import '../../../../../foundation/url_launcher.dart';
import '../../../../bookmarks/src/providers/bookmark_provider.dart';
import '../../../../bookmarks/src/types/bookmark.dart';
import '../../../../configs/config/providers.dart';
import '../../../../configs/config/types.dart';
import '../../../../configs/manage/providers.dart';
import '../../../../configs/manage/widgets.dart';
import '../../../../downloads/downloader/providers.dart';
import '../../../../router.dart';
import '../../../../tags/show/routes.dart';
import '../../../post/providers.dart';
import '../types/post_action_snapshot.dart';

enum PostActionId {
  download,
  favorite,
  unfavorite,
  share,
  browser,
  tags,
  comments,
  findOnOtherProfiles,
}

class PostActionDefinition {
  const PostActionDefinition({
    required this.id,
    required this.label,
    required this.icon,
    required this.execute,
    this.enabled = true,
  });
  final PostActionId id;
  final String label;
  final IconData icon;
  final Future<void> Function() execute;
  final bool enabled;
}

/// Defers capability/status subscriptions until the context menu is opened.
class PostContextMenuActions extends StatelessWidget {
  const PostContextMenuActions({super.key, required this.snapshot});

  final PostActionSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final actions = Consumer(
      builder: (context, ref, _) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final action in postActionDefinitions(context, ref, snapshot))
            KurumiContextMenuTile(
              title: action.label,
              enabled: action.enabled,
              onTap: () => action.execute(),
            ),
        ],
      ),
    );
    return switch (snapshot.commonConfig) {
      final config? => CurrentBooruConfigScope(config: config, child: actions),
      null => actions,
    };
  }
}

/// Shared definitions used by clicked-post menus and one/many selection UI.
List<PostActionDefinition> postActionDefinitions(
  BuildContext context,
  WidgetRef ref,
  PostActionSnapshot snapshot, {
  Future<void> Function()? downloadOverride,
}) {
  final feedback = Navigator.of(context, rootNavigator: true).context;
  Future<void> run(Future<void> Function() action) async {
    try {
      if (!snapshot.accountsMatch(ref.read(booruConfigProvider))) {
        throw StateError('Post action account changed');
      }
      await action();
    } catch (_) {
      if (feedback.mounted) {
        Kurumi.showErrorToast(
          feedback,
          feedback.t.post.action.operation_failed,
        );
      }
    }
  }

  final library = ref.watch(bookmarkProvider).valueOrNull;
  final stored = [
    for (final post in snapshot.posts) library?.bookmarkForPost(post),
  ];
  final canUseStoredDownload =
      snapshot.hasTargets && stored.every((p) => p != null);
  final fallbackAuth = ref.watchConfigAuth;
  final fallbackDownload = ref.watchConfigDownload;
  final groups = <BooruConfig, List<Post>>{};
  for (final target in snapshot.targets) {
    if (target.config case final source?) {
      groups.putIfAbsent(source, () => []).add(target.post);
    }
  }
  final normalDownloadParams = <BooruConfig, DownloadNotifierParams>{};
  for (final entry in groups.entries) {
    final params = ref.watch(
      downloadNotifierParamsProvider((entry.key.auth, entry.key.download)),
    );
    if (params.filenameBuilder != null &&
        (entry.value.length == 1 || params.canDownloadMultipleFiles())) {
      normalDownloadParams[entry.key] = params;
    }
  }
  final canDownloadResolved =
      snapshot.allResolved && normalDownloadParams.length == groups.length;
  final canFavorite =
      snapshot.allResolved &&
      snapshot.targets.every((target) {
        final auth = target.config!.auth;
        return ref.watch(booruLoginDetailsProvider(auth)).hasLogin() &&
            ref.watch(canFavoriteProvider(auth));
      });
  final favoriteStatuses = <bool?>[
    if (canFavorite)
      for (final target in snapshot.targets)
        ref.watch(
          favoriteStatusProvider((target.config!.auth, target.post.id)),
        ),
  ];
  if (canFavorite) {
    for (final target in snapshot.targets) {
      ref.watch(
        favoriteStatusLoaderProvider((target.config!.auth, target.post.id)),
      );
    }
  }
  final favoriteReady =
      canFavorite && favoriteStatuses.every((value) => value != null);
  final removeFavorites =
      favoriteReady && favoriteStatuses.every((value) => value!);
  final single = snapshot.isSingle ? snapshot.targets.single : null;
  final config = single?.config;
  final post = single?.post;
  final login = config == null
      ? null
      : ref.watch(booruLoginDetailsProvider(config.auth));
  return [
    if (post != null)
      PostActionDefinition(
        id: PostActionId.findOnOtherProfiles,
        label: context.t.post.cross_profile.action,
        icon: Icons.travel_explore,
        execute: () => run(() async => findOnOtherProfiles(ref, post)),
      ),
    if (snapshot.hasTargets &&
        (downloadOverride != null ||
            canDownloadResolved ||
            canUseStoredDownload))
      PostActionDefinition(
        id: PostActionId.download,
        label: context.t.download.download,
        icon: Icons.download,
        execute: () => run(() async {
          if (downloadOverride != null) {
            await downloadOverride();
          } else {
            // Capture all services and fallback snapshots before the first await.
            // One orphan/unsupported group must not downgrade supported sources
            // to legacy Original-only downloads or discard selected posts.
            final operations = [
              for (final entry in normalDownloadParams.entries)
                (
                  posts: List<Post>.unmodifiable(groups[entry.key]!),
                  notifier: ref.read(
                    downloadNotifierProvider(entry.value).notifier,
                  ),
                ),
            ];
            final fallbackOperations = [
              for (final entry in groups.entries)
                if (!normalDownloadParams.containsKey(entry.key))
                  (
                    auth: entry.key.auth,
                    download: entry.key.download,
                    bookmarks: List<Bookmark>.unmodifiable([
                      for (final post in entry.value)
                        library!.bookmarkForPost(post)!,
                    ]),
                  ),
              if (snapshot.targets.any((target) => target.config == null))
                (
                  auth: fallbackAuth,
                  download: fallbackDownload,
                  bookmarks: List<Bookmark>.unmodifiable([
                    for (final target in snapshot.targets)
                      if (target.config == null)
                        library!.bookmarkForPost(target.post)!,
                  ]),
                ),
            ];
            final fallbackNotifier = fallbackOperations.isEmpty
                ? null
                : ref.read(bookmarkProvider.notifier);
            for (final operation in operations) {
              if (operation.posts.length == 1) {
                await operation.notifier.download(operation.posts.single);
              } else {
                await operation.notifier.bulkDownload(operation.posts);
              }
            }
            for (final operation in fallbackOperations) {
              await fallbackNotifier!.downloadBookmarks(
                operation.auth,
                operation.download,
                operation.bookmarks,
              );
            }
          }
        }),
      ),
    if (canFavorite)
      PostActionDefinition(
        id: removeFavorites ? PostActionId.unfavorite : PostActionId.favorite,
        label: removeFavorites
            ? context.t.post.action.unfavorite
            : context.t.post.action.favorite,
        icon: removeFavorites ? Icons.favorite : Icons.favorite_border,
        enabled: favoriteReady,
        execute: () => run(() async {
          if (!favoriteReady) throw StateError('Favorite status is not ready');
          // Capture every source service and validate the entire selection before
          // the first mutation. Completed posts retain their known status on retry.
          final operations = [
            for (final target in snapshot.targets)
              (
                postId: target.post.id,
                profileId: target.config!.id,
                notifier: ref.read(
                  favoritesProvider(target.config!.auth).notifier,
                ),
              ),
          ];
          final result = await runFavoriteAction(feedback, () async {
            for (final operation in operations) {
              final success = removeFavorites
                  ? await operation.notifier.remove(
                      operation.postId,
                      profileId: operation.profileId,
                    )
                  : switch (await operation.notifier.add(
                      operation.postId,
                      profileId: operation.profileId,
                    )) {
                      AddFavoriteStatus.success ||
                      AddFavoriteStatus.alreadyExists => true,
                      _ => false,
                    };
              if (!success) throw StateError('Favorite action failed');
            }
          });
          if (result != null &&
              !result.cleanupInterrupted &&
              feedback.mounted) {
            Kurumi.showSuccessToast(
              feedback,
              feedback.t.favorites.update.success,
              duration: KurumiDurations.shortToast,
            );
          }
        }),
      ),
    if (post != null && config != null) ...[
      PostActionDefinition(
        id: PostActionId.share,
        label: context.t.post.action.share,
        icon: Icons.share,
        execute: () => run(() async {
          ref
              .read(shareProvider)
              .sharePost(
                post,
                config.auth,
                context: context,
                configViewer: config.viewer,
                download: config.download,
                filenameBuilder: ref.read(
                  downloadFilenameBuilderProvider(config.auth),
                ),
                imageCacheManager: ref.read(defaultImageCacheManagerProvider),
              );
        }),
      ),
      if (!(login?.hasStrictSFW ?? true))
        PostActionDefinition(
          id: PostActionId.browser,
          label: context.t.post.action.view_in_browser,
          icon: Icons.open_in_browser,
          execute: () => run(
            () async {
              await launchExternalUrlString(
                ref.read(postLinkGeneratorProvider(config.auth)).getLink(post),
                launcher: ref.read(externalUrlLauncherProvider),
              );
            },
          ),
        ),
      if (post.tags.isNotEmpty)
        PostActionDefinition(
          id: PostActionId.tags,
          label: context.t.post.action.view_tags,
          icon: Icons.tag,
          execute: () => run(() async {
            await goToShowTaglistPage(ref, post, config: config);
          }),
        ),
      if (post.hasComment &&
          ref.watch(booruBuilderProvider(config.auth))?.commentPageBuilder !=
              null)
        PostActionDefinition(
          id: PostActionId.comments,
          label: context.t.post.action.view_comments,
          icon: Icons.comment,
          execute: () => run(() async {
            goToCommentPage(context, ref, post);
          }),
        ),
    ],
  ];
}