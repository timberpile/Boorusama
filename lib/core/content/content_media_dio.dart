import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../configs/config/types.dart';

import '../http/client/providers.dart';
import '../http/client/src/data/source_media_http_adapter.dart';
import 'content_access.dart';
import 'content_access_provider.dart';

/// A scoped facade over the engine's existing transport. Account interceptors
/// cannot replay a media redirect outside the final adapter's header boundary.
final contentMediaDioProvider = Provider.autoDispose
    .family<Dio, ContentAccessKey>((ref, key) {
      final context = ref.watch(contentAccessContextProvider(key));
      final config = context?.config;
      if (context == null || config == null)
        throw StateError('Media access unavailable');
      if (config.anonymousReadScope case final scope?) {
        if (!scope.isCurrent) throw StateError('Media access unavailable');
        return ref.watch(dioForWidgetProvider(config.auth));
      }
      final source = ref.watch(dioForWidgetProvider(config.auth));
      var active = true;
      final facade = Dio(source.options.copyWith(queryParameters: const {}));
      facade.httpClientAdapter = SourceMediaHttpClientAdapter(
        delegate: source.httpClientAdapter,
        source: context.baseUrl,
        current: () =>
            active &&
            identical(ref.read(contentAccessContextProvider(key)), context),
      );
      ref.onDispose(() {
        active = false;
        facade.close(force: true);
      });
      return facade;
    }, dependencies: [contentAccessContextProvider, dioForWidgetProvider]);
