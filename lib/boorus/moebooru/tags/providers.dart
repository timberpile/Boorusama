// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../../core/boorus/booru/types.dart';
import '../../../core/configs/config/types.dart';
import '../../../core/search/queries/types.dart';
import '../../../core/tags/categories/types.dart';
import '../../../core/tags/local/providers.dart';
import '../../../core/tags/tag/types.dart';
import '../tag_summary/repo.dart';
import 'parser.dart';
import 'query_composer.dart';
import 'repository.dart';

final moebooruTagRepoProvider =
    Provider.family<MoebooruTagRepository, BooruConfigAuth>((ref, config) {
      return MoebooruTagRepository(
        repo: ref.watch(moebooruTagSummaryRepoProvider(config)),
      );
    });

final moebooruTagExtractorProvider =
    Provider.family<TagExtractor, BooruConfigAuth>(
      (ref, config) {
        return TagExtractorBuilder(
          siteHost: config.url,
          tagCache: ref.watch(tagCacheRepositoryProvider.future),
          sorter: TagSorter.defaults(),
          fetcher: (post, options) async {
            final allTagMap = await ref.read(
              moebooruAllTagsProvider(config).future,
            );

            final tags = <Tag>[];

            for (final t in post.tags) {
              final tag = allTagMap[t];
              if (tag != null) {
                tags.add(tag);
              } else {
                tags.add(
                  Tag.noCount(
                    name: t,
                    category: TagCategory.unknown(),
                  ),
                );
              }
            }

            return tags;
          },
        );
      },
    );

final moebooruAllTagsProvider =
    FutureProvider.family<Map<String, Tag>, BooruConfigAuth>((
      ref,
      config,
    ) async {
      if (config.booruType != BooruType.moebooru) return {};

      final repo = ref.watch(moebooruTagSummaryRepoProvider(config));
      final data = await repo.getTagSummaryData();

      return buildMoebooruTagMap(data);
    });

final moebooruTagQueryComposerProvider =
    Provider.family<TagQueryComposer, BooruConfigSearch>(
      (ref, config) => MoebooruTagQueryComposer(config: config),
    );
