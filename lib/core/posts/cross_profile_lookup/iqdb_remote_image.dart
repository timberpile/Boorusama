import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../configs/config/types.dart';
import '../../configs/manage/providers.dart';
import '../../configs/network/providers.dart';
import '../../content/content_access.dart';
import '../../content/content_access_provider.dart';
import '../../content/content_media_access.dart';
import '../../content/content_media_dio.dart';
import '../../http/client/providers.dart';
import '../../http/client/src/coordination/api_request_context.dart';
import '../post/types.dart';
import 'iqdb_lookup.dart';
import 'iqdb_signature.dart';

ContentAccessContext? lookupSourceAccess(
  WidgetRef ref,
  Post source, {
  ContentAccessContext? accessOverride,
}) {
  final inherited = ref.read(currentContentAccessKeyProvider);
  final hint = source.origin.profileIdHint;
  ContentAccessContext? access;
  if (accessOverride != null) {
    access = ref.read(contentAccessContextProvider(accessOverride.key));
  } else if (inherited != null) {
    access = ref.read(contentAccessContextProvider(inherited));
  } else if (!ref.read(contentAccessRequiredProvider)) {
    final resolution = const PostOriginResolver().resolve(
      source.origin,
      ref.read(booruConfigProvider),
      allowProfileHintFallback: false,
    );
    if (resolution case ResolvedPostOrigin(:final config)) {
      access = ref.read(contentProfileAccessProvider(config.id));
    }
  }
  if (access == null ||
      source.origin.booruType != access.key.engine ||
      source.origin.sourceHost != access.key.siteNamespace ||
      (hint != null && hint != access.key.profileId)) {
    return null;
  }
  return access;
}

Future<String?> remoteIqdbSignature(
  WidgetRef ref,
  Post source,
  ContentAccessContext access,
  bool Function() stopped,
) async {
  final profile = access.config;
  if (profile == null || stopped()) return null;
  final visibility = contentPostVisibilityProvider((
    access: access.key,
    post: source,
  ));
  final ready = Completer<bool>();
  bool current() {
    if (stopped() ||
        !identical(
          ref.read(contentAccessContextProvider(access.key)),
          access,
        )) {
      return false;
    }
    final state = ref.read(visibility);
    return !state.isLoading && (state.asData?.value ?? false);
  }

  final subscriptions = [
    ref.listenManual(visibility, (_, next) {
      if (!ready.isCompleted && !next.isLoading) {
        ready.complete(next.asData?.value ?? false);
      }
    }, fireImmediately: true),
    ref.listenManual(contentAccessContextProvider(access.key), (_, _) {}),
    ref.listenManual(contentMediaDioProvider(access.key), (_, _) {}),
  ];
  try {
    const timeout = Duration(seconds: 15);
    if (!await ready.future.timeout(timeout) || !current()) return null;
    final dio = ref.read(contentMediaDioProvider(access.key));
    final network = ref.read(networkSettingsProvider(profile.auth));
    final headers = ref.read(httpHeadersProvider(profile.auth));
    for (final url in {source.sampleImageUrl, source.originalImageUrl}) {
      if (!current()) return null;
      final request = network.resolveMedia(
        url,
        headers: headers,
        sourceUrl: profile.url,
      );
      final uri = Uri.tryParse(request.url);
      final publicPolicy = profile.anonymousReadScope?.source;
      if (uri == null ||
          uri.scheme != 'https' ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty ||
          (publicPolicy != null && !publicPolicy.allowsMedia(uri))) {
        continue;
      }
      final cancellation = CancelToken();
      try {
        final response = await dio
            .get<ResponseBody>(
              request.url,
              cancelToken: cancellation,
              options: Options(
                headers: request.headers,
                responseType: ResponseType.stream,
                extra: const {apiMediaRequestKey: true},
                followRedirects: false,
                receiveTimeout: timeout,
              ),
            )
            .timeout(timeout);
        final body = response.data;
        if (body == null || !current()) continue;
        final bytes = await readIqdbBytes(
          body.stream,
          iqdbImageByteLimit,
          current,
        ).timeout(timeout);
        if (bytes == null || !current()) continue;
        final signature = await iqdbSignatureFromBytes(bytes);
        if (signature != null && current()) return signature;
      } catch (_) {
        // A missing or unsupported sample can still have a usable original.
      } finally {
        cancellation.cancel();
      }
    }
  } catch (_) {
    // Policy or media access failed before a usable image was acquired.
  } finally {
    for (final subscription in subscriptions) {
      subscription.close();
    }
  }
  return null;
}
