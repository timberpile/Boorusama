import 'package:boorusama/core/settings/src/types/settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('new and missing-value settings use independent 4 dp defaults', () {
    final defaults = Settings.defaultSettings;
    expect(defaults.listing.imageGridPadding, 4);
    expect(defaults.listing.imageGridSpacing, 4);
    final json = defaults.toJson()..remove('imageGridPadding');
    expect(Settings.fromJson(json).listing.imageGridPadding, 4);
    final listing = ImageListingSettings.fromJson(
      defaults.listing.toJson()..remove('imageGridPadding'),
    );
    expect(listing.imageGridPadding, 4);
    expect(listing.copyWith(imageGridSpacing: 12).imageGridPadding, 4);
    expect(listing.copyWith(imageGridPadding: 20).imageGridSpacing, 4);
  });

  for (final padding in [0.0, 4.0, 16.0, 23.5]) {
    test('global/profile round trips preserve explicit padding $padding', () {
      final listing = Settings.defaultSettings.listing.copyWith(
        imageGridPadding: padding,
        imageGridSpacing: 7,
      );
      final global = Settings.defaultSettings.copyWith(listing: listing);
      expect(Settings.fromJson(global.toJson()).listing, listing);
      final profile = ListingConfigs(settings: listing, enable: true);
      expect(ListingConfigs.fromJsonString(profile.toJsonString()), profile);
      expect(listing.copyWith(postsPerPage: 90).imageGridPadding, padding);
    });
  }
}
