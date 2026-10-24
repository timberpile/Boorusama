import '../../../core/search/options/adapter_directives.dart';
import '../../../core/search/options/catalog/philomena.dart';

/// Sorting is an API parameter, not part of Philomena's native q grammar.
/// Only an explicit, supported top-level sort directive is consumed. Unknown or
/// grouped raw syntax stays untouched instead of being silently discarded.
class PhilomenaSearchRequest {
  const PhilomenaSearchRequest({
    required this.query,
    this.sortField,
    this.sortDirection,
  });

  factory PhilomenaSearchRequest.fromTags(List<String> tags) {
    String? field;
    String? direction;
    final conditions = <String>[];
    final retained = extractSearchAdapterDirectives(tags, (tag) {
      final parts = tag.split(':');
      if (parts case ['sort', final name, final order]
          when philomenaSortFields.contains(name) &&
              const {'asc', 'desc'}.contains(order)) {
        field = name;
        direction = order;
        return true;
      }
      return false;
    });
    for (final tag in retained) {
      // Plain Booru-style tag input uses underscores for spaces. Native
      // field names, literal URLs and grouped expressions must retain them.
      conditions.add(
        tag.contains(':') || RegExp(r'[()"\s]').hasMatch(tag)
            ? tag
            : tag.replaceAll('_', ' '),
      );
    }
    return PhilomenaSearchRequest(
      query: conditions.where((term) => term.trim().isNotEmpty).join(','),
      sortField: field,
      sortDirection: direction,
    );
  }
  final String query;
  final String? sortField;
  final String? sortDirection;
}
