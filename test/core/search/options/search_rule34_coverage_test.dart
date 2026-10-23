import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/search/options/providers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final r34 = capabilitiesFor(BooruType.gelbooruV2, 'https://rule34.xxx/');
  test(
    'Rule34 offers verified API filters rather than website-only predicates',
    () {
      for (final key in [
        'rating',
        'user',
        'md5',
        'parent',
        'width',
        'height',
        'score',
        'sort',
        'source',
      ]) {
        expect(r34.byKey(key), isNotNull, reason: key);
      }
      expect(r34.byKey('sort')!.compose('random'), 'sort:random');
      expect(r34.byKey('sort')!.compose('rating:desc'), isNull);
      for (final key in ['aspectratio', 'aspectratiof', 'sourcedomains']) {
        expect(
          r34.byKey(key),
          isNull,
          reason: '$key is not supported by the post API',
        );
      }
      expect(
        r34.byKey('source')!.compose('*://example.com/*'),
        'source:*://example.com/*',
      );
      expect(
        r34.byKey('source')!.compose('*example.com*', exclude: true),
        isNull,
      );
      expect(r34.byKey('parent')!.compose('>=1'), isNull);
    },
  );
  test('site-specific additions do not leak into other legacy hosts', () {
    for (final host in [
      'safebooru.org',
      'hypnohub.net',
      'realbooru.com',
      'xbooru.com',
      'bbooru.com',
      'tbib.org',
    ]) {
      final options = capabilitiesFor(BooruType.gelbooruV2, 'https://$host');
      expect(options.byKey('sort'), isNotNull);
      expect(options.byKey('aspectratio'), isNull);
      expect(options.byKey('sourcedomains'), isNull);
      expect(options.byKey('source'), isNull);
    }
    expect(
      capabilitiesFor(BooruType.gelbooruV2, 'https://unknown.example').options,
      isEmpty,
    );
  });
}
