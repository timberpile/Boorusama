import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/search/options/providers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('e621 preserves native file units and ratio notation', () {
    final options = capabilitiesFor(BooruType.e621, 'https://e621.net');
    expect(options.byKey('filesize')!.compose('>=2mb'), 'filesize:>=2mb');
    expect(options.byKey('filesize')!.compose('>=2gb'), isNull);
    expect(options.byKey('ratio')!.compose('16/9'), 'ratio:16:9');
    expect(options.byKey('rating')!.compose('g'), isNull);
    expect(options.byKey('status')!.compose('flagged'), 'status:flagged');
    expect(
      options.byKey('locked')!.compose('rating', exclude: true),
      '-locked:rating',
    );
  });
  test('Moebooru does not emit unsupported negative user or vote syntax', () {
    final options = capabilitiesFor(BooruType.moebooru, 'https://yande.re');
    expect(options.byKey('user')!.compose('example', exclude: true), isNull);
    expect(options.byKey('vote')!.compose('3:example', exclude: true), isNull);
    expect(
      options.byKey('width')!.compose('<1920', exclude: true),
      'width:>=1920',
    );
    expect(options.byKey('pool')!.compose('12', exclude: true), '-pool:12');
  });
  for (final type in [
    BooruType.danbooru,
    BooruType.gelbooru,
    BooruType.moebooru,
    BooruType.e621,
  ]) {
    test('${type.name} catalog has unique keys and valid presets', () {
      final options = capabilitiesFor(type, 'https://example.test').options;
      expect(options.map((o) => o.key).toSet().length, options.length);
      for (final option in options) {
        for (final choice in option.choices) {
          expect(
            option.compose(choice.value),
            isNotNull,
            reason: '${option.key}:${choice.value}',
          );
        }
      }
    });
  }
}
