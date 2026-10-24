import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../foundation/data_mutation_coordinator.dart';
import '../../../configs/config/types.dart';
import '../../../configs/manage/providers.dart';
import '../../../http/client/coordination.dart';
import '../../../posts/post/types.dart';
import '../data/providers.dart';
import '../providers/bookmark_provider.dart';
import '../types/bookmark_identity.dart';
import 'fetch_runner.dart';
import 'projection_queue.dart';
import 'settings_provider.dart';
import 'source.dart';
import 'target_settings.dart';

/// Captured before a request. Neither a later profile selection nor a target
/// change may redirect an in-flight operation to another account or group.
class ServerFavoriteSession {
  const ServerFavoriteSession(this.config, this.groupId);

  final BooruConfig config;
  final String groupId;
}

class ServerFavoriteProjectionFeedback {
  const ServerFavoriteProjectionFeedback(this.problem, {this.profileId});

  final String? profileId;
  final ServerFavoriteProblem problem;
}

final serverFavoriteFeedbackProvider =
    NotifierProvider<
      ServerFavoriteFeedbackNotifier,
      ServerFavoriteProjectionFeedback?
    >(ServerFavoriteFeedbackNotifier.new);

class ServerFavoriteFeedbackNotifier
    extends Notifier<ServerFavoriteProjectionFeedback?> {
  @override
  ServerFavoriteProjectionFeedback? build() => null;

  void clear() => state = null;

  void report(ServerFavoriteProblem problem, {String? profileId}) {
    state = ServerFavoriteProjectionFeedback(problem, profileId: profileId);
  }
}

final serverFavoriteFetchProvider =
    NotifierProvider<
      ServerFavoriteFetchNotifier,
      Map<String, ServerFavoriteProgress>
    >(
      ServerFavoriteFetchNotifier.new,
      dependencies: [
        bookmarkLibraryProvider,
        booruConfigProvider,
        serverFavoriteSettingsProvider,
      ],
    );

/// Keep the disabled feature cheap: do not instantiate the fetch controller or
/// load the bookmark library for ordinary favorite actions without a target.
Future<Future<void> Function()?> prepareServerFavoriteProjection(
  Ref ref,
  BooruConfigAuth auth,
  int postId,
  bool favorited, {
  String? profileId,
}) async {
  if (!supportsServerFavoriteProjection(auth.booruType)) return null;
  final settings = await ref.read(serverFavoriteSettingsProvider.future);
  final profiles = ref
      .read(booruConfigProvider)
      .where(
        (config) =>
            config.auth == auth &&
            (profileId == null || config.id == profileId),
      )
      .toList();
  if (profileId != null && profiles.isEmpty) {
    throw const ServerFavoriteException(ServerFavoriteProblem.accountChanged);
  }
  if (profiles.every((config) => settings.resolve(config.id) == null)) {
    return null;
  }
  if (profiles.length != 1) {
    throw const ServerFavoriteException(ServerFavoriteProblem.ambiguousAccount);
  }
  return ref
      .read(serverFavoriteFetchProvider.notifier)
      .prepareProjection(auth, postId, favorited, profileId: profileId);
}

class _FetchJob {
  final cancellation = ServerFavoriteCancellation();
  final completion = Completer<ServerFavoriteProgress>();
  ServerFavoriteSession? session;
}

class ServerFavoriteFetchNotifier
    extends Notifier<Map<String, ServerFavoriteProgress>> {
  final _jobs = <String, _FetchJob>{};
  // Accounts sharing a group share the canonical post/target queue too.
  final _projections = ServerFavoriteProjectionQueue<(String, int, String)>();
  var _disposed = false;

  @override
  Map<String, ServerFavoriteProgress> build() {
    ref.onDispose(() {
      _disposed = true;
      for (final job in _jobs.values) {
        job.cancellation.cancel();
      }
    });
    ref.listen(booruConfigProvider, (_, configs) {
      for (final job in _jobs.values) {
        final session = job.session;
        if (session == null) continue;
        if (!configs.any(
          (config) =>
              config.id == session.config.id &&
              config.auth == session.config.auth,
        )) {
          job.cancellation.cancel();
        }
      }
    });
    ref.listen(serverFavoriteSettingsProvider, (_, settings) {
      for (final job in _jobs.values) {
        final session = job.session;
        if (session == null) continue;
        if (settings.hasError ||
            (settings.hasValue &&
                settings.requireValue.resolve(session.config.id) !=
                    session.groupId)) {
          job.cancellation.cancel();
        }
      }
    });
    ref.listen(bookmarkLibraryProvider, (_, library) {
      if (!library.hasValue) return;
      for (final job in _jobs.values) {
        final session = job.session;
        if (session != null &&
            !library.requireValue.groupsById.containsKey(session.groupId)) {
          job.cancellation.cancel();
        }
      }
    });
    return const {};
  }

  void cancel(String profileId) => _jobs[profileId]?.cancellation.cancel();

  void cancelAll() {
    for (final job in _jobs.values) {
      job.cancellation.cancel();
    }
  }

  Future<void> startAll(Iterable<ServerFavoriteSession> sessions) async {
    await Future.wait([
      for (final session in sessions)
        start(session.config.id, expectedSession: session),
    ]);
  }

  /// Always explicit. Calling this again after completion/failure/cancellation
  /// starts at page one; memberships committed by previous runs remain intact.
  Future<ServerFavoriteProgress> start(
    String profileId, {
    ServerFavoriteSession? expectedSession,
  }) async {
    final existing = _jobs[profileId];
    if (existing != null) return existing.completion.future;
    final job = _FetchJob();
    _jobs[profileId] = job;
    _publish(
      profileId,
      job,
      const ServerFavoriteProgress(
        status: ServerFavoriteFetchStatus.running,
      ),
    );
    late ServerFavoriteProgress result;
    try {
      final session = await job.cancellation.wait(_capture(profileId));
      job.cancellation.throwIfCancelled();
      if (expectedSession != null) {
        if (session.config.id != expectedSession.config.id ||
            session.config.auth != expectedSession.config.auth) {
          throw const ServerFavoriteException(
            ServerFavoriteProblem.accountChanged,
          );
        }
        if (session.groupId != expectedSession.groupId) {
          throw const ServerFavoriteException(
            ServerFavoriteProblem.targetChanged,
          );
        }
      }
      job.session = session;
      final source = ref.read(serverFavoriteSourceProvider(session.config));
      result =
          await ServerFavoriteFetchRunner<Post>(
            // Thumbnail-only listings also resolve each post inside this
            // context, so their detail requests share the bulk pacing.
            fetchPage: (page) => runWithApiRequestContext(
              ApiRequestContext(
                requestClass: ApiRequestClass.bulkTransfer,
                allowCooldownRetry: false,
                canStart: () => !job.cancellation.isCancelled,
              ),
              () => source.fetchPage(page, cancellation: job.cancellation),
            ),
            identity: BookmarkIdentity.fromPost,
            validateSession: () => _validate(session),
            addPage: (posts, cancellation) => ref
                .read(dataMutationCoordinatorProvider)
                .runExclusive(() async {
                  cancellation.throwIfCancelled();
                  await _validate(session);
                  cancellation.throwIfCancelled();
                  for (final post in posts) {
                    _validatePost(session, post);
                  }
                  return ref
                      .read(bookmarkLibraryProvider.notifier)
                      .addPostsToGroup(
                        session.config.auth,
                        posts,
                        session.groupId,
                      );
                }),
          ).run(
            cancellation: job.cancellation,
            onProgress: (progress) => _publish(profileId, job, progress),
          );
    } on ServerFavoriteCancelled {
      result = const ServerFavoriteProgress(
        status: ServerFavoriteFetchStatus.cancelled,
      );
    } on ServerFavoriteException catch (error) {
      result = ServerFavoriteProgress(
        status: ServerFavoriteFetchStatus.failed,
        problem: error.problem,
      );
    } catch (_) {
      result = const ServerFavoriteProgress(
        status: ServerFavoriteFetchStatus.failed,
        problem: ServerFavoriteProblem.localFailure,
      );
    }
    _publish(profileId, job, result);
    if (identical(_jobs[profileId], job)) _jobs.remove(profileId);
    job.completion.complete(result);
    return result;
  }

  void _publish(String profileId, _FetchJob job, ServerFavoriteProgress value) {
    if (_disposed || !identical(_jobs[profileId], job)) return;
    state = Map.unmodifiable({...state, profileId: value});
  }

  Future<ServerFavoriteSession> _capture(
    String profileId, {
    bool fetching = true,
  }) async {
    final settings = await ref.read(serverFavoriteSettingsProvider.future);
    if (_disposed) throw const ServerFavoriteCancelled();
    final profiles = ref
        .read(booruConfigProvider)
        .where((config) => config.id == profileId)
        .toList();
    if (profiles.length != 1) {
      throw const ServerFavoriteException(ServerFavoriteProblem.accountChanged);
    }
    final groupId = settings.resolve(profileId);
    if (groupId == null) {
      throw const ServerFavoriteException(ServerFavoriteProblem.noTarget);
    }
    final session = ServerFavoriteSession(profiles.single, groupId);
    // Pure capability/credential validation: no client construction or request.
    if (fetching) {
      final problem = ref.read(
        serverFavoriteAvailabilityProvider(session.config.auth),
      );
      if (problem != null) throw ServerFavoriteException(problem);
    }
    await _validate(session);
    return session;
  }

  Future<void> _validate(ServerFavoriteSession session) async {
    if (_disposed) throw const ServerFavoriteCancelled();
    final settings = await ref.read(serverFavoriteSettingsProvider.future);
    if (_disposed) throw const ServerFavoriteCancelled();
    // Repository writes share the coordinator. Reading the persisted profiles
    // also covers the gap between a saved account change and notifier refresh.
    final configs = await ref.read(booruConfigRepoProvider).getAll();
    if (_disposed) throw const ServerFavoriteCancelled();
    final exists = configs.any(
      (config) =>
          config.id == session.config.id && config.auth == session.config.auth,
    );
    if (!exists) {
      throw const ServerFavoriteException(ServerFavoriteProblem.accountChanged);
    }
    if (settings.resolve(session.config.id) != session.groupId) {
      throw const ServerFavoriteException(ServerFavoriteProblem.targetChanged);
    }
    final groups = await ref.read(bookmarkGroupRepoProvider.future);
    if (await groups.getGroup(session.groupId) == null) {
      throw const ServerFavoriteException(ServerFavoriteProblem.targetMissing);
    }
  }

  void _validatePost(ServerFavoriteSession session, Post post) {
    if (post.origin.sourceHost != normalizePostSourceHost(session.config.url) ||
        BookmarkIdentity.tryFromPost(post) == null) {
      throw const ServerFavoriteException(
        ServerFavoriteProblem.missingPostIdentity,
      );
    }
  }

  /// Called before the remote action, not after switching profiles. The auth
  /// API predates profile IDs; fail closed when several profiles share it.
  Future<Future<void> Function()?> prepareProjection(
    BooruConfigAuth auth,
    int postId,
    bool favorited, {
    String? profileId,
  }) async {
    if (!supportsServerFavoriteProjection(auth.booruType)) return null;
    final settings = await ref.read(serverFavoriteSettingsProvider.future);
    if (_disposed) return null;
    final profiles = ref
        .read(booruConfigProvider)
        .where(
          (config) =>
              config.auth == auth &&
              (profileId == null || config.id == profileId),
        )
        .toList();
    if (profiles.isEmpty) return null;
    if (profiles.every((config) => settings.resolve(config.id) == null)) {
      return null;
    }
    if (profiles.length != 1) {
      throw const ServerFavoriteException(
        ServerFavoriteProblem.ambiguousAccount,
      );
    }
    final session = await _capture(profiles.single.id, fetching: false);
    if (session.config.auth != auth) {
      throw const ServerFavoriteException(ServerFavoriteProblem.accountChanged);
    }
    return () => _project(session, postId, favorited);
  }

  Future<void> _project(
    ServerFavoriteSession session,
    int postId,
    bool favorited,
  ) => _projections.run(
    (normalizePostSourceHost(session.config.url), postId, session.groupId),
    () => _applyProjection(session, postId, favorited),
  );

  Future<void> _applyProjection(
    ServerFavoriteSession session,
    int postId,
    bool favorited,
  ) async {
    if (_disposed) return;
    await _validate(session);
    final host = normalizePostSourceHost(session.config.url);
    final coordinator = ref.read(dataMutationCoordinatorProvider);
    final bookmarks = ref.read(bookmarkLibraryProvider.notifier);
    if (!favorited) {
      // Cancel older pages before joining the write queue. An accepted page
      // finishes first, and its newly created bookmark is then removable.
      for (final job in _jobs.values) {
        final other = job.session;
        if (other != null &&
            other.groupId == session.groupId &&
            normalizePostSourceHost(other.config.url) == host) {
          job.cancellation.cancel();
        }
      }
      await coordinator.runExclusive(() async {
        await _validate(session);
        // Look up the bookmark *after* any accepted page has committed. A
        // pre-queue snapshot could miss a newly imported bookmark entirely.
        final library = await bookmarks.snapshotForExport();
        final matches = library.items
            .where(
              (bookmark) =>
                  bookmark.post.id == postId &&
                  bookmark.post.origin.sourceHost == host,
            )
            .toList();
        if (matches.isNotEmpty) {
          await bookmarks.removePostsFromGroup(
            session.config.auth,
            matches.map((bookmark) => bookmark.post),
            session.groupId,
          );
        }
      });
      return;
    }

    final library = await bookmarks.snapshotForExport();
    Post? post;
    for (final bookmark in library.items) {
      if (bookmark.post.id == postId &&
          bookmark.post.origin.sourceHost == host) {
        post = bookmark.post;
        break;
      }
    }
    post ??= await ref.read(serverFavoritePostLoaderProvider(session.config))(
      postId,
    );
    if (post == null || post.id != postId) {
      throw const ServerFavoriteException(
        ServerFavoriteProblem.missingPostIdentity,
      );
    }
    final selected = post;
    _validatePost(session, selected);
    await coordinator.runExclusive(() async {
      await _validate(session);
      await bookmarks.addPostsToGroup(
        session.config.auth,
        [selected],
        session.groupId,
      );
    });
  }
}
