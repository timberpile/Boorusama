import '../../../../boorus/gelbooru/tags/site_search_options.dart';
import '../search_option.dart';
import 'common.dart';

/// Common legacy fields follow the existing extractor and Safebooru's help.
/// Rule34's API differs from its website help: only verified API filters are
/// offered here. Do not propagate its random/source support to other clones.
List<SearchOption> gelbooruOptions({required bool legacy, String url = ''}) {
  final support = gelbooruSiteSearchOptions(url, legacy: legacy);
  final rule34 = legacy && gelbooruSiteHost(url) == 'rule34.xxx';
  return [
    ratingOption(legacy: legacy),
    SearchOption(
      kind: SearchOptionKind.sort,
      key: 'sort',
      input: SearchOptionInput.choice,
      choices: [
        const SearchOptionChoice('newest', 'id:desc'),
        const SearchOptionChoice('oldest', 'id:asc'),
        const SearchOptionChoice('highest_score', 'score:desc'),
        const SearchOptionChoice('lowest_score', 'score:asc'),
        for (final field in support.sortFields)
          for (final direction in ['desc', 'asc'])
            if (!const {
              'id:desc',
              'id:asc',
              'score:desc',
              'score:asc',
            }.contains('$field:$direction'))
              SearchOptionChoice('${field}_$direction', '$field:$direction'),
        if (support.randomSort) const SearchOptionChoice('random', 'random'),
      ],
    ),
    scoreOption(ranges: false),
    numericOption('id', kind: SearchOptionKind.postId, ranges: false),
    textOption('user', kind: SearchOptionKind.uploader, description: 'user'),
    for (final key in ['width', 'height'])
      numericOption(
        key,
        description: 'pixels',
        ranges: false,
        choices: pixelChoices,
        negation: SearchOptionNegation.comparison,
      ),
    const GelbooruExactIdOption('parent', description: 'id'),
    textOption('md5', description: 'hash'),
    if (!legacy) ...[
      const GelbooruExactIdOption('fav', description: 'user_id'),
      const GelbooruExactIdOption('pool', description: 'pool_id'),
    ],
    if (rule34) textOption('source', description: 'source'),
  ];
}

class GelbooruExactIdOption extends SearchOption {
  const GelbooruExactIdOption(String key, {required String description})
    : super(
        key: key,
        kind: SearchOptionKind.metadata,
        input: SearchOptionInput.number,
        labelKey: key,
        descriptionKey: description,
        allowNegative: false,
      );
  @override
  bool get isComparable => false;
  @override
  bool accepts(String value) => RegExp(r'^[0-9]+$').hasMatch(value);
}

bool knownLegacyGelbooru(String url) => const {
  'rule34.xxx',
  'hypnohub.net',
  'realbooru.com',
  'xbooru.com',
  'safebooru.org',
  'bbooru.com',
  'tbib.org',
}.contains(gelbooruSiteHost(url));
