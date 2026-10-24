import 'dart:async';

import 'package:equatable/equatable.dart';

import 'target_settings.dart';

enum ServerFavoriteFetchStatus { idle, running, completed, cancelled, failed }

enum ServerFavoriteFetchPhase { downloading, saving }

class ServerFavoriteProgress extends Equatable {
  const ServerFavoriteProgress({
    this.status = ServerFavoriteFetchStatus.idle,
    this.phase = ServerFavoriteFetchPhase.downloading,
    this.downloadedPages = 0,
    this.pages = 0,
    this.added = 0,
    this.problem,
  });

  final ServerFavoriteFetchStatus status;
  final ServerFavoriteFetchPhase phase;
  final int downloadedPages;
  final int pages;
  final int added;
  final ServerFavoriteProblem? problem;

  bool get running => status == ServerFavoriteFetchStatus.running;

  @override
  List<Object?> get props => [
    status,
    phase,
    downloadedPages,
    pages,
    added,
    problem,
  ];
}

class ServerFavoriteCancellation {
  final _signal = Completer<void>();

  bool get isCancelled => _signal.isCompleted;

  void cancel() {
    if (!isCancelled) _signal.complete();
  }

  void throwIfCancelled() {
    if (isCancelled) throw const ServerFavoriteCancelled();
  }

  /// A client without transport cancellation may finish its current request,
  /// but its late result cannot cause a bookmark write or another page request.
  Future<T> wait<T>(Future<T> operation) {
    return Future.any([
      operation,
      _signal.future.then<T>((_) => throw const ServerFavoriteCancelled()),
    ]);
  }
}

class ServerFavoriteCancelled implements Exception {
  const ServerFavoriteCancelled();
}

class ServerFavoritePage<T> {
  ServerFavoritePage(Iterable<T> posts, {this.hasMore})
    : posts = List.unmodifiable(posts);

  final List<T> posts;

  /// Null means the source has no reliable end marker. Request until empty;
  /// never infer exhaustion from a short (possibly server-filtered) page.
  final bool? hasMore;
}

/// Explicit, additive fetch only. There are no timers, lifecycle hooks, durable
/// cursors, or remote mutations. Download the complete server listing
/// before saving it in reverse, including page order. A retry repeats safely.
class ServerFavoriteFetchRunner<T> {
  const ServerFavoriteFetchRunner({
    required this.fetchPage,
    required this.identity,
    required this.validateSession,
    required this.addPage,
  });

  final Future<ServerFavoritePage<T>> Function(int page) fetchPage;
  final Object Function(T post) identity;
  final Future<void> Function() validateSession;

  /// Must revalidate the session and cancellation inside the bookmark mutation
  /// queue, then add membership idempotently. Return the newly added count.
  final Future<int> Function(
    List<T> posts,
    ServerFavoriteCancellation cancellation,
  )
  addPage;

  Future<ServerFavoriteProgress> run({
    required ServerFavoriteCancellation cancellation,
    required void Function(ServerFavoriteProgress) onProgress,
  }) async {
    var pages = 0;
    var added = 0;
    var phase = ServerFavoriteFetchPhase.downloading;
    var downloadedPages = 0;
    var stage = ServerFavoriteProblem.localFailure;
    final seen = <Object>{};
    final downloaded = <List<T>>[];

    ServerFavoriteProgress publish(
      ServerFavoriteFetchStatus status, [
      ServerFavoriteProblem? problem,
    ]) {
      final progress = ServerFavoriteProgress(
        status: status,
        phase: phase,
        downloadedPages: downloadedPages,
        pages: pages,
        added: added,
        problem: problem,
      );
      onProgress(progress);
      return progress;
    }

    publish(ServerFavoriteFetchStatus.running);
    try {
      for (var page = 1; ; page++) {
        cancellation.throwIfCancelled();
        stage = ServerFavoriteProblem.localFailure;
        await cancellation.wait(validateSession());
        cancellation.throwIfCancelled();
        stage = ServerFavoriteProblem.remoteFailure;
        final response = await cancellation.wait(fetchPage(page));
        cancellation.throwIfCancelled();
        stage = ServerFavoriteProblem.localFailure;
        await cancellation.wait(validateSession());
        cancellation.throwIfCancelled();

        if (response.posts.isEmpty) {
          if (response.hasMore == true) {
            throw const ServerFavoriteException(
              ServerFavoriteProblem.paginationStalled,
            );
          }
          break;
        }

        // Deduplicate each page and detect non-advancing overlapping pages.
        // Keep the first occurrence's position across overlapping pages too.
        final unique = <Object, T>{};
        for (final post in response.posts) {
          unique.putIfAbsent(identity(post), () => post);
        }
        final advances = unique.keys.any((key) => !seen.contains(key));
        if (!advances && response.hasMore != false) {
          throw const ServerFavoriteException(
            ServerFavoriteProblem.paginationStalled,
          );
        }

        downloaded.add([
          for (final entry in unique.entries)
            if (!seen.contains(entry.key)) entry.value,
        ]);
        seen.addAll(unique.keys);
        downloadedPages++;
        publish(ServerFavoriteFetchStatus.running);
        cancellation.throwIfCancelled();
        if (response.hasMore == false) {
          break;
        }
      }
      phase = ServerFavoriteFetchPhase.saving;
      publish(ServerFavoriteFetchStatus.running);
      for (final posts in downloaded.reversed) {
        if (posts.isEmpty) continue;
        cancellation.throwIfCancelled();
        await cancellation.wait(validateSession());
        cancellation.throwIfCancelled();
        // Do not race cancellation against an accepted durable write. Finish
        // the page, report its committed count, and stop before the next page.
        added += await addPage(posts.reversed.toList(), cancellation);
        pages++;
        publish(ServerFavoriteFetchStatus.running);
        cancellation.throwIfCancelled();
      }
      return publish(ServerFavoriteFetchStatus.completed);
    } on ServerFavoriteCancelled {
      return publish(ServerFavoriteFetchStatus.cancelled);
    } on ServerFavoriteException catch (error) {
      return publish(ServerFavoriteFetchStatus.failed, error.problem);
    } on TimeoutException {
      return publish(
        ServerFavoriteFetchStatus.failed,
        ServerFavoriteProblem.timedOut,
      );
    } catch (_) {
      // The failure category is safe to display; raw request errors can include
      // private URLs, login details, or response bodies and must not be exposed.
      return publish(ServerFavoriteFetchStatus.failed, stage);
    }
  }
}
