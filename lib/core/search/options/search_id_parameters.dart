import 'adapter_directives.dart';

typedef SearchIdParameters = ({List<String> terms, Map<String, int> ids});

/// Consume only top-level, positive-ID directives declared by this engine.
/// Grouped, negated, unknown and malformed input remains verbatim; this is not
/// a parser for the remaining native query. Subsequent explicit directives win.
SearchIdParameters splitSearchIdParameters(
  List<String> terms,
  Set<String> keys,
) {
  final ids = <String, int>{};
  final retained = extractSearchAdapterDirectives(terms, (term) {
    final colon = term.indexOf(':');
    final key = colon > 0 ? term.substring(0, colon) : '';
    final value = colon > 0 ? term.substring(colon + 1) : '';
    final id = keys.contains(key) && RegExp(r'^[1-9][0-9]*$').hasMatch(value)
        ? int.tryParse(value)
        : null;
    if (id != null) {
      ids[key] = id;
      return true;
    }
    return false;
  });
  return (terms: List.unmodifiable(retained), ids: Map.unmodifiable(ids));
}
