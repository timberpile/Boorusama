import 'package:boorusama/core/settings/src/types/settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final legacy in [true, false]) {
    test('legacy header value $legacy does not enable pinning', () {
      final json = Settings.defaultSettings.toJson()
        ..remove('keepTimelineToolbarVisible')
        ..['showPostListConfigHeader'] = legacy;
      final restored = Settings.fromJson(json);
      expect(restored.listing.keepTimelineToolbarVisible, isFalse);
      expect(restored.listing.showPostListConfigHeader, legacy);
    });
  }

  for (final value in [null, 'true', 1, [], {}]) {
    test('malformed scroll preference $value falls back to auto-hide', () {
      final json = Settings.defaultSettings.toJson()
        ..['keepTimelineToolbarVisible'] = value;
      expect(
        Settings.fromJson(json).listing.keepTimelineToolbarVisible,
        isFalse,
      );
    });
  }

  test('global and profile backups preserve an explicit pin preference', () {
    final listing = Settings.defaultSettings.listing.copyWith(
      keepTimelineToolbarVisible: true,
    );
    final settings = Settings.defaultSettings.copyWith(listing: listing);
    expect(Settings.fromJson(settings.toJson()).listing, listing);
    final profile = ListingConfigs(settings: listing, enable: true);
    expect(ListingConfigs.fromJsonString(profile.toJsonString()), profile);
    expect(
      listing.copyWith(postsPerPage: 90).keepTimelineToolbarVisible,
      isTrue,
    );
    expect(
      listing
          .copyWith(keepTimelineToolbarVisible: false)
          .keepTimelineToolbarVisible,
      isFalse,
    );
  });
}
