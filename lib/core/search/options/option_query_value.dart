/// Reads the value of one known option without interpreting opaque queries.
/// The caller must select the key from the active profile's catalog.
String? optionQueryValue(String unsignedQuery, String key) {
  if (unsignedQuery.startsWith('$key:')) {
    return unsignedQuery.substring(key.length + 1);
  }
  final lower = '($key.gte:';
  final upper = ',$key.lte:';
  if (unsignedQuery.startsWith(lower) && unsignedQuery.endsWith(')')) {
    final middle = unsignedQuery.substring(
      lower.length,
      unsignedQuery.length - 1,
    );
    final parts = middle.split(upper);
    if (parts.length == 2 &&
        !parts.any((part) => RegExp('[,()]').hasMatch(part))) {
      return '${parts.first}..${parts.last}';
    }
  }
  for (final (suffix, comparison) in const [
    ('gte', '>='),
    ('lte', '<='),
    ('gt', '>'),
    ('lt', '<'),
  ]) {
    final prefix = '$key.$suffix:';
    if (unsignedQuery.startsWith(prefix)) {
      return '$comparison${unsignedQuery.substring(prefix.length)}';
    }
  }
  for (final comparison in const ['>=', '<=', '=', '>', '<']) {
    final prefix = '$key$comparison';
    if (unsignedQuery.startsWith(prefix)) {
      return '${comparison == '=' ? '' : comparison}${unsignedQuery.substring(prefix.length)}';
    }
  }
  return null;
}

/// One guided condition replaces all declared spellings of its predicate.
/// Danbooru's full ordering vocabulary also denotes one exclusive family.
/// Activate this rule only when the active catalog declares that vocabulary;
/// unknown hosts and profiles with merely an `order` key retain their input.
Set<String> optionReplacementKeys(
  String key,
  Set<String> declaredKeys, {
  Map<String, String> aliases = const {},
}) {
  const ordering = {'order', 'ordfav', 'ordvote', 'ordfavgroup', 'ordpool'};
  if (ordering.contains(key) && declaredKeys.containsAll(ordering)) {
    return ordering;
  }
  final canonical = aliases[key] ?? key;
  return {
    key,
    canonical,
    for (final entry in aliases.entries)
      if (entry.value == canonical && declaredKeys.contains(entry.key))
        entry.key,
  };
}
