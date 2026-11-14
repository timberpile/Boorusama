import 'package:boorusama/core/backups/folder_sync/catalog.dart';
import 'package:boorusama/core/backups/folder_sync/protocol.dart';
import 'package:flutter_test/flutter_test.dart';

const publisher = '11111111-2222-4333-8444-555555555555';
const sourceA = '22222222-2222-4333-8444-555555555555';
const sourceB = '33333333-2222-4333-8444-555555555555';

void main() {
  SyncCatalogEntry entry(String source, {String? parent}) => SyncCatalogEntry(
    id: SyncCollectionId(
      publisher: publisher,
      kind: 'bookmarks',
      source: source,
    ),
    name: 'Source',
    state: SyncPublicationState.withdrawn,
    parent: parent,
  );
  SyncCatalog catalog(List<SyncCatalogEntry> entries) => SyncCatalog(
    publisher: publisher,
    sequence: 1,
    name: 'Publisher',
    entries: entries,
  );

  test(
    'typed catalog round-trips explicit state without inventing deletion',
    () {
      final value = catalog([entry(sourceA)]);
      final decoded = SyncCatalog.fromJson(
        Map<String, dynamic>.from(value.toJson()),
      );
      expect(decoded.entries.single.state, SyncPublicationState.withdrawn);
      expect(decoded.entries.single.revision, isNull);
      expect(catalog([]).entries, isEmpty);
    },
  );
  test('duplicate sources, self parents and hierarchy cycles are rejected', () {
    expect(
      () => catalog([entry(sourceA), entry(sourceA)]),
      throwsFormatException,
    );
    expect(() => entry(sourceA, parent: sourceA), throwsFormatException);
    expect(
      () => catalog([
        entry(sourceA, parent: sourceB),
        entry(sourceB, parent: sourceA),
      ]),
      throwsFormatException,
    );
  });
  test('an active entry requires a complete bound revision', () {
    expect(
      () => SyncCatalogEntry(
        id: entry(sourceA).id,
        name: 'Source',
        state: SyncPublicationState.active,
      ),
      throwsFormatException,
    );
    final foreign = SyncRevision(
      collection: entry(sourceB).id,
      revision: 1,
      length: 1,
      sha256: syncDigest([1]),
      semanticHash: syncDigest([1]),
      schema: 10,
    );
    expect(
      () => SyncCatalogEntry(
        id: entry(sourceA).id,
        name: 'Source',
        state: SyncPublicationState.active,
        revision: foreign,
      ),
      throwsFormatException,
    );
  });
  test('unknown states cannot be treated as empty or withdrawn', () {
    final raw = Map<String, dynamic>.from(entry(sourceA).toJson())
      ..['state'] = 'future';
    expect(
      () => SyncCatalogEntry.fromJson(raw, publisher),
      throwsA(isA<SyncUpdateRequired>()),
    );
  });
}
