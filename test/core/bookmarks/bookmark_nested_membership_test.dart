import 'package:boorusama/core/bookmarks/src/types/bookmark_group.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_group_tree.dart';
import 'package:boorusama/core/bookmarks/src/widgets/bookmark_folder_picker_contents.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'nested counts exclude direct membership and aggregate all descendants',
    () {
      final tree = BookmarkGroupTree([
        BookmarkGroup(id: 'a', name: 'A', bookmarkIds: const {}),
        BookmarkGroup(
          id: 'b',
          name: 'B',
          bookmarkIds: const {},
          parentGroupId: 'a',
        ),
        BookmarkGroup(
          id: 'c',
          name: 'C',
          bookmarkIds: const {},
          parentGroupId: 'b',
        ),
        BookmarkGroup(
          id: 'd',
          name: 'D',
          bookmarkIds: const {},
          parentGroupId: 'a',
        ),
        BookmarkGroup(id: 'e', name: 'E', bookmarkIds: const {}),
      ]);
      expect(bookmarkNestedMembershipCounts(tree, {'a', 'c', 'd'}), {
        'a': 2,
        'b': 1,
        'c': 0,
        'd': 0,
        'e': 0,
      });
      expect(bookmarkNestedMembershipCounts(tree, {'a'}), {
        'a': 0,
        'b': 0,
        'c': 0,
        'd': 0,
        'e': 0,
      });
    },
  );
}
