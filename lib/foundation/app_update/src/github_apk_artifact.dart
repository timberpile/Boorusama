/// A release APK described by the existing GitHub release receipt manifest.
final class GitHubApkArtifact {
  const GitHubApkArtifact({
    required this.fileName,
    required this.architecture,
    required this.size,
    required this.sha256,
    required this.downloadUrl,
  });

  final String fileName;
  final String architecture;
  final int size;
  final String sha256;
  final Uri downloadUrl;

  Map<String, Object> toJson() => {
    'target': 'apk',
    'fileName': fileName,
    'size': size,
    'sha256': sha256,
  };

  static List<GitHubApkArtifact> parseAssets(
    Object? source, {
    required String releaseUrl,
  }) {
    final uri = Uri.tryParse(releaseUrl);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != 'github.com' ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.pathSegments.length != 5 ||
        uri.pathSegments[0] != 'timberpile' ||
        uri.pathSegments[1] != 'Boorusama' ||
        uri.pathSegments[2] != 'releases' ||
        uri.pathSegments[3] != 'tag' ||
        !RegExp(r'^v[0-9A-Za-z._-]+$').hasMatch(uri.pathSegments[4]) ||
        source is! List) {
      return const [];
    }

    final result = <GitHubApkArtifact>[];
    for (final entry in source) {
      if (entry is! Map) continue;
      if (entry['target'] != 'apk') continue;
      final fileName = entry['fileName'];
      final sha256 = entry['sha256'];
      final size = entry['size'];
      if (fileName is! String ||
          sha256 is! String ||
          size is! int ||
          size <= 0 ||
          !RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(sha256)) {
        continue;
      }

      final match = RegExp(
        r'^boorusama-[0-9A-Za-z.+_-]+-android-(arm64|armv7|x64|universal)\.apk$',
      ).firstMatch(fileName);
      if (match == null) continue;

      result.add(
        GitHubApkArtifact(
          fileName: fileName,
          architecture: match.group(1)!,
          size: size,
          sha256: sha256.toLowerCase(),
          downloadUrl: Uri(
            scheme: 'https',
            host: 'github.com',
            pathSegments: [
              'timberpile',
              'Boorusama',
              'releases',
              'download',
              uri.pathSegments[4],
              fileName,
            ],
          ),
        ),
      );
    }
    return result;
  }

  /// Respect the OS preference order instead of assuming arm64 on all devices.
  static GitHubApkArtifact? selectForAbis(
    List<GitHubApkArtifact> artifacts,
    List<String> supportedAbis,
  ) {
    for (final abi in supportedAbis) {
      final architecture = switch (abi) {
        'arm64-v8a' => 'arm64',
        'armeabi-v7a' => 'armv7',
        'x86_64' => 'x64',
        _ => null,
      };
      if (architecture == null) continue;
      for (final artifact in artifacts) {
        if (artifact.architecture == architecture) return artifact;
      }
    }
    for (final artifact in artifacts) {
      if (artifact.architecture == 'universal') return artifact;
    }
    return null;
  }
}
