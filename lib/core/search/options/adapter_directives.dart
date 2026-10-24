/// Extracts engine-declared API directives from flattened history, Topic and
/// shared queries. It does not tokenize or rewrite the remaining native query.
/// Quoted, escaped and grouped expressions are opaque. Malformed grouping
/// leaves the entire item untouched so incomplete input cannot broaden a search.
List<String> extractSearchAdapterDirectives(
  List<String> terms,
  bool Function(String token) consume,
) => [
  for (final term in terms)
    if (_extract(term, consume) case final remaining? when remaining.isNotEmpty)
      remaining,
];

String? _extract(String term, bool Function(String) consume) {
  final spans = <(int, int)>[];
  final stack = <String>[];
  String? quote;
  var escaped = false;
  var start = 0;
  for (var i = 0; i < term.length; i++) {
    final c = term[i];
    if (escaped) {
      escaped = false;
      continue;
    }
    if (c == r'\') {
      escaped = true;
    } else if (quote != null) {
      if (c == quote) quote = null;
    } else if (c == '"' || c == "'") {
      quote = c;
    } else if (const ['(', '[', '{'].contains(c)) {
      stack.add(c);
    } else if (const [')', ']', '}'].contains(c)) {
      if (stack.isEmpty ||
          '([{'.indexOf(stack.removeLast()) != ')]}'.indexOf(c)) {
        return term;
      }
    } else if (stack.isEmpty && RegExp(r'\s').hasMatch(c)) {
      if (start < i) spans.add((start, i));
      start = i + 1;
    }
  }
  if (quote != null || escaped || stack.isNotEmpty) return term;
  if (start < term.length) spans.add((start, term.length));
  final removed = [
    for (final span in spans)
      if (consume(term.substring(span.$1, span.$2))) span,
  ];
  if (removed.isEmpty) return term;
  final remaining = StringBuffer();
  var cursor = 0;
  for (final (start, end) in removed) {
    remaining.write(term.substring(cursor, start));
    cursor = end;
  }
  remaining.write(term.substring(cursor));
  return remaining.toString().trim();
}
