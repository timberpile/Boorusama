import 'package:booru_clients/nhentai.dart';

/// The trailing nhentai term being completed, with its preceding query intact.
final class NhentaiSearchTerm {
  const NhentaiSearchTerm._(this.before, this.operator, this.type, this.prefix);

  static final _terms = RegExp(r'(?:[^\s"\\]|\\.|"(?:[^"\\]|\\.)*(?:"|$))+');
  static final _category = RegExp('^([a-z]+):');
  static final _qualifiedTag = RegExp(
    r'^-?([a-z]+):("(?:[^"\\]|\\.)*"|[^\s"]+)$',
  );

  /// Recognizes one complete typed tag, including any quoted whitespace.
  static ({String type, String name})? qualifiedTag(String query) {
    final match = _qualifiedTag.firstMatch(query);
    if (match == null) return null;
    final type = match[1]!;
    if (!NhentaiClient.tagTypes.contains(type)) return null;
    final value = match[2]!;
    final name = value.startsWith('"')
        ? _unescape(value.substring(1, value.length - 1))
        : value;
    return name.isEmpty ? null : (type: type, name: name);
  }

  static String _unescape(String value) =>
      value.replaceAllMapped(RegExp(r'\\(["\\])'), (match) => match[1]!);

  static bool isSingle(String query) {
    final text = query.trim();
    return _terms.matchAsPrefix(text)?.end == text.length;
  }

  static NhentaiSearchTerm? trailing(String query) {
    final match = _terms.allMatches(query).lastOrNull;
    if (match == null || match.end != query.length) return null;
    final original = match[0]!;
    final operator = original.startsWith('-') ? '-' : '';
    final term = original.substring(operator.length);
    final category = _category.firstMatch(term);
    final type = category?.group(1);
    if (type != null && !NhentaiClient.tagTypes.contains(type)) return null;
    final prefix = _unescape(
      term
          .substring(category?.end ?? 0)
          .replaceFirst(RegExp('^"'), '')
          .replaceFirst(RegExp(r'"$'), ''),
    ).trimLeft();
    return NhentaiSearchTerm._(
      query.substring(0, match.start),
      operator,
      type,
      prefix,
    );
  }

  final String before;
  final String operator;
  final String? type;
  final String prefix;
}

String quoteNhentaiSearchValue(String value) {
  final escaped = value.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
  return '"$escaped"';
}

String nhentaiTagQuery(String name, String? category) {
  final value = quoteNhentaiSearchValue(name);
  return category == null ? value : '$category:$value';
}
