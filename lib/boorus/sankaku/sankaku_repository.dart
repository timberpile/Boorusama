import '../../core/search/search/src/types/search_option.dart';

// Package imports:
import 'package:booru_clients/sankaku.dart';
import 'package:coreutils/coreutils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rich_text_controller/rich_text_controller.dart';

// Project imports:
import '../../core/boorus/defaults/types.dart';
import '../../core/configs/config/types.dart';
import '../../core/configs/create/create.dart';
import '../../core/downloads/filename/types.dart';
import '../../core/errors/types.dart';
import '../../core/http/client/providers.dart';
import '../../core/posts/post/types.dart';
import '../../core/search/queries/types.dart';
import '../../core/tags/autocompletes/types.dart';
import '../../core/tags/metatag/types.dart';
import '../../core/tags/tag/types.dart';
import 'errors/error_translator.dart';
import 'posts/post_codec.dart';
import 'posts/providers.dart';
import 'posts/types.dart';
import 'search/tag_query_composer.dart';
import 'tags/providers.dart';

class SankakuRepository extends BooruRepositoryDefault
    implements SearchOptionsCapability {
  const SankakuRepository({required this.ref});

  @override
  List<SearchOption> get searchOptions => const [
    SearchOption(
      kind: SearchOptionKind.rating,
      prefix: 'rating',
      values: ['s', 'q', 'e'],
      valueLabels: {
        's': SearchOptionValueLabel.safe,
        'q': SearchOptionValueLabel.questionable,
        'e': SearchOptionValueLabel.explicit,
      },
    ),
    SearchOption(kind: SearchOptionKind.date, prefix: 'date'),
    SearchOption(
      kind: SearchOptionKind.order,
      prefix: 'order',
      values: ['id', 'score'],
      valueLabels: {
        'id': SearchOptionValueLabel.newest,
        'score': SearchOptionValueLabel.score,
      },
    ),
    SearchOption(kind: SearchOptionKind.user, prefix: 'user'),
    SearchOption(kind: SearchOptionKind.pool, prefix: 'pool'),
    SearchOption(kind: SearchOptionKind.favorites, prefix: 'fav'),
  ];

  @override
  final Ref ref;

  @override
  BooruPostDataCodec<SankakuPostData> get postDataCodec =>
      const SankakuPostCodec();

  @override
  AppErrorTranslator appErrorTranslator(BooruConfigAuth config) =>
      ref.watch(sankakuAppErrorTranslatorProvider);

  @override
  TagQueryComposer tagComposer(BooruConfigSearch config) =>
      ref.watch(sankakuTagQueryComposerProvider(config));

  @override
  PostRepository<Post> post(BooruConfigSearch config) {
    return ref.read(sankakuPostRepoProvider(config));
  }

  @override
  AutocompleteRepository autocomplete(BooruConfigAuth config) {
    return ref.read(sankakuAutocompleteRepoProvider(config));
  }

  @override
  MetatagExtractor getMetatagExtractor(BooruConfigAuth config) =>
      ref.watch(sankakuMetatagExtractorProvider);

  @override
  TextMatcher queryMatcher(BooruConfigAuth config) =>
      ref.watch(sankakuQueryMatcherProvider);

  @override
  BooruSiteValidator? siteValidator(BooruConfigAuth config) {
    final dio = ref.watch(defaultDioProvider(config));

    return () => SankakuClient(
      baseUrl: config.url,
      dio: dio,
      username: config.login,
      password: config.apiKey,
    ).getPosts().then((value) => true);
  }

  @override
  PostLinkGenerator postLinkGenerator(BooruConfigAuth config) {
    return SankakuPostLinkGenerator(baseUrl: config.url);
  }

  @override
  DownloadFilenameGenerator downloadFilenameBuilder(BooruConfigAuth config) {
    return DownloadFileNameBuilder<Post>(
      defaultFileNameFormat: kBoorusamaCustomDownloadFileNameFormat,
      defaultBulkDownloadFileNameFormat:
          kBoorusamaBulkDownloadCustomFileNameFormat,
      sampleData: kDanbooruPostSamples,
      tokenHandlers: [
        WidthTokenHandler(),
        HeightTokenHandler(),
        AspectRatioTokenHandler(),
        TokenHandler(
          'artist',
          (post, config) => post.artistTags?.join(' ') ?? '',
        ),
        TokenHandler(
          'character',
          (post, config) => post.characterTags?.join(' ') ?? '',
        ),
        TokenHandler(
          'copyright',
          (post, config) => post.copyrightTags?.join(' ') ?? '',
        ),
        TokenHandler('general', (post, config) => post.generalTags.join(' ')),
        TokenHandler('meta', (post, config) => post.metaTags.join(' ')),
        MPixelsTokenHandler(),
        TokenHandler(
          'source',
          (post, config) => normalizeUrl(config.downloadUrl),
        ),
      ],
    );
  }

  @override
  TagExtractor tagExtractor(BooruConfigAuth config) {
    return ref.watch(sankakuTagExtractorProvider(config));
  }
}
