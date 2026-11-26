import 'dart:typed_data';

import 'package:booru_clients/nhentai.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/boorus/booru/types.dart';
import '../../../core/configs/config/types.dart';
import '../../../core/content/content_access_provider.dart';
import '../../../core/content/types.dart';
import '../../../core/http/client/coordination.dart';
import '../../../core/http/client/providers.dart';
import '../../../core/proxy/types.dart';

bool isNhentaiApiKey(String? key) =>
    key != null && RegExp(r'^[A-Za-z0-9_-]{16,256}$').hasMatch(key);

typedef NhentaiAccountConnection = ({Dio dio, NhentaiAccountClient client});

NhentaiAccountConnection newNhentaiAccountConnection({
  required String apiKey,
  required String userAgent,
  required ApiRequestCoordinator coordinator,
  required bool Function() current,
  ProxySettings? proxy,
}) {
  if (!isNhentaiApiKey(apiKey)) {
    throw const FormatException('Invalid nhentai API key');
  }
  final dio = newGenericDio(
    baseUrl: NhentaiClient.site.toString(),
    userAgent: userAgent,
    proxySettings: proxy,
  );
  dio.options
    ..connectTimeout = const Duration(seconds: 15)
    ..receiveTimeout = const Duration(seconds: 20);
  dio.httpClientAdapter = NhentaiAccountTransport(
    delegate: dio.httpClientAdapter,
    apiKey: apiKey,
    current: current,
  );
  coordinateApiDio(dio, coordinator);
  return (dio: dio, client: NhentaiAccountClient(dio: dio));
}

final nhentaiAccountClientProvider = Provider.autoDispose
    .family<NhentaiAccountClient?, ContentAccessKey>(
      (ref, key) {
        final access = ref.watch(contentAccessContextProvider(key));
        final profile = key.profileId;
        final config = access?.config?.auth;
        if (profile == null ||
            config == null ||
            config.anonymousReadScope != null ||
            !isNhentaiApiKey(config.apiKey) ||
            !isNhentaiProfile(config)) {
          return null;
        }
        var open = true;
        final connection = newNhentaiAccountConnection(
          apiKey: config.apiKey!,
          userAgent: ref.watch(defaultUserAgentProvider),
          coordinator: ref.watch(apiRequestCoordinatorProvider),
          proxy: config.proxySettings,
          current: () =>
              open &&
              ref.read(contentProfileAccessProvider(profile))?.key == key,
        );
        ref.onDispose(() {
          open = false;
          connection.dio.close(force: true);
        });
        return connection.client;
      },
      dependencies: [
        contentAccessContextProvider,
        contentProfileAccessProvider,
      ],
    );

bool isNhentaiProfile(BooruConfigAuth config) {
  final uri = Uri.tryParse(config.url);
  return config.booruType == BooruType.nhentai &&
      uri != null &&
      (uri == NhentaiClient.site ||
          uri == NhentaiClient.site.replace(path: '/'));
}

/// Adds the key at the last HTTP boundary. Request options used by Dio,
/// request coordination and application error messages stay credential-free.
final class NhentaiAccountTransport implements HttpClientAdapter {
  NhentaiAccountTransport({
    required this.delegate,
    required String apiKey,
    required this.current,
  }) : _apiKey = apiKey;

  final HttpClientAdapter delegate;
  final bool Function() current;
  final String _apiKey;
  var _closed = false;

  static bool allows(Uri uri, String method) {
    if (uri.scheme != 'https' ||
        uri.host != 'nhentai.net' ||
        uri.port != 443 ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment) {
      return false;
    }
    if (uri.path == '/api/v2/user') return method == 'GET' && !uri.hasQuery;
    if (uri.path == '/api/v2/favorites') {
      final page = uri.queryParametersAll['page']?.singleOrNull;
      return method == 'GET' &&
          uri.queryParametersAll.length == 1 &&
          (int.tryParse(page ?? '') ?? 0) > 0;
    }
    return !uri.hasQuery &&
        const {'POST', 'DELETE'}.contains(method) &&
        RegExp(r'^/api/v2/galleries/[1-9][0-9]*/favorite$').hasMatch(uri.path);
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    _requireCurrent(options);
    if (!allows(options.uri, options.method) ||
        options.data != null ||
        requestStream != null) {
      throw DioException(
        requestOptions: options,
        message: 'Request is outside the nhentai account policy',
      );
    }
    final ResponseBody response;
    try {
      response = await delegate.fetch(
        options.copyWith(
          followRedirects: false,
          headers: {
            for (final header in options.headers.entries)
              if (const {
                'accept',
                'accept-encoding',
                'user-agent',
              }.contains(header.key.toLowerCase()))
                header.key: header.value,
            'Authorization': 'Key $_apiKey',
          },
        ),
        null,
        cancelFuture,
      );
    } on DioException catch (error) {
      // Adapter failures may carry the forwarded RequestOptions.
      throw DioException(
        requestOptions: options,
        type: error.type,
        message: 'nhentai account request failed',
      );
    }
    if (_closed || !current()) {
      await response.stream.listen(null).cancel();
      _requireCurrent(options);
    }
    response.stream = response.stream.map((bytes) {
      _requireCurrent(options);
      return bytes;
    });
    return response;
  }

  void _requireCurrent(RequestOptions options) {
    if (_closed || !current()) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.cancel,
        message: 'nhentai account changed',
      );
    }
  }

  @override
  void close({bool force = false}) {
    _closed = true;
    delegate.close(force: force);
  }
}
