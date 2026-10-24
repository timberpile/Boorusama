import 'search_option.dart';

/// Search both localized titles and wire keys, without requiring a title prefix.
List<SearchOption> matchSearchOptions({
  required Iterable<SearchOption> options,
  required String query,
  required String Function(SearchOption) title,
  Map<String, String> aliases = const {},
}) {
  String normalize(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[_\s-]+'), ' ').trim();

  final clean = normalize(query);
  if (clean.isEmpty) return [];
  final words = clean.split(' ');
  final matches = <({SearchOption option, int rank, int length, int index})>[];
  var index = 0;
  for (final option in options) {
    final label = normalize(title(option));
    final terms = [
      label,
      normalize(option.key),
      for (final entry in aliases.entries)
        if (entry.value == option.key) normalize(entry.key),
    ];
    if (words.every((word) => terms.any((term) => term.contains(word)))) {
      matches.add((
        option: option,
        rank: terms.contains(clean)
            ? 0
            : terms.any((term) => term.startsWith(clean))
            ? 1
            : 2,
        // Prefer concise matches so broad terms such as "count" do not bury
        // "Tag count" beneath more specific count options in the catalog.
        length: label.length,
        index: index,
      ));
    }
    index++;
  }
  matches.sort((a, b) {
    final rank = a.rank.compareTo(b.rank);
    if (rank != 0) return rank;
    final length = a.length.compareTo(b.length);
    return length != 0 ? length : a.index.compareTo(b.index);
  });
  return [for (final match in matches) match.option];
}
