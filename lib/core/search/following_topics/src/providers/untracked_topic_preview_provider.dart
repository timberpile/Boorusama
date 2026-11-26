import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../foundation/loggers.dart';
import '../../../../boorus/engine/providers.dart';
import '../../../../configs/config/types.dart';
import '../../../../content/content_access_provider.dart';
import '../../../../developer_options/providers.dart';
import '../../../../errors/error.dart';
import '../../../../http/client/coordination.dart';
import '../../../../posts/post/providers.dart';
import '../../../../posts/post/types.dart';
import '../../../selected_tags/types.dart';
import '../refresh/search_refresh_query_adapter.dart';
import '../services/topic_preview_loader.dart';
import '../types/following_topic.dart';
import '../types/search_refresh.dart';
import 'following_topic_selectors.dart';
import 'following_topic_refresh_source_provider.dart';

// A shared gate prevents a grid of unsupported Topics from flooding one site.
final topicPreviewLoaderProvider = Provider((ref) => TopicPreviewLoader());

typedef UntrackedTopicPreviewKey = ({
  BooruConfig config,
  String query,
  SearchQueryStructure? structure,
  int revision,
  DateTime? attemptedAt,
});

/// The Topic card and its parent Folder choose the same preview and cache key
/// for a Topic with a resolved source.
final untrackedTopicPreviewKeyProvider = Provider.autoDispose
    .family<UntrackedTopicPreviewKey?, (FollowingTopic, BooruConfig)>((
      ref,
      input,
    ) {
      final (topic, config) = input;
      final auth = config.auth;
      if (ref.watch(followingTopicGalleryRefreshSourceProvider(auth)) != null) {
        return null;
      }
      if (config.anonymousReadScope == null &&
          topic.lastErrorKind != SearchRefreshErrorKind.unsupported &&
          ref.watch(followingTopicTrackingSupportedProvider(auth)) &&
          supportsSearchRefreshQuery(
            ref.watch(booruRepoProvider(auth))?.searchRefreshQueryAdapter(auth),
            topic.query,
          )) {
        return null;
      }
      return (
        config: config,
        query: topic.query,
        structure: topic.queryStructure,
        revision: topic.runtimeRevision,
        attemptedAt: topic.lastAttemptAt,
      );
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
          canStart: () =>
              !disposed &&
              !token.isCancelled &&
              (key.config.anonymousReadScope?.isCurrent ?? true),
          fetch: () => runWithApiRequestContext(
            ApiRequestContext(
              requestClass: ApiRequestClass.preload,
              replaySafety: ApiReplaySafety.safeRead,
              admissionBehavior: ApiAdmissionBehavior.dropIfUnavailable,
              allowCooldownRetry: false,
              cancelToken: token,
              canStart: () =>
                  !disposed &&
                  !token.isCancelled &&
                  (key.config.anonymousReadScope?.isCurrent ?? true),
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
                (page) => page.posts
                    .where((post) {
                      final scope = key.config.anonymousReadScope;
                      if (scope == null) return true;
                      final uri = Uri.tryParse(post.thumbnailImageUrl);
                      return !disposed &&
                          scope.isCurrent &&
                          uri != null &&
                          scope.source.allowsMedia(uri) &&
                          (ref
                                  .watch(
                                    contentPostVisibilityProvider((
                                      access: scope.key,
                                      post: post,
                                    )),
                                  )
                                  .valueOrNull ??
                              false);
                    })
                    .map((post) => post.thumbnailImageUrl),
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
