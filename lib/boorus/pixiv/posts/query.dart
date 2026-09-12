/// Prefix that scopes a search to one user's illusts, e.g. `user:12345`.
const kPixivUserPrefix = 'user:';

/// A search resolved from Boorusama's flat tag list into the shape Pixiv's
/// API actually accepts.
///
/// The core `PostRepository` contract hands the engine a list of tag
/// strings, but Pixiv only offers a single free-text search plus a
/// per-user illust listing. User scope is therefore carried as a `user:`
/// meta-tag, and anything unprefixed is treated as free text.
class PixivQuery {
  const PixivQuery({
    this.userId,
    this.text,
  });

  /// Parses Boorusama's tag list.
  ///
  /// Later occurrences win, so tapping a user after typing one behaves the
  /// way a user would expect. A malformed `user:` value (non-numeric, or
  /// empty) is ignored rather than crashing the search.
  factory PixivQuery.parse(List<String> tags) {
    int? userId;
    final freeText = <String>[];

    for (final raw in tags) {
      final entry = raw.trim();
      if (entry.isEmpty) continue;

      if (entry.startsWith(kPixivUserPrefix)) {
        final value = entry.substring(kPixivUserPrefix.length);
        final parsed = int.tryParse(value);

        if (parsed != null && parsed > 0) {
          userId = parsed;
        }
        continue;
      }

      freeText.add(entry);
    }

    return PixivQuery(
      userId: userId,
      text: freeText.isEmpty ? null : freeText.join(' '),
    );
  }

  final int? userId;
  final String? text;

  /// Whether this search targets a single user's illusts.
  bool get hasUser => userId != null;

  /// The meta-tag form, for putting a user scope back into the search bar.
  static String userTag(int userId) => '$kPixivUserPrefix$userId';
}
