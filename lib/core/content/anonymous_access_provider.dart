import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../blacklists/providers.dart';
import '../configs/config/types.dart';
import '../http/client/providers.dart';
import '../http/client/src/coordination/coordinated_dio.dart';
import '../http/client/src/data/public_read_http_adapter.dart';
import 'anonymous_read_scope.dart';
import 'anonymous_source_policy.dart';
import 'content_access.dart';
import 'content_access_provider.dart';
import '../bookmarks/src/providers/pool_bookmark_provider.dart'
    show poolCoverPolicy;

final anonymousSourcePolicyProvider = Provider(
  (ref) => const AnonymousSourcePolicy(),
);

/// Only a visible consumer obtains a scope. Preparing it reads local policy;
/// the shared existing Dio factory remains lazy until an actual approved read.
final AutoDisposeProviderFamily<ContentAccessContext?, AnonymousSource>
anonymousContentAccessProvider = Provider.autoDispose
    .family<ContentAccessContext?, AnonymousSource>(
      (ref, source) {
        final allowed = ref.watch(anonymousSourcePolicyProvider);
        if (allowed.resolve(source.engine, source.site) != source) return null;
        // A profile change revokes old public bindings instead of silently moving
        // an in-flight result into a newly available account or policy.
        final profiles = ref.watch(contentAccessScopesProvider);
        final blacklist = ref.watch(globalBlacklistedTagsProvider);
        if (blacklist.isLoading || blacklist.hasError || !blacklist.hasValue) {
          return null;
        }
        final base = BooruConfig.fromJson({
          ...BooruConfig.empty.toJson(),
          'id': '00000000-0000-4000-8000-000000000000',
          'booruId': source.engine.id,
          'booruIdHint': source.engine.id,
          'name': '',
          'url': source.site.toString(),
          'apiKey': null,
          'login': null,
          'passHash': null,
          'proxySettings': null,
          'networkSettings': null,
        });
        final epochs = ref.read(contentAccessEpochsProvider);
        final key = ContentAccessKey(
          engine: source.engine,
          siteNamespace: source.site.host,
          authEpoch: epochs.next(),
          policyEpoch: epochs.next(),
        );
        late final AnonymousReadScope scope;
        scope = AnonymousReadScope(
          source: source,
          key: key,
          current: () =>
              identical(ref.read(contentAccessScopesProvider), profiles) &&
              identical(ref.read(anonymousSourcePolicyProvider), allowed) &&
              identical(ref.read(globalBlacklistedTagsProvider), blacklist),
          createDio: () {
            final coordinator = ref.read(apiRequestCoordinatorProvider);
            final dio = newGenericDio(
              baseUrl: source.site.toString(),
              userAgent: ref.read(defaultUserAgentProvider),
              headers: {'Referer': source.site.toString()},
            );
            // Use the ordinary transport and coordination. No stored challenge
            // cookies, account headers, profile proxy or native cookie jar enter it.
            dio.httpClientAdapter = PublicReadHttpClientAdapter(
              delegate: dio.httpClientAdapter,
              source: source,
              current: () => scope.isCurrent,
            );
            coordinateApiDio(dio, coordinator);
            return dio;
          },
        );
        ref.onDispose(scope.dispose);
        return ContentAccessContext.anonymous(
          config: base.copyWith(anonymousReadScope: scope),
          scope: scope,
          policyFingerprint: poolCoverPolicy(
            base,
            blacklist.requireValue.map((e) => e.name).toSet(),
          ),
        );
      },
      dependencies: [
        anonymousSourcePolicyProvider,
        contentAccessScopesProvider,
        globalBlacklistedTagsProvider,
        contentAccessEpochsProvider,
        apiRequestCoordinatorProvider,
        defaultUserAgentProvider,
      ],
    );
