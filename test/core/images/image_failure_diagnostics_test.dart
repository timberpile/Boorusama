import 'dart:typed_data';

import 'package:boorusama/core/images/booru_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../posts/details/progressive_image_test_utils.dart' as images;

void main() {
  testWidgets(
    'BooruRawImage reports the HTTP failure instead of Empty response',
    (tester) async {
      final adapter = images.ControlledImageAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      addTearDown(() => dio.close(force: true));
      final messages = <String>[];
      final originalDebugPrint = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) messages.add(message);
      };
      const url = 'https://i.pximg.net/denied.jpg';
      try {
        await tester.pumpWidget(
          images.testApp(
            BooruRawImage(
              dio: dio,
              imageUrl: url,
              imageCacheManager: images.TestImageCache({}),
            ),
          ),
        );
        await tester.runAsync(() async {
          await images.pumpUntil(
            tester,
            () => adapter.pending.containsKey(url),
            reason: 'media request',
          );
          adapter.complete(url, Uint8List(0), status: 403);
          await images.pumpUntil(
            tester,
            () => find.byType(ErrorPlaceholder).evaluate().isNotEmpty,
            reason: 'failed-image presentation',
          );
        });
        expect(messages.join('\n'), contains('httpStatusCode: 403'));
        expect(messages.join('\n'), isNot(contains('Empty response')));
        expect(adapter.requests, hasLength(1));
      } finally {
        // Binding invariants run before addTearDown callbacks.
        debugPrint = originalDebugPrint;
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        tester.binding.imageCache.clear();
      }
    },
  );
}
