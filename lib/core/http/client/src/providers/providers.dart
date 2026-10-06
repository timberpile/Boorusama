// Package imports:
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation/foundation.dart';

// Project imports:
import '../../../../../foundation/info/app_info.dart';
import '../../../../../foundation/info/package_info.dart';
import '../../../../../foundation/loggers.dart';
import '../../../../../foundation/vendors/google/providers.dart';
import '../../../../boorus/booru/providers.dart';
import '../../../../boorus/engine/providers.dart';
import '../../../../configs/config/types.dart';
import '../../../../ddos/handler/providers.dart';
import '../coordination/api_request_coordinator.dart';
import '../coordination/api_auth_refresh_registry.dart';
import '../types/dio_options.dart';
import '../types/http_utils.dart';
import '../types/network_protocol_info.dart';
import 'dio.dart';

final apiAuthRefreshRegistryProvider = Provider<ApiAuthRefreshRegistry>(
  (ref) => ApiAuthRefreshRegistry(),
);

final apiRequestCoordinatorProvider = Provider<ApiRequestCoordinator>((ref) {
  final coordinator = ApiRequestCoordinator();
  ref.onDispose(coordinator.dispose);
  return coordinator;
});

final defaultDioProvider = Provider.family<Dio, BooruConfigAuth>((ref, config) {
  final ddosProtectionHandler = ref.watch(httpDdosProtectionBypassProvider);
  final loggerService = ref.watch(loggerProvider);

  return newDio(
    apiCoordinator: ref.watch(apiRequestCoordinatorProvider),
    options: DioOptions(
      ddosProtectionHandler: ddosProtectionHandler,
      userAgent: ref.watch(defaultUserAgentProvider),
      loggerService: loggerService,
      networkProtocolInfo: ref.watch(
        defaultNetworkProtocolInfoProvider(config),
      ),
      baseUrl: config.url,
      proxySettings: config.proxySettings,
      skipCertificateVerification:
          config.networkSettings?.httpSettings?.skipCertificateVerification ??
          false,
    ),
  );
});

final genericDioProvider = Provider<Dio>(
  (ref) {
    final loggerService = ref.watch(loggerProvider);
    final cronetAvailable = ref.watch(isCronetAvailableProvider);

    return newGenericDio(
      baseUrl: null,
      userAgent: ref.watch(defaultUserAgentProvider),
      logger: loggerService,
      protocolInfo: NetworkProtocolInfo.generic(
        cronetAvailable: cronetAvailable,
      ),
    );
  },
);

// Don't use this provider inside any of other providers that used inside any of the booru repositories.
// It is only used for widget only to prevent circular dependencies.
final dioForWidgetProvider = Provider.family<Dio, BooruConfigAuth>(
  (ref, config) {
    final repository = ref
        .watch(booruEngineRegistryProvider)
        .getRepository(config.booruType);

    if (repository == null) {
      return ref.watch(genericDioProvider);
    }

    return repository.dio(config);
  },
  name: 'dioProvider',
);

final userAgentProvider = Provider.family<String, BooruConfigAuth>(
  (ref, config) {
    final dio = ref.watch(dioForWidgetProvider(config));

    final userAgent = dio.options.headers[AppHttpHeaders.userAgentHeader];

    return switch (userAgent) {
      final String ua => ua,
      final List<String> uaList => uaList.firstOrNull ?? '',
      _ => '',
    };
  },
);

final httpHeadersProvider =
    Provider.family<Map<String, String>, BooruConfigAuth>(
      (ref, config) {
        return {
          AppHttpHeaders.userAgentHeader: ref.watch(userAgentProvider(config)),
          ...ref.watch(extraHttpHeaderProvider(config)),
          ...ref.watch(cachedBypassDdosHeadersProvider(config.url)),
        };
      },
    );

final extraHttpHeaderProvider =
    Provider.family<Map<String, String>, BooruConfigAuth>(
      (ref, config) {
        final headers = ref
            .watch(booruEngineRegistryProvider)
            .getRepository(config.booruType)
            ?.extraHttpHeaders(config);

        if (headers == null) {
          return {};
        }

        return headers;
      },
    );

final faviconDioProvider = Provider<Dio>((ref) {
  return Dio();
});

final defaultUserAgentProvider = Provider.autoDispose<String>((ref) {
  final appInfo = ref.watch(appInfoProvider);
  final packageInfo = ref.watch(packageInfoProvider);

  return '${appInfo.appName.sentenceCase}/${packageInfo.version}';
});

final defaultNetworkProtocolInfoProvider =
    Provider.family<NetworkProtocolInfo, BooruConfigAuth>((ref, config) {
      final booruDb = ref.watch(booruDbProvider);
      final cronetAvailable = ref.watch(isCronetAvailableProvider);

      final booru =
          booruDb.getBooruFromUrl(config.url) ??
          booruDb.getBooruFromId(config.booruIdHint);
      final detectedProtocol = booru?.getSiteProtocol(config.url);

      final customProtocol = config
          .networkSettings
          ?.httpSettings
          ?.protocolOption
          .toNetworkProtocol();

      return NetworkProtocolInfo(
        customProtocol: customProtocol,
        detectedProtocol: detectedProtocol,
        platform: PlatformInfo.fromCurrent(
          cronetAvailable: cronetAvailable,
        ),
      );
    });
