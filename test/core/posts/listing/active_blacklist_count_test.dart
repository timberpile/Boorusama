import 'package:boorusama/core/posts/listing/src/types/active_blacklist_count.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const matches = {
    'official_art': {1, 2},
    'animated': {2},
    'unused': <int>{},
  };

  test('overlapping rules count each hidden post only once', () {
    expect(countActiveBlacklistPosts(matches, const {}), 2);
  });

  test('temporarily revealed rules do not contribute hidden posts', () {
    expect(countActiveBlacklistPosts(matches, const {'official_art': false}), 1);
    expect(
      countActiveBlacklistPosts(matches, const {
        'official_art': false,
        'animated': false,
      }),
      0,
    );
    expect(matches['official_art'], {1, 2});
  });

  test('restoring all rules restores the unique hidden count', () {
    expect(
      countActiveBlacklistPosts(matches, const {
        'official_art': true,
        'animated': true,
      }),
      2,
    );
    expect(countActiveBlacklistPosts(const {}, const {}), 0);
  });
}
