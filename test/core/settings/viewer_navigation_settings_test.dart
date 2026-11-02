import 'dart:convert';

import 'package:boorusama/core/backups/types/types.dart';
import 'package:boorusama/core/backups/utils/json_handler.dart';
import 'package:boorusama/core/settings/src/types/settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final value in [
    1,
    '1',
    'vertical',
    0,
    '0',
    'horizontal',
    null,
    'unknown',
  ]) {
    test(
      'global settings ignore legacy swipeMode $value on load and restore',
      () {
        final expected = Settings.defaultSettings.copyWith(
          viewer: Settings.defaultSettings.viewer.copyWith(
            snapZoomToFit: false,
            slideshowInterval: 10,
          ),
        );
        final legacy = expected.toJson()..['swipeMode'] = value;
        // SettingsBackupSource uses this handler for both import and export.
        final handler = SingleHandler<Settings>(
          parser: Settings.fromJson,
          encoder: (settings) => settings.toJson(),
        );

        final restored = handler.parse(
          ExportDataPayload.legacy(data: [legacy]),
        );

        expect(restored, expected);
        expect(Settings.fromJson(legacy), expected);
        expect(handler.encode(restored).single, isNot(contains('swipeMode')));
        expect(
          handler.parse(
            ExportDataPayload.legacy(data: handler.encode(restored)),
          ),
          expected,
        );
      },
    );

    test('profile viewer overrides ignore legacy swipeMode $value', () {
      final expected = ViewerConfigs(
        enable: true,
        settings: Settings.defaultSettings.viewer.copyWith(
          loadOriginalOnZoom: false,
          autoAdjustComicStrips: false,
        ),
      );
      final legacy = expected.toJson();
      (legacy['settings'] as Map<String, dynamic>)['swipeMode'] = value;

      final restored = ViewerConfigs.fromJsonString(jsonEncode(legacy));

      expect(restored, expected);
      expect(restored.settings.toJson(), isNot(contains('swipeMode')));
      expect(ViewerConfigs.fromJsonString(restored.toJsonString()), expected);
    });
  }
}
