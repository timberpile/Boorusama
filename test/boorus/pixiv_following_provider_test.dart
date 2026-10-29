import 'dart:async';

import 'package:booru_clients/pixiv.dart';
import 'package:boorusama/boorus/pixiv/following/providers.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final params = (
    config: BooruConfig.defaultConfig(booruType: BooruType.pixiv,
      url: 'https://www.pixiv.net', customDownloadFileNameFormat: null),
    userId: 7,
    restrict: PixivFollowRestrict.public,
  );
  PixivFollowingArtist artist(int id) => PixivFollowingArtist(
    user: PixivIllustUser(id: id),
  );

  test('coalesces load-more and deduplicates artists while preserving order', () async {
    final gate = Completer<PixivFollowingPage>();
    final offsets = <int>[];
    final container = ProviderContainer(overrides: [
      pixivFollowingLoaderProvider(params).overrideWithValue((offset, _) async {
        offsets.add(offset);
        return offset == 0
          ? PixivFollowingPage([artist(1)], nextOffset: 30)
          : gate.future;
      }),
    ]);
    final provider = pixivFollowingProvider(params);
    final sub = container.listen(provider, (_, _) {});
    addTearDown(() { sub.close(); container.dispose(); });
    await container.read(provider.future);
    final first = container.read(provider.notifier).loadMore();
    await container.read(provider.notifier).loadMore();
    expect(offsets, [0, 30]);
    gate.complete(PixivFollowingPage([artist(1), artist(2)]));
    await first;
    final state = container.read(provider).requireValue;
    expect(state.artists.map((a) => a.user.id), [1, 2]);
    expect(state.hasMore, isFalse);
    await container.read(provider.notifier).loadMore();
    expect(offsets, [0, 30]);
  });

  test('failed pagination preserves results and retries the same offset', () async {
    var fail = true;
    final offsets = <int>[];
    final container = ProviderContainer(overrides: [
      pixivFollowingLoaderProvider(params).overrideWithValue((offset, _) async {
        offsets.add(offset);
        if (offset == 30 && fail) { fail = false; throw StateError('fixture'); }
        return PixivFollowingPage([artist(offset == 0 ? 1 : 2)],
          nextOffset: offset == 0 ? 30 : null);
      }),
    ]);
    final provider = pixivFollowingProvider(params);
    final sub = container.listen(provider, (_, _) {});
    addTearDown(() { sub.close(); container.dispose(); });
    await container.read(provider.future);
    await container.read(provider.notifier).loadMore();
    expect(container.read(provider).requireValue.failedMore, isTrue);
    expect(container.read(provider).requireValue.artists.single.user.id, 1);
    await container.read(provider.notifier).loadMore();
    expect(offsets, [0, 30, 30]);
    expect(container.read(provider).requireValue.failedMore, isFalse);
  });

  test('closing an account cancels and ignores a delayed pagination response', () async {
    final gate = Completer<PixivFollowingPage>();
    CancelToken? pendingToken;
    final container = ProviderContainer(overrides: [
      pixivFollowingLoaderProvider(params).overrideWithValue((offset, token) async {
        if (offset == 0) return PixivFollowingPage([artist(1)], nextOffset: 30);
        pendingToken = token;
        return gate.future;
      }),
    ]);
    final provider = pixivFollowingProvider(params);
    container.listen(provider, (_, _) {});
    await container.read(provider.future);
    final pending = container.read(provider.notifier).loadMore();
    container.dispose();
    gate.complete(PixivFollowingPage([artist(2)]));
    await pending;
    expect(pendingToken?.isCancelled, isTrue);
  });
}
