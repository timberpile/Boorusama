import 'package:booru_clients/pixiv.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/boorus/booru/types.dart';
import '../../../core/configs/config/types.dart';
import '../../../core/content/content_access_provider.dart';
import '../../../core/http/client/coordination.dart';
import '../../../core/posts/favorites/types.dart';
import '../client_provider.dart';
import '../configs/extra_data.dart';

typedef PixivFavoriteActor = ({
  int authEpoch,
  BooruConfigAuth auth,
  int userId,
});

PixivFavoriteActor? _actor(ContentProfileScope? scope) {
  if (scope == null || scope.config.auth.booruType != BooruType.pixiv) {
    return null;
  }
  final auth = scope.config.auth;
  final userId = pixivAuthenticatedUserId(auth);
  if (userId == null || auth.anonymousReadScope != null) return null;
  return (authEpoch: scope.authEpoch, auth: auth, userId: userId);
}

typedef PixivFavoriteEntry = ({
  PixivBookmarkDetail? detail,
  bool? pendingFavorite,
  // Draw the last observed heart while an uncertain outcome requires a read.
  bool? lastKnownFavorite,
  bool checkingStatus,
  bool lookupFailed,
  bool visibilityChecked,
});

extension PixivFavoriteEntryState on PixivFavoriteEntry {
  bool get pending => pendingFavorite != null;
}

const unknownPixivFavorite = (
  detail: null,
  pendingFavorite: null,
  lastKnownFavorite: null,
  checkingStatus: false,
  lookupFailed: false,
  visibilityChecked: false,
);

final class PixivFavoritesState {
  const PixivFavoritesState(
    this.actor, {
    this.entries = const {},
    this.listRevisions = const {},
  });

  final PixivFavoriteActor? actor;
  final Map<int, PixivFavoriteEntry> entries;
  final Map<PixivBookmarkVisibility, int> listRevisions;

  PixivFavoriteEntry entry(int illustId) =>
      entries[illustId] ?? unknownPixivFavorite;
}

typedef PixivFavoriteRead = ({CancelToken lifetime, int sequence});

final pixivFavoriteStateProvider = NotifierProvider.autoDispose
    .family<PixivFavoriteNotifier, PixivFavoritesState, String>(
      PixivFavoriteNotifier.new,
      dependencies: [contentAccessScopesProvider],
    );

final class PixivFavoriteNotifier
    extends AutoDisposeFamilyNotifier<PixivFavoritesState, String> {
  late CancelToken _lifetime;
  final _requests = <int, CancelToken>{};
  final _settledAt = <int, int>{};
  var _sequence = 0;

  @override
  PixivFavoritesState build(String arg) {
    final actor = ref.watch(
      contentAccessScopesProvider.select((scopes) => _actor(scopes[arg])),
    );
    final lifetime = _lifetime = CancelToken();
    ref.onDispose(() {
      lifetime.cancel('Pixiv Favorite session ended');
      for (final request in _requests.values) {
        request.cancel('Pixiv Favorite session ended');
      }
      _requests.clear();
    });
    _settledAt.clear();
    return PixivFavoritesState(actor);
  }

  PixivFavoriteRead? beginRead(BooruConfigAuth auth, int authEpoch) {
    final actor = state.actor;
    if (actor == null || actor.auth != auth || actor.authEpoch != authEpoch) {
      return null;
    }
    return (lifetime: _lifetime, sequence: ++_sequence);
  }

  void observe(
    PixivFavoriteRead? read,
    Iterable<PixivIllustDto> artworks, {
    PixivBookmarkVisibility? ownList,
  }) {
    if (read == null ||
        read.lifetime.isCancelled ||
        !identical(read.lifetime, _lifetime)) {
      return;
    }
    final actor = state.actor;
    if (actor == null || !_isCurrent(read.lifetime, actor)) return;
    final entries = Map<int, PixivFavoriteEntry>.of(state.entries);
    var changed = false;
    for (final artwork in artworks) {
      final id = artwork.id;
      final isBookmarked = ownList != null ? true : artwork.isBookmarked;
      if (id == null || id <= 0 || isBookmarked == null) continue;
      if (read.sequence < (_settledAt[id] ?? 0)) continue;
      final existing = state.entry(id);
      if (existing.pending || existing.checkingStatus) continue;
      _settledAt[id] = read.sequence;
      final next = (
        detail: (
          isBookmarked: isBookmarked,
          visibility: isBookmarked
              ? ownList ?? existing.detail?.visibility
              : null,
        ),
        pendingFavorite: null,
        lastKnownFavorite: null,
        checkingStatus: false,
        lookupFailed: false,
        visibilityChecked: isBookmarked && existing.visibilityChecked,
      );
      if (next == existing) continue;
      entries[id] = next;
      changed = true;
    }
    if (changed) {
      state = PixivFavoritesState(
        actor,
        entries: entries,
        listRevisions: state.listRevisions,
      );
    }
  }

  bool _isCurrent(CancelToken lifetime, PixivFavoriteActor actor) =>
      !lifetime.isCancelled &&
      _actor(ref.read(contentAccessScopesProvider)[arg]) == actor;

  Future<void> lookup(
    PixivFavoriteActor actor,
    int illustId, {
    required bool Function() isCurrent,
    bool retry = false,
  }) => _operate(actor, illustId, isCurrent: isCurrent, retry: retry);

  Future<void> setFavorite(
    PixivFavoriteActor actor,
    int illustId, {
    required PixivBookmarkVisibility? addVisibility,
    required bool Function() isCurrent,
  }) => _operate(
    actor,
    illustId,
    isCurrent: isCurrent,
    write: true,
    addVisibility: addVisibility,
  );

  Future<void> _operate(
    PixivFavoriteActor actor,
    int illustId, {
    required bool Function() isCurrent,
    bool retry = false,
    bool write = false,
    PixivBookmarkVisibility? addVisibility,
  }) async {
    final lifetime = _lifetime;
    if (illustId <= 0 || !_isCurrent(lifetime, actor) || !isCurrent()) return;
    final entry = state.entry(illustId);
    if (entry.pending || (!write && entry.checkingStatus)) return;
    final before = entry.detail;
    if (write) {
      final wasFavorited = before?.isBookmarked ?? false;
      if (entry.lookupFailed || wasFavorited == (addVisibility != null)) {
        return;
      }
    } else if (!retry &&
        (entry.lookupFailed ||
            (before != null &&
                (!before.isBookmarked ||
                    before.visibility != null ||
                    entry.visibilityChecked)))) {
      return;
    }

    final client = ref.read(pixivClientProvider(actor.auth));
    // An explicit action can supersede a passive lookup for this artwork.
    _requests[illustId]?.cancel('Pixiv Favorite status lookup superseded');
    final request = _requests[illustId] = CancelToken();
    _store(
      illustId,
      before,
      pendingFavorite: write ? addVisibility != null : null,
      lastKnownFavorite: entry.lastKnownFavorite,
      checkingStatus: !write,
      visibilityChecked: entry.visibilityChecked,
    );
    var observed = before;
    var lastKnownFavorite = before?.isBookmarked ?? entry.lastKnownFavorite;
    var attemptedWrite = false;
    var lookupFailed = false;
    var visibilityChecked = entry.visibilityChecked;
    var refresh = <PixivBookmarkVisibility>{};
    bool requestCurrent() =>
        !request.isCancelled &&
        identical(_requests[illustId], request) &&
        _isCurrent(lifetime, actor);
    bool canStart() => requestCurrent() && isCurrent();
    Future<PixivBookmarkDetail> readDetail(bool Function() current) =>
        runWithApiRequestContext(
          ApiRequestContext(
            cancelToken: request,
            replaySafety: ApiReplaySafety.safeRead,
            canStart: current,
            canAdmit: current,
          ),
          () => client.getIllustBookmarkDetail(
            illustId: illustId,
            cancelToken: request,
          ),
        );

    try {
      final preflight = await readDetail(canStart);
      if (!requestCurrent()) return;
      observed = preflight;
      lastKnownFavorite = preflight.isBookmarked;
      visibilityChecked = true;
      if (!write) {
        if (retry && entry.lookupFailed && before == null) {
          refresh = PixivBookmarkVisibility.values.toSet();
        } else if (before != null &&
            (before.isBookmarked != preflight.isBookmarked ||
                (before.visibility != null &&
                    preflight.visibility != null &&
                    before.visibility != preflight.visibility))) {
          refresh = _affectedLists(before, preflight);
        }
        return;
      }
      if (!canStart()) return;
      final adding = addVisibility != null;
      if (preflight.isBookmarked == adding) {
        refresh = _affectedLists(before, preflight);
        return;
      }

      attemptedWrite = true;
      await runWithApiRequestContext(
        ApiRequestContext(
          cancelToken: request,
          replaySafety: ApiReplaySafety.mutation,
          canStart: canStart,
          canAdmit: canStart,
          allowCooldownRetry: false,
        ),
        () => adding
            ? client.addIllustBookmark(
                illustId: illustId,
                visibility: addVisibility,
                cancelToken: request,
              )
            : client.deleteIllustBookmark(
                illustId: illustId,
                cancelToken: request,
              ),
      );
      if (!requestCurrent()) return;
      observed = await readDetail(requestCurrent);
      attemptedWrite = false;
      refresh = _affectedLists(preflight, observed);
      if (observed.isBookmarked != adding ||
          (adding && observed.visibility != addVisibility)) {
        throw FavoriteActionFailure.unconfirmed;
      }
    } on PixivAuthException {
      observed = null;
      lookupFailed = true;
      throw FavoriteActionFailure.websiteSessionRejected;
    } on DioException catch (error) {
      if (attemptedWrite) observed = null;
      lookupFailed = attemptedWrite || error.type != DioExceptionType.cancel;
      rethrow;
    } on PixivException {
      if (attemptedWrite) observed = null;
      lookupFailed = true;
      throw FavoriteActionFailure.unconfirmed;
    } on FormatException {
      if (attemptedWrite) observed = null;
      lookupFailed = true;
      throw FavoriteActionFailure.unconfirmed;
    } finally {
      if (requestCurrent()) {
        _requests.remove(illustId);
        _settledAt[illustId] = ++_sequence;
        _store(
          illustId,
          observed,
          lastKnownFavorite: lookupFailed && observed == null
              ? lastKnownFavorite
              : null,
          lookupFailed: lookupFailed,
          visibilityChecked: visibilityChecked,
          refresh: refresh,
        );
      }
    }
  }

  void _store(
    int illustId,
    PixivBookmarkDetail? detail, {
    bool? pendingFavorite,
    bool? lastKnownFavorite,
    bool checkingStatus = false,
    bool lookupFailed = false,
    bool visibilityChecked = false,
    Set<PixivBookmarkVisibility> refresh = const {},
  }) {
    final revisions = state.listRevisions;
    state = PixivFavoritesState(
      state.actor,
      entries: {
        ...state.entries,
        illustId: (
          detail: detail,
          pendingFavorite: pendingFavorite,
          lastKnownFavorite: lastKnownFavorite,
          checkingStatus: checkingStatus,
          lookupFailed: lookupFailed,
          visibilityChecked: visibilityChecked,
        ),
      },
      listRevisions: refresh.isEmpty
          ? revisions
          : {
              ...revisions,
              for (final list in refresh) list: (revisions[list] ?? 0) + 1,
            },
    );
  }
}

Set<PixivBookmarkVisibility> _affectedLists(
  PixivBookmarkDetail? previous,
  PixivBookmarkDetail current,
) {
  Iterable<PixivBookmarkVisibility> lists(PixivBookmarkDetail? detail) =>
      switch (detail) {
        (isBookmarked: true, visibility: final visibility?) => [visibility],
        (isBookmarked: true, visibility: null) =>
          PixivBookmarkVisibility.values,
        _ => const [],
      };
  return previous == current ? {} : {...lists(previous), ...lists(current)};
}
