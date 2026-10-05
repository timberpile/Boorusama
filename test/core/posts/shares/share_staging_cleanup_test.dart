// ignore_for_file: avoid_slow_async_io
import 'dart:io';

import 'package:boorusama/core/posts/shares/src/share_media_preparation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'startup removes only expired app-owned platform share copies',
    () async {
      final root = await Directory.systemTemp.createTemp('share-stage-');
      addTearDown(() => root.delete(recursive: true));
      final platformStage = Directory('${root.path}/share_plus');
      await platformStage.create();
      final expiredOwned = File(
        '${platformStage.path}/boorusama_share_old.png',
      );
      final recentOwned = File('${platformStage.path}/boorusama_share_new.png');
      final expiredOther = File('${platformStage.path}/other_feature.png');
      await expiredOwned.writeAsBytes([1]);
      await recentOwned.writeAsBytes([2]);
      await expiredOther.writeAsBytes([3]);
      final oldTime = DateTime.now().subtract(const Duration(hours: 25));
      await expiredOwned.setLastModified(oldTime);
      await expiredOther.setLastModified(oldTime);

      await ShareMediaPreparation(
        rootPath: root.path,
        dio: Dio(),
        cachedBytes: (_) async => null,
      ).cleanupExpired();

      expect(await expiredOwned.exists(), isFalse);
      expect(await recentOwned.exists(), isTrue);
      expect(await expiredOther.exists(), isTrue);
    },
  );
}
