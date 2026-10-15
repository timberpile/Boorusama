/// Bookmark search supports only exact tags and a leading negative operator.
class BookmarkSearchToken {
  const BookmarkSearchToken._(this.tag, this.isNegative);

  factory BookmarkSearchToken.parse(String text) {
    final token = text.trim();
    final isNegative = token.startsWith('-');
    return BookmarkSearchToken._(
      token.substring(isNegative ? 1 : 0).toLowerCase(),
      isNegative,
    );
  }

  factory BookmarkSearchToken.current(String text) =>
      BookmarkSearchToken.parse(text.trim().split(RegExp(r'\s+')).last);

  final String tag;
  final bool isNegative;
}

String canonicalBookmarkTag(String text) =>
    text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_');

/// Longest phrase first: a readable tag may contain several typed words.
/// Earlier, unrelated tokens in a pasted query remain outside the replacement.
Iterable<({String prefix, BookmarkSearchToken token})>
bookmarkSuggestionQueries(String text) sync* {
  final words = text.trim().split(RegExp(r'\s+'));
  for (var start = 0; start < words.length; start++) {
    yield (
      prefix: words.take(start).join(' '),
      token: BookmarkSearchToken.parse(words.skip(start).join('_')),
    );
  }
}

String insertBookmarkTagSuggestion(String text, String suggestion) {
  final canonical = canonicalBookmarkTag(suggestion);
  for (final query in bookmarkSuggestionQueries(text)) {
    if (!canonical.contains(query.token.tag)) continue;
    final replacement = '${query.token.isNegative ? '-' : ''}$canonical';
    return '${[query.prefix, replacement].where((s) => s.isNotEmpty).join(' ')} ';
  }
  return '${[text.trim(), canonical].where((s) => s.isNotEmpty).join(' ')} ';
}

/// Prefer an exact known readable phrase, otherwise preserve the existing
/// whitespace-delimited syntax for pasted canonical queries.
List<String> parseBookmarkSearchInput(
  String text, {
  Set<String> knownTags = const {},
}) {
  final words = text.trim().toLowerCase().split(RegExp(r'\s+'));
  final tags = <String>[];
  var start = 0;
  while (start < words.length) {
    var end = words.length;
    while (end > start + 1) {
      final candidate = words.sublist(start, end).join('_');
      if (knownTags.contains(BookmarkSearchToken.parse(candidate).tag)) break;
      end--;
    }
    final candidate = words.sublist(start, end).join('_');
    if (BookmarkSearchToken.parse(candidate).tag.isNotEmpty) {
      tags.add(candidate);
    }
    start = end;
  }
  return tags;
}
