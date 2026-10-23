import 'dart:typed_data';

import 'package:boorusama/core/developer_options/providers.dart';
import 'package:boorusama/core/http/client/coordination.dart';
import 'package:boorusama/core/posts/post/providers.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/search/following_topics/src/providers/untracked_topic_preview_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';

import 'following_topic_test_utils.dart';
import 'topic_test_utils.dart';

void main() {
  for (final scenario in ['success', 'busy', 'rate-limited']) {
    test(
      'preview transport honors admission and one-page/no-replay bounds: $scenario',
      () async {
        final coordinator = ApiRequestCoordinator();
        addTearDown(coordinator.dispose);
        final quota = ApiQuotaKey.fromUri(Uri.parse(testProfile.url));
        final held = <ApiRequestPermit>[];
        if (scenario == 'busy') {
          for (var i = 0; i < 4; i++) {
            held.add(await coordinator.acquire(quota));
          }
        }
        addTearDown(() {
          for (final permit in held) {
            permit.abandon();
          }
        });
        final transport = _Transport(
          status: scenario == 'rate-limited' ? 429 : 200,
        );
        final dio = Dio(BaseOptions(baseUrl: testProfile.url))
          ..httpClientAdapter = transport;
        coordinateApiDio(dio, coordinator);
        addTearDown(() => dio.close(force: true));
        final container = ProviderContainer(
          overrides: [
            automaticMediaLoadingEnabledProvider.overrideWithValue(true),
            originAwarePostRepoProvider.overrideWith((ref, config) {
              expect(config, testProfile);
              return TestSearchPostRepository((query, page, limit) async {
                await dio.get(
                  '/posts.json',
                  queryParameters: {
                    'tags': query,
                    'page': page,
                    'limit': limit,
                  },
                );
                return Either.of(
                  PostResult(posts: [testSearchPost(1, null)], total: 1),
                );
              });
            }),
          ],
        );
        addTearDown(container.dispose);
        final provider = untrackedTopicPreviewProvider((
          config: testProfile,
          query: 'cat rating:safe',
          structure: null,
          revision: 0,
          attemptedAt: null,
        ));
        final listener = container.listen(provider, (_, _) {});
        addTearDown(listener.close);
        if (scenario == 'success') {
          expect(await container.read(provider.future), [
            'https://example.com/1-thumb.jpg',
          ]);
        } else {
          await expectLater(
            container.read(provider.future),
            throwsA(isA<DioException>()),
          );
        }
        expect(transport.requests, hasLength(scenario == 'busy' ? 0 : 1));
        expect(coordinator.snapshot(quota).queued, 0);
        expect(
          coordinator.snapshot(quota).inFlight,
          scenario == 'busy' ? 4 : 0,
        );
        if (transport.requests case [final request]) {
          expect(request.uri.host, 'active.example');
          expect(request.queryParameters, {
            'tags': 'cat rating:safe',
            'page': 1,
            'limit': 4,
          });
          expect(
            apiRequestContextFor(request).requestClass,
            ApiRequestClass.preload,
          );
          expect(apiRequestContextFor(request).allowCooldownRetry, isFalse);
        }
        if (scenario == 'rate-limited') {
          expect(coordinator.snapshot(quota).retryAt, isNotNull);
        }
      },
    );
  }
}

class _Transport implements HttpClientAdapter {
  _Transport({required this.status});
  final int status;
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      '[]',
      status,
      headers: {
        'content-type': ['application/json'],
        if (status == 429) 'retry-after': ['120'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
