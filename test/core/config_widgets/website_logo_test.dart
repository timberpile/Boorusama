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
}
