// Package imports:
import 'package:equatable/equatable.dart';

class SortableTagType extends Equatable {
  const SortableTagType({
    required this.name,
  });

  final String name;

  @override
  List<Object?> get props => [name];

  static bool isValidSortMetatag(
    String query,
    Set<SortableTagType> sortableTypes, {
    bool allowRandomSort = false,
    bool allowSeededRandomSort = false,
  }) => switch (query.split(':')) {
    ['sort', 'random'] => allowRandomSort,
    ['sort', 'random', final seed]
        when allowSeededRandomSort &&
            RegExp(r'^(?:0|[1-9][0-9]{0,4})$').hasMatch(seed) &&
            int.parse(seed) <= 10000 =>
      true,
    ['sort', final type, final order]
        when sortableTypes.any((t) => t.name == type) &&
            SortType.isValid(order) =>
      true,
    _ => false,
  };
}

enum SortType {
  ascending,
  descending;

  factory SortType.fromString(String value) => switch (value.toLowerCase()) {
    'asc' || 'ascending' => SortType.ascending,
    'desc' || 'descending' => SortType.descending,
    _ => SortType.ascending,
  };

  String toShortString() => switch (this) {
    ascending => 'asc',
    descending => 'desc',
  };

  static bool isValid(String value) {
    final validValues = SortType.values.map((e) => e.toShortString()).toSet();
    return validValues.contains(value);
  }
}

String buildMetatagRegexPattern({
  required List<String> metatags,
  required List<String> sortableTypes,
  bool allowRandomSort = false,
  bool allowSeededRandomSort = false,
}) {
  final regularMetatags = metatags.where((e) => e != 'sort').join('|');
  final sortParts = [
    if (sortableTypes.isNotEmpty)
      '(?:${sortableTypes.join('|')})(?::(?:asc|desc)?)?',
    if (allowRandomSort)
      allowSeededRandomSort ? 'random(?::[0-9]{0,5})?' : 'random',
  ];

  return 'sort:(?:(?:${sortParts.join('|')}))?|(?:$regularMetatags):';
}

String? extractMetatagMatch(
  String input,
  List<String> metatags,
  List<String> sortableTypes, {
  bool allowRandomSort = false,
  bool allowSeededRandomSort = false,
}) {
  final pattern = buildMetatagRegexPattern(
    metatags: metatags,
    sortableTypes: sortableTypes,
    allowRandomSort: allowRandomSort,
    allowSeededRandomSort: allowSeededRandomSort,
  );
  final regex = RegExp(pattern, caseSensitive: false);
  final match = regex.firstMatch(input);

  return (match != null && match.start == 0) ? match.group(0) : null;
}
