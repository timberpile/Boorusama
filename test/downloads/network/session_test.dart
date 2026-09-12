// Package imports:
import 'package:test/test.dart';

// Project imports:
import 'package:boorusama/core/downloads/downloader/types.dart';

void main() {
  test('ask mode keeps Wi-Fi-started downloads off mobile data', () async {
    final session = DownloadNetworkSession();

    final constraint = await session.resolve(
      policy: DownloadNetworkPolicy.askOnMobileData,
      isMobileDataOnly: false,
      prompt: () => throw StateError('Wi-Fi downloads must not prompt'),
    );

    expect(constraint, DownloadNetworkConstraint.wifiRequired);
  });

  test(
    'a remembered mobile-data decision is reused for the app session',
    () async {
      final session = DownloadNetworkSession();
      var promptCount = 0;

      Future<DownloadNetworkPromptResult?> prompt() async {
        promptCount++;
        return const DownloadNetworkPromptResult(
          constraint: DownloadNetworkConstraint.wifiRequired,
          rememberForSession: true,
        );
      }

      final first = await session.resolve(
        policy: DownloadNetworkPolicy.askOnMobileData,
        isMobileDataOnly: true,
        prompt: prompt,
      );
      final second = await session.resolve(
        policy: DownloadNetworkPolicy.askOnMobileData,
        isMobileDataOnly: true,
        prompt: prompt,
      );

      expect(first, DownloadNetworkConstraint.wifiRequired);
      expect(second, DownloadNetworkConstraint.wifiRequired);
      expect(promptCount, 1);
    },
  );
}
