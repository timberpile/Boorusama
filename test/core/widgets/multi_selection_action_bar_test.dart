// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';

// Project imports:
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/src/types/settings.dart';
import 'package:boorusama/core/widgets/multi_select_button.dart';
import 'package:boorusama/core/widgets/multi_selection_action_bar.dart';

void main() {
  testWidgets('popup actions remain directly usable on constrained rows', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWithValue(Settings.defaultSettings),
        ],
        child: BooruLocalization(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 260,
                child: MultiSelectionActionBar(
                  children: [
                    MultiSelectButton(
                      icon: const Icon(Icons.download),
                      name: 'Download',
                      onPressed: () {},
                    ),
                    const MultiSelectPopupButton(
                      icon: Icon(Icons.bookmark),
                      name: 'Bookmark',
                      enabled: true,
                      items: [Text('Group actions')],
                    ),
                    MultiSelectButton(
                      icon: const Icon(Icons.delete),
                      name: 'Delete',
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Bookmark'), findsOneWidget);

    final popupTapTarget = find
        .descendant(
          of: find.byType(MultiSelectPopupButton),
          matching: find.byType(InkWell),
        )
        .first;
    await tester.tap(popupTapTarget);
    await tester.pumpAndSettle();

    expect(find.text('Group actions'), findsOneWidget);
  });
}
