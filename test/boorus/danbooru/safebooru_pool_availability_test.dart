import 'package:booru_clients/danbooru.dart';
import 'package:boorusama/boorus/danbooru/pools/pool/src/types/safebooru_pool_availability.dart';
import 'package:boorusama/boorus/danbooru/pools/pool/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final config = BooruConfig.empty.search;
  DanbooruPool pool(List<int>? ids, {bool complete = true}) => DanbooruPool(
    id: 1,
    postIds: ids,
    manifestComplete: complete,
    category: null,
    description: null,
    postCount: ids?.length,
    name: 'Pool',
    createdAt: null,
    updatedAt: null,
  );
  PostDto row(
    int id, {
    String? rating = 'g',
    bool? deleted = false,
    bool? banned = false,
    String? tags = '',
    String? ext = 'jpg',
  }) => PostDto.fromJson({
    'id': id,
    'rating': rating,
    'is_deleted': deleted,
    'is_banned': banned,
    'tag_string': tags,
    'file_ext': ext,
    'preview_file_url': 'https://cdn.test/$id.jpg',
  });
  test('bounded candidates retain priority and sharing across manifests', () {
    expect(poolAvailabilityCandidates(pool([1, 2, 3])), [3, 2, 1]);
    expect(poolAvailabilityCandidates(pool([1, 2, 3, 4, 5, 6])), [6, 4, 1]);
    expect(poolAvailabilityCandidates(pool([1, 1, 2])), [2, 1]);
  });
  test(
    'empty authority, omitted IDs, sampled denial and failed facts differ',
    () {
      expect(
        assessSafebooruPool(pool([]), {}, config, {}).availability,
        PoolAvailability.provenEmpty,
      );
      expect(
        assessSafebooruPool(
          pool([], complete: false),
          {},
          config,
          {},
        ).availability,
        PoolAvailability.unknown,
      );
      expect(
        assessSafebooruPool(pool([1]), {}, config, {}).availability,
        PoolAvailability.unknown,
      );
      expect(
        assessSafebooruPool(
          pool([1, 2, 3, 4]),
          {
            1: row(1, rating: 'e'),
            3: row(3, rating: 'e'),
            4: row(4, rating: 'e'),
          },
          config,
          {},
        ).availability,
        PoolAvailability.unknown,
      );
      expect(
        assessSafebooruPool(
          pool([1]),
          {1: row(1, rating: 'e')},
          config,
          {},
        ).accessibleCount,
        0,
      );
    },
  );
  test('accessible without static cover and exact positive coverage', () {
    final available = assessSafebooruPool(
      pool([1, 2]),
      {1: row(1), 2: row(2, rating: 'e')},
      config,
      {},
    );
    expect(available.availability, PoolAvailability.accessible);
    expect(available.accessibleCount, 1);
    final noCover = assessSafebooruPool(
      pool([1]),
      {1: row(1, ext: 'webm')},
      config,
      {},
    );
    expect(noCover.availability, PoolAvailability.accessible);
  });
  test('missing raw facts and unresolved policy never authorize', () {
    for (final value in [
      row(1, rating: null),
      row(1, ext: null),
      row(1, tags: null),
    ]) {
      expect(
        assessSafebooruPool(pool([1]), {1: value}, config, {}).availability,
        PoolAvailability.unknown,
      );
    }
    expect(
      assessSafebooruPool(pool([1]), {1: row(1)}, config, null).availability,
      PoolAvailability.unknown,
    );
  });
}
