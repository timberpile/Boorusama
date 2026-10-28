import 'package:coreutils/coreutils.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/configs/config/types.dart';
import '../client_provider.dart';
import '../downloads/url_provider.dart';

final animePicturesMediaDioProvider = Provider.family<Dio, BooruConfigAuth>((
  ref,
  config,
) {
  final resolver = ref.watch(
    animePicturesDownloadFileUrlExtractorProvider(config),
  );
  final dio = createAnimePicturesDio(ref, config);
  dio.interceptors.add(
    AnimePicturesMediaCookieInterceptor(resolver.cookieForMediaUrl),
  );
  ref.onDispose(dio.close);
  return dio;
});

final class AnimePicturesMediaCookieInterceptor extends Interceptor {
  AnimePicturesMediaCookieInterceptor(this.cookieForUrl);
  final String? Function(String) cookieForUrl;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final cookie = cookieForUrl(options.uri.toString());
    if (cookie != null)
      options.headers['cookie'] = CookieUtils.mergeCookieHeaders(
        options.headers['cookie']?.toString() ?? '',
        cookie,
      );
    handler.next(options);
  }
}
