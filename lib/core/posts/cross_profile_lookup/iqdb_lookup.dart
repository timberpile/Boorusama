import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:booru_clients/danbooru.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../boorus/danbooru/posts/post/src/converter.dart';
import '../../blacklists/providers.dart';
import '../../configs/config/types.dart';
import '../../configs/manage/providers.dart';
import '../../http/client/coordination.dart';
import '../../http/client/providers.dart';
import '../../proxy/client.dart';
import '../post/providers.dart';
import '../post/types.dart';
import 'lookup_preferences.dart';
import 'providers.dart';
import 'types.dart';

const minimumVisibleIqdbScore = 70.0;

typedef IqdbHit = ({
  BooruConfig profile,
  String postId,
  double score,
  Post? post,
});

typedef IqdbSearch = Future<List<IqdbHit>?> Function(
  LookupTarget target,
  String signature,
  IqdbPermission permission,
  bool Function() stopped,
);

@visibleForTesting
final iqdbAdapterFactoryProvider =
    Provider<HttpClientAdapter Function(BooruConfig)>(
      (ref) =>
          (profile) => switch (profile.proxySettings) {
            final proxy? => IOHttpClientAdapter(
              createHttpClient: () =>
                  createProxyHttpClient(proxy)..badCertificateCallback = null,
            ),
            null => HttpClientAdapter(),
          },
    );

final iqdbSearchProvider = Provider<IqdbSearch>((ref) {
  final coordinator = ref.watch(apiRequestCoordinatorProvider);
  final createAdapter = ref.watch(iqdbAdapterFactoryProvider);
  var disposed = false;
  ref.onDispose(() => disposed = true);
  return (target, signature, permission, stopped) async {
    final profile = target.profile;
    bool current() {
      if (disposed || stopped()) return false;
      final preferences = ref.read(lookupPreferencesProvider);
      return preferences.permits(permission) &&
          stillSelected(
            preferences,
            target,
            PostLookupMatchKind.similarImage,
          ) &&
          ref.read(booruConfigProvider).contains(profile);
    }

    final endpoint = iqdbLookupEndpoint(profile);
    if (endpoint == null ||
        !current() ||
        !target.methods.contains(PostLookupMatchKind.similarImage) ||
        !supportsIqdbLookup(profile) ||
        !_signaturePattern.hasMatch(signature)) {
      return null;
    }
    final origin = postOriginFromConfig(profile);
    final filter = blacklistTagsProvider(profile.filter);
    final subscription = ref.listen(filter, (_, _) {});
    try {
      await ref.read(filter.future).timeout(_requestLimit);
      if (!current()) return null;
      final data = await _request(
        endpoint,
        profile,
        signature,
        current,
        coordinator: coordinator,
        adapter: createAdapter(profile),
      );
      if (data == null || !current()) return null;
      final filterState = ref.read(filter);
      final tags = filterState.isLoading ? null : filterState.asData?.value;
      if (tags == null) return null;
      final hits = <IqdbHit>[];
      for (final dto in data) {
        final id = dto.postId;
        final score = dto.score;
        if (id == null ||
            id <= 0 ||
            score == null ||
            !score.isFinite ||
            score < 0 ||
            score > 100) {
          return null;
        }
        final raw = dto.post;
        if (raw != null && raw.id != id) return null;
        // The API omits file URLs when its visibility policy hides a post.
        final post =
            raw == null ||
                (endpoint.host == 'safebooru.donmai.us' &&
                    (raw.rating != 'g' || (raw.fileUrl?.isEmpty ?? true)))
            ? null
            : postDtoToPostNoMetadata(raw).copyWith(origin: origin);
        hits.add((
          profile: profile,
          postId: id.toString(),
          score: score,
          post: post != null && isExactLookupPostVisible(post, profile, tags)
              ? post
              : null,
        ));
      }
      return hits;
    } on DioException catch (error) {
      if (error.error case final ApiCooldownException cooldown when current()) {
        throw cooldown;
      }
      return null;
    } catch (_) {
      return null;
    } finally {
      subscription.close();
    }
  };
});

final _signaturePattern = RegExp(r'^iqdb_[0-9a-f]{528}$');
const _requestLimit = Duration(seconds: 15);
const _maxResponseBytes = 1024 * 1024;
const _resultLimit = 10;

Future<List<IqdbResultDto>?> _request(
  Uri endpoint,
  BooruConfig profile,
  String signature,
  bool Function() current, {
  required ApiRequestCoordinator coordinator,
  required HttpClientAdapter adapter,
}) async {
  final auth = profile.auth;
  final credentials = base64Encode(
    utf8.encode('${auth.login!.trim()}:${auth.apiKey!.trim()}'),
  );
  final dio = Dio(
    BaseOptions(
      connectTimeout: _requestLimit,
      receiveTimeout: _requestLimit,
      followRedirects: false,
      receiveDataWhenStatusError: false,
      responseType: ResponseType.stream,
      headers: {
        'Authorization': 'Basic $credentials',
        'Accept': 'application/json',
        'User-Agent': 'Boorusama',
      },
    ),
  );
  dio.httpClientAdapter = adapter;
  coordinateApiDio(dio, coordinator);

  final caller = ApiRequestContext.current();
  final cancellation = CancelToken();
  Timer? responseDeadline;
  bool canStart() => current() && (caller.canStart?.call() ?? true);
  try {
    final response = await dio.getUri<ResponseBody>(
      endpoint.replace(
        queryParameters: {'hash': signature, 'limit': '$_resultLimit'},
      ),
      options: Options(
        extra: {
          apiRequestContextKey: ApiRequestContext(
            requestClassResolver: () => caller.requestClass,
            allowCooldownRetryResolver: () => caller.allowCooldownRetry,
            admissionBehavior: caller.admissionBehavior,
            cancelToken: caller.cancelToken,
            canStart: canStart,
            canAdmit: caller.canAdmit,
            changes: caller.changes,
            onDataTransport: caller.onDataTransport,
            onStarted: () {
              // Coordinator admission may wait for another request or a refill.
              // Start the transport deadline only when this request dispatches.
              caller.onStarted?.call();
              responseDeadline?.cancel();
              responseDeadline = Timer(_requestLimit, cancellation.cancel);
            },
          ),
        },
      ),
      cancelToken: cancellation,
    );
    responseDeadline?.cancel();
    final body = response.data;
    if (body == null) return null;
    if (!current()) {
      await body.stream.listen(null).cancel();
      return null;
    }
    final bytes = await readIqdbBytes(
      body.stream,
      _maxResponseBytes,
      current,
    ).timeout(_requestLimit);
    if (bytes == null || !current()) return null;
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! List || decoded.length > _resultLimit) return null;
    return [
      for (final row in decoded)
        IqdbResultDto.fromJson(row as Map<String, dynamic>),
    ];
  } finally {
    responseDeadline?.cancel();
    cancellation.cancel();
    dio.close(force: true);
  }
}

Future<Uint8List?> readIqdbBytes(
  Stream<Uint8List> chunks,
  int limit,
  bool Function() current,
) async {
  final buffer = BytesBuilder(copy: false);
  await for (final chunk in chunks) {
    if (!current() || buffer.length + chunk.length > limit) return null;
    buffer.add(chunk);
  }
  return current() ? buffer.takeBytes() : null;
}

typedef IqdbCandidates = ({
  IqdbHit? automatic,
  List<IqdbHit> visible,
});

IqdbCandidates rankIqdbHits(Iterable<IqdbHit> hits, int threshold) {
  // Both Donmai hosts share the same post IDs.
  final distinct = <String, IqdbHit>{};
  for (final hit in hits) {
    final key = hit.postId;
    final previous = distinct[key];
    if (previous == null ||
        hit.score > previous.score ||
        (hit.score == previous.score && previous.post == null)) {
      distinct[key] = hit;
    }
  }
  final ranked = distinct.values.toList()
    ..sort((a, b) => b.score.compareTo(a.score));
  final best = ranked.firstOrNull;
  final automatic =
      best != null &&
      best.post != null &&
      best.score >= threshold &&
      (ranked.length < 2 || best.score > ranked[1].score);
  // A duplicate can be visible under one configured account and hidden under
  // another. Preserve an eligible review candidate without promoting its score.
  final visible = <String, IqdbHit>{};
  for (final hit in hits) {
    if (hit.post == null || hit.score < minimumVisibleIqdbScore) continue;
    final key = hit.postId;
    if ((visible[key]?.score ?? -1) < hit.score) visible[key] = hit;
  }
  return (
    automatic: automatic ? best : null,
    visible: visible.values.toList()
      ..sort((a, b) => b.score.compareTo(a.score)),
  );
}

bool isCurrentIqdbHit(Ref ref, IqdbHit hit) {
  final post = hit.post;
  if (post == null || !ref.read(booruConfigProvider).contains(hit.profile)) {
    return false;
  }
  final state = ref.read(blacklistTagsProvider(hit.profile.filter));
  final tags = state.isLoading ? null : state.asData?.value;
  return tags != null && isExactLookupPostVisible(post, hit.profile, tags);
}
