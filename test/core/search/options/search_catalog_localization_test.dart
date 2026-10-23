import 'dart:io';
import 'dart:convert';

import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/search/options/providers.dart';
import 'package:boorusama/core/search/options/search_option.dart';
import 'package:boorusama/core/search/options/labels.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('declared catalog labels and descriptions exist in both locales', () {
    for (final language in ['en-US', 'de-DE']) {
      final locale =
          jsonDecode(
                File('packages/i18n/translations/$language.json')
                    .readAsStringSync(),
              )['search_options']['ext']
              as Map;
      final missing = <String>{};
      for (final type in [
        BooruType.danbooru,
        BooruType.gelbooru,
        BooruType.gelbooruV2,
        BooruType.e621,
        BooruType.moebooru,
        BooruType.szurubooru,
        BooruType.philomena,
        BooruType.hybooru,
        BooruType.hydrus,
        BooruType.nozomi,
        BooruType.eshuushuu,
        BooruType.animePictures,
        BooruType.shimmie2,
      ]) {
        final url = type == BooruType.shimmie2
            ? 'https://rule34.paheal.net'
            : type == BooruType.gelbooruV2
            ? 'https://rule34.xxx'
            : 'https://example.test';
        for (final option in capabilitiesFor(type, url).options) {
          if (option.labelKey != null ||
              option.kind == SearchOptionKind.metadata) {
            final k = searchOptionLocalizationKey(
              option.labelKey ?? option.key,
            );
            if (!(locale['labels'] as Map).containsKey(k)) {
              missing.add('labels.$k');
            }
          }
          if (option.descriptionKey case final k?) {
            if (!(locale['descriptions'] as Map).containsKey(
              searchOptionLocalizationKey(k),
            )) {
              missing.add('descriptions.$k');
            }
          }
        }
      }
      expect(missing, isEmpty, reason: language);
    }
  });
}
