// Package imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:boorusama/foundation/app_update/src/github_apk_artifact.dart';

void main() {
  const releaseUrl =
      'https://github.com/timberpile/Boorusama/releases/tag/v4.5.0-timberpile.5';

  GitHubApkArtifact artifact(String architecture) {
    final name = 'boorusama-4.5.0-timberpile.5+189-android-$architecture.apk';
    return GitHubApkArtifact.parseAssets([
      {
        'target': 'apk',
        'fileName': name,
        'size': 1024,
        'sha256': List.filled(64, 'a').join(),
      },
    ], releaseUrl: releaseUrl).single;
  }

  test(
    'prefers OS ABI order and never selects an incompatible architecture',
    () {
      final armv7 = artifact('armv7');
      final arm64 = artifact('arm64');

      expect(
        GitHubApkArtifact.selectForAbis(
          [armv7, arm64],
          ['arm64-v8a', 'armeabi-v7a'],
        ),
        same(arm64),
      );
      expect(
        GitHubApkArtifact.selectForAbis(
          [arm64],
          ['x86_64'],
        ),
        isNull,
      );
      expect(
        GitHubApkArtifact.selectForAbis(
          [arm64, artifact('universal')],
          ['x86_64'],
        )?.architecture,
        'universal',
      );
    },
  );

  test('rejects malformed assets and untrusted release links', () {
    final source = [
      {
        'target': 'apk',
        'fileName': 'boorusama-4.5.0+189-android-arm64.apk',
        'size': 20,
        'sha256': 'invalid',
      },
    ];
    expect(
      GitHubApkArtifact.parseAssets(source, releaseUrl: releaseUrl),
      isEmpty,
    );
    expect(
      GitHubApkArtifact.parseAssets(
        [
          {
            'target': 'apk',
            'fileName': 'boorusama-4.5.0+189-android-arm64.apk',
            'size': 20,
            'sha256': List.filled(64, 'a').join(),
          },
        ],
        releaseUrl: 'https://evil.example/releases/tag/v4.5.0',
      ),
      isEmpty,
    );
  });
}
