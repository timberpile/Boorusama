// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../../core/cache/misc_data_store.dart';
import '../../../core/settings/src/providers/settings_provider.dart';
import '../../info/package_info.dart';
import '../../platform.dart';
import 'github_apk_downloader.dart';
import 'types/app_update_checker.dart';
import 'types/update_status.dart';
import 'update_check_coordinator.dart';

const _kReleaseChannel = String.fromEnvironment('RELEASE_CHANNEL');
const _kReleaseChannelGithub = 'github';
const _kReleaseChannelPlay = 'play';

final githubApkDownloaderProvider = Provider<GitHubApkDownloader>(
  (ref) => GitHubApkDownloader(),
);

final updateChecksSupportedProvider = Provider<bool>((ref) {
  if (ref.watch(isDevEnvironmentProvider) || isWeb()) return false;

  return switch (_kReleaseChannel) {
    _kReleaseChannelPlay => isAndroid(),
    _kReleaseChannelGithub => isMobilePlatform() || isDesktopPlatform(),
    _ => false,
  };
});

final githubAndroidInstallationSupportedProvider = Provider<bool>((ref) {
  return ref.watch(updateChecksSupportedProvider) &&
      isAndroid() &&
      _kReleaseChannel == _kReleaseChannelGithub;
});

final shouldCheckForUpdateProvider = Provider<bool>((ref) {
  return ref.watch(updateChecksSupportedProvider) &&
      ref.watch(settingsProvider.select((s) => s.automaticUpdateChecks));
});

final appUpdateCheckerProvider = Provider<AppUpdateChecker>(
  (ref) => UnsupportedPlatformChecker(),
);

final appUpdateCoordinatorProvider = Provider<UpdateCheckCoordinator>((ref) {
  final checker = ref.watch(appUpdateCheckerProvider);
  final info = ref.watch(packageInfoProvider);
  final store = ref.watch(miscDataStoreProvider);
  final key =
      '${_kReleaseChannel}_update_check_${info.packageName}_${info.version}_${info.buildNumber}';
  return UpdateCheckCoordinator(
    checkForUpdate: checker.checkForUpdate,
    load: () => store.get(key),
    save: (value) => store.put(key, value),
  );
});

final appUpdateStatusProvider = FutureProvider<UpdateStatus>((ref) {
  if (!ref.watch(updateChecksSupportedProvider)) {
    return Future.value(const UpdateNotAvailable());
  }

  final coordinator = ref.watch(appUpdateCoordinatorProvider);
  if (!ref.watch(shouldCheckForUpdateProvider)) {
    return Future.value(coordinator.cachedStatus ?? const UpdateNotAvailable());
  }
  return coordinator.check();
});
