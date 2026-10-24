// Dart imports:
import 'dart:async';
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

  tearDown(() {
    if (temporaryDirectory.existsSync()) {
      temporaryDirectory.deleteSync(recursive: true);
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

    expect(apk.parent.parent.path, endsWith('/github-updates'));
    expect(apk.path, endsWith('/update.apk'));
    expect(await apk.readAsBytes(), bytes);
    expect(progress, isNotEmpty);
    expect(
      File('${apk.parent.path}/pending.apk').existsSync(),
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
        artifact(server, bytes, expectedHash: List.filled(64, '0').join()),
        cancelToken: CancelToken(),
      ),
      throwsA(isA<FormatException>()),
    );
    final updates = Directory('${temporaryDirectory.path}/github-updates');
    expect(
      updates.listSync(recursive: true).whereType<File>().isNotEmpty,
      isFalse,
    );
    expect(updates.listSync().isNotEmpty, isFalse);
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
    expect(
      updates.listSync(recursive: true).whereType<File>().isNotEmpty,
      isFalse,
    );
    expect(updates.listSync().isNotEmpty, isFalse);
  });
  test('overlapping downloads cannot delete or replace each other', () async {
    final started = Completer<void>();
    final release = Completer<void>();
    final firstBytes = utf8.encode('first APK');
    final secondBytes = utf8.encode('second APK');
    final firstServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => firstServer.close(force: true));
    firstServer.listen((request) async {
      started.complete();
      await release.future;
      request.response.add(firstBytes);
      await request.response.close();
    });
    final secondServer = await _serve(secondBytes);
    final first = downloader().download(
      artifact(firstServer, firstBytes),
      cancelToken: CancelToken(),
    );
    await started.future.timeout(const Duration(seconds: 10));
    final second = await downloader().download(
      artifact(secondServer, secondBytes),
      cancelToken: CancelToken(),
    );
    release.complete();
    final firstApk = await first;
    expect(firstApk.path, isNot(second.path));
    expect(await firstApk.readAsBytes(), firstBytes);
    expect(await second.readAsBytes(), secondBytes);
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
