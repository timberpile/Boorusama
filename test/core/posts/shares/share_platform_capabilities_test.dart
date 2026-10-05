import 'package:boorusama/core/posts/shares/src/share_platform_capabilities.dart';
import 'package:boorusama/foundation/platform.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final cases = [
    (platform: AppPlatform.android, copyImage: true, shareMedia: true),
    (platform: AppPlatform.ios, copyImage: true, shareMedia: true),
    (platform: AppPlatform.macos, copyImage: true, shareMedia: true),
    (platform: AppPlatform.windows, copyImage: true, shareMedia: true),
    (platform: AppPlatform.linux, copyImage: false, shareMedia: false),
    (platform: AppPlatform.web, copyImage: false, shareMedia: false),
  ];

  for (final testCase in cases) {
    test('${testCase.platform} exposes only supported media controls', () {
      final capabilities = SharePlatformCapabilities.forPlatform(
        testCase.platform,
      );

      expect(capabilities.canCopyImage, testCase.copyImage);
      expect(capabilities.canShareMedia, testCase.shareMedia);
    });
  }
}
