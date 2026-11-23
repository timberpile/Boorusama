import 'package:boorusama/core/backups/mitemite/catalog.dart';
import 'package:boorusama/core/backups/mitemite/protocol.dart';
import 'package:flutter_test/flutter_test.dart';

const publisher = '11111111-2222-4333-8444-555555555555';
const sourceA = '22222222-2222-4333-8444-555555555555';
const sourceB = '33333333-2222-4333-8444-555555555555';

void main() {
  SyncCatalogEntry entry(
    String source, {
    String? parent,
    String kind = 'bookmarks',
    SyncPublicationState state = SyncPublicationState.withdrawn,
  }) => SyncCatalogEntry(
    id: SyncCollectionId(
      publisher: publisher,
      kind: kind,
      source: source,
    ),
    name: 'Source',
    state: state,
    parent: parent,
    revision: state != SyncPublicationState.active
        ? null
        : SyncRevision(
            collection: SyncCollectionId(
              publisher: publisher,
              kind: kind,
              source: source,
            ),
            revision: 1,
            length: 1,
            sha256: syncDigest([1]),
            semanticHash: syncDigest([1]),
            schema: 10,
          ),
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
  test('duplicate sources and self parents are rejected', () {
    expect(
      () => catalog([entry(sourceA), entry(sourceA)]),
      throwsFormatException,
    );
    expect(() => entry(sourceA, parent: sourceA), throwsFormatException);
  });
  for (final kind in ['bookmarks', 'following_topics']) {
    test(
      '$kind validates active cycles without interpreting historical links as live edges',
      () {
        expect(
          () => catalog([
            entry(
              sourceA,
              kind: kind,
              parent: sourceB,
              state: SyncPublicationState.active,
            ),
            entry(
              sourceB,
              kind: kind,
              parent: sourceA,
              state: SyncPublicationState.active,
            ),
          ]),
          throwsFormatException,
        );
        for (final state in [
          SyncPublicationState.withdrawn,
          SyncPublicationState.deleted,
        ]) {
          final accepted = catalog([
            entry(
              sourceA,
              kind: kind,
              parent: sourceB,
              state: SyncPublicationState.active,
            ),
            entry(sourceB, kind: kind, parent: sourceA, state: state),
          ]);
          final decoded = SyncCatalog.fromJson(
            Map<String, dynamic>.from(accepted.toJson()),
          );
          expect(decoded.entries.last.parent, sourceA);
          expect(decoded.entries.last.state, state);
        }
        expect(
          catalog([
            entry(
              sourceA,
              kind: kind,
              parent: sourceB,
              state: SyncPublicationState.active,
            ),
          ]).entries.single.parent,
          sourceB,
        );
      },
    );
  }
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
