// Package imports:
import 'package:booru_clients/hydrus.dart';

// Project imports:
import '../../../core/tags/autocompletes/types.dart';
import '../../../core/tags/categories/types.dart';
import '../../../core/tags/tag/types.dart';

AutocompleteData parseHydrusAutocompleteData(AutocompleteDto dto) {
  final category = parseHydrusCategory(dto.value);

  return AutocompleteData(
    label: parseHydrusTagLabel(dto.value),
    value: dto.value,
    category: category,
    postCount: dto.count,
  );
}

String? parseHydrusCategory(String value) {
  final separator = value.indexOf(':');
  return separator > 0 ? value.substring(0, separator).toLowerCase() : null;
}

String parseHydrusTagLabel(String value) {
  final separator = value.indexOf(':');
  return separator > 0 && separator < value.length - 1
      ? value.substring(separator + 1)
      : value;
}

Tag parseHydrusTag(String value) {
  final namespace = parseHydrusCategory(value);

  return Tag.noCount(
    name: value,
    label: parseHydrusTagLabel(value),
    category: _hydrusTagCategory(namespace),
  );
}

TagCategory _hydrusTagCategory(String? namespace) => switch (namespace) {
  null || '' => TagCategory.general(),
  'artist' || 'creator' => TagCategory.artist(),
  'character' || 'person' => TagCategory.character(),
  'copyright' || 'series' || 'studio' => TagCategory.copyright(),
  'meta' || 'metadata' || 'system' || 'rating' => TagCategory.meta(),
  final namespace => TagCategory(
    id: namespace.hashCode,
    name: namespace,
  ),
};
