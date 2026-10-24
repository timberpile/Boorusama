import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/search/options/providers.dart';
import 'package:boorusama/core/search/selected_tags/types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final catalog = capabilitiesFor(BooruType.hydrus, 'http://localhost:45869');
  test('system predicates retain their native name and exact operators', () {
    expect(
      catalog.byKey('system:width')!.compose('>=1080'),
      'system:width>=1080',
    );
    expect(
      catalog.byKey('system:width')!.compose('<1080', exclude: true),
      'system:width>=1080',
    );
    expect(
      catalog.byKey('system:number_of_tags')!.compose('>10'),
      'system:number_of_tags>10',
    );
    expect(catalog.byKey('system:number_of_tags')!.compose('>=10'), isNull);
    expect(
      catalog.byKey('system:filesize')!.compose('1mb'),
      'system:filesize=1mb',
    );
    expect(catalog.byKey('system:filesize')!.compose('1.5mb'), isNull);
    expect(catalog.byKey('system:limit')!.compose('>=100'), isNull);
    expect(
      catalog.byKey('system:duration')!.compose('>=10ms'),
      'system:duration>=10ms',
    );
    expect(catalog.byKey('system:duration')!.compose('1mo'), isNull);
  });
  test('catalog values survive the actual selected-item representation', () {
    for (final option in catalog.options) {
      for (final choice in option.choices) {
        final wire = option.compose(choice.value);
        expect(wire, isNotNull, reason: option.key);
        expect(TagSearchItem.fromString(wire!).toString(), wire);
        expect(catalog.contextFor(wire)!.option.key, option.key);
        expect(wire.startsWith('-system:'), isFalse);
      }
    }
    final date = catalog.byKey('system:imported_date')!;
    expect(date.compose('>2026-10-01'), 'system:imported_date>2026-10-01');
    expect(date.compose('2026-02-30'), isNull);
  });
}
