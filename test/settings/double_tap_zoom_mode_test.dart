// Package imports:
import 'package:test/test.dart';

// Project imports:
import 'package:boorusama/core/settings/types.dart';

void main() {
  for (final storedValue in [null, 0, 1, 'classic', 'fitCycle', 'unknown', 99]) {
    test('ignores retired zoom behavior value $storedValue', () {
      final json = Settings.defaultSettings.toJson();
      if (storedValue == null) {
        json.remove('doubleTapZoomMode');
      } else {
        json['doubleTapZoomMode'] = storedValue;
      }

      final settings = Settings.fromJson(json);

      expect(settings.viewer.toJson(), isNot(contains('doubleTapZoomMode')));
      expect(settings.toJson(), isNot(contains('doubleTapZoomMode')));
      expect(settings.viewer.snapZoomToFit, isTrue);
    });
  }

  test('legacy zoom choice cannot return through unrelated setting changes', () {
    final json = Settings.defaultSettings.toJson()
      ..['doubleTapZoomMode'] = 1;

    final settings = Settings.fromJson(json);
    final updated = settings.viewer.copyWith(loadOriginalOnZoom: false);

    expect(updated.loadOriginalOnZoom, isFalse);
    expect(updated.toJson(), isNot(contains('doubleTapZoomMode')));
  });
}
