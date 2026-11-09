import 'package:booru_clients/nhentai.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/configs/config/types.dart';
import '../../../core/http/client/coordination.dart';
import '../client_provider.dart';
import 'store.dart';

final nhentaiTagCacheProvider =
    Provider.family<NhentaiTagCache, BooruConfigAuth>(
      (ref, config) {
        final client = ref.watch(nhentaiClientProvider(config));
        final cache = NhentaiTagCache(
          store: ref.watch(nhentaiTagStoreProvider),
          lookup: (ids, token) => client.getTagsByIds(ids, cancelToken: token),
          catalog: (category, sort, page, token) => runWithApiRequestContext(
            ApiRequestContext(
              requestClass: ApiRequestClass.preload,
              replaySafety: ApiReplaySafety.safeRead,
              cancelToken: token,
              allowCooldownRetry: false,
              admissionBehavior: ApiAdmissionBehavior.dropIfUnavailable,
            ),
            () => client.getTagCatalog(
              category,
              sort: sort,
              page: page,
              cancelToken: token,
            ),
          ),
        );
        ref.onDispose(cache.dispose);
        return cache;
      },
    );
