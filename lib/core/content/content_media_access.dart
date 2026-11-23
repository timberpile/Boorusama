import 'package:cache_manager/cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../configs/config/types.dart';
import '../posts/post/types.dart';
import 'content_access.dart';
import 'content_access_provider.dart';

/// Legacy unbound media keeps its existing behavior. Source-bound viewers and
/// cards explicitly require a current key, including during loading/revocation.
final currentContentAccessKeyProvider = Provider<ContentAccessKey?>(
  (ref) => null,
);
final contentAccessRequiredProvider = Provider<bool>((ref) => false);
final currentContentBookmarkIdProvider = Provider<int?>((ref) => null);

typedef ContentMediaAccess = ({
  bool allowed,
  ContentAccessKey? key,
  ContentAccessContext? context,
});

ContentMediaAccess watchContentMediaAccess(
  WidgetRef ref,
  BooruConfigAuth config, {
  ContentAccessKey? key,
  Post? post,
}) {
  final access =
      key ??
      config.anonymousReadScope?.key ??
      ref.watch(currentContentAccessKeyProvider);
  final required =
      key != null ||
      config.anonymousReadScope != null ||
      ref.watch(contentAccessRequiredProvider);
  if (access == null) return (allowed: !required, key: null, context: null);
  if (access.engine != config.booruType ||
      access.siteNamespace != normalizePostSourceHost(config.url)) {
    return (allowed: false, key: access, context: null);
  }
  final context = ref.watch(contentAccessContextProvider(access));
  // Check Post facts only for explicitly bound content. Ordinary Browse keeps
  // its established filter controls and revealable blur overlays.
  final visible =
      post == null ||
      switch (ref.watch(
        contentPostVisibilityProvider((access: access, post: post)),
      )) {
        AsyncData(:final value) => value,
        _ => false,
      };
  return (
    allowed:
        visible &&
        context != null &&
        context.config?.auth == config &&
        (context.config?.anonymousReadScope?.isCurrent ?? true),
    key: access,
    context: context,
  );
}

/// The cache keeps ordinary URL/custom keys across navigation and restarts.
/// Presentation and transport validate current access independently of disk keys.
/// The shared manager owns its quota, leases and lifecycle.
final contentMediaCacheManagerProvider = Provider.autoDispose
    .family<
      ImageCacheManager,
      ({ImageCacheManager manager, ContentAccessKey access})
    >((ref, request) => request.manager);
