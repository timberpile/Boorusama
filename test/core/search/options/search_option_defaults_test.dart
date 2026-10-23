import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/search/options/providers.dart';
import 'package:boorusama/core/search/options/search_option_defaults.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('duration defaults use units accepted by the active engine', () {
    final danbooru = capabilitiesFor(
      BooruType.danbooru,
      'https://danbooru.donmai.us',
    ).byKey('age')!;
    final hydrus = capabilitiesFor(
      BooruType.hydrus,
      'http://localhost:45869',
    ).byKey('system:duration')!;
    expect(initialSearchOptionValue(danbooru, null), '<7d');
    final initial = initialSearchOptionValue(hydrus, null);
    expect(hydrus.accepts(initial), isTrue);
    expect(hydrus.compose(initial), isNotNull);
    expect(initial, isNot('<7d'));
  });
  test('opening a sheet does not replace an explicit draft with a preset', () {
    final option = capabilitiesFor(
      BooruType.hybooru,
      'https://booru.funmaker.moe',
    ).byKey('rating')!;
    expect(initialSearchOptionValue(option, '2-4'), '2..4');
    expect(initialSearchOptionValue(option, ''), '');
    expect(initialSearchOptionValue(option, 'invalid'), 'invalid');
  });
}
