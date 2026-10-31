import 'package:boorusama/core/bookmarks/src/providers/bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_group.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_library_state.dart';
import 'package:boorusama/core/bookmarks/src/widgets/bookmark_folder_picker_contents.dart';
import 'package:boorusama/core/bookmarks/src/widgets/bookmark_multi_selection.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/groups/folder_tree.dart';
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

void main() {
  setUpAll(() => ensureI18nInitialized('en-US'));
  for (final operation in BookmarkMultiSelectionOperation.values) {
    testWidgets(
      'batch $operation keeps applicable groups and useful ancestors',
      (tester) async {
        final rows = [
          for (var id = 1; id <= 2; id++)
            Bookmark.empty.copyWith(
              id: id,
              sourceUrl: 'https://source.test',
              postId: () => 100 + id,
            ),
        ];
        final library = BookmarkLibraryState(
          bookmarks: rows,
          folders: const [
            CollectionFolder(id: 'root', name: 'Ancestor'),
            CollectionFolder(id: 'leaf', name: 'Nested', parentId: 'root'),
            CollectionFolder(id: 'empty', name: 'Empty', parentId: 'root'),
            CollectionFolder(id: 'unrelated', name: 'Unrelated'),
          ],
          groups: [
            BookmarkGroup(
              id: 'applicable',
              name: 'Partial group',
              bookmarkIds: {1},
              folderId: 'leaf',
            ),
            BookmarkGroup(
              id: 'unused',
              name: 'Unused group',
              bookmarkIds: {},
              folderId: 'unrelated',
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
          picker.folders.map((folder) => folder.id).toSet(),
          add ? {'root', 'leaf', 'empty', 'unrelated'} : {'root', 'leaf'},
        );
        expect(
          picker.groups.map((group) => group.id).toSet(),
          add ? {'applicable', 'unused'} : {'applicable'},
        );
        expect(picker.onCreateGroup != null, add);
        expect(find.text('Unrelated'), add ? findsOneWidget : findsNothing);
        await tester.tap(find.text('Ancestor'));
        await tester.pumpAndSettle();
        expect(find.text('Empty'), add ? findsOneWidget : findsNothing);
        await tester.tap(find.text('Nested'));
        await tester.pumpAndSettle();
        expect(find.text('Partial group'), findsOneWidget);
        expect(find.text('1 of 2 selected'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
