// Dart imports:
import 'dart:async';
import 'dart:convert';

// Project imports:
import 'github_apk_artifact.dart';
import 'types/update_status.dart';

/// Coordinates foreground checks; successes survive process restarts.
class UpdateCheckCoordinator {
  UpdateCheckCoordinator({
    required this.checkForUpdate,
    required this.load,
    required this.save,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;

  final Future<UpdateStatus> Function() checkForUpdate;
  final String? Function() load;
  final Future<void> Function(String) save;
  final DateTime Function() clock;

  static const checkInterval = Duration(hours: 24);
  static const errorBackoff = Duration(hours: 1);

  Future<UpdateStatus>? _inFlight;
  DateTime? _failedAt;

  DateTime? get lastCheckedAt => _read()?.checkedAt;

  UpdateStatus? get cachedStatus => _read()?.status;

  bool get isCheckDue {
    final now = clock();
    if (_failedAt case final failedAt?) {
      final elapsed = now.difference(failedAt);
      if (!elapsed.isNegative && elapsed < errorBackoff) return false;
    }
    final cached = _read();
    if (cached == null) return true;
    final elapsed = now.difference(cached.checkedAt);
    return elapsed.isNegative || elapsed >= checkInterval;
  }

  Future<UpdateStatus> check({bool force = false}) {
    if (_inFlight case final future?) return future;
    if (!force && !isCheckDue) {
      return Future.value(cachedStatus ?? const UpdateNotAvailable());
    }

    final future = _fetchAndCache();
    _inFlight = future;
    return future.whenComplete(() => _inFlight = null);
  }

  Future<UpdateStatus> _fetchAndCache() async {
    final UpdateStatus result;
    try {
      result = await checkForUpdate();
    } on Object catch (error) {
      _failedAt = clock();
      return UpdateError(error);
    }

    if (result is UpdateError) {
      _failedAt = clock();
      return result;
    }

    _failedAt = null;
    try {
      await save(jsonEncode({
        'checkedAt': clock().toUtc().toIso8601String(),
        'status': switch (result) {
          UpdateAvailable(
            :final storeVersion,
            :final currentVersion,
            :final releaseNotes,
            :final storeUrl,
            :final githubBuildNumber,
            :final githubApks,
          ) =>
            {
              'kind': 'available',
              'storeVersion': storeVersion,
              'currentVersion': currentVersion,
              'releaseNotes': releaseNotes,
              'storeUrl': storeUrl,
              'githubBuildNumber': githubBuildNumber,
              'artifacts': [for (final apk in githubApks) apk.toJson()],
            },
          _ => {'kind': 'not_available'},
        },
      }));
    } on Object {
      // A read-only or full preferences store must not suppress a fresh result.
    }
    return result;
  }

  _CachedUpdate? _read() {
    try {
      final raw = load();
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final dateString = decoded['checkedAt'];
      final json = decoded['status'];
      if (dateString is! String || json is! Map<String, dynamic>) {
        return null;
      }
      final date = DateTime.tryParse(dateString);
      if (date == null) return null;

      if (json['kind'] == 'not_available') {
        return _CachedUpdate(date, const UpdateNotAvailable());
      }
      if (json['kind'] != 'available') return null;

      final storeVersion = json['storeVersion'];
      final currentVersion = json['currentVersion'];
      final releaseNotes = json['releaseNotes'];
      final storeUrl = json['storeUrl'];
      if (storeVersion is! String ||
          currentVersion is! String ||
          releaseNotes is! String ||
          storeUrl is! String) {
        return null;
      }

      return _CachedUpdate(
        date,
        UpdateAvailable(
          storeVersion: storeVersion,
          currentVersion: currentVersion,
          releaseNotes: releaseNotes,
          storeUrl: storeUrl,
          githubBuildNumber: json['githubBuildNumber'] is int
              ? json['githubBuildNumber'] as int
              : null,
          githubApks: GitHubApkArtifact.parseAssets(
            json['artifacts'],
            releaseUrl: storeUrl,
          ),
        ),
      );
    } on Object {
      return null;
    }
  }
}

final class _CachedUpdate {
  const _CachedUpdate(this.checkedAt, this.status);

  final DateTime checkedAt;
  final UpdateStatus status;
}
