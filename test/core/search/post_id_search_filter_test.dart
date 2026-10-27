import 'package:boorusama/core/search/options/catalog/danbooru.dart';
import 'package:boorusama/core/search/options/catalog/philomena.dart';
import 'package:boorusama/core/search/options/catalog/szurubooru.dart';
import 'package:boorusama/core/search/search/src/widgets/post_id_search_filter.dart';
import 'package:boorusama/core/search/selected_tags/types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('replaces prior ID predicates without modifying ordering or tags', () {
    final tags = [
      TagSearchItem.fromString('artist_name'),
      TagSearchItem.fromString('id:<50'),
      TagSearchItem.fromString('order:score'),
      TagSearchItem.fromString('id:20..40'),
    ];
    final idOption = danbooruOptions().firstWhere((o) => o.key == 'id');
    final refined = refinePostIdSearch(
      tags: tags,
      option: idOption,
      postId: 42,
      direction: PostIdSearchDirection.fromHere,
    );
    expect(refined?.map((e) => e.toString()).toList(), [
      'artist_name',
      'order:score',
      'id:>=42',
    ]);
    expect(tags.map((e) => e.toString()).toList(), [
      'artist_name',
      'id:<50',
      'order:score',
      'id:20..40',
    ]);
  });

  test('preserves opaque raw expressions and removes standalone ID terms', () {
    final idOption = danbooruOptions().firstWhere((o) => o.key == 'id');
    final refined = refinePostIdSearch(
      tags: [
        const TagSearchItem.raw(tag: 'cat ~dog id:>30 order:score'),
        TagSearchItem.fromString('rating:g'),
      ],
      option: idOption,
      postId: 42,
      direction: PostIdSearchDirection.untilHere,
    );
    expect(refined?.map((e) => e.toString()).toList(), [
      'cat ~dog order:score',
      'rating:g',
      'id:<=42',
    ]);
  });

  test(
    'rejects nested or ambiguous raw ID conditions without mutating them',
    () {
      final idOption = danbooruOptions().firstWhere((o) => o.key == 'id');
      for (final query in [
        '(id:>30 ~dog)',
        '(cat id:42)',
        '(cat id:42 dog)',
        'cat -id:20',
        'id:foo',
      ]) {
        final tags = [TagSearchItem.raw(tag: query)];
        expect(
          refinePostIdSearch(
            tags: tags,
            option: idOption,
            postId: 42,
            direction: PostIdSearchDirection.fromHere,
          ),
          isNull,
        );
        expect(tags.single.toString(), query);
      }
    },
  );

  test('uses source-specific inclusive ID syntax', () {
    for (final (option, from, until) in [
      (
        szurubooruOptions().firstWhere((o) => o.key == 'id'),
        'id:42..',
        'id:..42',
      ),
      (
        philomenaOptions().firstWhere((o) => o.key == 'id'),
        'id.gte:42',
        'id.lte:42',
      ),
    ]) {
      for (final (direction, expected) in [
        (PostIdSearchDirection.fromHere, from),
        (PostIdSearchDirection.untilHere, until),
      ]) {
        final refined = refinePostIdSearch(
          tags: [TagSearchItem.fromString('cat')],
          option: option,
          postId: 42,
          direction: direction,
        );
        expect(refined?.last.toString(), expected);
        expect(
          refinePostIdSearch(
            tags: refined!,
            option: option,
            postId: 43,
            direction: PostIdSearchDirection.fromHere,
          )?.map((tag) => tag.toString()),
          ['cat', from.replaceAll('42', '43')],
        );
      }
    }
  });

  test('rejects nonpositive IDs and options without range comparisons', () {
    final idOption = danbooruOptions().firstWhere((o) => o.key == 'id');
    expect(
      refinePostIdSearch(
        tags: [],
        option: idOption,
        postId: 0,
        direction: PostIdSearchDirection.untilHere,
      ),
      isNull,
    );
  });
}
