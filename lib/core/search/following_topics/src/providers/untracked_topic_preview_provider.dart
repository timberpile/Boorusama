import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../foundation/loggers.dart';
import '../../../../configs/config/types.dart';
import '../../../../errors/error.dart';
import '../../../../developer_options/providers.dart';
import '../../../../http/client/coordination.dart';
import '../../../../posts/post/providers.dart';
import '../../../../posts/post/types.dart';
import '../../../selected_tags/types.dart';
import '../services/topic_preview_loader.dart';
import '../types/following_topic.dart';

// A shared gate prevents a grid of unsupported Topics from flooding one site.
final topicPreviewLoaderProvider = Provider((ref) => TopicPreviewLoader());

typedef UntrackedTopicPreviewKey = ({
  BooruConfig config,
  String query,
  SearchQueryStructure? structure,
  int revision,
  DateTime? attemptedAt,
});

/// Cache identity includes the full originating profile (including its auth
/// and content policy), query, and refresh revision. Never use browse auth.
final untrackedTopicPreviewProvider = FutureProvider.autoDispose
    .family<List<String>, UntrackedTopicPreviewKey>((ref, key) async {
      if (!ref.watch(automaticMediaLoadingEnabledProvider)) return const [];
      final repository = ref.watch(originAwarePostRepoProvider(key.config));
      final loader = ref.watch(topicPreviewLoaderProvider);
      final token = CancelToken();
      var disposed = false;
      ref.onDispose(() {
        disposed = true;
        token.cancel();
      });
      void retain(Duration duration) {
        if (disposed) return;
        final link = ref.keepAlive();
        final timer = Timer(duration, link.close);
        ref.onDispose(timer.cancel);
      }

      try {
        final urls = await loader.load(
          canStart: () => !disposed && !token.isCancelled,
          fetch: () => runWithApiRequestContext(
            ApiRequestContext(
              requestClass: ApiRequestClass.preload,
              replaySafety: ApiReplaySafety.safeRead,
              admissionBehavior: ApiAdmissionBehavior.dropIfUnavailable,
              allowCooldownRetry: false,
              cancelToken: token,
              canStart: () => !disposed && !token.isCancelled,
            ),
            () async {
              // One first page only. Raw suppresses cascading requests, not
              // the repository's normal profile query composer/authentication.
              final request = key.structure == null
                  ? repository.getPosts(
                      key.query,
                      1,
                      limit: 4,
                      options: PostFetchOptions.raw,
                    )
                  : repository.getPostsFromController(
                      SearchTagSet.fromList(key.structure!.typedTags),
                      1,
                      limit: 4,
                      options: PostFetchOptions.raw,
                    );
              final result = await request.run();
              return result.fold(
                (error) => throw error,
                (page) => page.posts.map((post) => post.thumbnailImageUrl),
              );
            },
          ),
        );
        retain(const Duration(minutes: 5));
        return urls;
      } catch (error, stackTrace) {
        if (!disposed &&
            !token.isCancelled &&
            error is! RequestCancelledError &&
            error is! ApiRequestDeferredException &&
            !(error is DioException &&
                error.error is ApiRequestDeferredException)) {
          ref
              .read(loggerProvider)
              .handledError(
                'Following',
                switch (error) {
                  ServerError(:final httpStatusCode) =>
                    'load_untracked_preview:http_status=$httpStatusCode',
                  AppError(:final type) =>
                    'load_untracked_preview:${type.name}',
                  _ => 'load_untracked_preview',
                },
                error: error,
                stackTrace: stackTrace,
                outcome: 'negative_cache',
                level: LogLevel.warning,
              );
        }
        // Brief negative caching avoids repeated failures during list rebuilds.
        // Disposal/cancellation must not retain a stale result.
        if (!token.isCancelled) retain(const Duration(seconds: 30));
        rethrow;
      }
    });
