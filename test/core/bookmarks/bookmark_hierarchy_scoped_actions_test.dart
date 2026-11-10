import 'dart:async';

import 'package:boorusama/core/bookmarks/src/providers/bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_group.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_library_state.dart';
import 'package:boorusama/core/bookmarks/src/types/legacy_group_bookmark.dart';
import 'package:boorusama/core/bookmarks/src/widgets/bookmark_multi_selection.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

import 'pool_bookmark_test_utils.dart';

void main() {
  const parent = '11111111-1111-4111-8111-111111111111';
  const child = '22222222-2222-4222-8222-222222222222';
  const outside = '33333333-3333-4333-8333-333333333333';
  final known = testPoolPost(101).copyWith(id: 21);
  final opaque = testPoolPost(102).copyWith(id: 22, postId: () => null);
  final collection = LegacyGroupBookmark.fromMetadata(
    id: 23,
    metadata: testPool(id: 303),
  );
  final library = BookmarkLibraryState(
    bookmarks: [known, opaque],
    records: [known, opaque, collection],
    groups: [
      BookmarkGroup(id: parent, name: 'Parent', bookmarkIds: {}),
      BookmarkGroup(
        id: child,
        name: 'Actual source',
        parentGroupId: parent,
        bookmarkIds: {21, 22, 23},
      ),
      BookmarkGroup(
        id: outside,
        name: 'Outside subtree',
        bookmarkIds: {21, 22, 23},
      ),
    ],
  );

  testWidgets(
    'aggregate removal offers actual direct sources within its subtree',
    (tester) async {
      BookmarkGroupSelectionTarget? selected;
      final posts = [known.post, opaque.post];
      final pools = library.pools;
      final summary = BookmarkGroupSelectionSummary.fromPosts(
        posts: posts,
        state: library,
        booruId: 1,
        pools: pools,
      );
      expect(summary.countFor(parent), 0);
      expect(summary.countFor(child), 3);
      expect(summary.countFor(outside), 3);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [bookmarkProvider.overrideWith(() => _Library(library))],
          child: BooruLocalization(
            child: MaterialApp(
              builder: (context, child) => KurumiTheme(
                data: KurumiThemeData.fromMaterial(Theme.of(context)),
                child: child!,
              ),
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () async {
                      selected = await showBookmarkGroupSelectionDialog(
                        context,
                        operation: BookmarkMultiSelectionOperation.remove,
                        posts: posts,
                        pools: pools,
                        config: BooruConfig.empty.auth,
                        allowedGroupIds: library.groupTree.subtreeIds(parent),
                      );
                    },
                    child: const Text('Remove'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      expect(find.text('Outside subtree'), findsNothing);
      final rootRow = find.byKey(
        const ValueKey(('bookmark-picker-group', parent)),
      );
      final rect = tester.getRect(rootRow);
      await tester.tapAt(Offset(rect.left + 30, rect.center.dy));
      await tester.pumpAndSettle();
      expect(
        selected,
        isNull,
        reason:
            'An empty ancestor is navigation, never a fabricated direct source',
      );
      expect(
        find.byKey(const ValueKey('bookmark-picker-path')),
        findsNothing,
        reason: 'The body cannot navigate an ancestor without direct members',
      );
      await tester.tapAt(Offset(rect.right - 40, rect.center.dy));
      await tester.pumpAndSettle();
      expect(find.text('Actual source'), findsOneWidget);
      expect(find.text('Outside subtree'), findsNothing);
      final sourceRow = tester.getRect(
        find.byKey(const ValueKey(('bookmark-picker-group', child))),
      );
      await tester.tapAt(Offset(sourceRow.left + 30, sourceRow.center.dy));
      await tester.pumpAndSettle();
      expect(selected?.id, child);
      expect(library.groupsById[parent]!.bookmarkIds, isEmpty);
      expect(library.groupsById[outside]!.bookmarkIds, {21, 22, 23});
      expect(tester.takeException(), isNull);
    },
  );
}

class _Library extends BookmarkLibraryNotifier {
  _Library(this.library);
  final BookmarkLibraryState library;
  @override
  FutureOr<BookmarkLibraryState> build() => library;
}
