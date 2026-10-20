import '../github_apk_artifact.dart';

sealed class UpdateStatus {
  const UpdateStatus();
}

final class UpdateAvailable extends UpdateStatus {
  const UpdateAvailable({
    required this.storeVersion,
    required this.currentVersion,
    required this.releaseNotes,
    required this.storeUrl,
    this.githubBuildNumber,
    this.githubApks = const [],
  });

  final String storeVersion;
  final String currentVersion;
  final String releaseNotes;
  final String storeUrl;
  final int? githubBuildNumber;
  final List<GitHubApkArtifact> githubApks;
}

final class UpdateNotAvailable extends UpdateStatus {
  const UpdateNotAvailable();
}

final class UpdateError extends UpdateStatus {
  const UpdateError(this.error);

  final Object error;
}
