import '../search_option.dart';

/// Hydrus numeric service ratings are not content-safety ratings. Hybooru's
/// range syntax uses '-', and its upper rating bound is service-dependent.
class HybooruRatingOption extends SearchOption {
  const HybooruRatingOption()
    : super(
        kind: SearchOptionKind.metadata,
        key: 'rating',
        input: SearchOptionInput.number,
        labelKey: 'numeric_rating',
        descriptionKey: 'numeric_service',
        allowRange: true,
        allowNegative: false,
        negation: SearchOptionNegation.prefix,
        choices: const [SearchOptionChoice('none', 'none')],
      );
  @override
  List<String> get comparisons => const [''];
  @override
  String editorValue(String value) {
    final match = RegExp(r'^([0-9]+)-([0-9]+)$').firstMatch(value);
    return match == null ? value : '${match[1]}..${match[2]}';
  }

  @override
  bool accepts(String value) =>
      value == 'none' ||
      (RegExp(r'^[0-9]+(?:\.\.[0-9]+)?$').hasMatch(value) &&
          super.accepts(value));
  @override
  String? compose(String value, {bool exclude = false}) => accepts(value)
      ? '${exclude ? '-' : ''}rating:${value.replaceFirst('..', '-')}'
      : null;
}

List<SearchOption> hybooruOptions() => [
  SearchOption(
    kind: SearchOptionKind.sort,
    key: 'order',
    input: SearchOptionInput.text,
    descriptionKey: 'hybooru_sort',
    choices: [
      const SearchOptionChoice('newest', 'date_desc'),
      const SearchOptionChoice('oldest', 'date_asc'),
      const SearchOptionChoice('highest_score', 'score_desc'),
      for (final key in ['id', 'score', 'size'])
        for (final direction in ['asc', 'desc'])
          if (key != 'score' || direction != 'desc')
            SearchOptionChoice('${key}_$direction', '${key}_$direction'),
    ],
  ),
  const HybooruRatingOption(),
  const SearchOption(
    kind: SearchOptionKind.metadata,
    key: 'system',
    input: SearchOptionInput.choice,
    labelKey: 'system',
    descriptionKey: 'hydrus_state',
    negation: SearchOptionNegation.prefix,
    choices: [
      SearchOptionChoice('inbox', 'inbox'),
      SearchOptionChoice('archive', 'archive'),
      SearchOptionChoice('trash', 'trash'),
    ],
  ),
];
