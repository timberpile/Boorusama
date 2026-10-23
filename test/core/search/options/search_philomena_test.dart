import 'package:boorusama/boorus/philomena/posts/search_request.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/search/options/providers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final catalog = capabilitiesFor(
    BooruType.philomena,
    'https://derpibooru.org',
  );
  test('native fields use suffix comparisons and grouped bounds', () {
    final score = catalog.byKey('score')!;
    expect(score.compose('>=50'), 'score.gte:50');
    expect(score.compose('<0', exclude: true), '-score.lt:0');
    expect(score.compose('20..50'), '(score.gte:20,score.lte:50)');
    expect(catalog.contextFor('-(score.gte:20,score.lte:50)')!.value, '20..50');
    expect(catalog.byKey('uploader_id')!.compose('>=1'), isNull);
    expect(catalog.byKey('uploader_id')!.compose('1'), 'uploader_id:1');
    for (final option in catalog.options) {
      for (final choice in option.choices) {
        expect(
          option.compose(choice.value),
          isNotNull,
          reason: '${option.key}:${choice.value}',
        );
      }
    }
  });
  test(
    'sort is sent as API parameters and native underscores are preserved',
    () {
      final request = PhilomenaSearchRequest.fromTags([
        'twilight_sparkle',
        'created_at.gte:2026-10-01',
        'source_url:https://example.test/a_b.png',
        'sort:score:desc',
      ]);
      expect(
        request.query,
        'twilight sparkle,created_at.gte:2026-10-01,source_url:https://example.test/a_b.png',
      );
      expect(request.sortField, 'score');
      expect(request.sortDirection, 'desc');
    },
  );
  test('flattened shared and history queries retain API sorting', () {
    final request = PhilomenaSearchRequest.fromTags([
      'safe, (pony OR pegasus) sort:score:desc',
    ]);
    expect(request.query, 'safe, (pony OR pegasus)');
    expect(request.sortField, 'score');
    expect(request.sortDirection, 'desc');
    final quoted = PhilomenaSearchRequest.fromTags([
      'description:"sort:score:desc" sort:id:asc',
    ]);
    expect(quoted.query, 'description:"sort:score:desc"');
    expect(quoted.sortField, 'id');
  });
  test('unknown and grouped raw directives are never silently deleted', () {
    final request = PhilomenaSearchRequest.fromTags([
      '(sort:score:desc OR safe)',
      'sort:unknown:asc',
    ]);
    expect(request.query, '(sort:score:desc OR safe),sort:unknown:asc');
    expect(request.sortField, isNull);
    expect(
      PhilomenaSearchRequest.fromTags(['sort:id:asc', 'sort:faves:desc'])
          .sortField,
      'faves',
    );
  });
}
