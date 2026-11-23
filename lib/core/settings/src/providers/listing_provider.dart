// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../../configs/manage/providers.dart';
import '../../../configs/config/types.dart';
import '../../../navigation/page_presentation_profile.dart';
import '../../../images/types.dart';
import '../../../content/content_access_provider.dart';
import '../../../content/content_access.dart';
import '../types/settings.dart';
import 'settings_provider.dart';

final imageListingSettingsProvider = Provider<ImageListingSettings>((ref) {
  final listing = ref.watch(settingsProvider.select((value) => value.listing));

  // check if user has set custom settings
  final listingConfigs = ref.watch(
    pagePresentationProfileProvider.select((value) => value?.listing),
  );

  return _effectiveListing(listing, listingConfigs);
}, dependencies: [pagePresentationProfileProvider, settingsProvider]);

final hasCustomListingSettingsProvider = Provider<bool>((ref) {
  final listingConfigs = ref.watch(
    pagePresentationProfileProvider.select((value) => value?.listing),
  );

  return listingConfigs != null && listingConfigs.enable;
}, dependencies: [pagePresentationProfileProvider]);

final imageListingQualityProvider = Provider<ImageQuality>((ref) {
  return ref.watch(
    imageListingSettingsProvider.select((value) => value.imageQuality),
  );
}, dependencies: [imageListingSettingsProvider]);

/// Repository requests have an explicit source and do not inherit widget scopes.
final listingSettingsForAuthProvider =
    Provider.family<ImageListingSettings, BooruConfigAuth>((ref, auth) {
      final global = ref.watch(settingsProvider.select((s) => s.listing));
      final profiles = ref
          .watch(booruConfigProvider)
          .where((c) => c.auth == auth)
          .toList();
      final custom = profiles.length == 1 ? profiles.single.listing : null;
      return custom != null && custom.enable ? custom.settings : global;
    });

/// Group reads use the exact bound profile, including when accounts share auth.
final listingSettingsForAccessProvider = Provider.autoDispose
    .family<ImageListingSettings, ContentAccessKey>(
      (ref, key) {
        final global = ref.watch(
          settingsProvider.select((value) => value.listing),
        );
        final profile = ref.watch(contentAccessContextProvider(key))?.config;
        return _effectiveListing(
          global,
          profile?.anonymousReadScope == null ? profile?.listing : null,
        );
      },
      dependencies: [settingsProvider, contentAccessContextProvider],
    );

ImageListingSettings _effectiveListing(
  ImageListingSettings global,
  ListingConfigs? custom,
) => custom != null && custom.enable ? custom.settings : global;
