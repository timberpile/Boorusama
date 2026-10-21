import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';

import 'package:boorusama/core/settings/src/search/settings_search.dart';
import 'package:boorusama/core/settings/src/search/settings_search_catalog.dart';

void main() {
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
