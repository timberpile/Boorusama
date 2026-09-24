// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:dio/dio.dart';
import 'package:extended_image/extended_image.dart';
import 'package:extended_image/src/dio_extended_image_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/kurumi.dart';

// Project imports:
import 'package:boorusama/core/images/booru_image.dart';

void main() {
  testWidgets('shows the configured fallback after the primary image fails', (
    tester,
  ) async {
    final controller = ExtendedImageController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _testApp(
        BooruRawImage(
          dio: Dio(),
          imageUrl: 'https://example.test/poster.jpg',
          fallbackUrl: 'https://example.test/thumbnail.jpg',
          controller: controller,
        ),
      ),
    );

    expect(_networkUrls(tester), contains('https://example.test/poster.jpg'));
    expect(
      _networkUrls(tester),
      isNot(contains('https://example.test/thumbnail.jpg')),
    );

    controller.changeLoadState(LoadState.failed);
    await tester.pump();

    expect(
      _networkUrls(tester),
      contains('https://example.test/thumbnail.jpg'),
    );
    expect(find.byType(ErrorPlaceholder), findsNothing);
  });

  testWidgets('uses the normal error placeholder when the fallback fails', (
    tester,
  ) async {
    final controller = ExtendedImageController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _testApp(
        BooruRawImage(
          dio: Dio(),
          imageUrl: 'https://example.test/poster.jpg',
          fallbackUrl: 'https://example.test/thumbnail.jpg',
          controller: controller,
        ),
      ),
    );

    controller.changeLoadState(LoadState.failed);
    await tester.pump();

    final fallback = tester
        .widgetList<ExtendedImage>(find.byType(ExtendedImage))
        .singleWhere(
          (image) =>
              image.image is DioExtendedNetworkImageProvider &&
              (image.image as DioExtendedNetworkImageProvider).url ==
                  'https://example.test/thumbnail.jpg',
        );

    expect(fallback.errorWidget, isA<ErrorPlaceholder>());
  });
}

Widget _testApp(Widget child) => MaterialApp(
  builder: (context, child) => KurumiTheme(
    data: KurumiThemeData.fromMaterial(Theme.of(context)),
    child: child!,
  ),
  home: Scaffold(body: child),
);

List<String> _networkUrls(WidgetTester tester) => tester
    .widgetList<ExtendedImage>(find.byType(ExtendedImage))
    .map((image) => image.image)
    .whereType<DioExtendedNetworkImageProvider>()
    .map((provider) => provider.url)
    .toList();
