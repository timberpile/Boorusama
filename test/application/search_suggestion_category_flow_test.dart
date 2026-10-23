import 'package:boorusama/core/search/search/src/widgets/desktop_search_bar.dart';
import 'package:boorusama/core/search/search/src/widgets/search_app_bar.dart';
import 'package:boorusama/core/search/search/src/widgets/selected_tag_chip.dart';
import 'package:boorusama/core/search/suggestions/tag_suggestion_item.dart';
import 'package:boorusama/core/themes/colors/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/kurumi.dart' as kurumi;

import 'support/app_flow_driver.dart';
import 'support/fake_booru_backend.dart';
import 'support/headless_app_harness.dart';

void main() {
  for (final desktop in [false, true]) {
    testWidgets(
      '${desktop ? 'desktop' : 'mobile'} selection retains suggestion category on a cold cache',
      (tester) async {
        final backend = FakeBooruBackend()
          ..autocompleteTags.add('hatsune_miku')
          ..autocompleteCategories['hatsune_miku'] = '4';
        final harness = await HeadlessAppHarness.mount(
          tester,
          booruBackend: backend,
          phone: desktop ? null : TestPhone.portrait,
          viewportSize: desktop ? const Size(1280, 800) : null,
        );
        if (!desktop)
          await AppFlowDriver(tester: tester, harness: harness).openSearch();
        final field = find
            .descendant(
              of: find.byType(desktop ? DesktopSearchbar : SearchAppBar),
              matching: find.byType(EditableText),
            )
            .first;
        await tester.tap(field);
        await tester.enterText(field, 'hatsune');
        await harness.pumpUntilFound(tester, find.byType(TagSuggestionItem));
        await tester.tap(find.byType(TagSuggestionItem).first);
        await harness.pumpUntilFound(
          tester,
          find.byType(CategoryAwareSelectedTagChip),
        );
        final chip = tester.widget<CategoryAwareSelectedTagChip>(
          find.byType(CategoryAwareSelectedTagChip).first,
        );
        expect(chip.tagSearchItem.rawTag, 'hatsune_miku');
        expect(chip.tagSearchItem.category, '4');
        // Finish the landing view's existing delayed entrance on the test clock.
        await tester.pump(const Duration(milliseconds: 100));
        await harness.settle(tester);
        final selected = find.byType(SelectedTagChip).first;
        final categoryColor = tester.widget<SelectedTagChip>(selected).tagColor;
        expect(categoryColor, isNotNull);
        final colors = ProviderScope.containerOf(tester.element(selected))
            .read(booruChipColorsProvider)
            .fromColor(categoryColor)!;
        final materialChip = tester.widget<kurumi.KurumiMaterialChip>(
          find.descendant(
            of: selected,
            matching: find.byType(kurumi.KurumiMaterialChip),
          ),
        );
        expect(materialChip.backgroundColor, colors.backgroundColor);
        final label = materialChip.label as RichText;
        final spans = (label.text as TextSpan).children!.cast<TextSpan>();
        expect(
          spans.firstWhere((span) => span.text == 'hatsune miku').style!.color,
          colors.foregroundColor,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
