// Package imports:
import 'package:booru_clients/e621.dart';
import 'package:coreutils/coreutils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../core/configs/config/types.dart';
import '../../core/http/client/providers.dart';

final e621ClientProvider = Provider.family<E621Client, BooruConfigAuth>((
  ref,
  config,
) {
  final dio = ref.watch(defaultDioProvider(config));
  if (config.apiKey?.isNotEmpty ?? false) {
    dio.options.extra[privateRequestDiagnosticsKey] = true;
  }

  return E621Client(
    baseUrl: config.url,
    dio: dio,
    login: config.login,
    apiKey: config.apiKey,
  );
});
