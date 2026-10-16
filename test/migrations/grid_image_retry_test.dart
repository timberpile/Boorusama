import 'package:boorusama/core/images/booru_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:i18n/src/gen/strings.g.dart' show TranslationProvider;
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

import '../core/posts/details/progressive_image_test_utils.dart';

void main() {
  testWidgets(
    'Retry reloads a failed image without triggering the tile action',
    (tester) async {
      final adapter = ControlledImageAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final cache = TestImageCache({});
      var opens = 0;
      const url = 'https://fixture.test/grid.png';
      await tester.pumpWidget(
        TranslationProvider(
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: KurumiTheme(
                data: KurumiThemeData.fromMaterial(Theme.of(context)),
                child: child!,
              ),
            ),
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 180,
                  height: 180,
                  child: GestureDetector(
                    onTap: () => opens++,
                    child: BooruRawImage(
                      dio: dio,
                      imageUrl: url,
                      imageCacheManager: cache,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(
        () => pumpUntil(
          tester,
          () => adapter.pending.containsKey(url),
          reason: 'initial image',
        ),
      );
      adapter.complete(url, Uint8List(0), status: 403);
      await tester.runAsync(
        () => pumpUntil(
          tester,
          () => find.text('Retry').evaluate().isNotEmpty,
          reason: 'retry control',
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.tapAt(
        tester.getTopLeft(find.byType(BooruRawImage)) + const Offset(4, 4),
      );
      expect(opens, 1);
      adapter.pending.remove(url);
      await tester.tap(find.text('Retry'));
      await tester.runAsync(
        () => pumpUntil(
          tester,
          () => adapter.requests.length == 2,
          reason: 'explicit grid retry',
        ),
      );
      expect(opens, 1);
      adapter.complete(url, Uint8List(0), status: 403);
      await tester.runAsync(
        () => pumpUntil(
          tester,
          () => find.text('Retry').evaluate().isNotEmpty,
          reason: 'keyboard retry control',
        ),
      );
      adapter.pending.remove(url);
      Focus.of(tester.element(find.text('Retry'))).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.runAsync(
        () => pumpUntil(
          tester,
          () => adapter.requests.length == 3,
          reason: 'keyboard retry request',
        ),
      );
      expect(opens, 1);
      adapter.complete(url, targetPng);
      await tester.runAsync(() => waitForPixel(tester, [0, 0, 255, 255]));
      expect(find.text('Retry'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      dio.close(force: true);
    },
  );
}
