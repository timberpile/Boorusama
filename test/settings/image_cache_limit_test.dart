import 'package:boorusama/core/settings/types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final value in [null, 'invalid', -1, 'unlimited']) {
    test(
      'legacy or invalid image limit $value defaults independently to 1 GB',
      () {
        final settings = Settings.fromJson({
          ...Settings.defaultSettings.toJson(),
          'imageCacheMaxSize': value,
          'videoCacheMaxSize': '5GB',
        });
        final reopened = Settings.fromJson(settings.toJson());
        expect(reopened.toJson()['imageCacheMaxSize'], '1GB');
        expect(reopened.toJson()['videoCacheMaxSize'], '5GB');
      },
    );
  }
  for (final value in [0, '0B', '500MB', '2GB']) {
    test(
      'image limit $value survives settings recreation without changing video or post quality',
      () {
        final settings = Settings.fromJson({
          ...Settings.defaultSettings.toJson(),
          'imageCacheMaxSize': value,
          'videoCacheMaxSize': '10GB',
          'postQuality': 'low',
        });
        expect(settings.viewer.postQuality, PostQuality.medium);
        final reopened = Settings.fromJson(settings.toJson());
        expect(
          reopened.toJson()['imageCacheMaxSize'],
          value == 0 ? '0B' : value,
        );
        expect(reopened.toJson()['videoCacheMaxSize'], '10GB');
        expect(reopened.viewer.postQuality, PostQuality.medium);
        expect(reopened.toJson()['postQuality'], PostQuality.medium.toData());
      },
    );
  }
}
