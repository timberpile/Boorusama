import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:boorusama/core/cache/providers.dart';
import 'package:boorusama/core/search/search/src/widgets/constants.dart';
import 'package:boorusama/core/search/search/src/widgets/favorite_tags_section.dart';
import 'package:boorusama/core/widgets/import_tag_dialog.dart';

import 'support/app_flow_driver.dart';
import 'support/app_flow_finders.dart';

// Flutter imports:
import 'package:material_ui/material_ui.dart';

// Package imports:
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/kurumi.dart';
import 'package:material_symbols_icons/symbols.dart';

// Project imports:
import 'package:boorusama/core/tags/favorites/src/pages/edit_favorite_tag_sheet.dart';
import 'package:boorusama/core/tags/favorites/widgets.dart';

import '../support/boorusama_test_runtime.dart';
import 'support/fake_booru_backend.dart';
import 'support/headless_app_harness.dart';

void main() {
  for (final populated in [false, true]) {
    testWidgets(
      'Search omits Import and Favorite Tags still imports (populated=$populated)',
      (tester) async {
        final backend = FakeBooruBackend();
        final repository = MemoryFavoriteTagRepository();
        if (populated) {
          await repository.create(name: 'cat', labels: ['Animals']);
        }
        final harness = HeadlessAppHarness(
          booruBackend: backend,
          runtime: backend.createRuntime(favoriteTagRepository: repository),
        );
        addTearDown(() => harness.teardown(tester));
        await harness.pump(tester);
        final driver = AppFlowDriver(tester: tester, harness: harness);
        await driver.openSearch();
        await tester.tap(
          find.byTooltip(appStrings(tester).search_options.title),
        );
        await harness.settle(tester);
        expect(find.byType(FavoriteTagsSection), findsOneWidget);
        expect(find.byType(ImportTagButton), findsNothing);
        if (populated) {
          final container = ProviderScope.containerOf(
            tester.element(find.byType(FavoriteTagsSection)),
          );
          await container
              .read(
                miscDataProvider(kSearchSelectedFavoriteTagLabelKey).notifier,
              )
              .put('Missing label');
          await harness.settle(tester);
          expect(find.byType(ImportTagButton), findsNothing);
          expect(
            find.descendant(
              of: find.byType(FavoriteTagsSection),
              matching: find.text('cat'),
            ),
            findsNothing,
          );
        }
        await tester.tap(
          find.descendant(
            of: find.byType(FavoriteTagsSection),
            matching: find.byIcon(Symbols.settings),
          ),
        );
        await harness.pumpUntilFound(tester, find.byType(FavoriteTagsPage));
        await harness.settle(tester);
        await tester.tap(
          find
              .descendant(
                of: find.descendant(
                  of: find.byType(FavoriteTagsPage),
                  matching: find.byType(KurumiAppBar),
                ),
                matching: find.byType(KurumiPopupMenuButton),
              )
              .first,
        );
        await harness.settle(tester);
        await tester.tap(
          find.ancestor(
            of: find.text('Import'),
            matching: find.byType(KurumiPopupMenuItem),
          ),
        );
        await harness.pumpUntilFound(tester, find.byType(ImportTagsDialog));
        await tester.enterText(
          find.descendant(
            of: find.byType(ImportTagsDialog),
            matching: find.byType(EditableText),
          ),
          'landscape',
        );
        await tester.pump();
        final import = find.descendant(
          of: find.byType(ImportTagsDialog),
          matching: find.widgetWithText(FilledButton, 'Import'),
        );
        await tester.ensureVisible(import);
        await tester.tap(import);
        await harness.pumpUntil(
          tester,
          () => repository.tags.any((tag) => tag.name == 'landscape'),
        );
        await harness.settle(tester);
        expect(repository.tags.map((tag) => tag.name), contains('landscape'));
        expect(find.byType(ImportTagsDialog), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'creates and removes a favorite tag through the UI',
    (tester) async {
      final backend = FakeBooruBackend();
      final repository = MemoryFavoriteTagRepository();
      final harness = HeadlessAppHarness(
        booruBackend: backend,
        runtime: backend.createRuntime(
          favoriteTagRepository: repository,
        ),
      );
      addTearDown(() => harness.teardown(tester));

      await harness.pump(tester);
      await tester.tap(find.byKey(const Key('nav-menu-toggle')).first);
      await tester.pump();
      await harness.settle(tester);
      await tester.tap(find.text('Favorite Tags'));
      await tester.pump();
      await harness.pumpUntilFound(tester, find.byType(FavoriteTagsPage));
      await harness.settle(tester);

      await tester.tap(
        find.descendant(
          of: find.byType(FavoriteTagsPage),
          matching: find.byIcon(Symbols.add),
        ),
      );
      await tester.pump();
      await harness.settle(tester);

      final valueField = find.descendant(
        of: find.byType(EditFavoriteTagSheet),
        matching: find.byType(EditableText),
      );
      expect(valueField, findsOneWidget);
      await tester.enterText(valueField, 'cat');
      expect(tester.widget<EditableText>(valueField).controller.text, 'cat');
      await tester.pump();
      final saveButton = find.descendant(
        of: find.byType(EditFavoriteTagSheet),
        matching: find.byTooltip('Save'),
      );
      expect(saveButton, findsOneWidget);
      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await harness.pumpUntil(
        tester,
        () => repository.tags.isNotEmpty,
      );
      await harness.settle(tester);

      expect(repository.tags.single.name, 'cat');
      expect(find.text('cat'), findsOneWidget);
      final row = find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == '_ListTile',
      );
      expect(row, findsOneWidget);
      await tester.tap(
        find.descendant(
          of: row,
          matching: find.byType(KurumiPopupMenuButton),
        ),
      );
      await harness.settle(tester);
      expect(find.byType(KurumiPopupMenuItem), findsNWidgets(3));
      await tester.tap(find.byType(KurumiPopupMenuItem).last);
      await harness.pumpUntil(
        tester,
        () => repository.tags.isEmpty,
      );
      await harness.settle(tester);

      expect(find.text('cat'), findsNothing);
    },
  );
}
