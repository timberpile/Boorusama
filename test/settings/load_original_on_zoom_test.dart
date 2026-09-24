// Package imports:
import 'package:test/test.dart';

// Project imports:
import 'package:boorusama/core/settings/types.dart';

void main() {
  test('loading the original on zoom is enabled for new settings', () {
    expect(Settings.defaultSettings.viewer.loadOriginalOnZoom, isTrue);
  });

  test('loading the original on zoom is enabled when no choice is stored', () {
    final json = Settings.defaultSettings.toJson()
      ..remove('loadOriginalOnZoom');

    final settings = Settings.fromJson(json);

    expect(settings.viewer.loadOriginalOnZoom, isTrue);
  });

  test('loading the original on zoom remains disabled when opted out', () {
    final disabled = Settings.defaultSettings.copyWith(
      viewer: Settings.defaultSettings.viewer.copyWith(
        loadOriginalOnZoom: false,
      ),
    );

    final restored = Settings.fromJson(disabled.toJson());

    expect(restored.viewer.loadOriginalOnZoom, isFalse);
  });
}
