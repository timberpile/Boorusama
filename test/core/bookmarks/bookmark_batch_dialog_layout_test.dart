import 'package:boorusama/core/bookmarks/src/types/bookmark_group.dart';
import 'package:boorusama/core/bookmarks/src/widgets/bookmark_batch_dialog.dart';
import 'package:boorusama/core/bookmarks/src/widgets/bookmark_folder_picker_contents.dart';
import 'package:boorusama/core/groups/folder_tree.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

void main() {
  setUpAll(() => ensureI18nInitialized('en-US'));

  Future<void> open(
    WidgetTester tester, {
    required int count,
    double scale = 1,
    bool nested = false,
    String title = 'Add bookmarks to group',
    Brightness brightness = Brightness.light,
    ValueChanged<String?>? selected,
  }) async {
    await tester.pumpWidget(
      BooruLocalization(
        child: MaterialApp(
          theme: ThemeData(brightness: brightness),
          builder: (context, child) => KurumiTheme(
            data: KurumiThemeData.fromMaterial(Theme.of(context)),
            child: MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  final value = await showDialog<String>(
                    context: context,
                    builder: (context) => BookmarkBatchDialog(
                      title: title,
                      child: BookmarkFolderPickerContents(
                        compact: true,
                        folders: nested
                            ? const [
                                CollectionFolder(id: 'folder', name: 'Folder'),
                              ]
                            : const [],
                        groups: [
                          for (var i = 0; i < count; i++)
                            BookmarkGroup(
                              id: '$i',
                              name: 'Group $i',
                              bookmarkIds: {},
                              folderId: nested ? 'folder' : null,
                            ),
                        ],
                        onCreateGroup: (_) {},
                        groupBuilder: (context, group) =>
                            BookmarkPickerMenuItem(
                              title: group.name,
                              icon: const Icon(Icons.bookmark_outline),
                              detail: '1 / 2',
                              hideOnTap: false,
                              onTap: () => Navigator.pop(context, group.id),
                            ),
                      ),
                    ),
                  );
                  selected?.call(value);
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('a short picker uses less height than a long picker', (
    tester,
  ) async {
    await open(tester, count: 1);
    final short = tester
        .getSize(find.byKey(const Key('bookmark-batch-surface')))
        .height;
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await open(tester, count: 30);
    final long = tester
        .getSize(find.byKey(const Key('bookmark-batch-surface')))
        .height;
    expect(short, lessThan(long));
    expect(find.text('Cancel').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'folder navigation keeps the group choice and membership detail',
    (tester) async {
      String? result;
      await open(
        tester,
        count: 1,
        nested: true,
        selected: (value) => result = value,
      );
      await tester.tap(find.text('Folder'));
      await tester.pumpAndSettle();
      expect(find.text('1 / 2'), findsOneWidget);
      await tester.tap(find.text('Group 0'));
      await tester.pumpAndSettle();
      expect(result, '0');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'narrow enlarged-text picker remains bounded above the keyboard',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 220);
      addTearDown(tester.view.reset);
      await open(tester, count: 30, scale: 2);
      final bounds = tester.getRect(
        find.byKey(const Key('bookmark-batch-surface')),
      );
      expect(bounds.left, greaterThanOrEqualTo(0));
      expect(bounds.right, lessThanOrEqualTo(320));
      expect(bounds.bottom, lessThanOrEqualTo(420));
      expect(find.text('Cancel').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  for (final brightness in Brightness.values) {
    testWidgets(
      'long Remove title is adaptive and readable with keyboard in $brightness',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        tester.view.viewInsets = const FakeViewPadding(bottom: 220);
        addTearDown(tester.view.reset);
        const title = 'Remove Bookmarks from Group';
        await open(
          tester,
          count: 30,
          scale: 2,
          title: title,
          brightness: brightness,
        );
        expect(find.byType(KurumiFittedText), findsOneWidget);
        final text = tester.widget<Text>(find.text(title));
        expect(text.style!.fontSize, greaterThanOrEqualTo(12));
        expect(text.maxLines, isNull);
        expect(find.text('Cancel').hitTestable(), findsOneWidget);
        expect(
          tester
              .getRect(find.byKey(const Key('bookmark-batch-surface')))
              .bottom,
          lessThanOrEqualTo(420),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
