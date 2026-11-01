import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';

import 'package:boorusama/core/settings/src/search/settings_search.dart';
import 'package:boorusama/core/settings/src/search/settings_search_catalog.dart';

void main() {
  for (final locale in ['en-US', 'de-DE']) {
    testWidgets(
      'timeline pin setting is discoverable by its visible $locale label',
      (tester) async {
        await tester.runAsync(() => ensureI18nInitialized(locale));
        addTearDown(
          () => tester.runAsync(() => ensureI18nInitialized('en-US')),
        );
        late Translations t;
        await tester.pumpWidget(
          BooruLocalization(
            child: Builder(
              builder: (context) {
                t = context.t;
                return const SizedBox.shrink();
              },
            ),
          ),
        );
        final label = locale == 'de-DE'
            ? 'Timeline-Leiste sichtbar halten'
            : 'Keep Timeline Toolbar Visible';
        final catalog = buildSettingsSearchCatalog(
          t,
          sections: {'appearance': 'Appearance'},
          isMobile: true,
        );
        for (final query in [label, 'timeline', 'toolbar']) {
          final found = searchSettings(catalog, query);
          expect(
            found.any(
              (item) =>
                  item.id == 'appearance.keep_timeline_toolbar_visible' &&
                  item.title == label,
            ),
            isTrue,
          );
        }
      },
    );
  }

  testWidgets(
    'indexes translated controls only in available categories',
    (tester) async {
      late Translations translations;
      await tester.pumpWidget(
        BooruLocalization(
          child: Builder(
            builder: (context) {
              translations = context.t;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      final removed = buildSettingsSearchCatalog(
        translations,
        sections: {
          'server_favorites': translations.bookmark.server_favorites.title,
        },
        isMobile: false,
      );
      expect(
        removed.any((item) => item.id == 'server_favorites.global'),
        isFalse,
      );
      final sections = {
        'viewer': translations.settings.image_viewer.image_viewer,
        'download': translations.settings.download.title,
      };
      final desktop = buildSettingsSearchCatalog(
        translations,
        sections: sections,
        isMobile: false,
      );
      expect(
        desktop.every((item) => sections.containsKey(item.sectionId)),
        isTrue,
      );
      expect(desktop.map((item) => item.id).toSet().length, desktop.length);
      expect(desktop.any((item) => item.id == 'download.network'), isFalse);
      expect(
        searchSettings(
          desktop,
          translations.settings.image_viewer.mute_video,
        ).first.id,
        'viewer.mute_video',
      );

      final mobile = buildSettingsSearchCatalog(
        translations,
        sections: sections,
        isMobile: true,
      );
      expect(mobile.any((item) => item.id == 'download.network'), isTrue);
    },
  );
}
