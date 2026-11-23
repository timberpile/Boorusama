@TestOn('browser')
library;

import 'package:boorusama/foundation/database/indexed_db_store.dart';
import 'package:test/test.dart';

// Run in the test runner's disposable browser profile, never a user profile.
// Each test owns a distinct database and clears only its own synthetic rows.
void main() {
  var serial = 0;
  Future<IndexedDbStore> store({
    bool autoIncrement = true,
    List<IndexConfig>? indexes,
  }) async {
    final value = IndexedDbStore(
      dbName:
          'audit_key_types_${DateTime.now().microsecondsSinceEpoch}_${serial++}',
      storeName: 'records',
    );
    await value.initialize(autoIncrement: autoIncrement, indexes: indexes);
    addTearDown(value.clear);
    return value;
  }

  test(
    'generated numeric keys remain distinct from numeric-looking strings',
    () async {
      final db = await store();
      await db.add({'value': 'numeric'});
      expect((await db.get(1))?['value'], 'numeric');
      expect(await db.get('1'), isNull);
      await db.put({'value': 'text'}, '1');
      expect((await db.get(1))?['value'], 'numeric');
      expect((await db.get('1'))?['value'], 'text');
      expect(await db.getAll(), hasLength(2));
    },
  );

  test(
    'a primary key found through an index can update and delete its row',
    () async {
      final db = await store(
        indexes: [
          const IndexConfig(
            name: 'query_type',
            keyPath: ['query', 'type'],
            unique: true,
          ),
        ],
      );
      await db.add({'query': 'cat', 'type': 'simple', 'count': 1});
      final key = await db.findKey('query_type', ['cat', 'simple']);
      expect(key, isA<num>());
      await db.put({'query': 'cat', 'type': 'simple', 'count': 2}, key!);
      expect(
        (await db.getByIndex('query_type', ['cat', 'simple']))?['count'],
        2,
      );
      expect(await db.getAll(), hasLength(1));
      await db.delete(key);
      expect(await db.getAll(), isEmpty);
    },
  );

  test(
    'compound numeric and string keys do not overwrite each other',
    () async {
      final db = await store(autoIncrement: false);
      await db.put({'value': 'numeric part'}, [1, 'cat']);
      await db.put({'value': 'string part'}, ['1', 'cat']);
      expect(await db.getAll(), hasLength(2));
      expect((await db.get([1, 'cat']))?['value'], 'numeric part');
      expect((await db.get(['1', 'cat']))?['value'], 'string part');
      await db.delete([1, 'cat']);
      expect(await db.get([1, 'cat']), isNull);
      expect((await db.get(['1', 'cat']))?['value'], 'string part');
    },
  );
}
