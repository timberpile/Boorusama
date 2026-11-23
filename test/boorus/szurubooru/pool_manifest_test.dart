import 'package:booru_clients/szurubooru.dart';
import 'package:boorusama/boorus/szurubooru/pools/providers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('preserves an unknown Szurubooru Pool member manifest', () {
    final pool = poolDtoToSzurubooruPool(
      PoolDto.fromJson({'id': 17, 'posts': null}),
    );

    expect(pool?.postIds, isNull);
  });

  test('preserves a known empty Szurubooru Pool member manifest', () {
    final pool = poolDtoToSzurubooruPool(
      PoolDto.fromJson({'id': 17, 'posts': []}),
    );

    expect(pool?.postIds, isEmpty);
  });

  test('preserves ordered duplicate IDs in a Szurubooru Pool manifest', () {
    final pool = poolDtoToSzurubooruPool(
      PoolDto.fromJson({
        'id': 17,
        'posts': [
          {'id': 31},
          {'id': 14},
          {'id': 31},
        ],
      }),
    );

    expect(pool?.postIds, [31, 14, 31]);
  });

  test('an ID-less descriptor makes member positions unknown', () {
    final pool = poolDtoToSzurubooruPool(
      PoolDto.fromJson({
        'id': 17,
        'postCount': 9,
        'posts': [
          {'id': 31},
          {'thumbnailUrl': 'https://media.example/no-id.jpg'},
          {'id': 14},
        ],
      }),
    );

    expect(pool?.postIds, isNull);
    expect(pool?.postCount, 9);
  });
}
