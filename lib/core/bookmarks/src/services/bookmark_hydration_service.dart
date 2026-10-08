import 'dart:async';

import '../../../configs/config/types.dart';
import '../../../errors/types.dart';
import '../../../posts/post/types.dart';
import '../types/bookmark.dart';
import '../types/bookmark_hydration_log.dart';
import 'bookmark_library_service.dart';

bool needsBookmarkHydration(Bookmark bookmark) =>
    switch (bookmark.post.booruData) {
      LegacyPostData() || UnknownPostData() => true,
      _ => false,
    };

class BookmarkHydrationProgress {
  const BookmarkHydrationProgress({
    this.total = 0,
    this.updated = 0,
    this.skipped = 0,
    this.failed = 0,
    this.running = false,
    this.cancelled = false,
    this.rateLimitedSites = const {},
    this.logEntries = const [],
    this.retryPass = 0,
    this.retryAt,
  });

  final int total;
  final int updated;
  final int skipped;
  final int failed;
  final bool running;
  final bool cancelled;
  final Set<String> rateLimitedSites;
  final List<BookmarkHydrationLogEntry> logEntries;
  final int retryPass;
  final DateTime? retryAt;
  int get processed => updated + skipped + failed;
}

class BookmarkHydrationCancellation {
  var _cancelled = false;
  final _signal = Completer<void>();
  bool get cancelled => _cancelled;

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    _signal.complete();
  }

  Future<void> wait(Duration duration) async {
    if (cancelled || duration <= Duration.zero) return;
    final elapsed = Completer<void>();
    final timer = Timer(duration, elapsed.complete);
    try {
      await Future.any([elapsed.future, _signal.future]);
    } finally {
      timer.cancel();
    }
  }
}

/// Shared by viewer recovery and maintenance. Fetching stays on the existing
/// origin-aware repository so its authentication and rate limits still apply.
class BookmarkRecoveryService {
  const BookmarkRecoveryService({
    required this.fetchPost,
    required this.codecFor,
  });

  final Future<Post?> Function(BooruConfig config, int postId) fetchPost;
  final BooruPostDataCodec? Function(Post post) codecFor;

  Future<BookmarkRecovery> recover(
    Bookmark bookmark,
    BooruConfig config,
  ) async {
    final id = bookmark.postId;
    if (id == null || id <= 0) {
      return const BookmarkRecoverySkipped(
        reason: BookmarkHydrationLogReason.missingPostId,
      );
    }
    try {
      final post = await fetchPost(config, id);
      if (post == null) return const BookmarkRecoveryRemoved();
      final codec = codecFor(post);
      if (codec == null ||
          post.booruData is LegacyPostData ||
          post.booruData is UnknownPostData) {
        return const BookmarkRecoverySkipped();
      }
      return BookmarkRecoverySuccess(post, codec);
    } catch (error) {
      return switch (error) {
        RateLimitedError(:final retryAt) => BookmarkRecoveryRateLimited(
          retryAt: retryAt,
        ),
        ServerError(httpStatusCode: 429) => const BookmarkRecoveryRateLimited(),
        RequestCancelledError() => const BookmarkRecoveryCancelled(),
        _ => _describeFailure(error, config),
      };
    }
  }
}

sealed class BookmarkRecovery {
  const BookmarkRecovery();
}

class BookmarkRecoverySuccess extends BookmarkRecovery {
  const BookmarkRecoverySuccess(this.post, this.codec);
  final Post post;
  final BooruPostDataCodec codec;
}

class BookmarkRecoverySkipped extends BookmarkRecovery {
  const BookmarkRecoverySkipped({
    this.reason = BookmarkHydrationLogReason.unsupportedSnapshot,
  });
  final BookmarkHydrationLogReason reason;
}

class BookmarkRecoveryRemoved extends BookmarkRecovery {
  const BookmarkRecoveryRemoved();
}

class BookmarkRecoveryFailed extends BookmarkRecovery {
  const BookmarkRecoveryFailed({
    this.httpStatusCode,
    this.kind = BookmarkHydrationFailureKind.unknown,
    this.detail,
  });
  final int? httpStatusCode;
  final BookmarkHydrationFailureKind kind;
  final String? detail;
}

BookmarkRecoveryFailed _describeFailure(Object error, BooruConfig config) {
  if (error case UnknownError(:final error)) {
    return _describeFailure(error, config);
  }
  final kind = switch (error) {
    ServerError(httpStatusCode: 401 || 403) =>
      BookmarkHydrationFailureKind.accessDenied,
    ServerError() => BookmarkHydrationFailureKind.server,
    AppError(type: AppErrorType.cannotReachServer, :final message)
        when message.toLowerCase().contains('timeout') =>
      BookmarkHydrationFailureKind.timeout,
    AppError(type: AppErrorType.cannotReachServer) =>
      BookmarkHydrationFailureKind.connection,
    AppError(type: AppErrorType.handshakeFailed) =>
      BookmarkHydrationFailureKind.handshake,
    AppError(type: AppErrorType.certificateError) =>
      BookmarkHydrationFailureKind.certificate,
    AppError(type: AppErrorType.loadDataFromServerFailed) ||
    FormatException() ||
    TypeError() => BookmarkHydrationFailureKind.invalidResponse,
    _ => BookmarkHydrationFailureKind.unknown,
  };
  // HTTP bodies and transport errors may contain whole pages, headers or
  // authenticated URLs. Their structured category/status is sufficient.
  final detail = switch (error) {
    ServerError() => null,
    AppError(type: AppErrorType.loadDataFromServerFailed, :final message) =>
      message,
    AppError() => null,
    FormatException(:final message) => message,
    _ => error.toString(),
  };
  return BookmarkRecoveryFailed(
    kind: kind,
    httpStatusCode: error is ServerError ? error.httpStatusCode : null,
    detail: detail == null ? null : _safeErrorDetail(detail, config),
  );
}

String _safeErrorDetail(String detail, BooruConfig config) {
  var safe = detail.split(RegExp(r'[\r\n]')).first;
  for (final secret in [config.apiKey, config.login, config.passHash]) {
    if (secret == null || secret.isEmpty) continue;
    safe = safe.replaceAll(secret, '[redacted]');
    safe = safe.replaceAll(Uri.encodeComponent(secret), '[redacted]');
  }
  safe = safe.replaceAll(
    RegExp(r'https?://\S+', caseSensitive: false),
    '[URL]',
  );
  safe = safe.replaceAll(RegExp(r'[\x00-\x1f\x7f]'), ' ').trim();
  return safe.length > 240 ? '${safe.substring(0, 240)}…' : safe;
}

class BookmarkRecoveryRateLimited extends BookmarkRecovery {
  const BookmarkRecoveryRateLimited({this.retryAt});
  final DateTime? retryAt;
}

class BookmarkRecoveryCancelled extends BookmarkRecovery {
  const BookmarkRecoveryCancelled();
}

class BookmarkHydrationService {
  BookmarkHydrationService({
    required this.library,
    required this.recovery,
    DateTime Function()? now,
    Future<void> Function(Duration, BookmarkHydrationCancellation)? wait,
  }) : _now = now ?? (() => DateTime.now().toUtc()),
       _wait =
           wait ?? ((duration, cancellation) => cancellation.wait(duration));
  final BookmarkLibraryService library;
  final BookmarkRecoveryService recovery;
  final DateTime Function() _now;
  final Future<void> Function(Duration, BookmarkHydrationCancellation) _wait;

  Future<BookmarkHydrationProgress> run({
    required Iterable<Bookmark> bookmarks,
    required Iterable<BooruConfig> configs,
    required BookmarkHydrationCancellation cancellation,
    required void Function(BookmarkHydrationProgress) onProgress,
  }) async {
    final candidates = bookmarks.where(needsBookmarkHydration).toList();
    final profiles = configs.toList();
    var updated = 0;
    var skipped = 0;
    var failed = 0;
    var retryPass = 0;
    DateTime? retryAt;
    final rateLimitedSites = <String>{};
    final logEntries = <BookmarkHydrationLogEntry>[];
    void log(
      Bookmark bookmark,
      BookmarkHydrationLogReason reason, {
      int? httpStatusCode,
      DateTime? retryAt,
      BookmarkHydrationFailureKind? failureKind,
      String? errorDetail,
    }) {
      logEntries.add(
        BookmarkHydrationLogEntry(
          timestamp: _now(),
          domain: bookmark.post.origin.sourceHost,
          bookmarkId: bookmark.id,
          postId: bookmark.postId,
          reason: reason,
          httpStatusCode: httpStatusCode,
          retryAt: retryAt,
          failureKind: failureKind,
          errorDetail: errorDetail,
        ),
      );
      if (logEntries.length > BookmarkHydrationLogEntry.maxEntries) {
        logEntries.removeAt(0);
      }
    }

    BookmarkHydrationProgress progress(bool running) =>
        BookmarkHydrationProgress(
          total: candidates.length,
          updated: updated,
          skipped: skipped,
          failed: failed,
          running: running,
          cancelled: cancellation.cancelled,
          rateLimitedSites: Set.unmodifiable(rateLimitedSites),
          logEntries: List.unmodifiable(logEntries),
          retryPass: retryPass,
          retryAt: retryAt,
        );
    onProgress(progress(true));
    final sites = <String, List<({Bookmark bookmark, BooruConfig config})>>{};
    for (final bookmark in candidates) {
      if (cancellation.cancelled) break;
      switch (const PostOriginResolver().resolve(
        bookmark.post.origin,
        profiles,
      )) {
        case ResolvedPostOrigin(:final config):
          sites.putIfAbsent(bookmark.post.origin.sourceHost, () => []).add((
            bookmark: bookmark,
            config: config,
          ));
        case MissingPostOrigin():
          skipped++;
          log(bookmark, BookmarkHydrationLogReason.missingProfile);
          onProgress(progress(true));
        case AmbiguousPostOrigin():
          skipped++;
          log(bookmark, BookmarkHydrationLogReason.ambiguousProfile);
          onProgress(progress(true));
      }
    }

    final pending = [
      for (final entry in sites.entries)
        _BookmarkHydrationQueue(entry.key, entry.value),
    ];
    final failures =
        <String, List<({Bookmark bookmark, BooruConfig config})>>{};
    Future<void> processSites() async {
      while (!cancellation.cancelled && pending.isNotEmpty) {
        final now = _now();
        final ready = pending.indexWhere(
          (queue) => queue.retryAt == null || !queue.retryAt!.isAfter(now),
        );
        if (ready < 0) {
          final earliest = pending
              .map((queue) => queue.retryAt!)
              .reduce((a, b) => a.isBefore(b) ? a : b);
          await _wait(earliest.difference(now), cancellation);
          continue;
        }
        // A queue is owned by one worker until this bookmark finishes. Cooling
        // queues release the worker so even a fourth site can keep progressing.
        final queue = pending.removeAt(ready);
        if (rateLimitedSites.remove(queue.host)) onProgress(progress(true));
        queue.retryAt = null;
        final (:bookmark, :config) = queue.bookmarks[queue.index];
        var completed = true;
        var failedThisAttempt = false;
        try {
          switch (await recovery.recover(bookmark, config)) {
            case BookmarkRecoverySuccess(:final post, :final codec):
              await library.upgradeBookmarkSnapshot(
                bookmark: bookmark,
                post: post,
                dataCodec: codec,
              );
              updated++;
              log(bookmark, BookmarkHydrationLogReason.updated);
            case BookmarkRecoverySkipped(:final reason):
              skipped++;
              log(bookmark, reason);
            case BookmarkRecoveryRemoved():
              skipped++;
              log(bookmark, BookmarkHydrationLogReason.removedPost);
            case BookmarkRecoveryFailed(
              :final httpStatusCode,
              :final kind,
              :final detail,
            ):
              failedThisAttempt = true;
              log(
                bookmark,
                BookmarkHydrationLogReason.requestFailed,
                httpStatusCode: httpStatusCode,
                failureKind: kind,
                errorDetail: detail,
              );
            case BookmarkRecoveryRateLimited(:final retryAt):
              completed = false;
              queue.rateLimits++;
              // Normally the shared coordinator supplies Retry-After or its
              // fallback deadline. Raw 429 errors use the same bounded steps.
              const steps = [30, 120, 600, 1800];
              final errorTime = _now();
              final deadline =
                  retryAt ??
                  errorTime.add(
                    Duration(
                      seconds: steps[(queue.rateLimits - 1).clamp(0, 3)],
                    ),
                  );
              queue.retryAt = deadline.isAfter(errorTime)
                  ? deadline
                  : errorTime.add(const Duration(seconds: 1));
              rateLimitedSites.add(queue.host);
              log(
                bookmark,
                BookmarkHydrationLogReason.rateLimited,
                httpStatusCode: 429,
                retryAt: queue.retryAt,
              );
            case BookmarkRecoveryCancelled():
              log(bookmark, BookmarkHydrationLogReason.requestCancelled);
              if (cancellation.cancelled) return;
              skipped++;
          }
        } catch (error) {
          failedThisAttempt = true;
          final failure = _describeFailure(error, config);
          log(
            bookmark,
            BookmarkHydrationLogReason.saveFailed,
            errorDetail: failure.detail,
          );
        }
        if (completed) {
          // Failed is a count of remaining posts, never a count of attempts.
          if (failedThisAttempt) {
            if (retryPass == 0) failed++;
            failures.putIfAbsent(queue.host, () => []).add((
              bookmark: bookmark,
              config: config,
            ));
          } else if (retryPass > 0) {
            failed--;
          }
          queue.index++;
          queue.rateLimits = 0;
        }
        if (queue.index < queue.bookmarks.length) pending.add(queue);
        onProgress(progress(true));
      }
    }

    while (!cancellation.cancelled && pending.isNotEmpty) {
      final workerCount = pending.length < 3 ? pending.length : 3;
      // Only bounded workers are joined. Each retry pass contains just failures;
      // successful writes and terminal skips are never requested again.
      await Future.wait(List.generate(workerCount, (_) => processSites()));
      if (cancellation.cancelled || failures.isEmpty) break;
      const steps = [30, 120, 600, 1800];
      final delay = Duration(seconds: steps[retryPass.clamp(0, 3)]);
      retryAt = _now().add(delay);
      onProgress(progress(true));
      await _wait(delay, cancellation);
      if (cancellation.cancelled) break;
      retryPass++;
      retryAt = null;
      pending.addAll([
        for (final entry in failures.entries)
          _BookmarkHydrationQueue(entry.key, entry.value),
      ]);
      failures.clear();
      onProgress(progress(true));
    }
    retryAt = null;
    final result = progress(false);
    onProgress(result);
    return result;
  }
}

class _BookmarkHydrationQueue {
  _BookmarkHydrationQueue(this.host, this.bookmarks);
  final String host;
  final List<({Bookmark bookmark, BooruConfig config})> bookmarks;
  var index = 0;
  var rateLimits = 0;
  DateTime? retryAt;
}
