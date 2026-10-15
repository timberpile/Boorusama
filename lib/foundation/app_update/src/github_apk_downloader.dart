// Dart imports:
import 'dart:io';

// Package imports:
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

// Project imports:
import 'github_apk_artifact.dart';

/// Downloads a release APK into private cache and validates it before use.
class GitHubApkDownloader {
  GitHubApkDownloader({
    Dio? dio,
    Future<Directory> Function()? temporaryDirectory,
  }) : _dio = dio ?? Dio(),
       _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory;

  final Dio _dio;
  final Future<Directory> Function() _temporaryDirectory;

  Future<File> download(
    GitHubApkArtifact artifact, {
    required CancelToken cancelToken,
    void Function(int received, int total)? onProgress,
  }) async {
    final directory = Directory(
      '${(await _temporaryDirectory()).path}/github-updates',
    );
    await directory.create(recursive: true);
    final pending = File('${directory.path}/pending.apk');
    final verified = File('${directory.path}/update.apk');

    if (await pending.exists()) await pending.delete();
    if (await verified.exists()) await verified.delete();

    try {
      await _dio.download(
        artifact.downloadUrl.toString(),
        pending.path,
        cancelToken: cancelToken,
        onReceiveProgress: onProgress,
        options: Options(
          followRedirects: true,
          receiveTimeout: const Duration(minutes: 3),
        ),
      );

      if (cancelToken.isCancelled) throw const FormatException('Cancelled');
      if (await pending.length() != artifact.size) {
        throw const FormatException('APK download size does not match manifest');
      }

      final digest = await sha256.bind(pending.openRead()).first;
      if (digest.toString() != artifact.sha256) {
        throw const FormatException('APK SHA-256 does not match manifest');
      }

      return pending.rename(verified.path);
    } finally {
      if (await pending.exists()) await pending.delete();
    }
  }
}
