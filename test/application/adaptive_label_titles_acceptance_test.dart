import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/material.dart';
import 'package:kurumi/kurumi.dart';
import 'package:boorusama/core/tags/favorites/src/pages/favorite_tags_page.dart';
import 'package:boorusama/core/tags/favorites/src/pages/favorite_tag_labels_page.dart';

import 'support/headless_app_harness.dart';
import 'support/fake_booru_backend.dart';
import '../support/fakes/memory_repositories.dart';

void main() {
  for (final operation in ['Filter', 'Rename', 'Merge']) {
    testWidgets('production label $operation at 320dp 2x keyboard', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final repo = MemoryFavoriteTagRepository();
      await repo.create(name: 'cat', labels: ['Source label']);
      await repo.create(name: 'dog', labels: ['Target label']);
      final backend = FakeBooruBackend();
      final h = HeadlessAppHarness(
        viewportSize: const Size(320, 640),
        booruBackend: backend,
        runtime: backend.createRuntime(favoriteTagRepository: repo),
      );
      addTearDown(() => h.teardown(tester));
      await h.pump(tester);
      final nav = tester.state<NavigatorState>(find.byType(Navigator).last);
      nav.push(
        MaterialPageRoute<void>(
          builder: (_) => operation == 'Filter'
              ? const FavoriteTagsPage()
              : const FavoriteTagLabelsPage(),
        ),
      );
      await h.settle(tester);
      if (operation == 'Filter') {
        final filter = find.byType(KurumiOptionDropDownButton<String>);
        await tester.ensureVisible(filter);
        await tester.tap(filter);
      } else {
        await tester.tap(find.byType(KurumiPopupMenuButton).first);
        await h.settle(tester);
        final item = find.textContaining(operation);
        await tester.ensureVisible(item);
        await tester.tap(item);
      }
      await h.pumpUntilFound(
        tester,
        operation == 'Filter'
            ? find.byType(KurumiOptionSearchableSheet<String>)
            : find.byType(KurumiBottomSheetHeader),
      );
      await h.settle(tester);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      tester.view.viewInsets = const FakeViewPadding(bottom: 240);
      await h.settle(tester);
      final host = operation == 'Filter'
          ? find.byType(KurumiOptionSearchableSheet<String>)
          : find.byType(KurumiBottomSheetHeader);
      expect(host, findsOneWidget);
      final title = find.descendant(
        of: host,
        matching: find.byType(KurumiFittedText),
      );
      expect(title, findsWidgets);
      for (final e in title.evaluate()) {
        final r = tester.getRect(find.byWidget(e.widget));
        expect(r.right, lessThanOrEqualTo(320));
        expect(r.left, greaterThanOrEqualTo(0));
        expect(r.bottom, lessThanOrEqualTo(400));
      }
      expect(tester.takeException(), isNull);
      expect(repo.tags.map((tag) => tag.name), ['cat', 'dog']);
    });
  }
}
