import 'package:booru_clients/pixiv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/configs/config/types.dart';
import '../../../core/posts/post/providers.dart';
import '../client_provider.dart';
import 'session.dart';

final pixivFavoritesSessionProvider = Provider.autoDispose
    .family<
      PixivFavoritesSession,
      ({BooruConfig config, int userId, PixivBookmarkVisibility visibility})
    >(
      (ref, params) {
        final client = ref.watch(pixivClientProvider(params.config.auth));
        final session = PixivFavoritesSession(
          origin: postOriginFromConfig(params.config),
          load: (cursor, token) => client.getUserBookmarks(
            userId: params.userId,
            visibility: params.visibility,
            maxBookmarkId: cursor,
            cancelToken: token,
          ),
        );
        ref.onDispose(session.dispose);
        return session;
      },
    );
