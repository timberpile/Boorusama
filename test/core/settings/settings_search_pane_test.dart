import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:boorusama/core/settings/src/search/settings_search.dart';
import 'package:boorusama/core/settings/src/widgets/settings_navigation_pane.dart';
import 'package:boorusama/core/settings/src/widgets/settings_page_scaffold.dart';

const _entries = [
  SettingEntry(
    id: 'viewer',
    title: 'Image viewer',
    name: '/settings/image_viewer',
    icon: Icons.image,
    content: SizedBox.shrink(),
  ),
  SettingEntry(
    id: 'storage',
    title: 'Data and storage',
    name: '/settings/data_and_storage',
    icon: Icons.storage,
    content: SizedBox.shrink(),
  ),
];

const _items = [
  SettingsSearchItem(
    id: 'viewer.mute',
    sectionId: 'viewer',
    sectionTitle: 'Image viewer',
    title: 'Mute video playback by default',
    keywords: ['audio'],
  ),
  SettingsSearchItem(
    id: 'storage.cache',
    sectionId: 'storage',
    sectionTitle: 'Data and storage',
    title: 'Video cache',
  ),
  SettingsSearchItem(
    id: 'hidden.setting',
    sectionId: 'hidden',
    sectionTitle: 'Hidden category',
    title: 'Hidden setting',
  ),
];

Future<void> _pumpPane(
  WidgetTester tester, {
  ValueChanged<SettingEntry>? onSelected,
  double width = 400,
  double scale = 1,
  double keyboardHeight = 0,
  bool dense = false,
  bool showSearch = true,
  List<SettingsSearchItem> items = _items,
}) async {
  await tester.binding.setSurfaceSize(Size(width, 700));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            viewInsets: EdgeInsets.only(bottom: keyboardHeight),
          ),
          child: Scaffold(
            body: SettingsPageScope(
              options: SettingsPageOptions(
                entries: _entries,
                showIcon: !dense,
                dense: dense,
              ),
              child: SettingsSearchPane(
                showSearch: showSearch,
                entries: _entries,
                items: items,
                labels: (
                  hint: 'Search',
                  clear: 'Clear',
                  empty: 'No results',
                ),
                header: const Text('App settings'),
                footer: const Text('Other settings'),
                onSelected: onSelected ?? (_) {},
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('search stays hidden until opened and closing clears it', (
    tester,
  ) async {
    await _pumpPane(tester, showSearch: false);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Other settings'), findsOneWidget);

    await _pumpPane(tester);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).focusNode?.hasFocus,
      isTrue,
    );
    await tester.enterText(find.byType(TextField), 'audio');
    await tester.pump();
    expect(find.text('Mute video playback by default'), findsOneWidget);
    expect(find.text('Other settings'), findsNothing);

    await _pumpPane(tester, showSearch: false);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Other settings'), findsOneWidget);
    expect(find.text('Mute video playback by default'), findsNothing);

    await _pumpPane(tester);
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
  });

  testWidgets(
    'filters controls and restores categories when cleared',
    (tester) async {
      SettingEntry? selected;
      await _pumpPane(tester, onSelected: (entry) => selected = entry);
      expect(find.text('App settings'), findsOneWidget);
      expect(find.text('Other settings'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'audio');
      await tester.pump();
      expect(find.text('Mute video playback by default'), findsOneWidget);
      expect(find.text('Image viewer'), findsOneWidget);
      expect(find.text('Data and storage'), findsNothing);
      expect(find.text('Other settings'), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey('settings-navigation-viewer.mute')),
      );
      expect(selected, same(_entries.first));
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'audio',
      );

      await tester.tap(find.byTooltip('Clear'));
      await tester.pump();
      expect(find.text('Data and storage'), findsOneWidget);
      expect(find.text('Other settings'), findsOneWidget);
      expect(find.text('Mute video playback by default'), findsNothing);
    },
  );

  testWidgets(
    'keeps the query when returning from a settings page',
    (tester) async {
      await _pumpPane(
        tester,
        onSelected: (entry) {
          final context = tester.element(find.byType(SettingsSearchPane));
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  Scaffold(appBar: AppBar(title: Text(entry.title))),
            ),
          );
        },
      );
      await tester.enterText(find.byType(TextField), 'audio');
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('settings-navigation-viewer.mute')),
      );
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'audio',
      );
      expect(find.text('Mute video playback by default'), findsOneWidget);
    },
  );

  testWidgets(
    'hides unavailable destinations and handles an empty result',
    (tester) async {
      await _pumpPane(tester);
      await tester.enterText(find.byType(TextField), 'hidden');
      await tester.pump();
      expect(find.text('No results'), findsOneWidget);
      expect(find.text('Hidden setting'), findsNothing);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'supports submitting a result and clearing with Escape',
    (tester) async {
      SettingEntry? selected;
      await _pumpPane(tester, onSelected: (entry) => selected = entry);
      await tester.enterText(find.byType(TextField), 'audio');
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      expect(selected, same(_entries.first));

      await tester.tap(find.byType(TextField));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.text('Other settings'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
    },
  );

  for (final layout in [
    (width: 320.0, dense: false),
    (width: 240.0, dense: true),
  ]) {
    testWidgets(
      'fits ${layout.width} pixels with large text and an open keyboard',
      (tester) async {
        await _pumpPane(
          tester,
          width: layout.width,
          dense: layout.dense,
          scale: 2,
          keyboardHeight: 300,
        );
        await tester.enterText(find.byType(TextField), 'audio');
        await tester.pump();
        expect(find.text('Mute video playback by default'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byTooltip('Clear'));
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
