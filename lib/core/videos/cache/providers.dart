// Package imports:
import 'package:background_downloader/background_downloader.dart';
import 'package:cache_manager/cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../../foundation/filesystem.dart';
import '../../../foundation/platform.dart';
import '../../http/client/providers.dart';
import '../../settings/providers.dart';

final videoCacheManagerProvider = Provider<VideoCacheManager?>(
  (ref) {
    if (isWeb()) {
      return null;
    }

    final enable = ref.watch(
      sharedMediaSettingsProvider.select((s) => s.enableVideoCache),
    );

    if (!enable) return null;

    final videoCacheSize = ref.watch(
      settingsProvider.select((s) => s.videoCacheMaxSize),
    );

    if (videoCacheSize.isZero) return null;

    final fs = ref.watch(appFileSystemProvider);
    final manager = VideoCacheManager(
      maxTotalCacheSize: videoCacheSize.bytes,
      fileDownloader: FileDownloader(),
      dio: ref.watch(genericDioProvider),
      cacheRootPathProvider: () async {
        final path = await fs.getTemporaryPath();
        if (path == null) throw Exception('Cache directory not available');
        return path;
      },
    );

    ref.onDispose(() {
      manager.dispose();
    });

    return manager;
  },
);

/// Public playback must materialize through the guarded HTTP adapter before a
/// native player can open it. With retention disabled, its last lease deletes
/// the payload; this does not enable the user's optional background cache.
final guardedPlaybackCacheManagerProvider =
    Provider.autoDispose<VideoCacheManager>((ref) {
      final configured = ref.watch(videoCacheManagerProvider);
      if (configured != null) return configured;
      final fs = ref.watch(appFileSystemProvider);
      final manager = VideoCacheManager(
        maxTotalCacheSize: 100 * 1024 * 1024,
        fileDownloader: FileDownloader(),
        dio: ref.watch(genericDioProvider),
        cacheDirName: 'guarded-playback',
        cacheRootPathProvider: () async {
          final path = await fs.getTemporaryPath();
          if (path == null) throw StateError('Playback directory unavailable');
          return path;
        },
      );
      ref.onDispose(manager.dispose);
      return manager;
    });
