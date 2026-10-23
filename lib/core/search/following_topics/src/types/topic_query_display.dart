/// Read-only lexical presentation, never a query serializer or validator.
/// Preserve every raw character, including unknown syntax and quoted values.
class TopicQueryDisplayToken {
  const TopicQueryDisplayToken(this.raw);

  final String raw;
  bool get isWhitespace => raw.trim().isEmpty;
  String get operator =>
      raw.length > 1 && (raw.startsWith('-') || raw.startsWith('~'))
      ? raw[0]
      : '';
  String get body => raw.substring(operator.length);

  String? get tagName {
    if (isWhitespace || {'AND', 'OR', 'NOT'}.contains(body)) return null;
    if (RegExp(r'''[\s:"'\\{}\[\]*]''').hasMatch(body)) return null;
    if (body == '(' || body == ')' || body == '-' || body == '~') return null;
    return body;
  }

  String get displayBody => tagName == null ? body : body.replaceAll('_', ' ');
}

List<TopicQueryDisplayToken> topicQueryDisplayTokens(String query) {
  final tokens = <TopicQueryDisplayToken>[];
  var start = 0;
  var index = 0;
  while (index < query.length) {
    start = index;
    if (RegExp(r'\s').hasMatch(query[index])) {
      while (index < query.length && RegExp(r'\s').hasMatch(query[index])) {
        index++;
      }
    } else {
      String? quote;
      var escaped = false;
      while (index < query.length) {
        final character = query[index];
        if (!escaped && quote == null && RegExp(r'\s').hasMatch(character)) {
          break;
        }
        if (escaped) {
          escaped = false;
        } else if (character == '\\') {
          escaped = true;
        } else if (quote != null) {
          if (character == quote) quote = null;
        } else if (character == '"' || character == "'") {
          quote = character;
        }
        index++;
      }
    }
    tokens.add(TopicQueryDisplayToken(query.substring(start, index)));
  }
  return List.unmodifiable(tokens);
}
