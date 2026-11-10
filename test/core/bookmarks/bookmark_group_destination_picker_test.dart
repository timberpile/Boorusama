import 'package:boorusama/core/bookmarks/src/types/bookmark_group.dart';
import 'package:boorusama/core/bookmarks/src/widgets/bookmark_group_destination_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:material_ui/material_ui.dart';

BookmarkGroup group(
  String id, {
  String? parent,
  int position = 0,
  String? name,
}) => BookmarkGroup(
  id: id,
  name: name ?? id,
  bookmarkIds: const {},
  parentGroupId: parent,
  position: position,
);

Future<void> openPicker(
  WidgetTester tester, {
  required List<BookmarkGroup> groups,
  required Set<String> moving,
  String? initial,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  await tester.pumpWidget(
    BooruLocalization(
      child: MaterialApp(
        builder: (context, child) => MaterialUiCompatibilityBridge(
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: textScaler),
            child: child!,
          ),
        ),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showBookmarkGroupDestinationPicker(
              context,
              groups: groups,
              movingGroupIds: moving,
              initialParentGroupId: initial,
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('navigates into groups and returns selected destination', (
    tester,
  ) async {
    BookmarkGroupDestination? result;
    await tester.pumpWidget(
      BooruLocalization(
        child: MaterialApp(
          builder: (context, child) =>
              MaterialUiCompatibilityBridge(child: child!),
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showBookmarkGroupDestinationPicker(
                  context,
                  groups: [
                    group('moving'),
                    group('destination', name: 'Destination'),
                    group('nested', parent: 'destination', name: 'Nested'),
                  ],
                  movingGroupIds: const {'moving'},
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('destination-destination')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Move Here'));
    await tester.pumpAndSettle();
    expect(result, (parentGroupId: 'destination'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('excludes selected subtree and disables unchanged destination', (
    tester,
  ) async {
    await openPicker(
      tester,
      groups: [
        group('source'),
        group('moving', parent: 'source'),
        group('child', parent: 'moving'),
        group('duplicate-a', parent: 'source', name: 'Duplicate'),
        group('duplicate-b', parent: 'source', name: 'Duplicate'),
      ],
      moving: const {'moving'},
      initial: 'source',
    );
    expect(find.byKey(const ValueKey('destination-moving')), findsNothing);
    expect(find.byKey(const ValueKey('destination-child')), findsNothing);
    expect(find.text('Duplicate'), findsNWidgets(2));
    final moveButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Move Here'),
    );
    expect(moveButton.onPressed, isNull);
  });

  testWidgets('Home is a valid wrapped destination and fits enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await openPicker(
      tester,
      groups: [
        group('moving', parent: 'parent'),
        group('parent'),
      ],
      moving: const {'moving'},
      initial: 'parent',
      textScaler: const TextScaler.linear(1.6),
    );
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    final moveButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Move Here'),
    );
    expect(moveButton.onPressed, isNotNull);
    expect(find.byType(KurumiDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
