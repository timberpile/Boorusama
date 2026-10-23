import '../search_option.dart';

/// Keep readable inverted comparisons, but use actual predicate negation for
/// an equality or range. The latter cannot be expressed by one comparison.
class DanbooruRangeOption extends SearchOption {
  DanbooruRangeOption(SearchOption option)
    : super(
        kind: option.kind,
        key: option.key,
        input: option.input,
        choices: option.choices,
        negation: SearchOptionNegation.prefix,
        isFree: option.isFree,
        labelKey: option.labelKey,
        descriptionKey: option.descriptionKey,
        allowRange: option.allowRange,
        allowNegative: option.allowNegative,
      );
  @override
  String? compose(String value, {bool exclude = false}) {
    if (!accepts(value)) return null;
    if (!exclude) return '$key:$value';
    final inverse = SearchOption.complement(value);
    return inverse != null ? '$key:$inverse' : '-$key:$value';
  }
}

class DanbooruResultCountOption extends SearchOption {
  DanbooruResultCountOption(SearchOption option)
    : super(
        kind: option.kind,
        key: option.key,
        input: SearchOptionInput.number,
        choices: option.choices,
        labelKey: option.labelKey,
        descriptionKey: option.descriptionKey,
        allowNegative: false,
      );
  @override
  bool get isComparable => false;
  @override
  bool accepts(String value) {
    if (!RegExp(r'^[0-9]+$').hasMatch(value)) return false;
    final count = int.tryParse(value);
    return count != null && count >= (key == 'limit' ? 1 : 0);
  }
}

const _relationshipChoices = [
  SearchOptionChoice('any', 'any'),
  SearchOptionChoice('none', 'none'),
  SearchOptionChoice('pending', 'pending'),
  SearchOptionChoice('flagged', 'flagged'),
  SearchOptionChoice('appealed', 'appealed'),
  SearchOptionChoice('modqueue', 'modqueue'),
  SearchOptionChoice('deleted', 'deleted'),
  SearchOptionChoice('banned', 'banned'),
  SearchOptionChoice('active', 'active'),
  SearchOptionChoice('unmoderated', 'unmoderated'),
];

class DanbooruParentOption extends SearchOption {
  const DanbooruParentOption()
    : super(
        key: 'parent',
        kind: SearchOptionKind.metadata,
        input: SearchOptionInput.number,
        choices: _relationshipChoices,
        negation: SearchOptionNegation.prefix,
        labelKey: 'parent',
        descriptionKey: 'parent',
        allowNegative: false,
      );
  @override
  bool get isComparable => false;
  @override
  bool accepts(String value) =>
      choices.any((choice) => choice.value == value) ||
      (RegExp(r'^[0-9]+$').hasMatch(value) && int.tryParse(value) != null);
}

List<SearchOption> completeDanbooruOptions(List<SearchOption> options) => [
  for (final option in options)
    switch (option.key) {
      'age' || 'score' => DanbooruRangeOption(option),
      'limit' || 'random' => DanbooruResultCountOption(option),
      'parent' => const DanbooruParentOption(),
      'child' => const SearchOption(
        key: 'child',
        kind: SearchOptionKind.metadata,
        input: SearchOptionInput.choice,
        labelKey: 'child',
        descriptionKey: 'child',
        choices: _relationshipChoices,
        negation: SearchOptionNegation.prefix,
      ),
      _ => option,
    },
];
