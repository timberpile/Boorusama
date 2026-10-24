import 'package:boorusama/core/bookmarks/src/data/bookmark_group_name_filter.dart';
import 'package:boorusama/core/bookmarks/src/widgets/bookmark_overview_filter.dart';
import 'package:boorusama/core/groups/folder_tree.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

void main() {
  test('matching descendants retain their complete ancestor path', () {
    const folders = [
      CollectionFolder(id: 'root', name: 'Parent'),
      CollectionFolder(id: 'child', name: 'Child', parentId: 'root'),
      CollectionFolder(id: 'leaf', name: 'Matching folder', parentId: 'child'),
      CollectionFolder(id: 'other', name: 'Other'),
    ];
    expect(
      bookmarkMatchingFolderIds(
        folders: folders,
        matchingGroupFolderIds: const [],
        query: ' matching ',
      ),
      {'root', 'child', 'leaf'},
    );
    expect(
      bookmarkMatchingFolderIds(
        folders: folders,
        matchingGroupFolderIds: const ['child'],
        query: 'group',
      ),
      {'root', 'child'},
    );
    expect(
      bookmarkMatchingFolderIds(
        folders: folders,
        matchingGroupFolderIds: const [],
        query: 'absent',
      ),
      isEmpty,
    );
  });

  test('matches trimmed case-insensitive substrings, not tag syntax', () {
    expect(bookmarkGroupNameMatches('Favorite Landscapes', '  LAND  '), isTrue);
    expect(
      bookmarkGroupNameMatches('Favorite Landscapes', 'portrait'),
      isFalse,
    );
    expect(bookmarkGroupNameMatches('Favorite Landscapes', '-land'), isFalse);
    expect(bookmarkGroupNameMatches('Favorite Landscapes', '  '), isTrue);
    expect(bookmarkGroupNameMatches('All', 'all'), isTrue);
    expect(bookmarkGroupNameMatches('Ungrouped', 'group'), isTrue);
    expect(bookmarkGroupNameMatches('Alle', ' ALL '), isTrue);
    expect(bookmarkGroupNameMatches('Ohne Gruppe', 'GRUPPE'), isTrue);
  });

  test('preserves identity, duplicates, and caller ordering', () {
    final entries = [
      (id: 'b', name: 'Same'),
      (id: 'a', name: 'Other'),
      (id: 'c', name: 'Same'),
    ];
    final filtered = entries
        .where(
          (entry) => bookmarkGroupNameMatches(entry.name, 'same'),
        )
        .toList();
    expect(filtered.map((entry) => entry.id), ['b', 'c']);
    expect(
      entries.where((entry) => bookmarkGroupNameMatches(entry.name, '')),
      entries,
    );
    expect(entries.map((entry) => entry.name), ['Same', 'Other', 'Same']);
  });

  testWidgets('filter and clear remain usable at narrow width and large text', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    final observed = <String>[];
    controller.addListener(() => observed.add(controller.text));
    await tester.pumpWidget(
      BooruLocalization(
        child: MaterialApp(
          builder: (context, child) =>
              MaterialUiCompatibilityBridge(child: child!),
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: SizedBox(
                width: 280,
                child: BookmarkOverviewFilter(controller: controller),
              ),
            ),
          ),
        ),
      ),
    );
    final field = find.byKey(const Key('bookmark-group-name-filter'));
    await tester.enterText(field, '  Same  ');
    await tester.pump();
    expect(controller.text, '  Same  ');
    await tester.tap(find.byTooltip('Clear'));
    await tester.pump();
    expect(controller.text, isEmpty);
    expect(observed, contains('  Same  '));
    expect(observed.last, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('no-match state exposes a reset action', (tester) async {
    var cleared = false;
    await tester.pumpWidget(
      BooruLocalization(
        child: MaterialApp(
          builder: (context, child) =>
              MaterialUiCompatibilityBridge(child: child!),
          home: Scaffold(
            body: BookmarkOverviewNoMatches(onClear: () => cleared = true),
          ),
        ),
      ),
    );
    expect(find.byIcon(Icons.search_off), findsOneWidget);
    await tester.tap(find.text('Clear'));
    expect(cleared, isTrue);
  });
}
