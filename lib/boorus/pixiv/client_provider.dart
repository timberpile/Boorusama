// Dart imports:
import 'dart:async';
import 'dart:convert';

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

        unawaited(
          persistPixivRotatedToken(
            repo: ref.read(booruConfigRepoProvider),
            configId: configId,
            tokens: tokens,
            onLog: (message) => loggerService.info(_kLogService, message),
          ),
        );
      },
    ),
    _ => null,
  };

  final dio = newDio(
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
      // FIX 7c: conservative bound (eshuushuu's 30/60s), not the app's
      // default 10 requests/second — Pixiv's app-api is more sensitive to
      // bursts than the boorus this default was tuned for.
      SlidingWindowRateLimitInterceptor(
        config: const SlidingWindowRateLimitConfig(
          requestsPerWindow: 30,
          windowSizeMs: 60000,
          maxDelayMs: 10000,
        ),
      ),
      // FIX 7c: a "Rate Limit" response (or a plain HTTP 429) actually
      // suppresses further requests on this Dio for 300s, rather than only
      // surfacing an error for the one call that hit it.
      PixivRateLimitSuppressionInterceptor(),
      // Installed last so its 401 retry re-enters the chain above it — the
      // retry is paced by the rate limiter rather than sneaking past it.
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
int? resolvePixivConfigId(List<BooruConfig> configs, BooruConfigAuth auth) =>
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
  required int configId,
  required PixivTokens tokens,
  void Function(String message)? onLog,
  DateTime? now,
}) async {
  final refreshToken = tokens.refreshToken;

  if (refreshToken == null || refreshToken.isEmpty) {
    onLog?.call('Token response carried no refresh token; nothing persisted');
    return;
  }

  final configs = await repo.getAll();
  final current = configs.firstWhereOrNull((c) => c.id == configId);

  if (current == null) {
    onLog?.call('Config $configId no longer exists; nothing persisted');
    return;
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

  await repo.update(
    configId,
    current.toBooruConfigData().copyWith(
      apiKey: refreshToken,
      passHash: () => extraData.toPassHash(),
    ),
  );

  onLog?.call('Persisted rotated refresh token for config $configId');
}

/// Suppresses further requests on a Pixiv Dio for a back-off window after a
/// "Rate Limit" response, instead of merely letting that one call fail.
///
/// [SlidingWindowRateLimitInterceptor] paces requests but does not react to
/// what the server says about them — Pixiv's rate-limit signal can also
/// arrive as an `{"error": {"message": "Rate Limit ..."}}` body on an HTTP
/// 200, which a pure status-code check would miss entirely (see
/// `pixiv_client.dart`'s error-envelope handling).
class PixivRateLimitSuppressionInterceptor extends Interceptor {
  PixivRateLimitSuppressionInterceptor({
    this.backOff = const Duration(seconds: 300),
  });

  final Duration backOff;

  DateTime? _blockedUntil;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    final blockedUntil = _blockedUntil;

    if (blockedUntil != null) {
      if (DateTime.now().isBefore(blockedUntil)) {
        handler.reject(
          DioException(
            requestOptions: options,
            type: DioExceptionType.cancel,
            error: 'Pixiv rate limit active, retrying later',
          ),
        );
        return;
      }

      _blockedUntil = null;
    }

    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    if (_looksRateLimited(response.data)) {
      _blockedUntil = DateTime.now().add(backOff);
    }

    handler.next(response);
  }

  @override
  void onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) {
    if (err.response?.statusCode == 429 ||
        _looksRateLimited(err.response?.data)) {
      _blockedUntil = DateTime.now().add(backOff);
    }

    handler.next(err);
  }

  static bool _looksRateLimited(dynamic data) {
    final decoded = switch (data) {
      final String s when s.isNotEmpty => _tryDecode(s),
      final Map<dynamic, dynamic> m => m,
      _ => null,
    };

    final message = switch (decoded) {
      final Map<dynamic, dynamic> m => switch (m['error']) {
        final Map<dynamic, dynamic> error =>
          (error['message'] ?? error['user_message'] ?? '').toString(),
        _ => '',
      },
      _ => '',
    };

    return message.toLowerCase().contains('rate limit');
  }

  static dynamic _tryDecode(String s) {
    try {
      return jsonDecode(s);
    } catch (_) {
      return null;
    }
  }
}
