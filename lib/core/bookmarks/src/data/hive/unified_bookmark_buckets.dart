part of 'unified_bookmark_repository.dart';

String _bucketIndexKey(String group) => 'bookmarkMirrorBucketIndex.$group';
String _bucketRowKey(String group, int bucket) =>
    'bookmarkMirrorMembership.$group.$bucket';

extension BookmarkMirrorBucketMemberships on BookmarkHiveRepository {
  BookmarkGroup _asOrganizationGroup(BookmarkGroupHiveObject row) =>
      _organizationGroupSnapshots[row] ??= BookmarkGroup(
        id: row.id,
        name: row.name,
        bookmarkIds: row.bookmarkIds.toSet(),
        parentGroupId: row.parentGroupId,
        folderId: row.folderId,
        position: row.position,
        addedAt: {
          for (final entry in (row.addedAt ?? const <int, String>{}).entries)
            entry.key: DateTime.parse(entry.value),
        },
      );

  BookmarkGroupHiveObject _logicalOrganizationRow(BookmarkGroupHiveObject row) {
    if (_readMirrorBucketIndex(row.id).isEmpty) return row;
    final group = groupWithMirroredBuckets(_asOrganizationGroup(row));
    return BookmarkGroupHiveObject(
      id: row.id,
      name: row.name,
      parentGroupId: row.parentGroupId,
      folderId: row.folderId,
      position: row.position,
      bookmarkIds: group.bookmarkIds.toList()..sort(),
      addedAt: {
        for (final entry in group.addedAt.entries)
          entry.key: entry.value.toUtc().toIso8601String(),
      },
    );
  }

  BookmarkGroup _applyingMembershipBuckets(BookmarkGroup base, Object? patch) =>
      patch == null
      ? base
      : _withMembershipEdits(
          base,
          contentMap(patch).values.map(contentMap),
        );

  /// Materialize group membership only when a normal library reader asks for
  /// the effective Group. The Hive Group is the base and the indexed keys join
  /// the same recoverable mutation as the current mirror head.
  BookmarkGroup groupWithMirroredBuckets(BookmarkGroup base) {
    final index = _readMirrorBucketIndex(base.id);
    if (index.isEmpty) return base;
    if (_bucketGroupSnapshots[base.id] case (final previous, final snapshot)
        when identical(previous, base)) {
      return snapshot;
    }
    final result = _withMembershipEdits(base, [
      for (final bucket in index)
        contentMap(_metadata.get(_bucketRowKey(base.id, bucket))),
    ]);
    _bucketGroupSnapshots[base.id] = (base, result);
    return result;
  }

  List<int> _readMirrorBucketIndex(String group) {
    final raw = _metadata.get(_bucketIndexKey(group));
    if (raw == null) return const [];
    if (raw is! List ||
        raw.toSet().length != raw.length ||
        raw.any((index) => index is! int || index < 0 || index >= 256)) {
      throw const FormatException('Invalid received Bookmark membership index');
    }
    return raw.cast<int>();
  }

  BookmarkGroup _withMembershipEdits(
    BookmarkGroup base,
    Iterable<Map<String, Object?>> operations,
  ) {
    final ids = base.bookmarkIds.toSet();
    final dates = Map<int, DateTime>.of(base.addedAt);
    for (final entries in operations) {
      for (final entry in entries.entries) {
        final id = _localId(int.parse(entry.key));
        if (entry.value == null) {
          ids.remove(id);
          dates.remove(id);
        } else {
          final date = DateTime.parse(contentString(entry.value)).toUtc();
          ids.add(id);
          dates[id] = date;
        }
      }
    }
    return base.copyWith(bookmarkIds: ids, addedAt: dates);
  }

  Map<String, Object?> _serializeBucketEdits(
    Map<String, BookmarkMirrorMembershipPatch> patches,
  ) => {
    for (final group in patches.entries)
      group.key: {
        for (final bucket in group.value.buckets.entries)
          '${bucket.key}': {
            for (final edge in bucket.value.entries)
              '${edge.key}': edge.value?.toUtc().toIso8601String(),
          },
      },
  };

  Future<Map<String, Object?>> _prepareBucketMetadataWrites({
    required Map<String, Object?> patches,
    required Set<String> replacedGroups,
    required BookmarkMirrorState? nextMirrors,
    required Set<int> upserts,
    required Set<int> deletedIds,
  }) async {
    if (patches.isEmpty && replacedGroups.isEmpty) return const {};
    final (box, _) = await _organizationBoxes();
    final writes = <String, Object?>{};
    for (final group in replacedGroups) {
      final existing = _readMirrorBucketIndex(group);
      if (existing.isEmpty) continue;
      writes[_bucketIndexKey(group)] = <int>[];
      for (final bucket in existing) {
        writes[_bucketRowKey(group, bucket)] = const <String, Object?>{};
      }
      _bucketGroupSnapshots.remove(group);
    }
    for (final change in patches.entries) {
      final group = change.key;
      final base = box.get(group);
      if (base == null ||
          nextMirrors?.owners[group]?.bookmarkBucketManifest == null ||
          replacedGroups.contains(group)) {
        throw const FormatException(
          'Invalid received Bookmark membership change',
        );
      }
      final previous = _readMirrorBucketIndex(group).toSet();
      final indexed = previous.toSet();
      final seen = <int>{};
      for (final patch in contentMap(change.value).entries) {
        final bucket = int.tryParse(patch.key);
        if (bucket == null ||
            bucket < 0 ||
            bucket >= 256 ||
            '$bucket' != patch.key) {
          throw const FormatException(
            'Invalid received Bookmark membership bucket',
          );
        }
        final key = _bucketRowKey(group, bucket);
        final effective = previous.contains(bucket)
            ? contentMap(_metadata.get(key))
            : <String, Object?>{};
        for (final edge in contentMap(patch.value).entries) {
          final id = _localId(int.parse(edge.key));
          if (!seen.add(id)) {
            throw const FormatException('Duplicate received membership edit');
          }
          final date = edge.value;
          if (date != null) {
            final encoded = DateTime.parse(contentString(date))
                .toUtc()
                .toIso8601String();
            final header = _storedHeader(id);
            if (encoded != date ||
                deletedIds.contains(id) ||
                (!upserts.contains(id) &&
                    (header == null || header['kind'] == 'deleted'))) {
              throw const FormatException(
                'Invalid received Bookmark membership date',
              );
            }
          }
          if (base.addedAt?[id] == date) {
            effective.remove(edge.key);
          } else {
            effective[edge.key] = date;
          }
        }
        writes[key] = effective;
        if (effective.isEmpty) {
          indexed.remove(bucket);
        } else {
          indexed.add(bucket);
        }
      }
      writes[_bucketIndexKey(group)] = indexed.toList()..sort();
      _bucketGroupSnapshots.remove(group);
    }
    return writes;
  }
}
