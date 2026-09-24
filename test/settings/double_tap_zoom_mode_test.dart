// Package imports:
import 'package:kurumi/kurumi.dart';
import 'package:test/test.dart';

// Project imports:
import 'package:boorusama/core/settings/types.dart';

void main() {
  for (final storedValue in [null, 'unknown', 99]) {
    test('uses Fit cycle when the stored mode is $storedValue', () {
      final json = Settings.defaultSettings.toJson();
      if (storedValue == null) {
        json.remove('doubleTapZoomMode');
      } else {
        json['doubleTapZoomMode'] = storedValue;
      }

      final settings = Settings.fromJson(json);

      expect(settings.viewer.doubleTapZoomMode, DoubleTapZoomMode.fitCycle);
    });
  }

  test('restores an explicitly selected Classic mode', () {
    final classic = Settings.defaultSettings.copyWith(
      viewer: Settings.defaultSettings.viewer.copyWith(
        doubleTapZoomMode: DoubleTapZoomMode.classic,
      ),
    );

    final restored = Settings.fromJson(classic.toJson());

    expect(restored.viewer.doubleTapZoomMode, DoubleTapZoomMode.classic);
  });
}
