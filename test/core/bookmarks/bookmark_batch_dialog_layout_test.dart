import 'package:boorusama/core/bookmarks/src/types/bookmark_group.dart';
import 'package:boorusama/core/bookmarks/src/widgets/bookmark_batch_dialog.dart';
import 'package:boorusama/core/bookmarks/src/widgets/bookmark_folder_picker_contents.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

void main() {
  setUpAll(() => ensureI18nInitialized('en-US'));

  const folderGroupId = '11111111-1111-4111-8111-111111111111';
  String groupId(int index) =>
      '22222222-2222-4222-8222-${index.toString().padLeft(12, '0')}';

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
                        folders: const [],
                        groups: [
                          if (nested)
                            BookmarkGroup(
                              id: folderGroupId,
                              name: 'Folder',
                              bookmarkIds: {},
                            ),
                          for (var i = 0; i < count; i++)
                            BookmarkGroup(
                              id: groupId(i),
                              name: 'Group $i',
                              bookmarkIds: {},
                              parentGroupId: nested ? folderGroupId : null,
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
      final folderRow = find.byKey(
        const ValueKey(('bookmark-picker-group', folderGroupId)),
      );
      final folderBounds = tester.getRect(folderRow);
      await tester.tapAt(
        Offset(folderBounds.right - 40, folderBounds.center.dy),
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(ValueKey(('bookmark-picker-group', groupId(0)))),
          matching: find.text('1 / 2'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Group 0'));
      await tester.pumpAndSettle();
      expect(result, groupId(0));
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
