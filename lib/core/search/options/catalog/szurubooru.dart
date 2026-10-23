import '../search_option.dart';
import 'common.dart';

/// Szurubooru's parser uses inclusive ranges and comma-separated sort
/// directions. Reusing Danbooru comparison strings would send invalid queries.
class SzurubooruComparisonOption extends SearchOption {
  const SzurubooruComparisonOption({
    required super.key,
    super.kind = SearchOptionKind.metadata,
    super.input = SearchOptionInput.number,
    super.choices = const [],
    super.labelKey,
    super.descriptionKey,
    super.allowNegative = false,
  }) : super(allowRange: true, negation: SearchOptionNegation.prefix);

  @override
  String? compose(String value, {bool exclude = false}) {
    if (!accepts(value)) return null;
    var negated = exclude;
    String wire;
    if (value.startsWith('>=')) {
      wire = '${value.substring(2)}..';
    } else if (value.startsWith('<=')) {
      wire = '..${value.substring(2)}';
    } else if (value.startsWith('>')) {
      wire = '..${value.substring(1)}';
      negated = !negated;
    } else if (value.startsWith('<')) {
      wire = '${value.substring(1)}..';
      negated = !negated;
    } else {
      wire = value;
    }
    return '${negated ? '-' : ''}$key:$wire';
  }
}

/// Pool autocomplete returns an ID, but the text keyboard also allows users
/// to find a pool by name. An unresolved name cannot be applied as an ID.
class SzurubooruPoolOption extends SearchOption {
  const SzurubooruPoolOption()
    : super(
        kind: SearchOptionKind.metadata,
        key: 'pool',
        input: SearchOptionInput.text,
        labelKey: 'pool',
        descriptionKey: 'pool',
        negation: SearchOptionNegation.prefix,
      );

  @override
  bool accepts(String value) => RegExp(r'^[1-9][0-9]*$').hasMatch(value);
}

List<SearchOption> szurubooruOptions() {
  const prefix = SearchOptionNegation.prefix;
  const sortFields = [
    'id',
    'score',
    'tag-count',
    'comment-count',
    'fav-count',
    'note-count',
    'relation-count',
    'feature-count',
    'file-size',
    'image-width',
    'image-height',
    'image-area',
    'creation-date',
    'last-edit-date',
    'comment-date',
    'fav-date',
    'feature-date',
  ];
  return [
    const SearchOption(
      kind: SearchOptionKind.rating,
      key: 'rating',
      input: SearchOptionInput.choice,
      negation: prefix,
      choices: [
        SearchOptionChoice('safe', 'safe'),
        SearchOptionChoice('questionable', 'sketchy'),
        SearchOptionChoice('explicit', 'unsafe'),
      ],
    ),
    SearchOption(
      kind: SearchOptionKind.sort,
      key: 'sort',
      input: SearchOptionInput.choice,
      choices: [
        const SearchOptionChoice('newest', 'creation-date,desc'),
        const SearchOptionChoice('oldest', 'creation-date,asc'),
        const SearchOptionChoice('highest_score', 'score,desc'),
        const SearchOptionChoice('most_favorites', 'fav-count,desc'),
        const SearchOptionChoice('random', 'random'),
        for (final field in sortFields)
          for (final direction in ['asc', 'desc'])
            if (!const {
              'creation-date,asc',
              'creation-date,desc',
              'score,desc',
              'fav-count,desc',
            }.contains('$field,$direction'))
              SearchOptionChoice('$field,$direction', '$field,$direction'),
      ],
    ),
    const SzurubooruComparisonOption(
      key: 'score',
      kind: SearchOptionKind.score,
      allowNegative: true,
      choices: [
        SearchOptionChoice('score_20', '>=20'),
        SearchOptionChoice('score_50', '>=50'),
      ],
    ),
    const SzurubooruComparisonOption(key: 'id', kind: SearchOptionKind.postId),
    textOption(
      'uploader',
      kind: SearchOptionKind.uploader,
      description: 'user',
      negation: prefix,
    ),
    textOption(
      'comment',
      label: 'commenter',
      description: 'user',
      negation: prefix,
    ),
    textOption(
      'fav',
      label: 'favorited_by',
      description: 'user',
      negation: prefix,
    ),
    for (final key in [
      'creation-date',
      'last-edit-date',
      'comment-date',
      'fav-date',
      'feature-date',
    ])
      SzurubooruComparisonOption(
        key: key,
        input: SearchOptionInput.date,
        labelKey: key,
        descriptionKey: 'date',
        choices: const [
          SearchOptionChoice('today', 'today'),
          SearchOptionChoice('yesterday', 'yesterday'),
        ],
      ),
    for (final key in [
      'tag-count',
      'comment-count',
      'fav-count',
      'note-count',
      'relation-count',
      'feature-count',
    ])
      SzurubooruComparisonOption(
        key: key,
        labelKey: key,
        descriptionKey: 'count',
        choices: countChoices,
      ),
    for (final key in ['image-width', 'image-height'])
      SzurubooruComparisonOption(
        key: key,
        labelKey: key,
        descriptionKey: 'pixels',
        choices: pixelChoices,
      ),
    const SzurubooruComparisonOption(
      key: 'image-area',
      labelKey: 'image-area',
      descriptionKey: 'pixels',
    ),
    const SzurubooruComparisonOption(
      key: 'image-aspect-ratio',
      input: SearchOptionInput.ratio,
      labelKey: 'ratio',
      descriptionKey: 'ratio',
      choices: [
        SearchOptionChoice('16:9', '16:9', literal: true),
        SearchOptionChoice('1:1', '1:1', literal: true),
      ],
    ),
    const SzurubooruComparisonOption(
      key: 'file-size',
      labelKey: 'filesize',
      descriptionKey: 'bytes',
      choices: [
        SearchOptionChoice('≥ 1 MiB', '>=1048576', literal: true),
        SearchOptionChoice('≥ 10 MiB', '>=10485760', literal: true),
      ],
    ),
    enumOption(
      'type',
      ['image', 'animation', 'video', 'flash'],
      label: 'filetype',
      negation: prefix,
    ),
    enumOption('flag', ['loop', 'sound'], negation: prefix),
    enumOption(
      'special',
      ['fav', 'liked', 'disliked', 'tumbleweed'],
      description: 'account_special',
      negation: prefix,
    ),
    const SzurubooruPoolOption(),
    for (final key in ['tag', 'category', 'note-text'])
      textOption(key, negation: prefix),
    textOption('source', description: 'source', negation: prefix),
    textOption(
      'content-checksum',
      label: 'sha1',
      description: 'hash',
      negation: prefix,
    ),
    textOption('md5', description: 'hash', negation: prefix),
  ];
}
