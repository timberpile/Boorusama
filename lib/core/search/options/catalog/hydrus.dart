import '../search_option.dart';

/// Hydrus accepts underscores in predicate names, but requires '=' for exact
/// comparisons and rejects a leading '-' on system predicates. These compact
/// native clauses survive the existing single-item search representation.
class HydrusOption extends SearchOption {
  const HydrusOption({
    required super.key,
    super.input = SearchOptionInput.number,
    required super.labelKey,
    required super.descriptionKey,
    super.choices = const [],
    this.numberTest = false,
    this.exactOnly = false,
  }) : super(
         kind: SearchOptionKind.metadata,
         allowNegative: false,
         negation: numberTest
             ? SearchOptionNegation.comparison
             : SearchOptionNegation.none,
       );

  final bool numberTest;
  final bool exactOnly;

  @override
  List<String> get comparisons => exactOnly || !isComparable
      ? const ['']
      : numberTest
      ? const ['', '<', '<=', '>=', '>']
      : const ['', '<', '>'];

  @override
  List<String> get units => input == SearchOptionInput.duration
      ? const ['ms', 's', 'm', 'h']
      : super.units;

  @override
  bool accepts(String value) {
    if (value.contains('..')) return false;
    final operator = RegExp('^(>=|<=|>|<)').firstMatch(value);
    if (operator != null && !comparisons.contains(operator[0])) return false;
    final atom = value.substring(operator?.end ?? 0);
    if (input == SearchOptionInput.filesize) {
      return RegExp(
        r'^[0-9]+(?:b|kb|mb|gb)$',
        caseSensitive: false,
      ).hasMatch(atom);
    }
    if (input == SearchOptionInput.duration) {
      return RegExp(r'^[0-9]+(?:ms|s|m|h)$').hasMatch(atom);
    }
    return super.accepts(value);
  }

  @override
  String? compose(String value, {bool exclude = false}) {
    if (!accepts(value)) return null;
    var effectiveValue = value;
    if (exclude) {
      if (!supportsExclusion) return null;
      final inverse = SearchOption.complement(value);
      if (inverse == null || !accepts(inverse)) return null;
      effectiveValue = inverse;
    }
    final separator = RegExp('^[<>]').hasMatch(effectiveValue) ? '' : '=';
    return '$key$separator$effectiveValue';
  }
}

const _countChoices = [
  SearchOptionChoice('0', '0', literal: true),
  SearchOptionChoice('> 0', '>0', literal: true),
  SearchOptionChoice('> 10', '>10', literal: true),
];

List<SearchOption> hydrusOptions() => [
  for (final key in ['width', 'height'])
    HydrusOption(
      key: 'system:$key',
      labelKey: key,
      descriptionKey: 'pixels',
      numberTest: true,
      choices: const [
        SearchOptionChoice('≥ 1080 px', '>=1080', literal: true),
        SearchOptionChoice('≥ 1920 px', '>=1920', literal: true),
      ],
    ),
  const HydrusOption(
    key: 'system:filesize',
    labelKey: 'filesize',
    descriptionKey: 'integer_filesize',
    input: SearchOptionInput.filesize,
    choices: [
      SearchOptionChoice('< 1 MB', '<1mb', literal: true),
      SearchOptionChoice('> 10 MB', '>10mb', literal: true),
    ],
  ),
  const HydrusOption(
    key: 'system:duration',
    labelKey: 'duration',
    descriptionKey: 'duration',
    input: SearchOptionInput.duration,
    numberTest: true,
    choices: [
      SearchOptionChoice('≥ 10 s', '>=10s', literal: true),
      SearchOptionChoice('≥ 1 m', '>=1m', literal: true),
    ],
  ),
  const HydrusOption(
    key: 'system:framerate',
    labelKey: 'framerate',
    descriptionKey: 'frames_per_second',
    choices: [
      SearchOptionChoice('30', '30', literal: true),
      SearchOptionChoice('60', '60', literal: true),
    ],
  ),
  for (final key in [
    'number_of_tags',
    'number_of_urls',
    'number_of_notes',
    'media_views',
    'preview_views',
    'all_views',
  ])
    HydrusOption(
      key: 'system:$key',
      labelKey: key,
      descriptionKey: 'count',
      choices: _countChoices,
    ),
  for (final key in ['number_of_frames', 'number_of_words'])
    HydrusOption(
      key: 'system:$key',
      labelKey: key,
      descriptionKey: 'count',
      numberTest: true,
      choices: _countChoices,
    ),
  for (final key in [
    'imported_date',
    'modified_date',
    'archived_date',
    'last_viewed_date',
  ])
    HydrusOption(
      key: 'system:$key',
      labelKey: key,
      descriptionKey: 'hydrus_date',
      input: SearchOptionInput.date,
    ),
  const HydrusOption(
    key: 'system:limit',
    labelKey: 'limit',
    descriptionKey: 'limit',
    exactOnly: true,
    choices: [
      SearchOptionChoice('100', '100', literal: true),
      SearchOptionChoice('500', '500', literal: true),
    ],
  ),
];
