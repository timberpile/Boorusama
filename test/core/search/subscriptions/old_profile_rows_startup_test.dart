import 'package:boorusama/core/hive/hive_adapters.dart';
import 'package:boorusama/core/search/subscriptions/src/data/hive/search_subscription_repository_hive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

import 'subscription_test_utils.dart';

void main() {
  test(
    'old integer profile rows do not prevent search storage opening',
    () async {
      final oldRow = SearchSubscriptionHiveObjectAdapter().read(
        _Reader({
          0: 'old-pin',
          1: 12,
          2: 'cat',
          3: null,
          4: 0,
          5: DateTime.utc(2026),
          6: null,
          7: null,
          8: 0,
          9: null,
          10: <Object>[],
          11: <Object>[],
          12: null,
          13: 0,
          14: null,
          15: null,
        }),
      );
      final box = MemorySubscriptionBox();
      final organizationBox = MemoryBox<dynamic>();
      await box.put(oldRow.id, oldRow);
      await organizationBox.put('feed:old-feed', {
        'id': 'old-feed',
        'profileId': 12,
        'name': 'Old feed',
      });
      final repository = HiveSearchSubscriptionRepository(
        box: box,
        organizationBox: organizationBox,
      );

      expect(await repository.getAll(), isEmpty);
      expect(await repository.getFeeds(), isEmpty);
      expect((await repository.getOrganization()).homeSearchIds, isEmpty);
    },
  );
}

class _Reader implements BinaryReader {
  _Reader(Map<int, Object?> fields)
    : _bytes = [fields.length, ...fields.keys],
      _values = [...fields.values];

  final List<int> _bytes;
  final List<Object?> _values;

  @override
  int readByte() => _bytes.removeAt(0);

  @override
  dynamic read([int? typeId]) => _values.removeAt(0);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
