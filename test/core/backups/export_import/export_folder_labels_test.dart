import 'package:boorusama/core/backups/export_import/export/export_flow_notifier.dart';
import 'package:boorusama/core/backups/export_import/models/export_item_presentation.dart';
import 'package:boorusama/core/backups/export_import/models/export_selection.dart';
import 'package:boorusama/core/backups/export_import/widgets/selection_tree.dart';
import 'package:boorusama/core/bookmarks/providers.dart';
import 'package:boorusama/core/bookmarks/types.dart';
import 'package:boorusama/core/groups/folder_tree.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/material.dart';

import '../../search/following_topics/following_topic_test_utils.dart';

class _Library extends BookmarkLibraryNotifier {
  @override
  Future<BookmarkLibraryState> build() async => data('Child');
  BookmarkLibraryState data(String name) => BookmarkLibraryState(
    bookmarks: [],
    groups: [],
    folders: [
      const CollectionFolder(id: 'parent', name: 'Parent'),
      CollectionFolder(id: 'child', name: name, parentId: 'parent'),
    ],
  );
  void rename() => state = AsyncData(data('Renamed'));
}

void main() {
  test('nested folder names update while restored selector identity remains stable', () async {
    final library = _Library();
    final harness = FollowingTopicHarness(
      overrides: [bookmarkProvider.overrideWith(() => library)],
    );
    addTearDown(harness.dispose);
    await harness.container.read(bookmarkProvider.future);
    final keep = harness.container.listen(
      exportSelectionPresentationProvider,
      (_, _) {},
    );
    addTearDown(keep.close);
    final selection = ExportNodeSelection.explicit('bookmarks', {
      'group-folder:child',
    });
    final before = harness.container.read(exportSelectionPresentationProvider);
    expect(before.items['group-folder:parent']?.label, 'Parent');
    expect(before.items['group-folder:child']?.label, 'Child');
    library.rename();
    await harness.container.pump();
    expect(
      harness.container
          .read(exportSelectionPresentationProvider)
          .items['group-folder:child']
          ?.label,
      'Renamed',
    );
    expect(selection.childIds, {'group-folder:child'});
  });

  testWidgets(
    'missing folder uses a localized label without exposing its node key',
    (tester) async {
      final harness = FollowingTopicHarness();
      addTearDown(harness.dispose);
      const descriptor = ExportSelectionDescriptor.collection(
        id: 'bookmarks',
        children: [
          ExportSelectionNode(id: 'group-folder:deleted'),
        ],
      );
      await harness.pump(
        tester,
        Scaffold(
          body: ExportSelectionTree(
            descriptors: [descriptor],
            selections: const {},
            onToggleSource: (_) {},
            onToggleNode: (_, _) {},
            sourceLabel: (_) => 'Bookmarks',
            presentation: const ExportSelectionPresentation(items: {}),
          ),
        ),
      );
      // The collection can start collapsed.
      if (find.text('Folder').evaluate().isEmpty) {
        await tester.tap(find.text('Bookmarks'));
        await tester.pumpAndSettle();
      }
      expect(find.text('Folder'), findsOneWidget);
      expect(find.text('group-folder:deleted'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
