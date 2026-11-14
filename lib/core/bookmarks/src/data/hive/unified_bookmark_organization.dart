part of 'unified_bookmark_repository.dart';

/// Organization writes use the same journal and coordinator as payload writes.
/// This is a storage implementation detail, not a second membership authority.
extension BookmarkOrganizationWrites on BookmarkHiveRepository {
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
    final suffix = switch (active['version']) {
      2 => '_unified_v2',
      3 => '_hierarchy_v3',
      _ => null,
    };
    if (suffix == null ||
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
  }) async {
    final detachDeleted =
        removedRecordIds.isNotEmpty &&
        _metadata.get('activeOrganization') != null;
    if (groups.isEmpty &&
        removeGroups.isEmpty &&
        folders == null &&
        !detachDeleted)
      return null;
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
      for (final row in groupBox.values) {
        if (updates.containsKey(row.id) ||
            removeGroups.contains(row.id) ||
            !row.bookmarkIds.any(removedRecordIds.contains))
          continue;
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
      previous[id] = row == null ? null : _groupWire(row);
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
    await _validateOrganization(plan, recordIds, removedRecordIds);
    return plan;
  }

  Future<void> _validateOrganization(
    Map<String, Object?> plan,
    Set<int> recordIds,
    Set<int> removedIds,
  ) async {
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
      final actual = current == null ? null : _groupWire(current);
      final desired = updates[id];
      if (!BookmarkHiveRepository._same(actual, previous[id]) &&
          !BookmarkHiveRepository._same(actual, desired)) {
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
    if (contentMap(_metadata.get('activeOrganization'))['version'] == 3) {
      if (folders.isNotEmpty ||
          next.values.any((row) => row.folderId != null)) {
        throw const FormatException(
          'Legacy folders cannot mutate active hierarchy',
        );
      }
      BookmarkGroupTree([
        for (final row in next.values)
          BookmarkGroup(
            id: row.id,
            name: row.name,
            bookmarkIds: row.bookmarkIds.toSet(),
            parentGroupId: row.parentGroupId,
            position: row.position,
          ),
      ]);
    } else {
      if (next.values.any((row) => row.parentGroupId != null)) {
        throw const FormatException('Hierarchy parents require v3 activation');
      }
      FolderTree(folders).validatePlacements(
        next.values.map(
          (row) => FolderPlacement(
            itemId: row.id,
            folderId: row.folderId,
            position: row.position,
          ),
        ),
      );
    }
    for (final row in removedIds.isEmpty ? rows.values : next.values) {
      for (final id in row.bookmarkIds) {
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
    List<Bookmark> upserts,
  ) async {
    final before = _mirrors();
    if (before.owners.isEmpty && received == null) return;
    final (box, _) = await _organizationBoxes();
    BookmarkGroup group(BookmarkGroupHiveObject row) => BookmarkGroup(
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
    final current = {for (final row in box.values) row.id: group(row)};
    final updates = organization == null
        ? const <String, Object?>{}
        : contentMap(organization['groups']);
    final removed = organization == null
        ? const <String>{}
        : (organization['deletes']! as List).cast<String>().toSet();
    final desired = {
      for (final entry in current.entries)
        if (!removed.contains(entry.key)) entry.key: entry.value,
      for (final entry in updates.entries)
        entry.key: group(_groupRow(entry.value)),
    };
    if (received == null) {
      for (final record in upserts) {
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
                (old == null ||
                    bookmarkMirrorGroupDigest(old) !=
                        bookmarkMirrorGroupDigest(desired[id]!)))) {
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
    for (final entry in before.checkpoints.entries) {
      final next = received.checkpoints[entry.key];
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
    for (final record in upserts) {
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
    for (final id in {...updates.keys, ...removed}) {
      if (!before.isReceived(id) && !received.isReceived(id)) {
        throw const FormatException(
          'Received transaction cannot edit a local Group',
        );
      }
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
          (old == null ||
              bookmarkMirrorGroupDigest(old) != entry.value.groupDigest)) {
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
          bookmarkMirrorGroupDigest(target) != entry.value.groupDigest ||
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
    if (plan.containsKey('folders') &&
        contentMap(_metadata.get('activeOrganization'))['version'] == 2) {
      await folders.put('folders', plan['folders']);
    }
    return [groups, folders];
  }
}
