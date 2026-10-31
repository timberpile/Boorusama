import 'package:foundation/foundation.dart';

import '../../tags/autocompletes/types.dart';
import '../../tags/metatag/types.dart';
import '../options/option_query_value.dart';
import '../selected_tags/types.dart';

/// Filters confirmed ordinary terms without interpreting opaque raw queries.
/// Autocomplete values carry identity; labels may be translated or aliased.
IList<AutocompleteData> withoutSelectedTagSuggestions({
  required Iterable<AutocompleteData> suggestions,
  required Iterable<TagSearchItem> selectedTags,
  MetatagExtractor? extractor,
  Set<String> optionKeys = const {},
  Iterable<AutocompleteData> knownAliases = const [],
}) {
  bool ordinary(TagSearchItem item) {
    if (item.isRaw || item.metatag != null) return false;
    final unsigned = item.toString().replaceFirst(RegExp('^[-~]'), '');
    return !optionKeys.any((key) => optionQueryValue(unsigned, key) != null);
  }

  String identity(TagSearchItem item) => item.rawTag.toLowerCase();
  final selected = {
    for (final item in selectedTags)
      if (ordinary(item)) identity(item),
  };
  if (selected.isEmpty) return suggestions.toIList();

  final candidates = suggestions.toList(growable: false);
  final aliases = <String, Set<String>>{};
  for (final suggestion in [...candidates, ...knownAliases]) {
    final antecedent = suggestion.antecedent;
    if (suggestion.type != AutocompleteData.alias || antecedent == null) {
      continue;
    }
    final value = TagSearchItem.fromString(
      suggestion.value,
      extractor: extractor,
    );
    final alias = TagSearchItem.fromString(antecedent, extractor: extractor);
    if (!ordinary(value) || !ordinary(alias)) continue;
    final canonicalId = identity(value);
    final aliasId = identity(alias);
    if (canonicalId.isEmpty || aliasId.isEmpty) continue;
    aliases.putIfAbsent(canonicalId, () => <String>{}).add(aliasId);
    aliases.putIfAbsent(aliasId, () => <String>{}).add(canonicalId);
  }

  // Resolve explicit relationships before filtering any row. A selected alias
  // also excludes a separate canonical row, regardless of response order.
  // Only explicit alias relationships from the current profile participate;
  // spelling corrections are not aliases. Handle chains and cycles safely.
  final pending = selected.toList();
  for (var index = 0; index < pending.length; index++) {
    for (final related in aliases[pending[index]] ?? const <String>{}) {
      if (selected.add(related)) pending.add(related);
    }
  }

  return candidates.where((suggestion) {
    if (suggestion.type != null &&
        !AutocompleteData.isTagType(suggestion.type)) {
      return true;
    }
    final item = TagSearchItem.fromString(
      suggestion.value,
      extractor: extractor,
    );
    return !ordinary(item) || !selected.contains(identity(item));
  }).toIList();
}
