import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../posts/filter/types.dart';
import '../bookmarks/src/providers/pool_bookmark_provider.dart'
    show poolCoverAllowsRating;

import '../blacklists/providers.dart';
import '../bookmarks/src/providers/pool_bookmark_provider.dart'
    show poolCoverPolicy;
import '../configs/config/types.dart';
import '../configs/manage/providers.dart';
import '../errors/types.dart';
import '../posts/details/src/types/viewer_entry.dart';
import '../posts/post/types.dart';
import 'content_access.dart';
import 'anonymous_access_provider.dart';

/// Reuse the established non-secret visibility policy and effective blacklist.
/// A loading/failed policy cannot authorize cached Group metadata or media.
final contentEffectiveBlacklistProvider = Provider.autoDispose
    .family<AsyncValue<Set<String>>, String>((ref, profileId) {
      final matches = ref
          .watch(booruConfigProvider)
          .where((p) => p.id == profileId)
          .toList();
      if (matches.length != 1) {
        return AsyncError(
          AppError(
            type: AppErrorType.loadDataFromServerFailed,
            message: 'Content profile unavailable',
          ),
          StackTrace.current,
        );
      }
      return ref.watch(blacklistTagsProvider(matches.single.filter));
    }, dependencies: [booruConfigProvider, blacklistTagsProvider]);

final contentEffectivePolicyProvider = Provider.autoDispose
    .family<AsyncValue<String>, String>((ref, id) {
      final profiles = ref
          .watch(booruConfigProvider)
          .where((config) => config.id == id);
      if (profiles.length != 1)
        return AsyncError(
          StateError('Content profile unavailable'),
          StackTrace.current,
        );
      return ref
          .watch(contentEffectiveBlacklistProvider(id))
          .whenData((tags) => poolCoverPolicy(profiles.single, tags));
    }, dependencies: [booruConfigProvider, contentEffectiveBlacklistProvider]);

/// Only current profiles and monotonic counters are retained. Policy/client work
/// is deferred to the one profile actually requested by a visible consumer.
/// Shared across nested provider scopes which can share the same engine registry.
/// Values contain no profile data; only active scope maps retain configurations.
final contentAccessEpochsProvider = Provider((ref) => ContentAccessEpochs());

class ContentAccessEpochs {
  var _value = 0;
  int next() => ++_value;
}

typedef ContentProfileScope = ({
  BooruConfig config,
  int authEpoch,
  int bindingEpoch,
});

final contentAccessScopesProvider =
    NotifierProvider<ContentAccessScopes, Map<String, ContentProfileScope>>(
      ContentAccessScopes.new,
      dependencies: [booruConfigProvider, contentAccessEpochsProvider],
    );

class ContentAccessScopes extends Notifier<Map<String, ContentProfileScope>> {
  var _previous = <String, ContentProfileScope>{};
  int nextEpoch() => ref.read(contentAccessEpochsProvider).next();

  @override
  Map<String, ContentProfileScope> build() {
    final profiles = ref.watch(booruConfigProvider);
    final counts = <String, int>{};
    for (final profile in profiles) {
      counts.update(profile.id, (value) => value + 1, ifAbsent: () => 1);
    }
    final next = <String, ContentProfileScope>{};
    for (final config in profiles) {
      if (counts[config.id] != 1) continue;
      final old = _previous[config.id];
      final sameAuth = old != null && old.config.auth == config.auth;
      final sameBinding =
          sameAuth && ViewerSourceBinding(old.config).resolve([config]) != null;
      next[config.id] = (
        config: config,
        authEpoch: sameAuth ? old.authEpoch : nextEpoch(),
        bindingEpoch: sameBinding ? old.bindingEpoch : nextEpoch(),
      );
    }
    _previous = next;
    return Map.unmodifiable(next);
  }
}

final contentProfileAccessProvider =
    NotifierProvider.family<
      ContentProfileAccess,
      ContentAccessContext?,
      String
    >(
      ContentProfileAccess.new,
      dependencies: [
        contentAccessScopesProvider,
        contentEffectivePolicyProvider,
      ],
    );

class ContentProfileAccess
    extends FamilyNotifier<ContentAccessContext?, String> {
  ContentAccessContext? _previous;
  String? _policy;
  int? _bindingEpoch;

  @override
  ContentAccessContext? build(String profileId) {
    final scope = ref.watch(
      contentAccessScopesProvider.select((values) => values[profileId]),
    );
    if (scope == null) return _revoke();
    try {
      // Validate the configured source before policy work can construct clients.
      ContentAccessContext.profile(
        config: scope.config,
        authEpoch: scope.authEpoch,
        policyEpoch: scope.bindingEpoch,
      );
    } on FormatException {
      return _revoke();
    }
    final policy = ref.watch(contentEffectivePolicyProvider(profileId));
    if (policy.isLoading || policy.hasError || !policy.hasValue) {
      return _revoke();
    }
    final digest = policy.requireValue;
    if (_previous != null &&
        _policy == digest &&
        _bindingEpoch == scope.bindingEpoch) {
      return _previous;
    }
    _policy = digest;
    _bindingEpoch = scope.bindingEpoch;
    return _previous = ContentAccessContext.profile(
      config: scope.config,
      authEpoch: scope.authEpoch,
      policyEpoch: ref.read(contentAccessScopesProvider.notifier).nextEpoch(),
    );
  }

  ContentAccessContext? _revoke() {
    _previous = null;
    _policy = null;
    _bindingEpoch = null;
    return null;
  }
}

final contentAccessContextProvider = Provider.autoDispose
    .family<ContentAccessContext?, ContentAccessKey>(
      (ref, key) {
        final id = key.profileId;
        if (id == null) {
          final source = ref
              .watch(anonymousSourcePolicyProvider)
              .forNamespace(key.engine, key.siteNamespace);
          if (source == null) return null;
          final context = ref.watch(anonymousContentAccessProvider(source));
          return context?.key == key ? context : null;
        }
        final scope = ref.watch(
          contentAccessScopesProvider.select((values) => values[id]),
        );
        if (scope == null ||
            scope.authEpoch != key.authEpoch ||
            scope.config.auth.booruType != key.engine ||
            normalizePostSourceHost(scope.config.url) != key.siteNamespace) {
          return null;
        }
        final context = ref.watch(contentProfileAccessProvider(id));
        return context?.key == key ? context : null;
      },
      dependencies: [
        contentAccessScopesProvider,
        contentProfileAccessProvider,
        anonymousSourcePolicyProvider,
        anonymousContentAccessProvider,
      ],
    );

final contentAccessForReferenceProvider = Provider.autoDispose
    .family<ContentAccessContext?, ContentAccessRequest>(
      (ref, request) {
        final profiles = ref.watch(booruConfigProvider);
        final origin = PostOrigin.fromSource(
          booruType: request.reference.engine,
          booruId: 0,
          source: request.reference.site.toString(),
          profileIdHint: request.profileIdHint,
        );
        final resolved = const PostOriginResolver().resolve(
          origin,
          profiles,
          allowProfileHintFallback: request.allowProfileHintFallback,
        );
        return switch (resolved) {
          ResolvedPostOrigin(:final config) => ref.watch(
            contentProfileAccessProvider(config.id),
          ),
          AmbiguousPostOrigin() => null,
          MissingPostOrigin() => switch (ref
              .watch(anonymousSourcePolicyProvider)
              .resolve(request.reference.engine, request.reference.site)) {
            final source? => ref.watch(anonymousContentAccessProvider(source)),
            _ => null,
          },
        };
      },
      dependencies: [
        booruConfigProvider,
        contentProfileAccessProvider,
        anonymousSourcePolicyProvider,
        anonymousContentAccessProvider,
      ],
    );

final contentAccessForOriginProvider = Provider.autoDispose
    .family<ContentAccessContext?, PostOrigin>(
      (ref, origin) {
        final resolution = const PostOriginResolver().resolve(
          origin,
          ref.watch(booruConfigProvider),
          allowProfileHintFallback: true,
        );
        return switch (resolution) {
          ResolvedPostOrigin(:final config) => ref.watch(
            contentProfileAccessProvider(config.id),
          ),
          AmbiguousPostOrigin() => null,
          MissingPostOrigin() => switch (ref
              .watch(anonymousSourcePolicyProvider)
              .forNamespace(origin.booruType, origin.sourceHost)) {
            final source? => ref.watch(anonymousContentAccessProvider(source)),
            _ => null,
          },
        };
      },
      dependencies: [
        booruConfigProvider,
        contentProfileAccessProvider,
        anonymousSourcePolicyProvider,
        anonymousContentAccessProvider,
      ],
    );

/// Check saved Post facts against the same current policy used to admit media.
final contentPostVisibilityProvider = Provider.autoDispose
    .family<AsyncValue<bool>, ({ContentAccessKey access, Post post})>(
      (ref, request) {
        final access = ref.watch(contentAccessContextProvider(request.access));
        final config = access?.config;
        if (config == null) return const AsyncData(false);
        final tags = request.access.profileId == null
            ? ref
                  .watch(globalBlacklistedTagsProvider)
                  .whenData((rows) => rows.map((e) => e.name).toSet())
            : ref.watch(contentEffectiveBlacklistProvider(config.id));
        return tags.whenData(
          (tags) =>
              filterTags([request.post], tags).isNotEmpty &&
              poolCoverAllowsRating(config, request.post.rating) &&
              !(config.deletedItemBehavior.isHidden &&
                  (request.post.status?.matches('deleted') ?? false)) &&
              !(config.bannedPostVisibility.isHidden &&
                  (request.post.status?.matches('banned') ?? false)),
        );
      },
      dependencies: [
        contentAccessContextProvider,
        globalBlacklistedTagsProvider,
        contentEffectiveBlacklistProvider,
      ],
    );
