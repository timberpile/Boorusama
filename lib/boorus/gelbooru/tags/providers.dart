// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../../core/boorus/booru/types.dart';
import '../../../core/configs/config/types.dart';
import '../../../core/search/queries/types.dart';
import '../../../core/tags/autocompletes/types.dart';
import '../../../core/tags/local/providers.dart';
import '../../../core/tags/metatag/types.dart';
import '../../../core/tags/tag/providers.dart';
import '../../../core/tags/tag/types.dart';
import '../../../foundation/loggers/providers.dart';
import '../client_provider.dart';
import 'metatag_extractor.dart';
import 'site_search_options.dart';
import 'parser.dart';
import 'query_composer.dart';
import 'types.dart';
import 'utils.dart';

final gelbooruTagRepoProvider = Provider.family<TagRepository, BooruConfigAuth>(
  (ref, config) {
    final client = ref.watch(gelbooruClientProvider(config));
    final logger = ref.watch(loggerProvider);

    return TagRepositoryBuilder(
      getTags: (tags, page, {cancelToken}) async {
        final data = await client.getTags(
          page: page,
          tags: tags,
        );

        return data.map(gelbooruTagDtoToTag).toList();
      },
      logger: logger,
    );
  },
);

final gelbooruTagQueryComposerProvider =
    Provider.family<TagQueryComposer, BooruConfigSearch>(
      (ref, config) => GelbooruTagQueryComposer(config: config),
    );

final gelbooruTagResolverProvider =
    Provider.family<TagResolver, BooruConfigAuth>((ref, config) {
      return TagResolver(
        tagCacheBuilder: () => ref.watch(tagCacheRepositoryProvider.future),
        siteHost: config.url,
        cachedTagMapper: CachedTagMapper(
          categoryMapper: (cachedTag) =>
              stringToGelbooruTagCategory(cachedTag.category),
        ),
        tagRepositoryBuilder: () => ref.read(gelbooruTagRepoProvider(config)),
      );
    });

final gelbooruTagExtractorProvider =
    Provider.family<TagExtractor, BooruConfigAuth>(
      (ref, config) {
        return TagExtractorBuilder(
          siteHost: config.url,
          tagCache: ref.watch(tagCacheRepositoryProvider.future),
          sorter: TagSorter.defaults(),
          fetcherBatch: (posts, options) {
            final tags = posts.expand((post) => post.tags).toSet();
            final tagResolver = ref.read(gelbooruTagResolverProvider(config));

            return resolveGelbooruRawTags(
              tags,
              tagResolver,
              cancelToken: options.cancelToken,
            );
          },
          fetcher: (post, options) {
            final tagResolver = ref.read(gelbooruTagResolverProvider(config));

            final tagList = post.tags;

            return resolveGelbooruRawTags(
              tagList,
              tagResolver,
              cancelToken: options.cancelToken,
            );
          },
        );
      },
    );

final gelbooruAutocompleteRepoProvider =
    Provider.family<AutocompleteRepository, BooruConfigAuth>((ref, config) {
      final client = ref.watch(gelbooruClientProvider(config));

      return AutocompleteRepositoryBuilder(
        autocomplete: (query) async {
          final dtos = await client.autocomplete(term: query.text, limit: 20);

          return dtos
              .map(autocompleteDtoToAutocompleteData)
              .where((e) => e != AutocompleteData.empty)
              .toList();
        },
      );
    });

final gelbooruMetatagsProvider = Provider.family<Set<Metatag>, BooruConfigAuth>(
  (ref, config) => {
    const Metatag.simple(name: 'id'),
    const Metatag.simple(name: 'score'),
    const Metatag.simple(name: 'rating'),
    const Metatag.simple(name: 'user'),
    const Metatag.simple(name: 'height'),
    const Metatag.simple(name: 'width'),
    const Metatag.simple(name: 'parent'),
    const Metatag.simple(name: 'md5'),
    const Metatag.simple(name: 'sort'),
    if (config.booruType == BooruType.gelbooruV2)
      for (final key in gelbooruSiteSearchOptions(
        config.url,
        legacy: true,
      ).extraMetatags)
        Metatag.simple(name: key),
  },
);

final gelbooruSortableTagTypesProvider =
    Provider.family<Set<SortableTagType>, BooruConfigAuth>(
      (ref, config) => {
        for (final field in gelbooruSiteSearchOptions(
          config.url,
          legacy: config.booruType == BooruType.gelbooruV2,
        ).sortFields)
          SortableTagType(name: field),
      },
    );

final gelbooruMetatagExtractorProvider =
    Provider.family<GelbooruMetatagExtractor, BooruConfigAuth>(
      (ref, config) {
        final site = gelbooruSiteSearchOptions(
          config.url,
          legacy: config.booruType == BooruType.gelbooruV2,
        );
        return GelbooruMetatagExtractor(
          metatags: ref.watch(gelbooruMetatagsProvider(config)).toSet(),
          sortableTypes: ref.watch(gelbooruSortableTagTypesProvider(config)),
          allowRandomSort: site.randomSort,
          allowSeededRandomSort: site.seededRandomSort,
        );
      },
    );

final gelbooruMetatagRegexProvider = Provider.family<RegExp, BooruConfigAuth>(
  (ref, config) {
    final metatags = ref
        .watch(gelbooruMetatagsProvider(config))
        .map((e) => e.name)
        .toList();
    final sortableTypes = ref
        .watch(gelbooruSortableTagTypesProvider(config))
        .map((e) => e.name)
        .toList();

    final site = gelbooruSiteSearchOptions(
      config.url,
      legacy: config.booruType == BooruType.gelbooruV2,
    );
    final pattern = buildMetatagRegexPattern(
      metatags: metatags,
      sortableTypes: sortableTypes,
      allowRandomSort: site.randomSort,
      allowSeededRandomSort: site.seededRandomSort,
    );

    return RegExp(pattern, caseSensitive: false);
  },
);
