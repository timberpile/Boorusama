import 'package:booru_clients/moebooru.dart';
import 'package:boorusama/boorus/moebooru/tags/parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the platform tag mapper preserves names and categories', () async {
    final rows = ['1`artist`alias', for (var i = 0; i < 12000; i++) '0`tag_$i'];
    final tags = await buildMoebooruTagMap(TagSummaryDto(data: rows.join(' ')));
    expect(tags.length, rows.length);
    expect(tags['artist']?.category.name, 'artist');
    expect(tags['tag_11999']?.category.name, 'general');
    expect(tags.containsKey('alias'), isFalse);
    expect(await buildMoebooruTagMap(TagSummaryDto(data: '')), isEmpty);
    await expectLater(
      buildMoebooruTagMap(TagSummaryDto(data: 'invalid')),
      throwsException,
    );
  });
}
