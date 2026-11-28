import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';
import 'package:i18n/i18n.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:uuid/uuid.dart';

import '../../../foundation/cooperative_work.dart';
import '../../bookmarks/src/data/hive/repository.dart';
import '../../bookmarks/src/data/stored_bookmark_codec.dart';
import '../../bookmarks/src/types/bookmark_record_fields.dart';
import '../../bookmarks/types.dart';
import '../export_import/import/bookmark_profile_dependency.dart';
import '../export_import/import/bookmark_profile_mapping.dart';
import '../export_import/import/import_change_preview.dart';
import '../export_import/import/import_plan.dart';
import '../export_import/import/import_preflight.dart';
import '../export_import/import/import_progress.dart';
import '../export_import/import/profile_dependency_planner.dart';
import '../export_import/models/import_action.dart';
import 'bookmark_transfer_database.dart';
import 'detached_bookmark_codec.dart';
import 'search_backup_profile.dart';

final class BookmarkTransferImport {
  const BookmarkTransferImport({
    required this.incoming,
    required this.previous,
    required this.codec,
  });

  final BookmarkTransferDatabase incoming;
  final BookmarkTransferDatabase previous;
  final StoredBookmarkCodec codec;

  Future<List<BackupProfileReference>> profileReferences(
    ResolvedImportSource plan,
  ) => runImportWorker(_BookmarkProfileReferences(incoming, plan).run);

  static List<BackupProfileReference> _readProfileReferences(
    BookmarkTransferDatabase incoming,
    ResolvedImportSource plan,
  ) {
    if (plan.action == ImportAction.skip) return const [];
    final db = incoming.open(preimage: false);
    try {
      db.execute('PRAGMA temp_store = FILE');
      final actions = _GroupActions(db, plan);
      actions.selectRecords(db);
      return [
        for (final row in db.select('''
          SELECT DISTINCT profile_id, engine, site FROM records JOIN selected USING (id)
        '''))
          BackupProfileReference(
            id: row['profile_id'] as String,
            booruType: row['engine'] as String,
            url: row['site'] as String,
            name: row['site'] as String,
          ),
      ];
    } finally {
      db.close();
    }
  }

  Future<PlannedChangeSummary> plan({
    required ResolvedImportSource resolution,
    required Map<ProfileReferenceKey, String> mappings,
    required Set<ProfileReferenceKey> explicitMappings,
    required Set<String> receivedGroupIds,
    BookmarkHiveRepository? applyTo,
  }) async {
    if (resolution.action == ImportAction.skip) {
      return const PlannedChangeSummary();
    }

    ImportProgress.current?.show(ImportProgressPhase.preparing);
    final path = applyTo == null
        ? null
        : '${incoming.path}.${const Uuid().v4()}.plan';
    final task = _PrepareBookmarkTransfer(
      importer: BookmarkTransferImport(
        incoming: incoming,
        previous: previous,
        codec: detachBookmarkRecordCodec(codec),
      ),
      resolution: resolution,
      mappings: mappings,
      explicitMappings: explicitMappings,
      receivedGroupIds: receivedGroupIds,
      importFolderName: Translations().folders.imported_groups,
      outputPath: path,
    );
    try {
      final prepared = await runImportWorker(task.run);
      if (applyTo != null && path != null) {
        final db = sqlite3.open(path, mode: OpenMode.readOnly);
        try {
          db.execute('PRAGMA temp_store = FILE');
          await _apply(db, applyTo, prepared);
        } finally {
          db.close();
        }
      }
      return prepared.summary;
    } finally {
      if (path != null) {
        final file = File(path);
        if (file.existsSync()) file.deleteSync();
      }
    }
  }

  Future<_BookmarkWritePlan> _prepare(_PrepareBookmarkTransfer task) async {
    final schema = task.outputPath == null ? 'temp' : 'write_plan';
    final db = incoming.open(
      preimage: false,
      writable: task.outputPath != null,
    );
    try {
      db.execute('PRAGMA temp_store = FILE');
      db.execute('ATTACH DATABASE ? AS previous', [previous.path]);
      if (task.outputPath case final path?) {
        sqlite3.open(path).close();
        db.execute('ATTACH DATABASE ? AS write_plan', [path]);
      }
      db.execute('BEGIN');
      final groups = _GroupActions(db, task.resolution);
      groups.selectRecords(db);
      final definitions = groups.planGroups(db, task.importFolderName);
      await _planRecords(
        db,
        schema,
        groups.replace,
        task.mappings,
        task.explicitMappings,
      );
      _planMemberships(db, schema, groups);
      final changed = _changedGroups(db, definitions);
      final oldGroups = {
        for (final group in BookmarkTransferDatabase.groupDefinitions(
          db,
          schema: 'previous',
        ))
          group.id: group,
      };
      final oldIds = oldGroups.keys.toSet();
      if (_changesReceivedOnlyRecords(db, task.receivedGroupIds) ||
          task.receivedGroupIds.any(
            (id) =>
                changed.contains(id) ||
                !definitions.any((group) => group.id == id),
          ) ||
          definitions.any(
            (group) =>
                changed.contains(group.id) &&
                task.receivedGroupIds.contains(group.parentGroupId),
          )) {
        throw const FormatException(
          'Import would change a received Bookmark Group',
        );
      }
      final nextIds = definitions.map((group) => group.id).toSet();
      final metadata = PlannedChangeSummary(
        created: nextIds.difference(oldIds).length,
        updated: changed.intersection(oldIds).length,
        deleted: oldIds.difference(nextIds).length,
        unchanged: nextIds.intersection(oldIds).difference(changed).length,
      );
      final records = PlannedChangeSummary(
        created: _count(
          db,
          'SELECT COUNT(*) FROM planned WHERE destination < 0',
        ),
        updated: _count(
          db,
          'SELECT COUNT(*) FROM planned WHERE destination >= 0 AND wire IS NOT NULL',
        ),
        deleted: _count(db, 'SELECT COUNT(*) FROM removals'),
        unchanged:
            _count(db, 'SELECT COUNT(*) FROM previous.records') -
            _count(db, 'SELECT COUNT(*) FROM removals') -
            _count(
              db,
              'SELECT COUNT(*) FROM planned WHERE destination >= 0 AND wire IS NOT NULL',
            ),
      );
      final writes = _count(
        db,
        'SELECT COUNT(*) FROM planned WHERE wire IS NOT NULL',
      );
      var memberships = 0;
      if (task.outputPath != null) {
        final count = db.prepare(
          'SELECT COUNT(*) FROM final_members WHERE group_id = ?',
        );
        try {
          for (final group in changed) {
            memberships += count.select([group]).single.values.single! as int;
          }
        } finally {
          count.close();
        }
      }
      db.execute('COMMIT');
      final total = records + metadata;
      final summary = PlannedChangeSummary(
        created: total.created,
        updated: total.updated,
        deleted: total.deleted,
        unchanged: total.unchanged,
        entitySummaries: {'bookmark': records, 'bookmark-group': metadata},
        previewRows: [
          for (final group in definitions)
            if (changed.contains(group.id))
              _groupPreview(
                group,
                oldIds.contains(group.id)
                    ? ImportChangeKind.changed
                    : ImportChangeKind.added,
              ),
          for (final id in oldIds.difference(nextIds))
            _groupPreview(oldGroups[id]!, ImportChangeKind.removed),
          if (records.hasMutations)
            ImportChangePreviewRow(
              category: 'bookmark_metadata',
              id: 'metadata',
              kind: ImportChangeKind.changed,
              label: '__bookmark_metadata',
              limit: ImportPreviewLimit.bookmarkMetadata,
              countOverride: ImportChangeCounts(
                added: records.created,
                changed: records.updated,
                removed: records.deleted,
              ),
            ),
        ],
      );
      return _BookmarkWritePlan(
        summary,
        definitions,
        changed,
        writes,
        memberships,
        records.deleted,
      );
    } finally {
      db.close();
    }
  }

  bool _changesReceivedOnlyRecords(Database db, Set<String> receivedGroups) {
    if (receivedGroups.isEmpty) return false;
    db.execute(
      'CREATE TEMP TABLE received_groups(id TEXT PRIMARY KEY) WITHOUT ROWID',
    );
    final insert = db.prepare('INSERT INTO received_groups VALUES (?)');
    try {
      for (final id in receivedGroups) {
        insert.execute([id]);
      }
    } finally {
      insert.close();
    }
    // Record writes precede organization changes, so ownership here must
    // match the repository guard's view of the original memberships.
    return db.select('''
      SELECT 1 FROM planned AS p
      WHERE p.destination >= 0 AND p.wire IS NOT NULL
      AND EXISTS (SELECT 1 FROM previous.members AS m
        WHERE m.bookmark_id = p.destination AND m.group_id IN received_groups)
      AND NOT EXISTS (SELECT 1 FROM previous.members AS m
        WHERE m.bookmark_id = p.destination AND m.group_id NOT IN received_groups)
      LIMIT 1
    ''').isNotEmpty;
  }

  Future<void> _planRecords(
    Database db,
    String schema,
    bool replace,
    Map<ProfileReferenceKey, String> mappings,
    Set<ProfileReferenceKey> explicitMappings,
  ) async {
    db.execute('''
      CREATE TABLE $schema.planned(id INTEGER PRIMARY KEY, destination INTEGER UNIQUE NOT NULL, wire TEXT);
    ''');
    if (mappings.isEmpty &&
        db.select('SELECT 1 FROM previous.records LIMIT 1').isEmpty) {
      // Staging has already validated these wires. An empty destination
      // needs neither correspondence nor profile-hint rewriting.
      db.execute('''
        INSERT INTO planned SELECT id, -id - 1, wire
        FROM records JOIN selected USING (id)
      ''');
      return;
    }
    db.execute('''
      CREATE TEMP TABLE opaque(id INTEGER PRIMARY KEY, fingerprint TEXT);
      CREATE INDEX opaque_fingerprint ON opaque(fingerprint, id);
    ''');
    if (replace) _indexOpaquePreviousRecords(db);
    final insert = db.prepare('INSERT INTO planned VALUES (?, ?, ?)');
    final matchOpaque = db.prepare('''
      SELECT p.id, p.wire FROM opaque AS o JOIN previous.records AS p ON o.id = p.id
      WHERE o.fingerprint = ? AND NOT EXISTS (
        SELECT 1 FROM planned WHERE destination = p.id
      ) ORDER BY p.id LIMIT 1
    ''');
    final records = db.prepare('''
      SELECT r.id, r.identity, r.wire, p.wire AS old_wire
      FROM selected AS s JOIN records AS r ON s.id = r.id
      LEFT JOIN previous.records AS p ON p.identity = r.identity
      ORDER BY r.id
    ''');
    try {
      final cursor = records.selectCursor();
      var count = 0;
      while (cursor.moveNext()) {
        if (ImportProgress.current?.cancelled ?? false) {
          throw const BookmarkTransferCancelled();
        }
        final row = cursor.current;
        final record = codec.decode(jsonDecode(row['wire'] as String));
        final opaque = replace && row['identity'] == null;
        var oldWire = row['old_wire'] as String?;
        if (opaque) {
          oldWire =
              matchOpaque.select([
                    _opaqueFingerprint(db, 'main', record),
                  ]).firstOrNull?['wire']
                  as String?;
        }
        final old = oldWire == null ? null : codec.decode(jsonDecode(oldWire));
        final mapped =
            mapBookmarkImportProfiles(
              incoming: [record],
              local: [?old],
              mappings: mappings,
              explicitMappings: explicitMappings,
            )[record.id] ??
            record;

        final destination = old?.id ?? -record.id - 1;
        final hint = bookmarkRecordProfileHint(mapped);
        final next = switch (old) {
          null => mapped,
          final existing when opaque => existing,
          final existing when replace => bookmarkWithId(mapped, existing.id),
          final existing
              when hint != null &&
                  hint != bookmarkRecordProfileHint(existing) =>
            bookmarkRecordWithProfileHint(existing, hint),
          final existing => existing,
        };
        final wire = identical(next, old)
            ? null
            : jsonEncode(codec.encode(next));
        insert.execute([record.id, destination, wire == oldWire ? null : wire]);
        if (++count % BookmarkTransferDatabase.batchSize == 0) {
          await Future<void>.delayed(Duration.zero);
        }
      }
    } finally {
      records.close();
      matchOpaque.close();
      insert.close();
    }
  }

  void _indexOpaquePreviousRecords(Database db) {
    final statement = db.prepare(
      'SELECT wire FROM previous.records WHERE identity IS NULL ORDER BY id',
    );
    final insert = db.prepare('INSERT INTO opaque VALUES (?, ?)');
    try {
      final cursor = statement.selectCursor();
      while (cursor.moveNext()) {
        final record = codec.decode(
          jsonDecode(cursor.current['wire'] as String),
        );
        insert.execute([record.id, _opaqueFingerprint(db, 'previous', record)]);
      }
    } finally {
      statement.close();
      insert.close();
    }
  }

  String _opaqueFingerprint(Database db, String schema, Bookmark record) {
    final memberships = db.select(
      '''
      SELECT group_id, added_at FROM $schema.members WHERE bookmark_id = ? ORDER BY group_id
    ''',
      [record.id],
    );
    return sha256
        .convert(
          utf8.encode(
            jsonEncode([
              _canonicalWire(codec.encodeForTransfer(record)..remove('id')),
              for (final row in memberships) [row['group_id'], row['added_at']],
            ]),
          ),
        )
        .toString();
  }

  Future<void> _apply(
    Database db,
    BookmarkHiveRepository store,
    _BookmarkWritePlan plan,
  ) async {
    final progress = ImportProgress.current;
    final budget = CooperativeWork();
    var written = 0;
    progress?.show(ImportProgressPhase.saving, total: plan.writes);
    db.execute(
      'CREATE TEMP TABLE reserved(temporary_id INTEGER PRIMARY KEY, actual_id INTEGER NOT NULL)',
    );
    final reserve = db.prepare('INSERT INTO reserved VALUES (?, ?)');
    try {
      var after = -1;
      while (true) {
        final batch = _recordBatch(
          db,
          '''
          SELECT id, destination, wire FROM planned WHERE id > ? AND wire IS NOT NULL
          ORDER BY id
        ''',
          after,
        );
        if (batch.isEmpty) break;
        final allocated = await store.reserveIds(
          batch.where((row) => (row['destination'] as int) < 0).length,
        );
        var slot = 0;
        final writes = <Bookmark>[];
        for (final row in batch) {
          after = row['id'] as int;
          final mark = codec.decode(jsonDecode(row['wire'] as String));
          var id = row['destination'] as int;
          if (id < 0) {
            final actual = allocated[slot++];
            reserve.execute([id, actual]);
            id = actual;
          }
          writes.add(bookmarkWithId(mark, id));
          if (budget.checkpoint() case final pause?) await pause;
        }
        await store.upsertTransferRecords(writes, budget);
        written += writes.length;
        progress?.show(
          ImportProgressPhase.saving,
          completed: written,
          total: plan.writes,
        );
        if (budget.checkpoint() case final pause?) await pause;
      }
    } finally {
      reserve.close();
    }

    await store.writeTransferOrganization(
      definitions: plan.groups,
      changed: plan.changed,
      onWritingGroup: () => progress?.show(ImportProgressPhase.writingGroup),
      onMembersPrepared: progress == null
          ? null
          : (count) => progress.show(
              ImportProgressPhase.memberships,
              completed: count,
              total: plan.memberships,
            ),
      members: (id) => _members(db, '''
        SELECT COALESCE(reserved.actual_id, m.bookmark_id) AS id, m.added_at
        FROM final_members AS m LEFT JOIN reserved ON reserved.temporary_id = m.bookmark_id
        WHERE m.group_id = ? ORDER BY id
      ''', id),
    );
    await _deleteRows(db, store, total: plan.removals);
  }

  static Future<void> restore(
    BookmarkTransferDatabase previous,
    StoredBookmarkCodec codec,
    BookmarkHiveRepository store,
  ) async {
    final db = previous.open(preimage: true);
    try {
      db.execute('PRAGMA temp_store = FILE');
      db.execute('CREATE TEMP TABLE removals(id INTEGER PRIMARY KEY)');
      final insert = db.prepare('INSERT INTO removals VALUES (?)');
      final exists = db.prepare('SELECT 1 FROM records WHERE id = ?');
      final work = CooperativeWork();
      try {
        await store.visitTransferRecords((record) async {
          if (exists.select([record.id]).isEmpty) insert.execute([record.id]);
          if (work.checkpoint() case final pause?) await pause;
        });
      } finally {
        exists.close();
        insert.close();
      }
      // Bring missing IDs back first so the old groups can reference them.
      // Restore surviving records' metadata under their original memberships,
      // since the interrupted apply may have removed their last local group.
      db.execute('CREATE TEMP TABLE changed_records(id INTEGER PRIMARY KEY)');
      final changed = db.prepare('INSERT INTO changed_records VALUES (?)');
      var last = -1;
      try {
        while (true) {
          final batch = _recordBatch(
            db,
            '''
          SELECT id, wire FROM records WHERE id > ? ORDER BY id
        ''',
            last,
          );
          if (batch.isEmpty) break;
          final writes = <Bookmark>[];
          for (final row in batch) {
            last = row['id'] as int;
            final current = await store.read(last);
            final wire = row['wire'] as String;
            if (current == null) {
              writes.add(codec.decode(jsonDecode(wire)));
            } else if (jsonEncode(codec.encode(current)) != wire) {
              changed.execute([last]);
            }
            if (work.checkpoint() case final pause?) await pause;
          }
          if (writes.isNotEmpty) await store.restoreTransferRecords(writes);
        }
      } finally {
        changed.close();
      }
      final groups = BookmarkTransferDatabase.groupDefinitions(db);
      final mirror = await store.readMirrorState();
      await store.writeTransferOrganization(
        definitions: groups,
        changed: {
          for (final group in groups)
            if (!mirror.isReceived(group.id)) group.id,
        },
        members: (id) => _members(db, '''
          SELECT bookmark_id AS id, added_at FROM members
          WHERE group_id = ? ORDER BY bookmark_id
        ''', id),
      );
      last = -1;
      while (true) {
        final batch = _recordBatch(db, '''
          SELECT c.id, r.wire FROM changed_records AS c
          JOIN records AS r ON r.id = c.id WHERE c.id > ? ORDER BY c.id
        ''', last);
        if (batch.isEmpty) break;
        final writes = <Bookmark>[];
        for (final row in batch) {
          last = row['id'] as int;
          writes.add(codec.decode(jsonDecode(row['wire'] as String)));
          if (work.checkpoint() case final pause?) await pause;
        }
        await store.restoreTransferRecords(writes);
      }
      await _deleteRows(db, store);
    } finally {
      db.close();
    }
  }
}

final class _BookmarkProfileReferences {
  const _BookmarkProfileReferences(this.incoming, this.resolution);

  final BookmarkTransferDatabase incoming;
  final ResolvedImportSource resolution;

  Future<List<BackupProfileReference>> run() => Future.sync(
    () => BookmarkTransferImport._readProfileReferences(incoming, resolution),
  );
}

final class _PrepareBookmarkTransfer {
  const _PrepareBookmarkTransfer({
    required this.importer,
    required this.resolution,
    required this.mappings,
    required this.explicitMappings,
    required this.receivedGroupIds,
    required this.importFolderName,
    this.outputPath,
  });

  final BookmarkTransferImport importer;
  final ResolvedImportSource resolution;
  final Map<ProfileReferenceKey, String> mappings;
  final Set<ProfileReferenceKey> explicitMappings;
  final Set<String> receivedGroupIds;
  final String importFolderName;
  final String? outputPath;

  Future<_BookmarkWritePlan> run() => importer._prepare(this);
}

final class _BookmarkWritePlan {
  const _BookmarkWritePlan(
    this.summary,
    this.groups,
    this.changed,
    this.writes,
    this.memberships,
    this.removals,
  );

  final PlannedChangeSummary summary;
  final List<BookmarkGroup> groups;
  final Set<String> changed;
  final int writes;
  final int memberships;
  final int removals;
}

ImportChangePreviewRow _groupPreview(
  BookmarkGroup group,
  ImportChangeKind kind,
) => ImportChangePreviewRow(
  category: 'bookmarks',
  id: group.id,
  label: safeImportDisplayValue('name', group.name),
  kind: kind,
);

Object? _canonicalWire(Object? value) => switch (value) {
  final Map<String, Object?> map => {
    for (final key in map.keys.toList()..sort()) key: _canonicalWire(map[key]),
  },
  final List<Object?> list => list.map(_canonicalWire).toList(),
  _ => value,
};

final class _GroupActions {
  _GroupActions(Database db, ResolvedImportSource resolution)
    : replace = resolution.action == ImportAction.replace,
      choices = {for (final item in resolution.items) item.id: item},
      incoming = BookmarkTransferDatabase.groupDefinitions(db);

  final bool replace;
  final Map<String, ResolvedImportItem> choices;
  final List<BookmarkGroup> incoming;
  bool get selectUngrouped =>
      replace ||
      (choices['ungrouped'] != null &&
          choices['ungrouped']!.action != ImportAction.skip);

  ResolvedImportItem? _choice(String id) =>
      choices['group:$id'] ?? choices['group-direct:$id'];

  void selectRecords(Database db) {
    db.execute('CREATE TEMP TABLE selected(id INTEGER PRIMARY KEY)');
    if (replace) {
      db.execute('INSERT INTO selected SELECT id FROM records');
      return;
    }
    final insert = db.prepare('''
      INSERT OR IGNORE INTO selected SELECT bookmark_id FROM members WHERE group_id = ?
    ''');
    try {
      for (final group in incoming) {
        if (_choice(group.id)?.action != ImportAction.skip) {
          insert.execute([group.id]);
        }
      }
    } finally {
      insert.close();
    }
    if (selectUngrouped) {
      db.execute('''
        INSERT OR IGNORE INTO selected
        SELECT r.id FROM records AS r WHERE NOT EXISTS (
          SELECT 1 FROM members AS m WHERE m.bookmark_id = r.id
        )
      ''');
    }
  }

  List<BookmarkGroup> planGroups(Database db, String importFolderName) {
    final old = {
      for (final group in BookmarkTransferDatabase.groupDefinitions(
        db,
        schema: 'previous',
      ))
        group.id: group,
    };
    final planned = replace ? <String, BookmarkGroup>{} : {...old};
    final selected = incoming
        .where(
          (group) => replace || _choice(group.id)?.action != ImportAction.skip,
        )
        .toList();
    final actions = {
      for (final group in selected)
        group.id: replace
            ? ImportAction.replace
            : _choice(group.id)?.action ??
                  (old.containsKey(group.id)
                      ? ImportAction.update
                      : ImportAction.copy),
    };
    String? wrapper;
    if (!replace &&
        selected.any(
          (group) => !group.isDefault && actions[group.id] == ImportAction.copy,
        )) {
      wrapper = const Uuid().v4();
      var position = 0;
      for (final group in old.values) {
        if (group.parentGroupId == null && group.position >= position) {
          position = group.position + 1;
        }
      }
      planned[wrapper] = BookmarkGroup(
        id: wrapper,
        name: importFolderName.trim(),
        bookmarkIds: const {},
        position: position,
      );
    }
    final targets = <String, String>{};
    for (final group in selected) {
      final action = actions[group.id]!;
      final target = switch (action) {
        ImportAction.mergeIntoTarget when !group.isDefault => _choice(
          group.id,
        )?.targetId?.replaceFirst(RegExp('^group:'), ''),
        ImportAction.copy
            when !group.isDefault && planned.containsKey(group.id) =>
          const Uuid().v4(),
        _ => group.id,
      };
      if (target == null ||
          (action == ImportAction.mergeIntoTarget &&
              !old.containsKey(target))) {
        throw const FormatException('Missing Bookmark merge target');
      }
      targets[group.id] = target;
    }

    db.execute(
      'CREATE TEMP TABLE group_targets(source TEXT PRIMARY KEY, target TEXT NOT NULL, merge INTEGER NOT NULL, ordinal INTEGER NOT NULL)',
    );
    final insert = db.prepare('INSERT INTO group_targets VALUES (?, ?, ?, ?)');
    try {
      for (final (ordinal, group) in selected.indexed) {
        final action = actions[group.id]!;
        final target = targets[group.id]!;
        final existing = planned[target];
        final merge =
            !replace &&
            (group.isDefault ||
                action == ImportAction.merge ||
                action == ImportAction.mergeIntoTarget);
        final parent = replace
            ? group.parentGroupId
            : action == ImportAction.copy
            ? targets[group.parentGroupId] ?? wrapper
            : existing != null
            ? existing.parentGroupId
            : targets[group.parentGroupId];
        planned[target] = BookmarkGroup(
          id: target,
          name: target == defaultBookmarkGroupId
              ? 'Default'
              : action == ImportAction.update || merge
              ? existing?.name ?? group.name
              : group.name,
          parentGroupId: target == defaultBookmarkGroupId ? null : parent,
          bookmarkIds: const {},
          position: replace
              ? group.position
              : existing?.position ?? group.position,
        );
        insert.execute([group.id, target, merge ? 1 : 0, ordinal]);
      }
    } finally {
      insert.close();
    }
    planned.putIfAbsent(
      defaultBookmarkGroupId,
      () => BookmarkGroup(
        id: defaultBookmarkGroupId,
        name: 'Default',
        bookmarkIds: const {},
      ),
    );
    BookmarkGroupTree(planned.values);
    return planned.values.toList();
  }
}

void _planMemberships(Database db, String schema, _GroupActions groups) {
  db.execute('''
    CREATE TABLE $schema.final_members(
      group_id TEXT NOT NULL, bookmark_id INTEGER NOT NULL,
      added_at TEXT NOT NULL, PRIMARY KEY(group_id, bookmark_id)
    ) WITHOUT ROWID;
    CREATE INDEX $schema.final_members_by_record ON final_members(bookmark_id);
    CREATE TABLE $schema.removals(id INTEGER PRIMARY KEY);
  ''');
  if (!groups.replace) {
    db.execute('''
      INSERT INTO final_members
      SELECT * FROM previous.members WHERE group_id NOT IN (
        SELECT target FROM group_targets WHERE merge = 0
      );
    ''');
  }
  db.execute('''
    INSERT OR IGNORE INTO final_members
    SELECT t.target, p.destination, m.added_at FROM members AS m
    JOIN group_targets AS t ON m.group_id = t.source
    JOIN planned AS p ON p.id = m.bookmark_id
    ORDER BY t.ordinal;
  ''');
  db.execute(
    '''
    INSERT OR IGNORE INTO final_members
    SELECT ?, p.destination, r.created FROM planned AS p JOIN records AS r USING (id)
    WHERE NOT EXISTS (SELECT 1 FROM final_members AS f WHERE f.bookmark_id = p.destination);
  ''',
    [defaultBookmarkGroupId],
  );
  if (groups.replace) {
    db.execute('''
      INSERT INTO removals SELECT r.id FROM previous.records AS r
      WHERE NOT EXISTS (SELECT 1 FROM planned WHERE destination = r.id);
    ''');
  } else {
    db.execute('''
      INSERT OR IGNORE INTO removals
      SELECT m.bookmark_id FROM previous.members AS m
      WHERE m.group_id IN (SELECT target FROM group_targets WHERE merge = 0)
        AND NOT EXISTS (SELECT 1 FROM final_members AS f WHERE f.bookmark_id = m.bookmark_id);
    ''');
  }
  if (!groups.replace) {
    db.execute(
      '''
      INSERT OR IGNORE INTO final_members
      SELECT ?, r.id, r.created FROM previous.records AS r
      WHERE NOT EXISTS (SELECT 1 FROM final_members AS f WHERE f.bookmark_id = r.id)
        AND NOT EXISTS (SELECT 1 FROM removals WHERE id = r.id);
    ''',
      [defaultBookmarkGroupId],
    );
  }
}

Set<String> _changedGroups(Database db, List<BookmarkGroup> groups) {
  final old = {
    for (final group in BookmarkTransferDatabase.groupDefinitions(
      db,
      schema: 'previous',
    ))
      group.id: group,
  };
  final changedMemberships = {
    for (final row in db.select('''
      SELECT DISTINCT f.group_id FROM final_members AS f WHERE NOT EXISTS (
        SELECT 1 FROM previous.members AS m
        WHERE m.group_id = f.group_id AND m.bookmark_id = f.bookmark_id AND m.added_at = f.added_at
      )
      UNION
      SELECT DISTINCT m.group_id FROM previous.members AS m WHERE NOT EXISTS (
        SELECT 1 FROM final_members AS f
        WHERE m.group_id = f.group_id AND m.bookmark_id = f.bookmark_id AND m.added_at = f.added_at
      )
    '''))
      row['group_id'] as String,
  };
  return {
    for (final group in groups)
      if (old[group.id] != group || changedMemberships.contains(group.id))
        group.id,
  };
}

int _count(Database db, String sql) =>
    db.select(sql).single.values.single! as int;

List<Row> _recordBatch(Database db, String sql, int after) {
  const maxCodeUnits = 8 * 1024 * 1024;
  final statement = db.prepare(sql);
  try {
    final result = <Row>[];
    var codeUnits = 0;
    final cursor = statement.selectCursor([after]);
    while (result.length < BookmarkTransferDatabase.batchSize &&
        cursor.moveNext()) {
      final row = cursor.current;
      codeUnits += (row['wire'] as String).length;
      if (result.isNotEmpty && codeUnits > maxCodeUnits) break;
      result.add(row);
    }
    return result;
  } finally {
    statement.close();
  }
}

Iterable<(int, String)> _members(Database db, String sql, String group) sync* {
  final statement = db.prepare(sql);
  try {
    final cursor = statement.selectCursor([group]);
    while (cursor.moveNext()) {
      final row = cursor.current;
      yield (row['id'] as int, row['added_at'] as String);
    }
  } finally {
    statement.close();
  }
}

Future<void> _deleteRows(
  Database db,
  BookmarkHiveRepository store, {
  int? total,
}) async {
  final progress = total == null ? null : ImportProgress.current;
  var removed = 0;
  progress?.show(ImportProgressPhase.removing, total: total);
  var last = -1;
  while (true) {
    final batch = db.select(
      'SELECT id FROM removals WHERE id > ? ORDER BY id LIMIT ?',
      [
        last,
        BookmarkTransferDatabase.batchSize,
      ],
    );
    if (batch.isEmpty) return;
    final ids = {for (final row in batch) row['id'] as int};
    last = ids.last;
    await store.deleteTransferRecords(ids);
    removed += ids.length;
    progress?.show(
      ImportProgressPhase.removing,
      completed: removed,
      total: total,
    );
  }
}
