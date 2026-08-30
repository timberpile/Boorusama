import 'package:flutter_test/flutter_test.dart';

import 'package:boorusama/core/bookmarks/src/providers/bookmark_group_deletion.dart';

void main() {
  test('refreshes group state when orphan bookmark cleanup fails', () async {
    var selectionReset = false;
    var providersRefreshed = false;

    await expectLater(
      deleteBookmarkGroupAndRefresh(
        deleteGroup: () async => {12},
        removeOrphanBookmarks: (_) =>
          Future<void>.error(StateError('bookmark cleanup failed')),
        resetSelection: () async => selectionReset = true,
        refreshProviders: () => providersRefreshed = true,
      ),
      throwsA(isA<StateError>()),
    );

    expect(selectionReset, isTrue);
    expect(providersRefreshed, isTrue);
  });
}
