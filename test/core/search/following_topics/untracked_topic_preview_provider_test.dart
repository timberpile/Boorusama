import 'dart:async';

import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/developer_options/providers.dart';
import 'package:boorusama/core/http/client/coordination.dart';
import 'package:boorusama/core/posts/post/providers.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/search/following_topics/src/providers/untracked_topic_preview_provider.dart';
import 'package:boorusama/core/search/following_topics/types.dart';
import 'package:boorusama/core/search/selected_tags/types.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_async/fake_async.dart';
import 'package:foundation/foundation.dart';

import 'following_topic_test_utils.dart';
import 'topic_test_utils.dart';

UntrackedTopicPreviewKey _key({
  BooruConfig? config,
  String query = 'cat',
  int revision = 0,
  SearchQueryStructure? structure,
  DateTime? attemptedAt,
}) => (
  config: config ?? testProfile,
  query: query,
  structure: structure,
  revision: revision,
  attemptedAt: attemptedAt,
);

void main() {
  test(
    'success is retained, rebuilds are stable, and refresh/owner/query isolate requests',
    () => fakeAsync((clock) {
      final calls = <(BooruConfig, String)>[];
      final repository = TestSearchPostRepository((query, page, limit) async {
        expect((page, limit), (1, 4));
        final context = ApiRequestContext.current();
        expect(context.requestClass, ApiRequestClass.preload);
        expect(
          context.admissionBehavior,
          ApiAdmissionBehavior.dropIfUnavailable,
        );
        expect(context.allowCooldownRetry, isFalse);
        return Either.of(
          PostResult(posts: [testSearchPost(1, null)], total: 1),
        );
      });
      final container = ProviderContainer(
        overrides: [
          automaticMediaLoadingEnabledProvider.overrideWithValue(true),
          originAwarePostRepoProvider.overrideWith(
            (ref, config) => _RecordingRepo(repository, (q, options) {
              calls.add((config, q));
              expect(options, PostFetchOptions.raw);
            }),
          ),
        ],
      );
      clock.flushMicrotasks();
      final provider = untrackedTopicPreviewProvider(_key());
      var subscription = container.listen(provider, (_, _) {});
      clock.flushMicrotasks();
      expect(container.read(provider).requireValue, [
        'https://example.com/1-thumb.jpg',
      ]);
      clock.elapse(Duration.zero);
      clock.flushMicrotasks();
      expect(calls, hasLength(1));
      subscription.close();
      clock.elapse(const Duration(minutes: 4));
      subscription = container.listen(provider, (_, _) {});
      expect(container.read(provider).requireValue, isNotEmpty);
      expect(calls, hasLength(1));
      // An observed card remains stable even after its keep-alive window expires.
      clock.elapse(const Duration(minutes: 2));
      expect(calls, hasLength(1));
      subscription.close();
      clock.elapse(Duration.zero);
      clock.flushMicrotasks();
      subscription = container.listen(provider, (_, _) {});
      clock.flushMicrotasks();
      expect(calls, hasLength(2));
      for (final key in [
        _key(query: 'dog'),
        _key(config: otherTestProfile),
        _key(revision: 1),
        _key(structure: SearchQueryStructure.typedTags(['cat'])),
        _key(attemptedAt: DateTime.utc(2026, 10, 22)),
        _key(
          config: testProfile.copyWith(apiKey: 'synthetic-preview-test-token'),
        ),
      ]) {
        final next = untrackedTopicPreviewProvider(key);
        final listener = container.listen(next, (_, _) {});
        clock.flushMicrotasks();
        listener.close();
      }
      expect(calls, hasLength(8));
      expect(calls.map((c) => c.$1.id).toSet(), {
        testProfile.id,
        otherTestProfile.id,
      });
      subscription.close();
      container.dispose();
    }),
  );

  test(
    'negative cache expires after thirty seconds',
    () => fakeAsync((clock) {
      var calls = 0;
      final container = ProviderContainer(
        overrides: [
          automaticMediaLoadingEnabledProvider.overrideWithValue(true),
          originAwarePostRepoProvider.overrideWith(
            (ref, _) => TestSearchPostRepository((_, _, _) async {
              calls++;
              throw StateError('preview unavailable');
            }),
          ),
        ],
      );
      clock.flushMicrotasks();
      final provider = untrackedTopicPreviewProvider(_key());
      var listener = container.listen(provider, (_, _) {});
      clock.flushMicrotasks();
      expect(container.read(provider).hasError, isTrue);
      listener.close();
      clock.elapse(const Duration(seconds: 29));
      listener = container.listen(provider, (_, _) {});
      expect(container.read(provider).hasError, isTrue);
      expect(calls, 1);
      listener.close();
      clock.elapse(const Duration(seconds: 2));
      listener = container.listen(provider, (_, _) {});
      clock.flushMicrotasks();
      expect(container.read(provider).hasError, isTrue);
      expect(calls, 2);
      listener.close();
      container.dispose();
    }),
  );

  test(
    'disabled media never constructs a post repository',
    () => fakeAsync((clock) {
      final container = ProviderContainer(
        overrides: [
          automaticMediaLoadingEnabledProvider.overrideWithValue(false),
          originAwarePostRepoProvider.overrideWith(
            (ref, _) => throw StateError('must not fetch'),
          ),
        ],
      );
      clock.flushMicrotasks();
      final provider = untrackedTopicPreviewProvider(_key());
      final listener = container.listen(provider, (_, _) {});
      clock.flushMicrotasks();
      expect(container.read(provider).requireValue, isEmpty);
      listener.close();
      container.dispose();
    }),
  );

  test(
    'disposal cancels in-flight work without retaining a stale result',
    () => fakeAsync((clock) {
      final started = Completer<ApiRequestContext>();
      final finish = Completer<void>();
      final container = ProviderContainer(
        overrides: [
          automaticMediaLoadingEnabledProvider.overrideWithValue(true),
          originAwarePostRepoProvider.overrideWith(
            (ref, _) => TestSearchPostRepository((_, _, _) async {
              started.complete(ApiRequestContext.current());
              await finish.future;
              return Either.of(
                PostResult(posts: [testSearchPost(1, null)], total: 1),
              );
            }),
          ),
        ],
      );
      clock.flushMicrotasks();
      final provider = untrackedTopicPreviewProvider(_key());
      final listener = container.listen(provider, (_, _) {});
      clock.flushMicrotasks();
      ApiRequestContext? context;
      started.future.then((value) => context = value);
      clock.flushMicrotasks();
      listener.close();
      clock.elapse(Duration.zero);
      clock.flushMicrotasks();
      expect(context!.cancelToken!.isCancelled, isTrue);
      finish.complete();
      clock.flushMicrotasks();
      expect(container.exists(provider), isFalse);
      container.dispose();
    }),
  );
}

class _RecordingRepo extends PostRepository<Post> {
  _RecordingRepo(this.delegate, this.record);
  final PostRepository<Post> delegate;
  final void Function(String query, PostFetchOptions? options) record;
  @override
  PostsOrError<Post> getPostsFromController(
    SearchTagSet controller,
    int page, {
    int? limit,
    PostFetchOptions? options,
  }) => getPosts(
    controller.tags.map((tag) => tag.originalTag).join(' '),
    page,
    limit: limit,
    options: options,
  );
  @override
  PostsOrError<Post> getPosts(
    String tags,
    int page, {
    int? limit,
    PostFetchOptions? options,
  }) {
    record(tags, options);
    return delegate.getPosts(tags, page, limit: limit, options: options);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
