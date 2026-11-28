part of 'unified_bookmark_repository.dart';

const _bookmarkPublicationHistory = 4096;
const _bookmarkPublicationGeneration = 'bookmarkPublicationGeneration';

final class BookmarkPublicationChanges {
  const BookmarkPublicationChanges(this.records, this.memberships);

  final Set<int> records;
  final Map<String, Map<int, String?>> memberships;
}

extension BookmarkPublicationJournal on BookmarkHiveRepository {
  String? get bookmarkPublicationIndexPath =>
      _metadata.path == null ? null : '${_metadata.path}.publication.sqlite';

  Future<Map<int, ({int engine, ContentIdentity identity})>>
  readPublicationMemberKeys(
    Iterable<int> ids,
  ) => _ready(() async {
    final keys = <int, ({int engine, ContentIdentity identity})>{};
    final work = CooperativeWork();
    for (final id in ids) {
      final header = _storedHeader(id);
      if (header == null || header['kind'] == 'deleted') {
        throw const FormatException('Published Bookmark membership is missing');
      }
      final identity = BookmarkHiveRepository._identity(header);
      if (identity == null) {
        throw const FormatException(
          'Unaddressable content cannot be synchronized',
        );
      }
      keys[id] = (engine: header['engine']! as int, identity: identity);
      if (work.checkpoint() case final pause?) await pause;
    }
    return keys;
  });

  Future<
    ({
      String generation,
      int revision,
      List<BookmarkPublicationChanges>? changes,
    })
  >
  bookmarkPublicationChanges(String? generation, int? previous) =>
      _ready(() async {
        final revision = _metadata.get(BookmarkHiveRepository._revision) as int;
        var active = _metadata.get(_bookmarkPublicationGeneration) as String?;
        if (active == null) {
          active = const Uuid().v4();
          await _metadata.put(_bookmarkPublicationGeneration, active);
          await _sync([_metadata]);
        }
        if (generation != active ||
            previous == null ||
            previous > revision ||
            revision - previous > _bookmarkPublicationHistory) {
          return (generation: active, revision: revision, changes: null);
        }
        final changes = <BookmarkPublicationChanges>[];
        for (var cursor = previous + 1; cursor <= revision; cursor++) {
          final receipt = _metadata.get('bookmarkPublicationChange.$cursor');
          if (receipt is! Map || receipt['rebuild'] == true) {
            return (generation: active, revision: revision, changes: null);
          }
          changes.add(
            BookmarkPublicationChanges(
              (receipt['records'] as List).cast<int>().toSet(),
              {
                for (final entry in contentMap(receipt['memberships']).entries)
                  entry.key: {
                    for (final change in contentMap(entry.value).entries)
                      int.parse(change.key): change.value as String?,
                  },
              },
            ),
          );
        }
        return (generation: active, revision: revision, changes: changes);
      });

  Future<List<BookmarkGroup>> readLocalPublicationDefinitions() =>
      _ready(() async {
        final (groups, _) = await _organizationBoxes();
        final ownerIds = contentMap(
          contentMap(
            _metadata.get(BookmarkHiveRepository._mirrorStateKey),
          )['owners'],
        );
        return [
          for (final row in groups.values)
            if (!ownerIds.containsKey(row.id))
              BookmarkGroup(
                id: row.id,
                name: row.name,
                bookmarkIds: const {},
                parentGroupId: row.parentGroupId,
                position: row.position,
              ),
        ];
      });

  Map<String, Object?>? _bookmarkPublicationReceipt(
    Map<String, Object?> plan,
    BookmarkMirrorState? mirrors,
  ) {
    if (!_metadata.containsKey(_bookmarkPublicationGeneration)) return null;
    final records = contentMap(plan['previous']).keys.map(int.parse).toList();
    final memberships = <String, Map<String, Object?>>{};
    if (plan['organization'] case final org?) {
      final organization = contentMap(org);
      final oldGroups = contentMap(organization['previous']);
      final nextGroups = contentMap(organization['groups']);
      for (final group in {...oldGroups.keys, ...nextGroups.keys}) {
        if (mirrors?.isReceived(group) ?? false) continue;
        Map<String, Object?> dates(Object? group) =>
            group == null ? const {} : contentMap(contentMap(group)['addedAt']);
        final before = dates(oldGroups[group]);
        final after = dates(nextGroups[group]);
        final change = <String, Object?>{
          for (final id in {...before.keys, ...after.keys})
            if (before[id] != after[id]) id: after[id],
        };
        if (change.isNotEmpty) memberships[group] = change;
      }
    }
    if (records.length +
            memberships.values.fold<int>(0, (n, group) => n + group.length) >
        32768) {
      return const {'rebuild': true};
    }
    return {'records': records, 'memberships': memberships};
  }
}

/// Organization writes use the same journal and coordinator as payload writes.
/// This is a storage implementation detail, not a second membership authority.
extension BookmarkOrganizationWrites on BookmarkHiveRepository {
  /// Apply the prevalidated hierarchy under the enclosing package journal.
  /// A normal Hive mutation journal serializes both sides of each group. Here
  /// its rollback authority is the verified package preimage on disk.
  Future<void> writeTransferOrganization({
    required List<BookmarkGroup> definitions,
    required Set<String> changed,
    required Iterable<(int, String)> Function(String groupId) members,
    void Function(int)? onMembersPrepared,
    void Function()? onWritingGroup,
  }) => _ready(() async {
    final graph = BookmarkGroupTree(definitions);
    if (!graph.groupsById.containsKey(defaultBookmarkGroupId)) {
      throw const FormatException('Imported hierarchy is missing Default');
    }
    final (box, folderBox) = await _organizationBoxes();
    final removed = box.keys.cast<String>().toSet().difference(
      graph.groupsById.keys.toSet(),
    );
    final mirrors = _mirrors();
    if (mirrors.owners.keys.any(
          (id) => changed.contains(id) || removed.contains(id),
        ) ||
        definitions.any(
          (g) =>
              changed.contains(g.id) &&
              mirrors.isReceived(g.parentGroupId ?? ''),
        )) {
      throw const BookmarkMirrorReadOnly();
    }
    if (changed.isEmpty && removed.isEmpty) return;
    validateBookmarkCommitGuard();
    final work = CooperativeWork();
    var prepared = 0;
    for (final group in definitions) {
      if (!changed.contains(group.id)) continue;
      onMembersPrepared?.call(prepared);
      final ids = <int>[];
      final dates = <int, String>{};
      for (final (id, date) in members(group.id)) {
        final header = _storedHeader(id);
        if (header == null ||
            header['kind'] == 'deleted' ||
            (ids.isNotEmpty && ids.last >= id)) {
          throw const FormatException('Invalid imported group membership');
        }
        ids.add(id);
        dates[id] = date;
        onMembersPrepared?.call(++prepared);
        if (work.checkpoint() case final pause?) await pause;
      }
      onWritingGroup?.call();
      if (ids.length >= 2048) await work.yieldToEvents();
      await performanceRecorder.measureAsync(
        PerfOperation.bookmarkTransferGroupWrite,
        () => box.put(
          group.id,
          BookmarkGroupHiveObject.fromTransfer(
            id: group.id,
            name: group.name,
            bookmarkIds: ids,
            addedAt: dates,
            parentGroupId: group.parentGroupId,
            position: group.position,
          ),
        ),
      );
    }
    if (removed.isNotEmpty) await box.deleteAll(removed);
    await _sync([box, folderBox]);
    const key = BookmarkHiveRepository._revision;
    final revision = (_metadata.get(key) as int) + 1;
    await _metadata.put(key, revision);
    await _sync([_metadata]);
  });

  Future<T> runOrganizationOperation<T>(Future<T> Function() operation) =>
      _ready(() async {
        await _organizationBoxes();
        return operation();
      });

  Future<(Box<BookmarkGroupHiveObject>, Box<dynamic>)>
  _organizationBoxes() async {
    final active = contentMap(_metadata.get('activeOrganization'));
    final generation = contentMap(active['generation']);
    final groupName = contentString(generation['groups']);
    final folderName = contentString(generation['organization']);
    const suffix = BookmarkStorageMigration.generationSuffix;
    if (active['version'] != BookmarkStorageMigration.schemaVersion ||
        active['hierarchyPlanHash'] is! String ||
        groupName == folderName ||
        !groupName.endsWith(suffix) ||
        !folderName.endsWith(suffix)) {
      throw const FormatException('Unified Bookmark organization unavailable');
    }
    final cached = _organizationHandles;
    if (cached != null &&
        cached.$1.isOpen &&
        cached.$2.isOpen &&
        cached.$1.name == groupName &&
        cached.$2.name == folderName) {
      return cached;
    }
    if (!await Hive.boxExists(groupName) || !await Hive.boxExists(folderName)) {
      throw const FormatException('Active Bookmark organization is missing');
    }
    return _organizationHandles = (
      await Hive.openBox<BookmarkGroupHiveObject>(groupName),
      await Hive.openBox<dynamic>(folderName),
    );
  }

  static Map<String, Object?> _groupWire(BookmarkGroupHiveObject row) => {
    'id': row.id,
    'name': row.name,
    'bookmarkIds': row.bookmarkIds.toList()..sort(),
    'addedAt': {
      for (final entry in (row.addedAt ?? const {}).entries)
        '${entry.key}': entry.value,
    },
    'folderId': row.folderId,
    if (row.parentGroupId != null) 'parentGroupId': row.parentGroupId,
    'position': row.position,
  };

  static BookmarkGroupHiveObject _groupRow(Object? value) {
    final map = contentMap(value);
    final id = contentString(map['id']);
    final name = contentString(map['name']);
    final rawIds = map['bookmarkIds'];
    final position = map['position'];
    if (!Uuid.isValidUUID(fromString: id) ||
        id != id.toLowerCase() ||
        name != name.trim() ||
        rawIds is! List ||
        position is! int ||
        position < 0 ||
        (map['folderId'] != null && map['folderId'] is! String) ||
        (map['parentGroupId'] != null && map['parentGroupId'] is! String)) {
      throw const FormatException('Invalid unified Bookmark Group');
    }
    final ids = <int>{};
    for (final raw in rawIds) {
      if (raw is! int || raw < 0 || raw > maxBookmarkId || !ids.add(raw)) {
        throw const FormatException('Invalid Group member ID');
      }
    }
    final dates = contentMap(map['addedAt']);
    final parsed = <int, String>{};
    for (final entry in dates.entries) {
      final member = int.tryParse(entry.key);
      final date = DateTime.parse(contentString(entry.value)).toUtc();
      if (member == null ||
          !ids.contains(member) ||
          parsed.containsKey(member)) {
        throw const FormatException('Invalid Group membership date');
      }
      parsed[member] = date.toIso8601String();
    }
    if (parsed.length != ids.length ||
        (id == defaultBookmarkGroupId &&
            (name != 'Default' ||
                map['folderId'] != null ||
                map['parentGroupId'] != null))) {
      throw const FormatException('Invalid Group membership authority');
    }
    return BookmarkGroupHiveObject(
      id: id,
      name: name,
      bookmarkIds: ids.toList()..sort(),
      addedAt: parsed,
      folderId: map['folderId'] as String?,
      parentGroupId: map['parentGroupId'] as String?,
      position: position,
    );
  }

  Future<Map<String, Object?>?> _prepareOrganization({
    required List<BookmarkGroup> groups,
    required Set<String> removeGroups,
    required List<CollectionFolder>? folders,
    required Set<int> recordIds,
    required Set<int> removedRecordIds,
    Map<String, Object?> bucketEdits = const {},
  }) async {
    final detachDeleted =
        removedRecordIds.isNotEmpty &&
        _metadata.get('activeOrganization') != null;
    if (groups.isEmpty &&
        removeGroups.isEmpty &&
        folders == null &&
        !detachDeleted) {
      return null;
    }
    final (groupBox, folderBox) = await _organizationBoxes();
    final updates = <String, Map<String, Object?>>{};
    final previous = <String, Object?>{};
    for (final group in groups) {
      if (updates.containsKey(group.id) || removeGroups.contains(group.id)) {
        throw const FormatException('Duplicate organization mutation');
      }
      final wire = _groupWire(
        BookmarkGroupHiveObject(
          id: group.id,
          name: group.name,
          bookmarkIds: group.bookmarkIds.toList(),
          addedAt: {
            for (final entry in group.addedAt.entries)
              entry.key: entry.value.toUtc().toIso8601String(),
          },
          folderId: group.folderId,
          parentGroupId: group.parentGroupId,
          position: group.position,
        ),
      );
      updates[group.id] = _groupWire(_groupRow(wire));
    }
    if (detachDeleted) {
      // The facade's direct delete API must leave a restartable generation too.
      // Preserve caller-supplied changes; other affected memberships and dates
      // join this same journal, rather than relying on a later library repair.
      for (final stored in groupBox.values) {
        if (updates.containsKey(stored.id) ||
            removeGroups.contains(stored.id) ||
            bucketEdits.containsKey(stored.id)) {
          continue;
        }
        final row = _logicalOrganizationRow(stored);
        if (!row.bookmarkIds.any(removedRecordIds.contains)) {
          continue;
        }
        final wire = _groupWire(row);
        wire['bookmarkIds'] = [
          for (final id in row.bookmarkIds)
            if (!removedRecordIds.contains(id)) id,
        ];
        wire['addedAt'] = contentMap(wire['addedAt'])
          ..removeWhere((id, _) => removedRecordIds.contains(int.tryParse(id)));
        updates[row.id] = _groupWire(_groupRow(wire));
      }
    }
    if (updates.isEmpty && removeGroups.isEmpty && folders == null) return null;
    for (final id in {...updates.keys, ...removeGroups}) {
      if (!Uuid.isValidUUID(fromString: id) ||
          id != id.toLowerCase() ||
          (id == defaultBookmarkGroupId && removeGroups.contains(id))) {
        throw const FormatException('Invalid organization deletion');
      }
      final row = groupBox.get(id);
      previous[id] = row == null
          ? null
          : _groupWire(_logicalOrganizationRow(row));
    }
    final desiredFolders = folders?.map((folder) => folder.toJson()).toList();
    final plan = <String, Object?>{
      'generation': contentMap(
        contentMap(_metadata.get('activeOrganization'))['generation'],
      ),
      'groups': updates,
      'deletes': removeGroups.toList()..sort(),
      'previous': previous,
      if (folders != null) ...{
        'folders': desiredFolders,
        'previousFolders': folderBox.get('folders') ?? const [],
      },
    };
    await _validateOrganization(
      plan,
      recordIds,
      removedRecordIds,
      bucketEdits: bucketEdits,
    );
    return plan;
  }

  Future<void> _validateOrganization(
    Map<String, Object?> plan,
    Set<int> recordIds,
    Set<int> removedIds, {
    Map<String, Object?> bucketEdits = const {},
  }) async {
    final (groupBox, folderBox) = await _organizationBoxes();
    if (!BookmarkHiveRepository._same(
      plan['generation'],
      contentMap(_metadata.get('activeOrganization'))['generation'],
    )) {
      throw const FormatException('Organization generation changed');
    }
    final updates = contentMap(plan['groups']);
    final previous = contentMap(plan['previous']);
    final deletes = plan['deletes'];
    if (deletes is! List ||
        deletes.any((id) => id is! String) ||
        deletes.toSet().length != deletes.length ||
        updates.keys.any(deletes.contains) ||
        !const SetEquality<String>().equals(previous.keys.toSet(), {
          ...updates.keys,
          ...deletes.cast<String>(),
        })) {
      throw const FormatException('Invalid organization journal');
    }
    final rows = <String, BookmarkGroupHiveObject>{};
    for (final entry in updates.entries) {
      final row = _groupRow(entry.value);
      if (row.id != entry.key) throw const FormatException('Group ID mismatch');
      rows[row.id] = row;
    }
    for (final id in {...updates.keys, ...deletes.cast<String>()}) {
      if (!Uuid.isValidUUID(fromString: id) ||
          id != id.toLowerCase() ||
          (id == defaultBookmarkGroupId && deletes.contains(id))) {
        throw const FormatException('Invalid Group journal deletion');
      }
      final current = groupBox.get(id);
      final actual = current == null
          ? null
          : _groupWire(_logicalOrganizationRow(current));
      final desired = updates[id];
      if (!BookmarkHiveRepository._same(actual, previous[id]) &&
          !BookmarkHiveRepository._same(actual, desired) &&
          !(current != null &&
              _readMirrorBucketIndex(id).isNotEmpty &&
              BookmarkHiveRepository._same(_groupWire(current), desired))) {
        throw const FormatException('Group changed after preparation');
      }
    }
    final rawFolders = plan.containsKey('folders')
        ? plan['folders']
        : (folderBox.get('folders') ?? const []);
    if (rawFolders is! List) {
      throw const FormatException('Invalid folder journal');
    }
    final folders = rawFolders
        .map((raw) => CollectionFolder.fromJson(contentMap(raw)))
        .toList();
    final next = <String, BookmarkGroupHiveObject>{
      for (final row in groupBox.values)
        if (!deletes.contains(row.id)) row.id: row,
      ...rows,
    };
    if (folders.isNotEmpty || next.values.any((row) => row.folderId != null)) {
      throw const FormatException(
        'Legacy folders cannot mutate active hierarchy',
      );
    }
    BookmarkGroupTree([
      for (final row in next.values)
        BookmarkGroup(
          id: row.id,
          name: row.name,
          bookmarkIds: const {},
          parentGroupId: row.parentGroupId,
          position: row.position,
        ),
    ]);
    for (final row in removedIds.isEmpty ? rows.values : next.values) {
      final ids = rows.containsKey(row.id)
          ? row.bookmarkIds
          : _applyingMembershipBuckets(
              groupWithMirroredBuckets(_asOrganizationGroup(row)),
              bucketEdits[row.id],
            ).bookmarkIds;
      for (final id in ids) {
        final header = _storedHeader(id);
        if (removedIds.contains(id) ||
            (!recordIds.contains(id) &&
                (header == null || header['kind'] == 'deleted'))) {
          throw const FormatException(
            'Organization references an absent Bookmark',
          );
        }
      }
    }
    if (plan.containsKey('folders')) {
      final actual = folderBox.get('folders') ?? const [];
      if (!BookmarkHiveRepository._same(actual, plan['previousFolders']) &&
          !BookmarkHiveRepository._same(actual, plan['folders'])) {
        throw const FormatException('Folders changed after preparation');
      }
    }
  }

  Future<void> _guardMirrorMutation(
    Map<String, Object?>? organization,
    Set<int> removedIds,
    BookmarkMirrorState? received,
    Stream<Bookmark> upserts, {
    required bool hasUpserts,
    bool localCopy = false,
    Set<String> purgedSources = const {},
    CooperativeWork? work,
    Map<String, Object?> bucketEdits = const {},
  }) async {
    final before = _mirrors();
    if (before.owners.isEmpty && received == null) return;
    final (box, _) = await _organizationBoxes();
    String digest(BookmarkGroup value) =>
        _receivedGroupDigests[value] ??= bookmarkMirrorGroupDigest(value);
    final current = {
      for (final row in box.values)
        row.id: groupWithMirroredBuckets(_asOrganizationGroup(row)),
    };
    final updates = organization == null
        ? const <String, Object?>{}
        : contentMap(organization['groups']);
    final removed = organization == null
        ? const <String>{}
        : (organization['deletes']! as List).cast<String>().toSet();
    final desired = {
      for (final entry in current.entries)
        if (!removed.contains(entry.key))
          entry.key: _applyingMembershipBuckets(
            entry.value,
            bucketEdits[entry.key],
          ),
      for (final entry in updates.entries)
        entry.key: _asOrganizationGroup(_groupRow(entry.value)),
    };
    if (received == null) {
      await for (final record in upserts) {
        final memberships = current.values.where(
          (group) => group.bookmarkIds.contains(record.id),
        );
        if (memberships.any((group) => before.isReceived(group.id)) &&
            !memberships.any((group) => !before.isReceived(group.id))) {
          final previous = _read(record.id);
          if (previous == null ||
              !BookmarkHiveRepository._same(
                _codec.encode(previous),
                _codec.encode(record),
              )) {
            throw const BookmarkMirrorReadOnly();
          }
        }
      }
      for (final id in before.owners.keys) {
        final old = current[id];
        if (removed.contains(id) ||
            (old?.bookmarkIds.any(removedIds.contains) ?? false) ||
            (updates.containsKey(id) &&
                (old == null || digest(old) != digest(desired[id]!)))) {
          throw const BookmarkMirrorReadOnly();
        }
      }
      for (final id in updates.keys) {
        if (!before.isReceived(id) &&
            before.isReceived(desired[id]!.parentGroupId ?? '')) {
          throw const BookmarkMirrorReadOnly();
        }
      }
      return;
    }
    if (localCopy) {
      final original = before.toJson()
        ..remove('epoch')
        ..remove('activity');
      final next = received.toJson()
        ..remove('epoch')
        ..remove('activity');
      if (!BookmarkHiveRepository._same(original, next) ||
          hasUpserts ||
          removedIds.isNotEmpty ||
          removed.isNotEmpty ||
          updates.isEmpty ||
          updates.keys.any(current.containsKey) ||
          updates.keys.any(
            (id) =>
                desired[id]!.parentGroupId != null &&
                !updates.containsKey(desired[id]!.parentGroupId),
          )) {
        throw const FormatException(
          'Local Copy requires fresh Local Groups and unchanged source authority',
        );
      }
    }
    for (final entry in before.checkpoints.entries) {
      final next = received.checkpoints[entry.key];
      if (next == null && purgedSources.contains(entry.key)) continue;
      if (next == null ||
          next.revision < entry.value.revision ||
          (entry.value.retired &&
              !next.retired &&
              next.revision <= entry.value.revision) ||
          (next.revision == entry.value.revision &&
              (next.payloadDigest != entry.value.payloadDigest ||
                  (entry.value.descriptorDigest != null &&
                      next.descriptorDigest !=
                          entry.value.descriptorDigest)))) {
        throw const FormatException('Source revision history cannot roll back');
      }
    }
    await for (final record in upserts) {
      if (work?.checkpoint() case final pause?) await pause;
      final previous = _read(record.id);
      if (previous != null &&
          current.values.any(
            (group) =>
                !before.isReceived(group.id) &&
                group.bookmarkIds.contains(record.id),
          ) &&
          !BookmarkHiveRepository._same(
            _codec.encode(previous),
            _codec.encode(record),
          )) {
        throw const FormatException(
          'Received transaction cannot rewrite local content',
        );
      }
    }
    for (final id in {...updates.keys, ...removed, ...bucketEdits.keys}) {
      if (!before.isReceived(id) &&
          !received.isReceived(id) &&
          !(localCopy && !current.containsKey(id))) {
        throw const FormatException(
          'Received transaction cannot edit a local Group',
        );
      }
    }
    if (bucketEdits.isNotEmpty &&
        desired.values.any(
          (group) => removedIds.any(group.bookmarkIds.contains),
        )) {
      throw const FormatException('Removed Bookmark still has a membership');
    }
    for (final entry in before.owners.entries) {
      final next = received.owners[entry.key];
      if (next == null && !removed.contains(entry.key)) {
        throw const FormatException(
          'Mirror ownership cannot be detached from a retained Group',
        );
      }
      if (next != null && next.sourceKey != entry.value.sourceKey) {
        throw const FormatException(
          'Mirror source identity cannot be replaced',
        );
      }
      final old = current[entry.key];
      if ((updates.containsKey(entry.key) ||
              removed.contains(entry.key) ||
              next != entry.value) &&
          (old == null || digest(old) != entry.value.groupDigest)) {
        throw StateError(
          'Received Group changed outside its source transaction',
        );
      }
    }
    for (final entry in received.owners.entries) {
      final target = desired[entry.key];
      if (target == null ||
          entry.value.retired ||
          (!before.isReceived(entry.key) && current.containsKey(entry.key)) ||
          digest(target) != entry.value.groupDigest ||
          target.folderId != null) {
        throw const FormatException('Invalid received Group ownership');
      }
      final parent = target.parentGroupId;
      if (parent != null &&
          received.owners[parent]?.publisher != entry.value.publisher) {
        throw const FormatException(
          'Received and local device hierarchies cannot be mixed',
        );
      }
    }
    for (final entry in desired.entries) {
      if (!received.isReceived(entry.key) &&
          received.isReceived(entry.value.parentGroupId ?? '')) {
        throw const FormatException(
          'Local child cannot belong to a received hierarchy',
        );
      }
    }
  }

  Future<List<BoxBase<dynamic>>> _applyOrganization(
    Map<String, Object?> plan,
  ) async {
    final (groups, folders) = await _organizationBoxes();
    final writes = contentMap(plan['groups']);
    await groups.deleteAll((plan['deletes']! as List).cast<String>());
    await groups.putAll({
      for (final entry in writes.entries) entry.key: _groupRow(entry.value),
    });
    return [groups, folders];
  }
}
