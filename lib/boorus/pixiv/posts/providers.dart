// Package imports:
import 'package:booru_clients/pixiv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../../core/configs/config/types.dart';
import '../../../core/posts/post/providers.dart';
import '../../../core/posts/post/types.dart';
import '../../../core/search/queries/providers.dart';
import '../../../core/settings/providers.dart';
import '../client_provider.dart';
import 'parser.dart';
import 'query.dart';

final pixivPostRepoProvider =
    Provider.family<PostRepository, BooruConfigSearch>(
      (ref, config) {
        final client = ref.watch(pixivClientProvider(config.auth));
        final tagComposer = ref.watch(defaultTagQueryComposerProvider(config));

        return PostRepositoryBuilder(
          tagComposer: tagComposer,
          getSettings: () async => ref.read(imageListingSettingsProvider),
          fetchSingle: (id, {options}) {
            // Ids are synthesised per page, so they cannot be turned back
            // into an illust_id + page_index request on their own. Post
            // details are always reached from a listing, which already
            // holds the full post.
            return Future.value();
          },
          fetch: (tags, page, {limit, options}) async {
            final query = PixivQuery.parse(tags);
            final metadata = PostMetadata(
              page: page,
              search: tags.join(' '),
              limit: limit,
            );

            final userId = query.userId;
            final text = query.text;

            final List<PixivIllustDto> illusts;
            if (userId != null) {
              illusts = (await client.getUserIllusts(
                userId: userId,
                page: page,
              )).illusts;
            } else if (text != null) {
              illusts = (await client.searchIllust(
                word: text,
                page: page,
              )).illusts;
            } else {
              // Pixiv has no tag-less "recent" browse endpoint, so an empty
              // query would otherwise render as a blank grid, which reads as
              // broken. Fall back to the newest daily ranking snapshot
              // instead (see ranking/providers.dart for the same call with
              // date clamping/omission; here the date is simply omitted so
              // the API returns whatever it considers newest).
              illusts = (await client.getRanking(
                mode: PixivRankingMode.day,
                page: page,
              )).illusts;
            }

            return illustDtosToPosts(
              illusts,
              metadata: metadata,
            ).toResult();
          },
        );
      },
    );
