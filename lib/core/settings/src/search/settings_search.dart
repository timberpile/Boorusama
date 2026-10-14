/// A localized, read-only description of a setting and its owning category.
class SettingsSearchItem {
  const SettingsSearchItem({
    required this.id,
    required this.sectionId,
    required this.sectionTitle,
    required this.title,
    this.description = '',
    this.keywords = const [],
  });

  final String id;
  final String sectionId;
  final String sectionTitle;
  final String title;
  final String description;
  final List<String> keywords;
}

/// Matches every query word across labels, descriptions and aliases. Titles
/// rank ahead of incidental matches; ties retain the settings catalog order.
List<SettingsSearchItem> searchSettings(
  Iterable<SettingsSearchItem> items,
  String query,
) {
  final normalizedQuery = _normalize(query);
  if (normalizedQuery.isEmpty) return [];

  final words = normalizedQuery.split(' ').toSet();
  final matches = <({SettingsSearchItem item, int rank, int order})>[];
  var order = 0;

  for (final item in items) {
    final title = _normalize(item.title);
    final fields = [
      title,
      _normalize(item.sectionTitle),
      _normalize(item.description),
      ...item.keywords.map(_normalize),
    ];

    if (words.every((word) => fields.any((field) => field.contains(word)))) {
      final rank = title == normalizedQuery
          ? 0
          : title.startsWith(normalizedQuery)
          ? 1
          : title.contains(normalizedQuery)
          ? 2
          : words.every(title.contains)
          ? 3
          : 4;
      matches.add((item: item, rank: rank, order: order));
    }
    order++;
  }

  matches.sort((a, b) {
    final byRank = a.rank.compareTo(b.rank);
    return byRank != 0 ? byRank : a.order.compareTo(b.order);
  });
  return [for (final match in matches) match.item];
}

final _separators = RegExp(r'[\s_\-]+');

String _normalize(String value) =>
    value.toLowerCase().replaceAll(_separators, ' ').trim();
