// Package imports:
import 'package:test/test.dart';

// Project imports:
import 'package:boorusama/core/settings/types.dart';

void main() {
  test(
    'automatic comic-strip mode defaults to enabled for existing settings',
    () {
      final json = Settings.defaultSettings.toJson()
        ..remove('autoStartComicStripMode');

      final settings = Settings.fromJson(json);

      expect(settings.viewer.autoStartComicStripMode, isTrue);
    },
  );

  test('automatic comic-strip mode setting round trips when disabled', () {
    final disabled = Settings.defaultSettings.copyWith(
      viewer: Settings.defaultSettings.viewer.copyWith(
        autoStartComicStripMode: false,
      ),
    );

    final restored = Settings.fromJson(disabled.toJson());

    expect(restored.viewer.autoStartComicStripMode, isFalse);
  });
}
