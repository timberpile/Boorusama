import 'package:boorusama/core/bookmarks/src/providers/bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_group.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_library_state.dart';
import 'package:boorusama/core/bookmarks/src/widgets/bookmark_folder_picker_contents.dart';
import 'package:boorusama/core/bookmarks/src/widgets/bookmark_multi_selection.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:material_ui/material_ui.dart'
    show MaterialUiCompatibilityBridge;

class _Library extends BookmarkLibraryNotifier {
  _Library(this.library);
  final BookmarkLibraryState library;
  @override
  Future<BookmarkLibraryState> build() => Future.value(library);
}

const _ancestorId = '11111111-1111-4111-8111-111111111111';
const _nestedId = '22222222-2222-4222-8222-222222222222';
const _emptyId = '33333333-3333-4333-8333-333333333333';
const _unrelatedId = '44444444-4444-4444-8444-444444444444';
const _applicableId = '55555555-5555-4555-8555-555555555555';
const _unusedId = '66666666-6666-4666-8666-666666666666';

ValueKey<(String, String)> _groupRowKey(String id) =>
    ValueKey(('bookmark-picker-group', id));

Future<void> _navigateInto(WidgetTester tester, String id) async {
  final bounds = tester.getRect(find.byKey(_groupRowKey(id)));
  await tester.tapAt(Offset(bounds.right - 40, bounds.center.dy));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => ensureI18nInitialized('en-US'));
  for (final operation in BookmarkMultiSelectionOperation.values) {
    testWidgets(
      'batch $operation keeps applicable groups and useful ancestors',
      (tester) async {
        final rows = [
          for (var id = 1; id <= 2; id++)
            PostBookmark.empty.copyWith(
              id: id,
              sourceUrl: 'https://source.test',
              postId: () => 100 + id,
            ),
        ];
        final library = BookmarkLibraryState(
          bookmarks: rows,
          records: rows,
          groups: [
            BookmarkGroup(
              id: _ancestorId,
              name: 'Ancestor',
              bookmarkIds: {},
            ),
            BookmarkGroup(
              id: _nestedId,
              name: 'Nested',
              parentGroupId: _ancestorId,
              bookmarkIds: {},
            ),
            BookmarkGroup(
              id: _emptyId,
              name: 'Empty',
              parentGroupId: _ancestorId,
              bookmarkIds: {},
            ),
            BookmarkGroup(
              id: _unrelatedId,
              name: 'Unrelated',
              bookmarkIds: {},
            ),
            BookmarkGroup(
              id: _applicableId,
              name: 'Partial group',
              bookmarkIds: {1},
              parentGroupId: _nestedId,
            ),
            BookmarkGroup(
              id: _unusedId,
              name: 'Unused group',
              bookmarkIds: {},
              parentGroupId: _unrelatedId,
            ),
          ],
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [bookmarkProvider.overrideWith(() => _Library(library))],
            child: BooruLocalization(
              child: MaterialApp(
                builder: (context, child) => MaterialUiCompatibilityBridge(
                  child: KurumiTheme(
                    data: KurumiThemeData.fromMaterial(Theme.of(context)),
                    child: child!,
                  ),
                ),
                home: Builder(
                  builder: (context) => Scaffold(
                    body: TextButton(
                      onPressed: () => showBookmarkGroupSelectionDialog(
                        context,
                        operation: operation,
                        posts: rows.map((row) => row.post).toList(),
                        config: BooruConfig.empty.auth,
                      ),
                      child: const Text('Open'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        final picker = tester.widget<BookmarkFolderPickerContents>(
          find.byType(BookmarkFolderPickerContents),
        );
        final add = operation == BookmarkMultiSelectionOperation.add;
        expect(
          picker.groups.map((group) => group.id).toSet(),
          add
              ? {
                  _ancestorId,
                  _nestedId,
                  _emptyId,
                  _unrelatedId,
                  _applicableId,
                  _unusedId,
                }
              : {_ancestorId, _nestedId, _applicableId},
        );
        expect(picker.onCreateGroup != null, add);
        expect(find.text('Unrelated'), add ? findsOneWidget : findsNothing);
        await _navigateInto(tester, _ancestorId);
        await tester.pumpAndSettle();
        expect(find.text('Empty'), add ? findsOneWidget : findsNothing);
        await _navigateInto(tester, _nestedId);
        await tester.pumpAndSettle();
        expect(find.text('Partial group'), findsOneWidget);
        expect(find.text('1 of 2 selected'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
