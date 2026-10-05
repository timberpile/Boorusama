import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/config_widgets/website_logo.dart';

void main() {
  final cases = [
    (
      type: BooruType.danbooru,
      input: 'danbooru.donmai.us',
      expected: 'https://danbooru.donmai.us',
    ),
    (
      type: BooruType.gelbooru,
      input: 'gelbooru.com',
      expected: 'https://gelbooru.com',
    ),
    (
      type: BooruType.gelbooru,
      input: 'https://gelbooru.com/',
      expected: 'https://gelbooru.com/',
    ),
    (
      type: BooruType.gelbooru,
      input: 'booru.local:8080',
      expected: 'https://booru.local:8080',
    ),
    (
      type: BooruType.gelbooru,
      input: '[::1]:8080',
      expected: 'https://[::1]:8080',
    ),
  ];

  for (final testCase in cases) {
    test('site logo resolves ${testCase.input} as a web source', () {
      final logo = ConfigAwareWebsiteLogo.fromBooruType(
        testCase.type,
        testCase.input,
      );

      expect(logo.url, testCase.expected);
    });
  }

  final assetCases = [
    (
      type: BooruType.danbooru,
      url: 'https://danbooru.donmai.us/',
      asset: 'assets/images/danbooru-logo.png',
    ),
    (
      type: BooruType.hydrus,
      url: 'http://127.0.0.1:45869/',
      asset: 'assets/images/hydrus-logo.png',
    ),
  ];

  for (final testCase in assetCases) {
    testWidgets('${testCase.type.displayName} keeps its bundled site icon', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: ConfigAwareWebsiteLogo.fromBooruType(
              testCase.type,
              testCase.url,
            ),
          ),
        ),
      );

      final image = tester.widget<Image>(find.byType(Image));
      expect(image.image, isA<AssetImage>());
      expect((image.image as AssetImage).assetName, testCase.asset);
    });
  }
}
