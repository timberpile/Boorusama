import 'package:equatable/equatable.dart';

import 'option_query_value.dart';

enum SearchOptionKind {
  uploaded,
  rating,
  sort,
  score,
  postId,
  uploader,
  metadata,
  native,
}

enum SearchOptionInput {
  choice,
  number,
  duration,
  text,
  decimal,
  date,
  filesize,
  ratio,
}

enum SearchOptionNegation { none, prefix, comparison }

class SearchOptionChoice extends Equatable {
  const SearchOptionChoice(this.label, this.value, {this.literal = false});
  final String label;
  final String value;

  /// Literal labels are native values, units or numeric examples, not UI prose.
  final bool literal;
  @override
  List<Object?> get props => [label, value, literal];
}

class SearchOption extends Equatable {
  const SearchOption({
    required this.kind,
    required this.key,
    required this.input,
    this.choices = const [],
    this.negation = SearchOptionNegation.none,
    this.isFree = false,
    this.labelKey,
    this.descriptionKey,
    this.allowRange = false,
    this.allowNegative = true,
  });
  final SearchOptionKind kind;
  final String key;
  final SearchOptionInput input;
  final List<SearchOptionChoice> choices;
  final SearchOptionNegation negation;
  final bool isFree;
  final String? labelKey;
  final String? descriptionKey;
  final bool allowRange;
  final bool allowNegative;

  bool get supportsExclusion => negation != SearchOptionNegation.none;
  bool get isComparable => switch (input) {
    SearchOptionInput.choice || SearchOptionInput.text => false,
    _ => true,
  };
  List<String> get comparisons =>
      isComparable ? const ['', '<', '<=', '>=', '>'] : const [];

  /// Converts a native wire value back to the shared graphical input shape.
  String editorValue(String value) => value;

  List<String> get units => switch (input) {
    SearchOptionInput.duration => const ['s', 'mi', 'h', 'd', 'w', 'mo', 'y'],
    SearchOptionInput.filesize => const ['b', 'kb', 'mb', 'gb'],
    _ => const [],
  };

  // Decorating FREE metadata must not erase a site's serializer/validator.
  SearchOption withFree(bool value) =>
      isFree == value ? this : _FreeSearchOption(this, value);

  bool accepts(String value) {
    if (value.isEmpty ||
        value != value.trim() ||
        RegExp(r'[\s\x00-\x1f]').hasMatch(value)) {
      return false;
    }
    if (choices.any((choice) => choice.value == value)) return true;
    if (input == SearchOptionInput.choice) return false;
    if (input == SearchOptionInput.text) return true;
    if (value.contains('..')) {
      if (!allowRange || value.contains('...')) return false;
      final parts = value.split('..');
      if (parts.length != 2 || parts.every((part) => part.isEmpty)) {
        return false;
      }
      if (parts.any((part) => part.isNotEmpty && !_acceptsAtom(part))) {
        return false;
      }
      final first = _orderedValue(parts.first);
      final last = _orderedValue(parts.last);
      return first == null || last == null || first <= last;
    }
    final match = RegExp('^(>=|<=|>|<)').firstMatch(value);
    if (match != null && !comparisons.contains(match[0])) return false;
    return _acceptsAtom(value.substring(match?.end ?? 0));
  }

  bool _acceptsAtom(String atom) {
    if (atom.isEmpty) return false;
    return switch (input) {
      SearchOptionInput.number =>
        RegExp(r'^-?[0-9]+$').hasMatch(atom) &&
            (allowNegative || !atom.startsWith('-')),
      SearchOptionInput.decimal =>
        RegExp(r'^-?[0-9]+(?:\.[0-9]+)?$').hasMatch(atom) &&
            (allowNegative || !atom.startsWith('-')) &&
            (double.tryParse(atom)?.isFinite ?? false),
      SearchOptionInput.duration => RegExp(
        r'^[1-9][0-9]*(?:s|mi|h|d|w|mo|y)$',
      ).hasMatch(atom),
      SearchOptionInput.filesize => RegExp(
        r'^[0-9]+(?:\.[0-9]+)?(?:b|kb|mb|gb|k|m|g)?$',
        caseSensitive: false,
      ).hasMatch(atom),
      SearchOptionInput.ratio => _ratio(atom) != null,
      SearchOptionInput.date => parseDate(atom) != null,
      _ => false,
    };
  }

  static DateTime? parseDate(String value) {
    if (!RegExp(r'^[0-9]{4}-[0-9]{2}-[0-9]{2}$').hasMatch(value)) return null;
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return null;
    final fields = value.split('-').map(int.parse).toList();
    return parsed.year == fields[0] &&
            parsed.month == fields[1] &&
            parsed.day == fields[2]
        ? parsed
        : null;
  }

  static double? _ratio(String value) {
    if (!RegExp(r'^[0-9]+(?:\.[0-9]+)?(?:[:/][0-9]+(?:\.[0-9]+)?)?$')
        .hasMatch(value)) {
      return null;
    }
    final parts = value.split(RegExp('[:/]')).map(double.parse).toList();
    if (parts.any((part) => !part.isFinite || part <= 0)) return null;
    final result = parts.length == 1 ? parts.first : parts.first / parts.last;
    return result.isFinite ? result : null;
  }

  num? _orderedValue(String value) => switch (input) {
    SearchOptionInput.number ||
    SearchOptionInput.decimal => num.tryParse(value),
    SearchOptionInput.date => parseDate(value)?.millisecondsSinceEpoch,
    SearchOptionInput.ratio => _ratio(value),
    _ => null,
  };

  String? compose(String value, {bool exclude = false}) {
    if (!accepts(value)) return null;
    if (!exclude) return '$key:$value';
    return switch (negation) {
      SearchOptionNegation.none => null,
      SearchOptionNegation.prefix => '-$key:$value',
      SearchOptionNegation.comparison => switch (complement(value)) {
        final inverse? => '$key:$inverse',
        null => null,
      },
    };
  }

  static String? complement(String value) {
    for (final (operator, inverse) in const [
      ('>=', '<'),
      ('<=', '>'),
      ('>', '<='),
      ('<', '>='),
    ]) {
      if (value.startsWith(operator)) {
        return '$inverse${value.substring(operator.length)}';
      }
    }
    return null;
  }

  @override
  List<Object?> get props => [
    kind,
    key,
    input,
    choices,
    negation,
    isFree,
    labelKey,
    descriptionKey,
    allowRange,
    allowNegative,
  ];
}

class _FreeSearchOption extends SearchOption {
  _FreeSearchOption(this.delegate, bool free)
    : super(
        kind: delegate.kind,
        key: delegate.key,
        input: delegate.input,
        choices: delegate.choices,
        negation: delegate.negation,
        isFree: free,
        labelKey: delegate.labelKey,
        descriptionKey: delegate.descriptionKey,
        allowRange: delegate.allowRange,
        allowNegative: delegate.allowNegative,
      );
  final SearchOption delegate;
  @override
  bool get isComparable => delegate.isComparable;
  @override
  List<String> get comparisons => delegate.comparisons;
  @override
  List<String> get units => delegate.units;
  @override
  String editorValue(String value) => delegate.editorValue(value);
  @override
  bool accepts(String value) => delegate.accepts(value);
  @override
  String? compose(String value, {bool exclude = false}) =>
      delegate.compose(value, exclude: exclude);
}

class SearchOptionContext extends Equatable {
  const SearchOptionContext({
    required this.option,
    required this.value,
    required this.exclude,
  });
  final SearchOption option;
  final String value;
  final bool exclude;
  @override
  List<Object?> get props => [option, value, exclude];
}

class SearchCapabilities extends Equatable {
  const SearchCapabilities(this.options);
  const SearchCapabilities.empty() : options = const [];
  final List<SearchOption> options;
  SearchOption? byKey(String key) {
    for (final option in options) {
      if (option.key == key) return option;
    }
    return null;
  }

  SearchOptionContext? contextFor(String input) {
    final query = input.trim();
    final exclude = query.startsWith('-');
    final unsigned = exclude ? query.substring(1) : query;
    for (final option in options) {
      final value = optionQueryValue(unsigned, option.key);
      if (value != null) {
        return SearchOptionContext(
          option: option,
          value: option.editorValue(value),
          exclude: exclude,
        );
      }
    }
    return null;
  }

  @override
  List<Object?> get props => [options];
}
