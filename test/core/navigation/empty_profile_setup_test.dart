import 'package:boorusama/core/backups/export_import/clipboard/export_clipboard_service.dart';
import 'package:boorusama/core/backups/export_import/export/export_flow_page.dart';
import 'package:boorusama/core/backups/export_import/export_import_page.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/navigation/navigation_catalog.dart';
import 'package:boorusama/core/navigation/navigation_catalog_provider.dart';
import 'package:boorusama/core/navigation/navigation_destination_pages.dart';
import 'package:boorusama/foundation/filesystem.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

void main() {
  for (final favorites in [false, true]) {
    testWidgets(
      'empty ${favorites ? 'Favorites' : 'Browse'} offers setup and the existing import flow',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final profiles = StateProvider<List<BooruConfig>>((ref) => []);
        final container = ProviderContainer(
          overrides: [
            navigationProfilesProvider.overrideWith(
              (ref) => ref.watch(profiles),
            ),
            navigationCatalogProvider.overrideWithValue(
              NavigationCatalog(
                profileSections: [],
                globalEntries: [],
                eligibleFavoritesProfileIds: [],
              ),
            ),
            exportClipboardServiceProvider.overrideWithValue(
              ExportClipboardService(
                fs: const IoFileSystem(),
                clipboard: _Clipboard(),
              ),
            ),
          ],
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: BooruLocalization(
              child: MaterialApp(
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: const TextScaler.linear(2),
                    padding: const EdgeInsets.only(bottom: 88),
                  ),
                  child: child!,
                ),
                home: NavigationRecoveryPage(favorites: favorites),
              ),
            ),
          ),
        );
        expect(find.text('No profiles available'), findsOneWidget);
        expect(find.text('Choose a profile'), findsNothing);
        final add = find.byKey(const ValueKey('empty-profile-add'));
        final importAction = find.byKey(const ValueKey('empty-profile-import'));
        expect(tester.widget<ListTile>(add).onTap, isNotNull);
        expect(
          find.descendant(of: add, matching: find.byIcon(Icons.add)),
          findsOneWidget,
        );
        expect(find.text('Add Profile'), findsOneWidget);
        expect(importAction.hitTestable(), findsOneWidget);
        await tester.tap(importAction);
        await tester.pumpAndSettle();
        expect(find.byType(ExportImportPage), findsOneWidget);
        final importScroll = find
            .descendant(
              of: find.byType(ExportImportPage),
              matching: find.byType(Scrollable),
            )
            .first;
        for (final label in ['Import File', 'Import from Clipboard']) {
          await tester.scrollUntilVisible(
            find.text(label),
            120,
            scrollable: importScroll,
          );
          await tester.pumpAndSettle();
          expect(find.text(label).hitTestable(), findsOneWidget);
        }
        Navigator.of(tester.element(find.byType(ExportImportPage))).pop();
        await tester.pumpAndSettle();
        container.read(profiles.notifier).state = [
          BooruConfig.fromJson({
            ...BooruConfig.empty.toJson(),
            'id': '00000000-0000-4000-8000-000000000001',
            'name': 'Created profile',
            'url': 'https://example.com',
          }),
        ];
        await tester.pumpAndSettle();
        expect(find.text('No profiles available'), findsNothing);
        expect(add, findsNothing);
        expect(importAction, findsNothing);
        if (!favorites) {
          expect(find.text('Created profile'), findsOneWidget);
          expect(
            tester
                .widget<ListTile>(
                  find.widgetWithText(ListTile, 'Created profile'),
                )
                .onTap,
            isNotNull,
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}

class _Clipboard implements ExportClipboardPort {
  @override
  Future<bool> containsExport() async => false;
  @override
  Future<String?> read() async => null;
  @override
  Future<void> write(String value) async {}
}
