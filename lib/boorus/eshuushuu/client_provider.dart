// Dart imports:
import 'dart:async';

// Package imports:
import 'package:booru_clients/eshuushuu.dart';
import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../core/configs/config/data.dart';
import '../../core/configs/config/types.dart';
import '../../core/configs/manage/providers.dart';
import '../../core/ddos/handler/providers.dart';
import '../../core/http/client/providers.dart';
import '../../core/http/client/types.dart';
import '../../core/router.dart';
import '../../foundation/loggers.dart';
import 'auth/auth_interceptor.dart';
import 'auth/session_expired_dialog.dart';

final eshuushuuClientProvider =
    Provider.family<EShuushuuClient, BooruConfigAuth>(
      (ref, config) {
        final dio = ref.watch(eshuushuuDioProvider(config));

        return EShuushuuClient(
          dio: dio,
        );
      },
    );

final eshuushuuDioProvider = Provider.family<Dio, BooruConfigAuth>((
  ref,
  config,
) {
  final ddosProtectionHandler = ref.watch(httpDdosProtectionBypassProvider);
  final loggerService = ref.watch(loggerProvider);

  final refreshToken = config.apiKey;
  var expectedPersistedRefreshToken = refreshToken;
  final configId = ref
      .read(booruConfigProvider)
      .firstWhereOrNull(
        (stored) => BooruConfigAuth.fromConfig(stored) == config,
      )
      ?.id;

  return newDio(
    options: DioOptions(
      ddosProtectionHandler: ddosProtectionHandler,
      userAgent: ref.watch(defaultUserAgentProvider),
      loggerService: loggerService,
      networkProtocolInfo: ref.watch(
        defaultNetworkProtocolInfoProvider(config),
      ),
      baseUrl: config.url,
      proxySettings: config.proxySettings,
    ),
    additionalInterceptors: [
      SlidingWindowRateLimitInterceptor(
        config: const SlidingWindowRateLimitConfig(
          requestsPerWindow: 30,
          windowSizeMs: 60000,
          maxDelayMs: 10000,
        ),
      ),
      if (refreshToken != null && refreshToken.isNotEmpty)
        createEshuushuuAuthInterceptor(
          refreshToken: refreshToken,
          baseUrl: config.url,
          onLog: (message) => loggerService.info('Auth', message),
          onAuthFailed: () {
            showSessionExpiredDialog(
              onReLogin: () {
                if (configId != null) {
                  ref
                      .read(routerProvider)
                      .push(
                        Uri(
                          path: '/boorus/$configId/update',
                          queryParameters: {'q': 'auth'},
                        ).toString(),
                      );
                }
              },
            );
          },
          onTokenRefreshed: (tokens) {
            if (configId == null) {
              loggerService.warn(
                'Auth',
                'No config id resolved; rotated refresh token not persisted',
              );
              return;
            }
            final expectedRefreshToken = expectedPersistedRefreshToken;
            expectedPersistedRefreshToken = tokens.refreshToken;
            unawaited(
              updateBooruConfigAtomically(
                repository: ref.read(booruConfigRepoProvider),
                id: configId,
                transform: (current) => current.apiKey == expectedRefreshToken
                    ? current.toBooruConfigData().copyWith(
                        apiKey: tokens.refreshToken,
                      )
                    : null,
              ).then((updated) {
                if (updated == null) {
                  loggerService.warn(
                    'Auth',
                    'Config $configId changed or no longer exists; token not persisted',
                  );
                } else {
                  loggerService.info(
                    'Auth',
                    'Persisted rotated refresh token for config $configId',
                  );
                }
              }),
            );
          },
        ),
    ],
  );
});
