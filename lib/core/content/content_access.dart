import 'package:equatable/equatable.dart';

import '../boorus/booru/types.dart';
import '../configs/config/types.dart';
import '../posts/details/src/types/viewer_entry.dart';
import '../posts/links/boorusama_post_link.dart';
import '../posts/post/types.dart';
import 'content_reference.dart';
import 'anonymous_read_scope.dart';

/// Monotonic revisions are transient counters, never credentials or their hashes.
final class ContentAccessKey extends Equatable {
  ContentAccessKey({
    required this.engine,
    required String siteNamespace,
    this.profileId,
    required this.authEpoch,
    required this.policyEpoch,
  }) : siteNamespace = normalizePostSourceHost(siteNamespace) {
    if (engine == BooruType.unknown ||
        this.siteNamespace.isEmpty ||
        (profileId != null && !isCanonicalProfileId(profileId)) ||
        authEpoch < 0 ||
        policyEpoch < 0) {
      throw const FormatException('Invalid content access key');
    }
  }
  final BooruType engine;
  final String siteNamespace;
  final String? profileId;
  final int authEpoch;
  final int policyEpoch;
  @override
  List<Object?> get props => [
    engine,
    siteNamespace,
    profileId,
    authEpoch,
    policyEpoch,
  ];
}

final class ContentAccessContext {
  const ContentAccessContext._({
    required this.key,
    required this.baseUrl,
    required this.config,
  });

  factory ContentAccessContext.profile({
    required BooruConfig config,
    required int authEpoch,
    required int policyEpoch,
    Uri? baseUrl,
  }) {
    if (config.anonymousReadScope != null) {
      throw const FormatException('A public read scope is not a user profile');
    }
    final site = BoorusamaPostLink.parseSourceSite(config.url);
    return ContentAccessContext._(
      key: ContentAccessKey(
        engine: config.auth.booruType,
        siteNamespace: normalizePostSourceHost(site.toString()),
        profileId: config.id,
        authEpoch: authEpoch,
        policyEpoch: policyEpoch,
      ),
      baseUrl: baseUrl == null
          ? site
          : BoorusamaPostLink.parseSourceSite(baseUrl.toString()),
      config: config,
    );
  }

  factory ContentAccessContext.anonymous({
    required BooruConfig config,
    required AnonymousReadScope scope,
  }) {
    final auth = config.auth;
    if (!identical(config.anonymousReadScope, scope) ||
        auth.booruType != scope.source.engine ||
        config.url != scope.source.site.toString() ||
        auth.apiKey != null ||
        auth.login != null ||
        auth.passHash != null ||
        config.proxySettings != null ||
        config.networkSettings != null) {
      throw const FormatException(
        'Public read contexts cannot inherit account settings',
      );
    }
    return ContentAccessContext._(
      key: scope.key,
      baseUrl: scope.source.site,
      config: config,
    );
  }

  final ContentAccessKey key;

  /// The endpoint belongs to the authorized profile/adapter, not an imported URL.
  final Uri baseUrl;
  final BooruConfig? config;

  /// Registered adapters may map an authorized installation to their verified
  /// API endpoint. The account/policy binding is preserved; no imported address
  /// can grant access or substitute another configuration.
  ContentAccessContext withEndpoint(Uri endpoint) {
    final publicScope = config?.anonymousReadScope;
    if (publicScope != null &&
        endpoint != publicScope.source.site &&
        !publicScope.source.allowsApi(endpoint)) {
      throw const FormatException('Endpoint is outside public read permission');
    }
    return ContentAccessContext._(
      key: key,
      baseUrl: BoorusamaPostLink.parseSourceSite(endpoint.toString()),
      config: config,
    );
  }

  bool hasSameAuthorization(ContentAccessContext other) =>
      key == other.key && identical(config, other.config);

  bool accepts(ContentReference reference) =>
      reference.engine == key.engine &&
      reference.siteNamespace == key.siteNamespace;

  bool matchesProfiles(Iterable<BooruConfig> profiles) {
    if (key.profileId == null) {
      return config?.anonymousReadScope?.isCurrent ?? false;
    }
    return switch (config) {
      final config? => ViewerSourceBinding(config).resolve(profiles) != null,
      _ => false,
    };
  }
}

final class GroupLoadKey extends Equatable {
  GroupLoadKey({required this.reference, required this.access, this.orderKey}) {
    if (reference.kind != ContentKind.group ||
        reference.engine != access.engine ||
        reference.siteNamespace != access.siteNamespace ||
        orderKey == '' ||
        (orderKey != null && orderKey!.length > 256)) {
      throw const FormatException('Invalid access-scoped Group load key');
    }
  }
  final ContentReference reference;
  final ContentAccessKey access;
  final String? orderKey;
  GroupMetadataKey get metadata =>
      GroupMetadataKey(reference: reference, access: access);
  @override
  List<Object?> get props => [reference, access, orderKey];
}

/// Metadata intentionally excludes member order; member cache keys include it.
final class GroupMetadataKey extends Equatable {
  GroupMetadataKey({required this.reference, required this.access}) {
    GroupLoadKey(reference: reference, access: access);
  }
  final ContentReference reference;
  final ContentAccessKey access;
  @override
  List<Object?> get props => [reference, access];
}

final class ContentAccessRequest extends Equatable {
  const ContentAccessRequest({
    required this.reference,
    this.profileIdHint,
    this.allowProfileHintFallback = true,
  });
  final ContentReference reference;
  final String? profileIdHint;

  /// Unbound references retain compatible-account resolution. Saved Bookmark
  /// consumers opt out so a removed originating account cannot borrow another.
  final bool allowProfileHintFallback;
  @override
  List<Object?> get props => [
    reference,
    profileIdHint,
    allowProfileHintFallback,
  ];
}
