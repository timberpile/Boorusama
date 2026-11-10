import 'package:boorusama/core/bookmarks/src/providers/bookmark_group_selectors.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'host choices and restored URL choices share the listing source scope',
    () {
      for (final choice in [
        'example.test',
        'EXAMPLE.test',
        'https://example.test',
        'https://example.test/install/',
      ]) {
        expect(
          bookmarkSourceMatchesHost('https://example.test/posts/1', choice),
          isTrue,
        );
        expect(
          bookmarkSourceMatchesHost('https://another.test', choice),
          isFalse,
        );
      }
      expect(bookmarkSourceMatchesHost('', 'example.test'), isFalse);
      expect(bookmarkSourceMatchesHost('https://example.test', ''), isFalse);
    },
  );
}
