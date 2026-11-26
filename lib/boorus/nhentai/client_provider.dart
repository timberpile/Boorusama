import 'package:booru_clients/nhentai.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/boorus/booru/types.dart';
import '../../core/configs/config/types.dart';
import '../../core/content/anonymous_access_provider.dart';
import '../../core/content/nhentai_public_transport.dart';
import '../../core/http/client/providers.dart';
import 'availability.dart';

final nhentaiDioProvider = Provider.family<Dio, BooruConfigAuth>((ref, config) {
  final available = ref.watch(nhentaiAvailableProvider);
  final site = Uri.tryParse(config.url);
  final source = site == null
      ? null
      : ref
            .watch(anonymousSourcePolicyProvider)
            .resolve(BooruType.nhentai, site);
  if (!available || config.booruType != BooruType.nhentai || source == null) {
    throw const FormatException('Unavailable Gallery source');
  }
  if (config.anonymousReadScope case final scope?) return scope.dio;

  var current = true;
  final dio = newGenericDio(
    baseUrl: source.site.toString(),
    userAgent: ref.watch(defaultUserAgentProvider),
    apiCoordinator: ref.watch(apiRequestCoordinatorProvider),
    headers: {'Referer': source.site.toString()},
  );
  dio.httpClientAdapter = NhentaiPublicTransport(
    dio: dio,
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

final nhentaiMediaPolicyProvider =
    FutureProvider.family<NhentaiMediaPolicy, BooruConfigAuth>((ref, config) {
      final dio = ref.watch(nhentaiDioProvider(config));
      return NhentaiPublicTransport.of(dio).mediaPolicy();
    });

void refreshNhentaiMediaPolicy(WidgetRef ref, BooruConfigAuth config) {
  final dio = ref.read(nhentaiDioProvider(config));
  NhentaiPublicTransport.of(dio).invalidateMediaPolicy();
  ref.invalidate(nhentaiMediaPolicyProvider(config));
}
