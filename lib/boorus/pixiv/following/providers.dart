import 'package:booru_clients/pixiv.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/configs/config/types.dart';
import '../client_provider.dart';

typedef PixivFollowingParams = ({
  BooruConfig config,
  int userId,
  PixivFollowRestrict restrict,
});
typedef PixivFollowingLoader = Future<PixivFollowingPage> Function(
  int offset,
  CancelToken cancellation,
);

final pixivFollowingLoaderProvider = Provider.autoDispose
    .family<PixivFollowingLoader, PixivFollowingParams>((ref, params) {
      final client = ref.watch(pixivClientProvider(params.config.auth));
      return (offset, token) => client.getFollowingUsers(
        userId: params.userId,
        restrict: params.restrict,
        offset: offset,
        cancelToken: token,
      );
    });

class PixivFollowingState {
  const PixivFollowingState({
    required this.artists,
    this.nextOffset,
    this.loadingMore = false,
    this.failedMore = false,
  });
  final List<PixivFollowingArtist> artists;
  final int? nextOffset;
  final bool loadingMore;
  final bool failedMore;
  bool get hasMore => nextOffset != null;

  PixivFollowingState progress({bool loading = false, bool failed = false}) =>
      PixivFollowingState(
        artists: artists,
        nextOffset: nextOffset,
        loadingMore: loading,
        failedMore: failed,
      );
}

final pixivFollowingProvider = AsyncNotifierProvider.autoDispose
    .family<PixivFollowingNotifier, PixivFollowingState, PixivFollowingParams>(
      PixivFollowingNotifier.new,
    );

class PixivFollowingNotifier
    extends
        AutoDisposeFamilyAsyncNotifier<
          PixivFollowingState,
          PixivFollowingParams
        > {
  CancelToken? _cancel;
  late PixivFollowingLoader _load;

  @override
  Future<PixivFollowingState> build(PixivFollowingParams params) async {
    _cancel?.cancel('Pixiv following source replaced');
    final token = _cancel = CancelToken();
    ref.onDispose(() => token.cancel('Pixiv following scope closed'));
    _load = ref.watch(pixivFollowingLoaderProvider(params));
    final page = await _load(0, token);
    if (token.isCancelled) throw token.cancelError!;
    return PixivFollowingState(
      artists: _unique(page.artists),
      nextOffset: page.nextOffset,
    );
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (state.isLoading ||
        current == null ||
        current.loadingMore ||
        !current.hasMore)
      return;
    final token = _cancel!;
    final load = _load;
    state = AsyncData(current.progress(loading: true));
    try {
      final page = await load(current.nextOffset!, token);
      if (token.isCancelled || token != _cancel) return;
      state = AsyncData(
        PixivFollowingState(
          artists: _unique([...current.artists, ...page.artists]),
          nextOffset: page.nextOffset,
        ),
      );
    } catch (_) {
      if (token.isCancelled || token != _cancel) return;
      // Keep known results and the exact retry offset, not a false empty page.
      state = AsyncData(current.progress(failed: true));
    }
  }

  List<PixivFollowingArtist> _unique(Iterable<PixivFollowingArtist> values) {
    final ids = <int>{};
    return List.unmodifiable([
      for (final value in values)
        if (value.user.id case final id? when id > 0 && ids.add(id)) value,
    ]);
  }
}
