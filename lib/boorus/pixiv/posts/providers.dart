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
          fetchSingle: (id, {options}) async {
            final value = switch (id) {
              NumericPostId(:final value) when value >= 1000 => value,
              _ => null,
            };
            if (value == null) return null;
            final detail = await client.getIllustDetail(
              illustId: value ~/ 1000,
            );
            if (detail == null) return null;
            return illustDtoToPosts(
              detail,
            ).where((post) => post.id == value).firstOrNull;
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

            final PixivIllustListResult result;
            if (userId != null) {
              result = await client.getUserIllusts(
                userId: userId,
                page: page,
              );
            } else if (text != null) {
              result = await client.searchIllust(
                word: text,
                page: page,
              );
            } else {
              // Pixiv has no tag-less "recent" browse endpoint, so an empty
              // query would otherwise render as a blank grid, which reads as
              // broken. Fall back to the newest daily ranking snapshot
              // instead (see ranking/providers.dart for the same call with
              // date clamping/omission; here the date is simply omitted so
              // the API returns whatever it considers newest).
              result = await client.getRanking(
                mode: PixivRankingMode.day,
                page: page,
              );
            }

            return pixivIllustListResultToPostResult(
              result,
              metadata: metadata,
            );
          },
        );
      },
    );
