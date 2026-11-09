import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../configs/config/types.dart';
import '../configs/network/providers.dart';

import '../http/client/providers.dart';
import '../http/client/src/data/source_media_http_adapter.dart';
import '../images/media_diagnostics.dart';
import 'content_access.dart';
import 'content_access_provider.dart';

/// A scoped facade over the engine's existing transport. Account interceptors
/// cannot replay a media redirect outside the final adapter's header boundary.
final contentMediaDioProvider = Provider.autoDispose
    .family<Dio, ContentAccessKey>(
      (ref, key) {
        final context = ref.watch(contentAccessContextProvider(key));
        final config = context?.config;
        Dio unavailable() {
          // Revocation is an expected state during reactive scope teardown. Keep
          // consumers inert without throwing from the provider rebuild itself.
          final denied = Dio()..httpClientAdapter = _UnavailableMediaAdapter();
          ref.onDispose(() => denied.close(force: true));
          return denied;
        }

        if (context == null || config == null) return unavailable();
        if (config.anonymousReadScope case final scope?) {
          if (!scope.isCurrent) return unavailable();
          return ref.watch(dioForWidgetProvider(config.auth));
        }
        final source = ref.watch(dioForWidgetProvider(config.auth));
        var active = true;
        final facade = Dio(
          source.options.copyWith(
            queryParameters: const {},
            followRedirects: true,
          ),
        );
        facade.httpClientAdapter = SourceMediaHttpClientAdapter(
          delegate: source.httpClientAdapter,
          source: context.baseUrl,
          mediaHostOverrides: ref
              .watch(networkSettingsProvider(config.auth))
              .activeMediaHostOverrides,
          diagnostics: ref.watch(mediaDiagnosticsProvider(config.auth)),
          current: () =>
              active &&
              identical(ref.read(contentAccessContextProvider(key)), context),
        );
        ref.onDispose(() {
          active = false;
          facade.close(force: true);
        });
        return facade;
      },
      dependencies: [
        contentAccessContextProvider,
        dioForWidgetProvider,
        networkSettingsProvider,
        mediaDiagnosticsProvider,
      ],
    );

final class _UnavailableMediaAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    throw DioException(
      requestOptions: options,
      type: DioExceptionType.cancel,
      message: 'Media access revoked',
    );
  }

  @override
  void close({bool force = false}) {}
}
