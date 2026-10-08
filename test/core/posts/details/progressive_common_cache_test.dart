import 'dart:io';
import 'dart:typed_data';

import 'package:boorusama/core/posts/details/src/widgets/progressive_post_image.dart';
import 'package:boorusama/core/posts/listing/types.dart';
import 'package:cache_manager/cache_manager.dart';
import 'package:dio/dio.dart';
import 'package:extended_image/extended_image.dart';
import 'package:extended_image/src/image/raw_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'progressive_image_test_utils.dart';

void main() {
  testWidgets(
    'progressive stage and displayed decoded RAM providers persist real use without extra fetch',
    (tester) async {
      await tester.runAsync(() async {
        Future<T> real<T>(Future<T> Function() body) => body();
        const lower = 'https://common-cache.test/lower.png';
        const target = 'https://common-cache.test/target.png';
        late Directory directory;
        late DefaultImageCacheManager cache;
        final budget = lowerPng.length + targetPng.length + 10;
        await real(() async {
          directory = await Directory.systemTemp.createTemp(
            'progressive-cache-',
          );
          cache = DefaultImageCacheManager(
            maxBytes: budget,
            cacheRootPathProvider: () => directory.path,
          );
          await cache.saveFile('old', Uint8List(10));
          await cache.saveFile(cache.generateCacheKey(lower), lowerPng);
        });
        addTearDown(
          () => tester.runAsync(() async {
            await cache.dispose();
            await directory.delete(recursive: true);
          }),
        );
        PaintingBinding.instance.imageCache.clear();
        final adapter = ControlledImageAdapter();
        final dio = Dio()..httpClientAdapter = adapter;
        addTearDown(() => dio.close(force: true));
        Widget page() => testApp(
          RawProgressivePostImage(
            dio: dio,
            imageUrl: target,
            lowerMedia: const GridThumbnailMedia(url: lower, aspectRatio: 1),
            aspectRatio: 1,
            geometryAspectRatio: 1,
            cacheManager: cache,
          ),
        );
        await tester.pumpWidget(page());
        for (var i = 0; i < 8; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 80));
          await tester.pump();
        }
        expect(
          (await tester
                  .widget<ExtendedRawImage>(find.byType(ExtendedRawImage).first)
                  .image!
                  .toByteData())!
              .buffer
              .asUint8List()
              .take(4)
              .toList(),
          [255, 0, 0, 255],
        );
        final lowerProvider = tester
            .widget<ExtendedImage>(find.byType(ExtendedImage))
            .image;
        final lowerStream = lowerProvider.resolve(ImageConfiguration.empty);
        expect(lowerStream.completer, isNotNull);
        expect(adapter.requests, hasLength(1));
        adapter.complete(target, targetPng);
        for (var i = 0; i < 8; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 80));
          await tester.pump();
        }
        expect(
          (await tester
                  .widget<ExtendedRawImage>(find.byType(ExtendedRawImage).first)
                  .image!
                  .toByteData())!
              .buffer
              .asUint8List()
              .take(4)
              .toList(),
          [0, 0, 255, 255],
        );
        final targetProvider = tester
            .widget<ExtendedImage>(find.byType(ExtendedImage))
            .image;
        final targetCompleter = targetProvider
            .resolve(ImageConfiguration.empty)
            .completer;
        await real(() async {
          await cache.saveFile('unused', Uint8List(10));
          expect(await cache.getCachedFilePath('old'), isNull);
        });
        await tester.pumpWidget(
          testApp(
            Column(
              children: [
                Expanded(child: ExtendedImage(image: lowerProvider)),
                Expanded(child: ExtendedImage(image: targetProvider)),
              ],
            ),
          ),
        );
        for (var i = 0; i < 8; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 80));
          await tester.pump();
        }
        final shown = tester
            .widgetList<ExtendedImage>(find.byType(ExtendedImage))
            .last
            .image;
        expect(shown, same(targetProvider));
        expect(
          shown.resolve(ImageConfiguration.empty).completer,
          same(targetCompleter),
        );
        expect(
          lowerProvider.resolve(ImageConfiguration.empty).completer,
          same(lowerStream.completer),
        );
        expect(
          adapter.requests,
          hasLength(1),
          reason:
              'staging and displaying both decoded providers must use held RAM streams',
        );
        await tester.pumpWidget(const SizedBox());
        await real(() async {
          await cache.dispose();
          cache = DefaultImageCacheManager(
            maxBytes: budget,
            cacheRootPathProvider: () => directory.path,
          );
          await cache.saveFile('new', Uint8List(10));
          expect(
            await cache.getCachedFilePath('unused'),
            isNull,
            reason: 'staged and displayed RAM use must survive restart',
          );
          expect(
            await cache.getCachedFileBytes(cache.generateCacheKey(lower)),
            lowerPng,
          );
          expect(
            await cache.getCachedFileBytes(cache.generateCacheKey(target)),
            targetPng,
          );
        });
        PaintingBinding.instance.imageCache.clear();
      });
    },
  );
}
