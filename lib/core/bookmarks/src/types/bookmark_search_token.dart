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

String insertBookmarkTagSuggestion(String text, String suggestion) {
  final trimmed = text.trim();
  final parts = trimmed.isEmpty ? <String>[] : trimmed.split(RegExp(r'\s+'));
  final token = BookmarkSearchToken.current(text);
  final replacement = '${token.isNegative ? '-' : ''}$suggestion';
  if (parts.isNotEmpty && suggestion.toLowerCase().contains(token.tag)) {
    parts[parts.length - 1] = replacement;
  } else {
    parts.add(suggestion);
  }
  return '${parts.join(' ')} ';
}
