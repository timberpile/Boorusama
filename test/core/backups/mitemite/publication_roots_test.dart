import 'package:boorusama/core/backups/mitemite/catalog.dart';
import 'package:boorusama/core/backups/mitemite/protocol.dart';
import 'package:flutter_test/flutter_test.dart';

const publisher = '11111111-2222-4333-8444-555555555555';
const parent = '22222222-2222-4333-8444-555555555555';
const child = '33333333-2222-4333-8444-555555555555';

SyncCollectionId id(String source) => SyncCollectionId(
  publisher: publisher,
  kind: 'bookmarks',
  source: source,
);
SyncCatalogEntry entry(String source, {String? parent}) => SyncCatalogEntry(
  id: id(source),
  name: source,
  parent: parent,
  state: SyncPublicationState.active,
  revision: SyncRevision(
    collection: id(source),
    revision: 1,
    length: 1,
    sha256: syncDigest([1]),
    semanticHash: syncDigest([1]),
    schema: 10,
  ),
);

void main() {
  SyncCatalog catalog(Set<SyncCollectionId>? roots) => SyncCatalog(
    publisher: publisher,
    sequence: 1,
    name: 'Publisher',
    entries: [
      entry(parent),
      entry(child, parent: parent),
    ],
    publicationRoots: roots,
  );
  test('direct publication is independent of source ancestry', () {
    final parentOnly = catalog({id(parent)});
    expect(parentOnly.offeredEntries.map((e) => e.id.source), [parent]);
    expect(parentOnly.entries, hasLength(2));
    final overlap = catalog({id(parent), id(child)});
    expect(overlap.offeredEntries.map((e) => e.id.source), [parent, child]);
    final childOnly = catalog({id(child)});
    expect(childOnly.offeredEntries.single.id.source, child);
  });
  test(
    'signed roots round-trip without converting inherited children to offers',
    () {
      final original = catalog({id(parent)});
      final decoded = SyncCatalog.fromJson(
        Map<String, dynamic>.from(original.toJson()),
      );
      expect(decoded.publicationRoots, {id(parent)});
      expect(decoded.entries.last.parent, parent);
      expect(decoded.offeredEntries.single.id.source, parent);
    },
  );
  test('complete scope is versioned and requires an explicit root set', () {
    final original = catalog({id(parent)}).toJson();
    final decoded = SyncCatalog.fromJson({
      ...original,
      'publicationScopeVersion': 2,
    });
    expect(decoded.completeSnapshot, isTrue);
    expect(decoded.toJson()['publicationScopeVersion'], 2);
    expect(
      () => SyncCatalog.fromJson(
        {
          ...original,
          'publicationScopeVersion': 2,
        }..remove('publicationRoots'),
      ),
      throwsFormatException,
    );
  });
  test('legacy catalog is not guessed from parent IDs', () {
    final legacy = SyncCatalog.fromJson(
      Map<String, dynamic>.from(catalog(null).toJson()),
    );
    expect(legacy.publicationRoots, isNull);
    expect(legacy.offeredEntries, isEmpty);
    expect(
      legacy.entries,
      hasLength(2),
      reason: 'Existing subscriptions retain their source data',
    );
  });
  test('unknown root schema, duplicate and missing roots fail closed', () {
    final original = catalog({id(parent)}).toJson();
    expect(
      () => SyncCatalog.fromJson({...original, 'publicationScopeVersion': 3}),
      throwsA(isA<SyncUpdateRequired>()),
    );
    expect(
      () => SyncCatalog.fromJson({
        ...original,
        'publicationRoots': [id(parent).toJson(), id(parent).toJson()],
      }),
      throwsFormatException,
    );
    expect(
      () => catalog({id('44444444-2222-4333-8444-555555555555')}),
      throwsFormatException,
    );
    expect(
      () => SyncCatalog.fromJson({...original, 'publicationRoots': 'all'}),
      throwsFormatException,
    );
  });
  test('scope metadata is part of the canonical signed content', () {
    expect(
      syncDigest(syncJsonBytes(catalog({id(parent)}).toJson())),
      isNot(
        syncDigest(syncJsonBytes(catalog({id(parent), id(child)}).toJson())),
      ),
    );
  });
}
