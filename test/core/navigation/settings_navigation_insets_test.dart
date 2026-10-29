import 'package:boorusama/core/settings/src/search/settings_search.dart';
import 'package:boorusama/core/settings/src/widgets/settings_navigation_pane.dart';
import 'package:boorusama/core/settings/src/widgets/settings_page_scaffold.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

void main() {
  for (final searching in [false, true]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'the last settings action clears changing insets, search=$searching scale=$scale',
        (tester) async {
          tester.view.physicalSize = const Size(320, 640);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final scroll = ScrollController();
          addTearDown(scroll.dispose);
          final media = ValueNotifier(
            MediaQueryData(
              size: const Size(320, 640),
              padding: const EdgeInsets.only(bottom: 104),
              viewPadding: const EdgeInsets.only(bottom: 104),
              textScaler: TextScaler.linear(scale),
            ),
          );
          addTearDown(media.dispose);
          final entries = [
            for (var i = 0; i < 20; i++)
              SettingEntry(
                id: 'entry-$i',
                title: 'Entry $i',
                content: const SizedBox.shrink(),
                icon: Icons.settings,
                name: '/entry-$i',
              ),
          ];
          var activations = 0;
          await tester.pumpWidget(
            MaterialApp(
              builder: (context, child) => KurumiTheme(
                data: KurumiThemeData.fromMaterial(Theme.of(context)),
                child: ValueListenableBuilder<MediaQueryData>(
                  valueListenable: media,
                  builder: (_, value, child) => MediaQuery(
                    data: value,
                    child: child!,
                  ),
                  child: child,
                ),
              ),
              home: Scaffold(
                body: SettingsPageScope(
                  options: const SettingsPageOptions(
                    showIcon: true,
                    dense: false,
                  ),
                  child: SettingsSearchPane(
                    showSearch: searching,
                    entries: entries,
                    items: [
                      for (final entry in entries)
                        SettingsSearchItem(
                          id: 'item-${entry.id}',
                          sectionId: entry.id,
                          sectionTitle: entry.title,
                          title: entry.title,
                        ),
                    ],
                    labels: (
                      hint: 'Search',
                      clear: 'Clear',
                      empty: 'No results',
                    ),
                    scrollController: scroll,
                    onSelected: (_) => activations++,
                    footer: TextButton(
                      key: const ValueKey('settings-test-footer'),
                      onPressed: () => activations++,
                      child: const Text('Footer action'),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          if (searching) {
            await tester.enterText(find.byType(EditableText), 'Entry');
            await tester.pumpAndSettle();
          }
          final last = find.byKey(
            ValueKey(
              searching
                  ? 'settings-navigation-item-entry-19'
                  : 'settings-test-footer',
            ),
          );
          final viewport = find.byType(SingleChildScrollView);
          for (final (bottom, keyboard) in [
            (104.0, 0.0),
            (24.0, 0.0),
            (0.0, 240.0),
            (104.0, 0.0),
          ]) {
            media.value = media.value.copyWith(
              padding: EdgeInsets.only(bottom: bottom),
              viewPadding: EdgeInsets.only(bottom: bottom),
              viewInsets: EdgeInsets.only(bottom: keyboard),
            );
            await tester.pumpAndSettle();
            scroll.jumpTo(scroll.position.maxScrollExtent);
            await tester.pumpAndSettle();
            expect(
              tester.getRect(last).bottom,
              lessThanOrEqualTo(tester.getRect(viewport).bottom - bottom + 0.5),
            );
            expect(last.hitTestable(), findsOneWidget);
            expect(tester.takeException(), isNull);
          }
          await tester.tap(last);
          await tester.pumpAndSettle();
          expect(activations, 1);
        },
      );
    }
  }
}
