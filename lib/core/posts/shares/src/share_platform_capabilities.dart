import '../../../../foundation/platform.dart';

final class SharePlatformCapabilities {
  const SharePlatformCapabilities({
    required this.canCopyImage,
    required this.canShareMedia,
  });

  factory SharePlatformCapabilities.forPlatform(AppPlatform platform) =>
      switch (platform) {
        AppPlatform.android ||
        AppPlatform.ios ||
        AppPlatform.macos ||
        AppPlatform.windows => const SharePlatformCapabilities(
          canCopyImage: true,
          canShareMedia: true,
        ),
        AppPlatform.linux ||
        AppPlatform.web ||
        AppPlatform.unknown => const SharePlatformCapabilities(
          canCopyImage: false,
          canShareMedia: false,
        ),
      };

  final bool canCopyImage;
  final bool canShareMedia;
}
