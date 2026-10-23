import '../search_option.dart';
import 'common.dart';

const philomenaSortFields = {
  'id',
  'updated_at',
  'first_seen_at',
  'aspect_ratio',
  'faves',
  'downvotes',
  'upvotes',
  'width',
  'height',
  'score',
  'comment_count',
  'tag_count',
  'wilson_score',
  'pixels',
  'size',
  'duration',
  'hides',
  '_score',
  'random',
};

class PhilomenaComparisonOption extends SearchOption {
  const PhilomenaComparisonOption({
    required super.key,
    super.kind = SearchOptionKind.metadata,
    super.input = SearchOptionInput.number,
    super.labelKey,
    super.descriptionKey,
    super.choices = const [],
    super.allowNegative = false,
  }) : super(allowRange: true, negation: SearchOptionNegation.prefix);

  @override
  String? compose(String value, {bool exclude = false}) {
    if (!accepts(value)) return null;
    final parts = value.split('..');
    String expression;
    if (parts.length == 2) {
      final bounds = [
        if (parts.first.isNotEmpty) '$key.gte:${parts.first}',
        if (parts.last.isNotEmpty) '$key.lte:${parts.last}',
      ];
      expression = bounds.length == 1 ? bounds.single : '(${bounds.join(',')})';
    } else {
      var suffix = '';
      var atom = value;
      for (final (operator, field) in const [
        ('>=', '.gte'),
        ('<=', '.lte'),
        ('>', '.gt'),
        ('<', '.lt'),
      ]) {
        if (value.startsWith(operator)) {
          suffix = field;
          atom = value.substring(operator.length);
          break;
        }
      }
      expression = '$key$suffix:$atom';
    }
    return '${exclude ? '-' : ''}$expression';
  }
}

class PhilomenaExactIdOption extends SearchOption {
  const PhilomenaExactIdOption(String key)
    : super(
        key: key,
        kind: SearchOptionKind.metadata,
        input: SearchOptionInput.number,
        labelKey: key,
        descriptionKey: 'id',
        negation: SearchOptionNegation.prefix,
      );
  @override
  bool get isComparable => false;
  @override
  bool accepts(String value) => RegExp(r'^[0-9]+$').hasMatch(value);
}

List<SearchOption> philomenaOptions() => [
  SearchOption(
    kind: SearchOptionKind.sort,
    key: 'sort',
    input: SearchOptionInput.choice,
    descriptionKey: 'api_sort',
    choices: [
      const SearchOptionChoice('newest', 'first_seen_at:desc'),
      const SearchOptionChoice('oldest', 'first_seen_at:asc'),
      const SearchOptionChoice('highest_score', 'score:desc'),
      const SearchOptionChoice('most_favorites', 'faves:desc'),
      for (final field in philomenaSortFields)
        for (final direction in ['asc', 'desc'])
          if (!const {
            'first_seen_at:desc',
            'first_seen_at:asc',
            'score:desc',
            'faves:desc',
          }.contains('$field:$direction'))
            SearchOptionChoice('$field:$direction', '$field:$direction'),
    ],
  ),
  const PhilomenaComparisonOption(key: 'id', kind: SearchOptionKind.postId),
  const PhilomenaComparisonOption(
    key: 'score',
    kind: SearchOptionKind.score,
    allowNegative: true,
    choices: [
      SearchOptionChoice('score_20', '>=20'),
      SearchOptionChoice('score_50', '>=50'),
      SearchOptionChoice('score_100', '>=100'),
    ],
  ),
  for (final key in ['width', 'height'])
    PhilomenaComparisonOption(
      key: key,
      labelKey: key,
      descriptionKey: 'pixels',
      choices: pixelChoices,
    ),
  for (final key in [
    'upvotes',
    'downvotes',
    'hides',
    'faves',
    'comment_count',
    'source_count',
    'tag_count',
    'body_type_tag_count',
    'error_tag_count',
    'character_tag_count',
    'content_fanmade_tag_count',
    'content_official_tag_count',
    'oc_tag_count',
    'origin_tag_count',
    'rating_tag_count',
    'species_tag_count',
    'spoiler_tag_count',
  ])
    PhilomenaComparisonOption(
      key: key,
      labelKey: key,
      descriptionKey: 'count',
      choices: countChoices,
    ),
  for (final key in ['size', 'orig_size'])
    PhilomenaComparisonOption(
      key: key,
      labelKey: key,
      descriptionKey: 'bytes',
      choices: const [
        SearchOptionChoice('≥ 1 MiB', '>=1048576', literal: true),
      ],
    ),
  const PhilomenaComparisonOption(
    key: 'pixels',
    labelKey: 'pixels',
    descriptionKey: 'pixels',
  ),
  for (final key in ['aspect_ratio', 'wilson_score', 'duration'])
    PhilomenaComparisonOption(
      key: key,
      input: SearchOptionInput.decimal,
      labelKey: key,
      descriptionKey: key == 'duration' ? 'seconds' : 'decimal',
    ),
  for (final key in ['created_at', 'updated_at', 'first_seen_at'])
    PhilomenaComparisonOption(
      key: key,
      input: SearchOptionInput.date,
      labelKey: key,
      descriptionKey: 'date',
    ),
  for (final key in [
    'uploader_id',
    'faved_by_id',
    'duplicate_id',
    'gallery_id',
    'filter_id',
  ])
    PhilomenaExactIdOption(key),
  textOption(
    'uploader',
    kind: SearchOptionKind.uploader,
    description: 'user',
    negation: SearchOptionNegation.prefix,
  ),
  textOption(
    'faved_by',
    description: 'user',
    negation: SearchOptionNegation.prefix,
  ),
  textOption(
    'source_url',
    label: 'source',
    description: 'source',
    negation: SearchOptionNegation.prefix,
  ),
  for (final key in [
    'description',
    'file_name',
    'original_format',
    'mime_type',
    'sha512_hash',
    'orig_sha512_hash',
  ])
    textOption(
      key,
      description: key.contains('hash') ? 'hash' : 'text',
      negation: SearchOptionNegation.prefix,
    ),
  for (final key in ['animated', 'processed', 'thumbnails_generated'])
    enumOption(key, ['true', 'false'], negation: SearchOptionNegation.prefix),
  enumOption(
    'my',
    ['faves', 'upvotes', 'downvotes', 'uploads', 'hidden', 'subs', 'watched'],
    description: 'account_special',
    negation: SearchOptionNegation.prefix,
  ),
];
