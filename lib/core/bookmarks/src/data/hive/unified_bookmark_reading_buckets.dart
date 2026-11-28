part of 'unified_bookmark_repository.dart';

const _readingFields = ['members', 'read', 'arrivals'];
const _readingChunkRefs = 'privateReadingBuckets';
const _readingChunkPrefix = 'bookmarkMirrorReadingBucket.';
final _readingChunkKey = RegExp(r'^bookmarkMirrorReadingBucket\.[0-9a-f]{64}$');

extension BookmarkReadBucketStorage on BookmarkHiveRepository {
  /// Keep the large lists out of the owner head. Unchanged read rows are not
  /// rewritten, and changed rows commit with the existing membership journal.
  ({Map<String, Object?> wire, Map<String, Object?> rows, List<String> retired})
  _partitionMirrorReading(
    BookmarkMirrorState before,
    BookmarkMirrorState next,
  ) {
    final rawBefore = contentMap(
      _metadata.get(BookmarkHiveRepository._mirrorStateKey),
    );
    final previous = {
      for (final row in _storedMirrorOwners(rawBefore))
        '${row['publisher']}/${row['source']}': contentMap(row['reading']),
    };
    final rows = <String, Object?>{};
    Map<String, Object?> encode(BookmarkMirrorOwner owner) {
      final archived = before.checkpoints[owner.sourceKey];
      final stored = previous[owner.sourceKey];
      if (stored != null &&
          archived != null &&
          owner.hasSameReading(archived) &&
          stored.containsKey(_readingChunkRefs)) {
        return owner.toJson(storedReading: stored);
      }
      final read = owner.reading;
      final manifest = owner.bookmarkBucketManifest;
      if (manifest == null || read.isEmpty) {
        return owner.toJson(storedReading: read);
      }
      final count = contentMap(jsonDecode(manifest))['bucketCount'];
      final partitions = count is int && const {1, 16, 64, 256}.contains(count)
          ? count
          : 1;
      final partition = <int, Map<String, List<String>>>{};
      for (final field in _readingFields) {
        for (final value in (read.remove(field)! as List).cast<String>()) {
          final bucket =
              (sha256.convert(utf8.encode(value)).bytes.first * partitions) >>
              8;
          final lists = partition.putIfAbsent(bucket, () => {});
          (lists[field] ??= []).add(value);
        }
      }
      read[_readingChunkRefs] = {
        for (final bucket in partition.keys.toList()..sort())
          '$bucket': _keepReadingBucket(partition[bucket]!, rows),
      };
      return owner.toJson(storedReading: read);
    }

    final wire = next.toJson(compact: true, encodeOwner: encode);
    return (
      wire: wire,
      rows: rows,
      retired: _mirrorReadingPaths(
        rawBefore,
      ).difference(_mirrorReadingPaths(wire)).toList()..sort(),
    );
  }

  String _keepReadingBucket(
    Map<String, List<String>> values,
    Map<String, Object?> rows,
  ) {
    final content = {
      for (final field in _readingFields)
        field: values[field] ?? const <String>[],
    };
    final key = '$_readingChunkPrefix${BookmarkHiveRepository._hash(content)}';
    if (!_metadata.containsKey(key)) rows[key] = content;
    return key;
  }

  Iterable<Map<String, Object?>> _storedMirrorOwners(
    Map<String, Object?> state,
  ) sync* {
    yield* contentMap(state['owners']).values.map(contentMap);
    yield* contentMap(state['checkpoints'] ?? const <String, Object?>{}).values
        .map(contentMap);
  }

  Set<String> _mirrorReadingPaths(Map<String, Object?> state) => {
    for (final owner in _storedMirrorOwners(state))
      for (final reference in _readingReferences(
        contentMap(owner['reading']),
      ).values)
        reference,
  };

  Map<String, String> _readingReferences(Map<String, Object?> reading) {
    final refs = reading[_readingChunkRefs];
    if (refs == null) return const {};
    final parts = contentMap(refs).cast<String, String>();
    if (parts.length > 256 ||
        parts.entries.any((entry) {
          final index = int.tryParse(entry.key);
          return index == null ||
              index < 0 ||
              index >= 256 ||
              '$index' != entry.key ||
              !_readingChunkKey.hasMatch(entry.value);
        })) {
      throw const FormatException('Invalid Bookmark reading index');
    }
    return parts;
  }

  BookmarkMirrorState _restoreMirrorReading(
    Object? raw, {
    Map<String, Object?> stagedRows = const {},
  }) {
    final state = contentMap(raw);
    final decoded = <String, Map<String, Object?>>{};
    for (final section in ['owners', 'checkpoints']) {
      final owners = contentMap(state[section] ?? const {});
      decoded[section] = {
        for (final entry in owners.entries)
          entry.key: _restoreOwnerReading(contentMap(entry.value), stagedRows),
      };
    }
    return BookmarkMirrorState.fromJson({...state, ...decoded});
  }

  Map<String, Object?> _restoreOwnerReading(
    Map<String, Object?> owner,
    Map<String, Object?> stagedRows,
  ) {
    final reading = contentMap(owner['reading']);
    if (!reading.containsKey(_readingChunkRefs)) return owner;
    final collected = {for (final field in _readingFields) field: <String>[]};
    for (final key in _readingReferences(reading).values) {
      final row = contentMap(stagedRows[key] ?? _metadata.get(key));
      if (key != '$_readingChunkPrefix${BookmarkHiveRepository._hash(row)}') {
        throw const FormatException('Invalid Bookmark reading bucket contents');
      }
      for (final field in _readingFields) {
        collected[field]!.addAll((row[field]! as List).cast<String>());
      }
    }
    reading.remove(_readingChunkRefs);
    return {
      ...owner,
      'reading': {
        ...reading,
        for (final field in _readingFields) field: collected[field]!..sort(),
      },
    };
  }
}
