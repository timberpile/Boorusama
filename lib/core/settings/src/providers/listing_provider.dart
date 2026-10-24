// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../../configs/manage/providers.dart';
import '../../../configs/config/types.dart';
import '../../../navigation/page_presentation_profile.dart';
import '../../../images/types.dart';
import '../types/settings.dart';
import 'settings_provider.dart';

final imageListingSettingsProvider = Provider<ImageListingSettings>((ref) {
  final listing = ref.watch(settingsProvider.select((value) => value.listing));

  // check if user has set custom settings
  final listingConfigs = ref.watch(
    pagePresentationProfileProvider.select((value) => value?.listing),
  );

  // if user has set it and it's enabled, return it
  if (listingConfigs != null && listingConfigs.enable) {
    return listingConfigs.settings;
  }

  // otherwise, return the global settings
  return listing;
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
