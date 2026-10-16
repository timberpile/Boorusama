enum SearchOptionKind { rating, date, order, user, pool, favorites }

enum SearchOptionValueLabel {
  general,
  safe,
  sensitive,
  questionable,
  explicit,
  newest,
  score,
}

/// A site's syntax and supported values stay behind this capability. The shared
/// UI collects values and publishes the same query tokens as typed searches.
abstract interface class SearchOptionsCapability {
  List<SearchOption> get searchOptions;
}

class SearchOption {
  const SearchOption({
    required this.kind,
    required this.prefix,
    this.values = const [],
    this.valueLabels = const {},
  });

  final SearchOptionKind kind;
  final String prefix;
  final List<String> values;
  final Map<String, SearchOptionValueLabel> valueLabels;

  String? compose(String input) {
    final value = input.trim();
    if (value.isEmpty || value.contains(':')) return null;
    if (values.isNotEmpty && !values.contains(value)) return null;
    return '$prefix:${value.replaceAll(RegExp(r'\s+'), '_')}';
  }
}
