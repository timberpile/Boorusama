import 'package:booru_clients/nhentai.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/boorus/booru/types.dart';
import '../../core/configs/config/types.dart';
import '../../core/http/client/providers.dart';
import '../../core/http/client/src/data/public_read_http_adapter.dart';
import '../../core/content/anonymous_source_policy.dart';

final nhentaiDioProvider = Provider.family<Dio, BooruConfigAuth>((ref, config) {
  if (config.booruType != BooruType.nhentai ||
      Uri.tryParse(config.url)?.host != 'nhentai.net') {
    throw const FormatException('Foreign nhentai configuration');
  }
  if (config.anonymousReadScope case final scope?) return scope.dio;
  final source = const AnonymousSourcePolicy().resolve(
    BooruType.nhentai,
    Uri.parse('https://nhentai.net'),
  )!;
  var current = true;
  final dio = newGenericDio(
    baseUrl: source.site.toString(),
    userAgent: ref.watch(defaultUserAgentProvider),
    apiCoordinator: ref.watch(apiRequestCoordinatorProvider),
    headers: {'Referer': source.site.toString()},
    protocolInfo: ref.watch(defaultNetworkProtocolInfoProvider(config)),
    proxySettings: config.proxySettings,
  );
  dio.options
    ..connectTimeout = const Duration(seconds: 15)
    ..receiveTimeout = const Duration(seconds: 20);
  dio.httpClientAdapter = PublicReadHttpClientAdapter(
    delegate: dio.httpClientAdapter,
    source: source,
    current: () => current,
  );
  ref.onDispose(() {
    current = false;
    dio.close(force: true);
  });
  return dio;
});

final nhentaiClientProvider = Provider.family<NhentaiClient, BooruConfigAuth>(
  (ref, config) => NhentaiClient(dio: ref.watch(nhentaiDioProvider(config))),
);

/// The real CDN configuration is essential metadata, shared across visible
/// listing/Details observers; no media-host default is fabricated.
final nhentaiMediaPolicyProvider =
    FutureProvider.family<NhentaiMediaPolicy, BooruConfigAuth>((ref, config) {
      final token = CancelToken();
      ref.onDispose(() => token.cancel('nhentai media config disposed'));
      return ref
          .watch(nhentaiClientProvider(config))
          .getMediaPolicy(
            cancelToken: token,
          );
    });
