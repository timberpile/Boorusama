import 'package:booru_clients/pixiv.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/configs/config/types.dart';
import '../../../core/content/content_access.dart';
import '../../../core/content/content_access_provider.dart';
import '../../../core/http/client/coordination.dart';
import '../client_provider.dart';
import 'work_mapper.dart';

typedef PixivRelatedQuery = ({ContentAccessKey access, int illustId});

final pixivRelatedFirstPageProvider = FutureProvider.autoDispose
    .family<PixivRelatedPage, PixivRelatedQuery>(
      (ref, query) async {
        final access = ref.watch(contentAccessContextProvider(query.access));
        if (access?.config == null || access?.key.profileId == null) {
          throw StateError(
            'Pixiv related artworks require their original profile',
          );
        }
        final blacklist = ref
            .watch(contentEffectiveBlacklistProvider(access!.key.profileId!))
            .requireValue;
        final client = ref.watch(pixivClientProvider(access.config!.auth));
        final token = CancelToken();
        ref.onDispose(token.cancel);
        final page = await client.getRelatedIllusts(
          illustId: query.illustId,
          cancelToken: token,
        );
        if (token.isCancelled ||
            ref.read(contentAccessContextProvider(query.access)) != access) {
          throw StateError('Pixiv related artwork access changed');
        }
        return filterPixivRelatedPage(page, query, access, blacklist);
      },
      dependencies: [
        contentAccessContextProvider,
        contentEffectiveBlacklistProvider,
      ],
    );

PixivRelatedPage filterPixivRelatedPage(
  PixivRelatedPage page,
  PixivRelatedQuery query,
  ContentAccessContext access,
  Set<String> blacklist,
) {
  final seen = {query.illustId};
  return PixivRelatedPage(
    List.unmodifiable([
      for (final dto in page.illusts)
        if (pixivWorkIsVisible(dto) &&
            pixivWorkPassesFilters(dto, access, blacklist) &&
            seen.add(dto.id!))
          dto,
    ]),
    nextCursor: page.nextCursor,
  );
}

/// Adapts ordered Pixiv cursors to the native grid's sequential page requests.
class PixivRelatedSession {
  PixivRelatedSession({required this.load, required PixivRelatedPage firstPage})
    : _firstPage = firstPage;

  final Future<PixivRelatedPage> Function(PixivRelatedCursor?, CancelToken?)
  load;
  PixivRelatedPage? _firstPage;
  PixivRelatedCursor? _cursor;
  final _seenCursors = <PixivRelatedCursor>{};
  final _seenArtworks = <int>{};
  var _nextPage = 1;

  Future<PixivIllustListResult> fetch(int page) async {
    final first = page == 1;
    if (!first && page != _nextPage) {
      throw StateError('Pixiv related artworks require sequential pages');
    }
    final cursor = first ? null : _cursor;
    if (!first && cursor == null) return const PixivIllustListResult();

    final request = ApiRequestContext.current();
    final seed = first ? _firstPage : null;
    final result = seed ?? await load(cursor, request.cancelToken);
    if ((request.cancelToken?.isCancelled ?? false) ||
        !(request.canAdmit?.call() ?? true)) {
      throw StateError('Pixiv related artwork request cancelled');
    }

    if (first) {
      _firstPage = null;
      _seenArtworks.clear();
      _seenCursors.clear();
    }
    final next = result.nextCursor;
    _cursor = next != null && _seenCursors.add(next) ? next : null;
    _nextPage = page + 1;
    return PixivIllustListResult(
      illusts: [
        for (final dto in result.illusts)
          if (dto.id case final id? when _seenArtworks.add(id)) dto,
      ],
      hasMore: _cursor != null,
    );
  }
}
