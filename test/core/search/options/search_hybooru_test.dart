import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/search/options/providers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final catalog = capabilitiesFor(
    BooruType.hybooru,
    'https://booru.funmaker.moe',
  );
  test('numeric service ratings have exact values and closed ranges only', () {
    final rating = catalog.byKey('rating')!;
    expect(rating.comparisons, ['']);
    expect(rating.compose('2..4'), 'rating:2-4');
    expect(rating.compose('2..4', exclude: true), '-rating:2-4');
    expect(rating.compose('none'), 'rating:none');
    expect(rating.compose('>=2'), isNull);
    expect(rating.compose('4..2'), isNull);
    expect(rating.compose('2..'), isNull);
    expect(rating.compose('safe'), isNull);
    expect(catalog.contextFor('-rating:2-4')!.value, '2..4');
  });
  test('FREE decoration retains custom serializers and value decoding', () {
    final rating = catalog.byKey('rating')!.withFree(true);
    expect(rating.isFree, isTrue);
    expect(rating.compose('2..4'), 'rating:2-4');
    expect(rating.accepts('>=2'), isFalse);
    expect(rating.editorValue('2-4'), '2..4');
    expect(rating.comparisons, ['']);
  });
  test(
    'system states are not confused with the full Hydrus predicate language',
    () {
      expect(
        catalog.byKey('system')!.compose('inbox', exclude: true),
        '-system:inbox',
      );
      expect(catalog.byKey('system')!.compose('archive'), 'system:archive');
      expect(catalog.byKey('system')!.compose('width:100'), isNull);
      expect(catalog.byKey('order')!.compose('date_asc'), 'order:date_asc');
    },
  );
}
