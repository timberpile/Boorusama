// Package imports:
import 'package:test/test.dart';

// Project imports:
import 'package:boorusama/core/settings/types.dart';

void main() {
  test('snap zoom defaults to enabled for existing settings', () {
    final json = Settings.defaultSettings.toJson()..remove('snapZoomToFit');

    final settings = Settings.fromJson(json);

    expect(settings.viewer.snapZoomToFit, isTrue);
  });

  test('snap zoom setting round trips when disabled', () {
    final disabled = Settings.defaultSettings.copyWith(
      viewer: Settings.defaultSettings.viewer.copyWith(
        snapZoomToFit: false,
      ),
    );

    final restored = Settings.fromJson(disabled.toJson());

    expect(restored.viewer.snapZoomToFit, isFalse);
  });
}
