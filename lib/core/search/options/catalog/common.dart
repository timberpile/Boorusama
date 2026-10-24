import '../search_option.dart';

const anyNone = [
  SearchOptionChoice('any', 'any'),
  SearchOptionChoice('none', 'none'),
];
const countChoices = [
  SearchOptionChoice('0', '0', literal: true),
  SearchOptionChoice('> 0', '>0', literal: true),
  SearchOptionChoice('≥ 10', '>=10', literal: true),
];
const pixelChoices = [
  SearchOptionChoice('≥ 1080 px', '>=1080', literal: true),
  SearchOptionChoice('≥ 1920 px', '>=1920', literal: true),
  SearchOptionChoice('≥ 3840 px', '>=3840', literal: true),
];

SearchOption numericOption(
  String key, {
  SearchOptionKind kind = SearchOptionKind.metadata,
  SearchOptionInput input = SearchOptionInput.number,
  String? label,
  String? description,
  bool ranges = true,
  bool signed = false,
  SearchOptionNegation negation = SearchOptionNegation.none,
  List<SearchOptionChoice> choices = const [],
}) => SearchOption(
  kind: kind,
  key: key,
  input: input,
  labelKey: kind == SearchOptionKind.metadata ? label ?? key : null,
  descriptionKey:
      description ?? (kind == SearchOptionKind.metadata ? input.name : null),
  allowRange: ranges,
  allowNegative: signed,
  negation: negation,
  choices: choices,
);

SearchOption textOption(
  String key, {
  String? label,
  String description = 'text',
  SearchOptionKind kind = SearchOptionKind.metadata,
  SearchOptionNegation negation = SearchOptionNegation.none,
  List<SearchOptionChoice> choices = const [],
}) => SearchOption(
  kind: kind,
  key: key,
  input: SearchOptionInput.text,
  labelKey: kind == SearchOptionKind.metadata ? label ?? key : null,
  descriptionKey: description,
  negation: negation,
  choices: choices,
);

SearchOption enumOption(
  String key,
  List<String> values, {
  SearchOptionKind kind = SearchOptionKind.metadata,
  String? label,
  String description = 'choice',
  SearchOptionNegation negation = SearchOptionNegation.none,
}) => SearchOption(
  kind: kind,
  key: key,
  input: SearchOptionInput.choice,
  labelKey: kind == SearchOptionKind.metadata ? label ?? key : null,
  descriptionKey: description,
  negation: negation,
  choices: [for (final value in values) SearchOptionChoice(value, value)],
);

SearchOption scoreOption({bool ranges = true}) => numericOption(
  'score',
  kind: SearchOptionKind.score,
  signed: true,
  ranges: ranges,
  negation: SearchOptionNegation.comparison,
  choices: const [
    SearchOptionChoice('score_20', '>=20'),
    SearchOptionChoice('score_50', '>=50'),
    SearchOptionChoice('score_100', '>=100'),
  ],
);

SearchOption ratingOption({bool legacy = false, bool short = false}) =>
    SearchOption(
      kind: SearchOptionKind.rating,
      key: 'rating',
      input: SearchOptionInput.choice,
      negation: SearchOptionNegation.prefix,
      choices: [
        if (legacy)
          SearchOptionChoice('safe', short ? 's' : 'safe')
        else ...[
          SearchOptionChoice('general', short ? 'g' : 'general'),
          SearchOptionChoice('sensitive', short ? 's' : 'sensitive'),
        ],
        SearchOptionChoice('questionable', short ? 'q' : 'questionable'),
        SearchOptionChoice('explicit', short ? 'e' : 'explicit'),
      ],
    );
