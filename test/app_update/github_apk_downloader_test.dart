// Dart imports:
import 'dart:convert';
import 'dart:io';

// Package imports:
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:boorusama/foundation/app_update/src/github_apk_artifact.dart';
import 'package:boorusama/foundation/app_update/src/github_apk_downloader.dart';

void main() {
  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'boorusama-github-update-test-',
    );
  });

  tearDown(() async {
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  GitHubApkDownloader downloader() => GitHubApkDownloader(
    temporaryDirectory: () async => temporaryDirectory,
  );

  GitHubApkArtifact artifact(
    HttpServer server,
    List<int> bytes, {
    int? expectedSize,
    String? expectedHash,
  }) => GitHubApkArtifact(
    fileName: 'boorusama-4.5.0+100-android-arm64.apk',
    architecture: 'arm64',
    size: expectedSize ?? bytes.length,
    sha256: expectedHash ?? sha256.convert(bytes).toString(),
    downloadUrl: Uri.parse(
      'http://127.0.0.1:${server.port}/test-update.apk',
    ),
  );

  test('downloads a verified APK to the private update cache', () async {
    final bytes = utf8.encode(List.filled(1024, 'A').join());
    final server = await _serve(bytes);
    final progress = <int>[];

    final apk = await downloader().download(
      artifact(server, bytes),
      cancelToken: CancelToken(),
      onProgress: (received, total) => progress.add(received),
    );

    expect(apk.path, endsWith('/github-updates/update.apk'));
    expect(await apk.readAsBytes(), bytes);
    expect(progress, isNotEmpty);
    expect(
      await File('${apk.parent.path}/pending.apk').exists(),
      isFalse,
    );
  });

  test('rejects wrong size or digest and removes the partial APK', () async {
    final bytes = utf8.encode(List.filled(1024, 'B').join());
    final server = await _serve(bytes);
    final client = downloader();

    await expectLater(
      client.download(
        artifact(server, bytes, expectedSize: bytes.length + 1),
        cancelToken: CancelToken(),
      ),
      throwsA(isA<FormatException>()),
    );
    await expectLater(
      client.download(
        artifact(server, bytes, expectedHash: '0' * 64),
        cancelToken: CancelToken(),
      ),
      throwsA(isA<FormatException>()),
    );
    final updates = Directory('${temporaryDirectory.path}/github-updates');
    expect(await File('${updates.path}/pending.apk').exists(), isFalse);
    expect(await File('${updates.path}/update.apk').exists(), isFalse);
  });

  test('cancellation never exposes an unverified APK', () async {
    final bytes = utf8.encode(List.filled(65536, 'C').join());
    final server = await _serve(bytes);
    final token = CancelToken();

    await expectLater(
      downloader().download(
        artifact(server, bytes),
        cancelToken: token,
        onProgress: (_, _) {
          if (!token.isCancelled) token.cancel('test cancelled');
        },
      ),
      throwsA(isA<Exception>()),
    );

    final updates = Directory('${temporaryDirectory.path}/github-updates');
    expect(await File('${updates.path}/pending.apk').exists(), isFalse);
    expect(await File('${updates.path}/update.apk').exists(), isFalse);
  });
}

Future<HttpServer> _serve(List<int> bytes) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  addTearDown(() => server.close(force: true));
  server.listen((request) async {
    request.response.contentLength = bytes.length;
    request.response.add(bytes);
    await request.response.close();
  });
  return server;
}
