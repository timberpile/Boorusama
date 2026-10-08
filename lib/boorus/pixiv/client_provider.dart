// Dart imports:
import 'dart:async';

// Package imports:
import 'package:booru_clients/pixiv.dart';
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
import '../../core/http/client/coordination.dart';
import '../../core/router.dart';
import '../../foundation/loggers.dart';
import 'auth/auth_interceptor.dart';
import 'auth/session_expired_dialog.dart';
import 'configs/extra_data.dart';

const _kLogService = 'Pixiv Auth';

/// `PixivClient` is immutable per access token, but Pixiv's access token
/// lives one hour and is rotated in the background. Rather than rebuilding
/// the client (and this whole provider family) every time it rotates, the
/// live `Authorization` header is owned by [PixivAuthInterceptor], which
/// replaces this placeholder on every outgoing request.
///
/// `config.apiKey` deliberately is NOT used as the bearer: it holds the
/// long-lived *refresh* token, which the app-api never accepts.
const _kPlaceholderAccessToken = '';

final pixivOAuthDioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(baseUrl: kPixivOAuthBaseUrl, followRedirects: false),
  );
  coordinateApiDio(dio, ref.watch(apiRequestCoordinatorProvider));
  return dio;
});

final pixivClientProvider = Provider.family<PixivClient, BooruConfigAuth>((
  ref,
  config,
) {
  final dio = ref.watch(pixivDioProvider(config));

  return PixivClient(
    accessToken: _kPlaceholderAccessToken,
    dio: dio,
  );
});

final pixivDioProvider = Provider.family<Dio, BooruConfigAuth>((ref, config) {
  final ddosProtectionHandler = ref.watch(httpDdosProtectionBypassProvider);
  final loggerService = ref.watch(loggerProvider);

  final refreshToken = config.apiKey;
  var expectedPersistedRefreshToken = refreshToken;

  // FIX 6c: the config id is resolved ONCE here, at Dio build time, and
  // closed over by the callbacks below. Matching on `url` + `login` the way
  // eshuushuu does would be a cross-account credential overwrite here:
  // Pixiv is single-site, so every Pixiv profile shares `config.url`, and
  // the account identity lives in `passHash`, not `login` — profile A's
  // rotated token would land in profile B's record.
  //
  // Read, not watched: re-resolving on every config change would rebuild
  // this Dio mid-flight and drop the in-memory access token.
  final configId = resolvePixivConfigId(ref.read(booruConfigProvider), config);

  final authInterceptor = switch (refreshToken) {
    final String token when token.isNotEmpty => PixivAuthInterceptor(
      refreshToken: token,
      refresher: (current) => ref.read(apiAuthRefreshRegistryProvider).run(
        (
          'pixiv',
          PixivExtraData.fromPassHash(config.passHash).userId ??
              ref
                  .read(apiAuthRefreshRegistryProvider)
                  .opaqueCredentialIdentity(token),
        ),
        () => createPixivAuthClient(
          dio: ref.read(pixivOAuthDioProvider),
        ).refresh(refreshToken: current),
      ),
      onLog: (message) => loggerService.info(_kLogService, message),
      onAuthFailed: () => showPixivSessionExpiredDialog(
        onReLogin: () {
          if (configId == null) return;

          ref
              .read(routerProvider)
              .push(
                Uri(
                  path: '/boorus/$configId/update',
                  queryParameters: {'q': 'auth'},
                ).toString(),
              );
        },
      ),
      onTokenRefreshed: (tokens) {
        if (configId == null) {
          loggerService.warn(
            _kLogService,
            'No config id resolved; rotated refresh token not persisted',
          );
          return;
        }

        final expectedRefreshToken = expectedPersistedRefreshToken;
        if (tokens.refreshToken case final String rotated
            when rotated.isNotEmpty) {
          expectedPersistedRefreshToken = rotated;
        }
        unawaited(
          persistPixivRotatedToken(
            repo: ref.read(booruConfigRepoProvider),
            configId: configId,
            tokens: tokens,
            expectedRefreshToken: expectedRefreshToken,
            onLog: (message) => loggerService.info(_kLogService, message),
          ),
        );
      },
    ),
    _ => null,
  };

  final dio = newDio(
    apiCoordinator: ref.watch(apiRequestCoordinatorProvider),
    options: DioOptions(
      ddosProtectionHandler: ddosProtectionHandler,
      userAgent: ref.watch(defaultUserAgentProvider),
      loggerService: loggerService,
      networkProtocolInfo: ref.watch(
        defaultNetworkProtocolInfoProvider(config),
      ),
      baseUrl: kPixivApiBaseUrl,
      proxySettings: config.proxySettings,
      // FIX 7b: `skipCertificateVerification` is deliberately never passed
      // here (the default is `false` and stays that way), even though the
      // per-config UI exposes a toggle for it — this Dio carries a
      // full-account bearer token and must never allow that toggle to
      // disable TLS validation on it.
    ),
    additionalInterceptors: [
      ?authInterceptor,
    ],
  );

  // FIX 7b: authenticated calls must not follow a redirect blind.
  dio.options.followRedirects = false;

  // FIX 6e: the interceptor retries a refreshed 401 on THIS Dio (with a
  // re-entrancy marker in `options.extra`) instead of a throwaway
  // `Dio(BaseOptions(...))`, so the retry keeps the proxy settings,
  // protocol selection and rate limiting configured above.
  authInterceptor?.attach(dio);

  return dio;
});

/// Finds the stored config record this auth record belongs to.
///
/// Matching the whole [BooruConfigAuth] is exactly as precise as the key of
/// the provider family it identifies — two records that compare equal would
/// share one Dio anyway — and unlike a `url` + `login` match it cannot
/// confuse two Pixiv profiles, whose identity lives in `passHash`.
String? resolvePixivConfigId(List<BooruConfig> configs, BooruConfigAuth auth) =>
    configs.firstWhereOrNull((c) => BooruConfigAuth.fromConfig(c) == auth)?.id;

/// Persists a rotated refresh token (and the account metadata that came with
/// it) against the config record identified by [configId].
///
/// FIX 6b: the record is RE-READ from [repo] by id first, so this write
/// merges into whatever is actually stored rather than into a possibly stale
/// cached copy. FIX 6d: it deliberately does not touch `BooruConfigNotifier`
/// state — `BooruConfigAuth.props` includes `apiKey`, so doing that would
/// rebuild the family-keyed Dio mid-flight, drop the in-memory access token
/// and immediately trigger another refresh.
Future<void> persistPixivRotatedToken({
  required BooruConfigRepository repo,
  required String configId,
  required PixivTokens tokens,
  String? expectedRefreshToken,
  void Function(String message)? onLog,
  DateTime? now,
}) async {
  final refreshToken = tokens.refreshToken;

  if (refreshToken == null || refreshToken.isEmpty) {
    onLog?.call('Token response carried no refresh token; nothing persisted');
    return;
  }

  final updated = await updateBooruConfigAtomically(
    repository: repo,
    id: configId,
    transform: (current) {
      if (expectedRefreshToken != null &&
          current.apiKey != expectedRefreshToken) {
        return null;
      }
      final stored = PixivExtraData.fromPassHash(current.passHash);
      final user = tokens.user;
      final expiresIn = tokens.expiresIn;
      final extraData = PixivExtraData(
        userId: user?.id ?? stored.userId,
        userName: user?.name ?? stored.userName,
        isPremium: user?.isPremium ?? stored.isPremium,
        xRestrict: user?.xRestrict ?? stored.xRestrict,
        tokenExpiry: expiresIn == null
            ? stored.tokenExpiry
            : (now ?? DateTime.now()).add(Duration(seconds: expiresIn)),
      );
      return current.toBooruConfigData().copyWith(
        apiKey: refreshToken,
        passHash: () => extraData.toPassHash(),
      );
    },
  );

  if (updated == null) {
    onLog?.call(
      'Config $configId changed or no longer exists; nothing persisted',
    );
    return;
  }

  onLog?.call('Persisted rotated refresh token for config $configId');
}
