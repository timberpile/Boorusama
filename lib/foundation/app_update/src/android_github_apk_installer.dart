// Dart imports:
import 'dart:io';

// Flutter imports:
import 'package:flutter/services.dart';

/// Native checks the APK package, version code, and current signing certificate.
class AndroidGitHubApkInstaller {
  const AndroidGitHubApkInstaller();

  static const _channel = MethodChannel(
    'com.timberpile.boorusama/github_apk_install',
  );

  Future<List<String>> supportedAbis() async {
    return await _channel.invokeListMethod<String>('supportedAbis') ??
        const <String>[];
  }

  Future<bool> canInstall() async {
    return await _channel.invokeMethod<bool>('canInstall') ?? false;
  }

  Future<void> openInstallSettings() {
    return _channel.invokeMethod<void>('openInstallSettings');
  }

  Future<void> install(
    File apk, {
    required int buildNumber,
    required String version,
  }) {
    return _channel.invokeMethod<void>('install', {
      'path': apk.path,
      'buildNumber': buildNumber,
      'version': version,
    });
  }
}
