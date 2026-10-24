import 'package:booru_clients/nozomi.dart';
import 'package:boorusama/boorus/nozomi/posts/search_request.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/search/options/providers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Nozomi ordering selects the index and is not sent as a tag', () {
    final request = NozomiSearchRequest.fromTags([
      'landscape',
      '-comic',
      'order:popular',
    ]);
    expect(request.order, NozomiPostOrder.popular);
    expect(request.tags, ['landscape', '-comic']);
    final onlySort = NozomiSearchRequest.fromTags(['order:popular']);
    expect(onlySort.tags, isEmpty);
    expect(onlySort.order, NozomiPostOrder.popular);
  });
  test('explicit ordering overrides the old route parameter without destroying unknown input', () {
    final request = NozomiSearchRequest.fromTags([
      'order:date',
      'order:custom',
    ], fallbackOrder: NozomiPostOrder.popular);
    expect(request.order, NozomiPostOrder.date);
    expect(request.tags, ['order:custom']);
    expect(
      NozomiSearchRequest.fromTags(
        [],
        fallbackOrder: NozomiPostOrder.popular,
      ).order,
      NozomiPostOrder.popular,
    );
    expect(NozomiSearchRequest.fromTags(['(order:popular)']).tags, [
      '(order:popular)',
    ]);
  });
  test('flattened queries extract ordering while preserving raw tag names', () {
    final request = NozomiSearchRequest.fromTags(['one piece order:popular']);
    expect(request.order, NozomiPostOrder.popular);
    expect(request.tags, ['one piece']);
    final opaque = NozomiSearchRequest.fromTags(['(order:popular OR cat)']);
    expect(opaque.order, NozomiPostOrder.date);
    expect(opaque.tags, ['(order:popular OR cat)']);
  });
  test('the catalog exposes only the two supported index orders', () {
    final catalog = capabilitiesFor(BooruType.nozomi, 'https://nozomi.la');
    expect(catalog.options.length, 1);
    final sort = catalog.byKey('order')!;
    expect(sort.compose('date'), 'order:date');
    expect(sort.compose('popular'), 'order:popular');
    expect(sort.compose('popular', exclude: true), isNull);
  });
}
