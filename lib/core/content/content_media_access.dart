import 'package:cache_manager/cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../configs/config/types.dart';
import '../posts/post/types.dart';
import 'anonymous_source_policy.dart';
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
  return (
    allowed:
        context != null &&
        context.config?.auth == config &&
        (context.config?.anonymousReadScope?.isCurrent ?? true),
    key: access,
    context: context,
  );
}

// Retained for existing callers. The image cache below deliberately does not
// use this transient namespace for persistent keys.
String contentMediaCacheNamespace(ContentAccessKey key) =>
    'content-media-v${AnonymousSourcePolicy.version}/${key.engine.id}/'
    '${Uri.encodeComponent(key.siteNamespace)}/${key.profileId ?? 'public'}/'
    '${key.authEpoch}/${key.policyEpoch}';

final contentMediaCacheNamespaceProvider =
    Provider.family<String, ContentAccessKey>(
      (ref, key) =>
          '${ref.watch(contentAccessEpochsProvider).sessionId}/${contentMediaCacheNamespace(key)}',
      dependencies: [contentAccessEpochsProvider],
    );

/// Share the normal URL/custom-key cache with Browse and previous app sessions.
/// Access belongs to the caller and HTTP transport, not to a disk filename.
/// This provider does not own the manager and must not dispose or clear it when
/// a page, profile, or runtime access key changes.
final contentMediaCacheManagerProvider = Provider.autoDispose
    .family<
      ImageCacheManager,
      ({ImageCacheManager manager, ContentAccessKey access})
    >((ref, request) => request.manager);
