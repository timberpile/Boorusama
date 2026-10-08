// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../../configs/manage/providers.dart';
import '../../../configs/config/types.dart';
import '../types/settings.dart';
import 'settings_provider.dart';

final imageViewerSettingsProvider = Provider<ImageViewerSettings>((ref) {
  final viewer = ref.watch(settingsProvider.select((value) => value.viewer));

  // check if user has set custom settings
  final viewerConfigs = ref.watch(
    currentBooruConfigProvider.select((value) => value.viewerConfigs),
  );

  // if user has set it and it's enabled, return it
  if (viewerConfigs != null && viewerConfigs.enable) {
    return viewerConfigs.settings;
  }

  // otherwise, return the global settings
  return viewer;
});

final hasCustomViewerSettingsProvider = Provider<bool>((ref) {
  final viewerConfigs = ref.watch(
    currentBooruConfigProvider.select((value) => value.viewerConfigs),
  );

  return viewerConfigs != null && viewerConfigs.enable;
});

// Explicit auth keeps mixed pages and preloads independent of the selected profile.
final postQualityProvider = Provider.family<PostQuality, BooruConfigAuth>((
  ref,
  auth,
) {
  final global = ref.watch(
    settingsProvider.select((settings) => settings.viewer.postQuality),
  );
  final matches = ref
      .watch(booruConfigProvider)
      .where((config) => config.auth == auth)
      .toList();
  if (matches.length != 1) return global;
  final viewer = matches.single.viewerConfigs;
  return viewer != null && viewer.enable ? viewer.settings.postQuality : global;
});
