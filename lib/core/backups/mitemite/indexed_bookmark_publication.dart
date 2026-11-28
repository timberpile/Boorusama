import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

import '../../../foundation/cooperative_work.dart';
import '../../bookmarks/src/data/hive/unified_bookmark_repository.dart';
import '../../bookmarks/src/types/bookmark_group_repository.dart';
import '../../bookmarks/src/types/bookmark_record_fields.dart';
import '../../content/content_map.dart';
import '../../content/types.dart';
import '../sources/bookmark_backup_codec.dart';
import '../sources/bookmark_backup_schema.dart';
import 'bookmark_buckets.dart';
import 'protocol.dart';
import 'publication.dart';

String _portableKey(({int engine, ContentIdentity identity}) member) =>
    canonicalSyncJson([
      member.engine,
      member.identity.siteNamespace,
      member.identity.kind.name,
      member.identity.sourceKey,
    ]);

/// A replayable projection. The Bookmark journal owns edits, and the installed
/// signed catalog owns publication across a crash or a destination change.
final class IndexedBookmarkPublication {
  IndexedBookmarkPublication({
    required this.repository,
    required this.groups,
    required this.codec,
    required this.writer,
    required String path,
    required this.destination,
  }) : _db = sqlite3.open(path) {
    _db.execute('''
      CREATE TABLE IF NOT EXISTS source_state (
        id INTEGER PRIMARY KEY CHECK(id = 1), generation TEXT, revision INTEGER
      );
      CREATE TABLE IF NOT EXISTS sources (
        source TEXT PRIMARY KEY, buckets INTEGER NOT NULL
      ) WITHOUT ROWID;
      CREATE TABLE IF NOT EXISTS members (
        source TEXT NOT NULL, bucket INTEGER NOT NULL, member TEXT NOT NULL,
        local_id INTEGER NOT NULL, added_at TEXT NOT NULL,
        PRIMARY KEY (source, bucket, member), UNIQUE (source, local_id)
      ) WITHOUT ROWID;
      CREATE INDEX IF NOT EXISTS reverse_members ON members(local_id);
      CREATE TABLE IF NOT EXISTS dirty (
        source TEXT NOT NULL, bucket INTEGER NOT NULL,
        PRIMARY KEY(source, bucket)
      ) WITHOUT ROWID;
      CREATE TABLE IF NOT EXISTS published (
        source TEXT PRIMARY KEY, destination TEXT NOT NULL,
        revision INTEGER NOT NULL, manifest TEXT NOT NULL
      ) WITHOUT ROWID;
    ''');
  }

  final BookmarkHiveRepository repository;
  final BookmarkGroupRepository groups;
  final BookmarkBackupCodec codec;
  final SyncPublicationWriter writer;
  final String destination;
  final Database _db;
  final _proposed = <String, SyncBookmarkManifest>{};

  void close() => _db.close();

  Future<void> prepare(
    Set<String> covered, {
    required int snapshotRevision,
    required Future<void> Function() validateSnapshot,
  }) async {
    final rows = _db.select('SELECT generation, revision FROM source_state');
    final cursor = rows.isEmpty ? null : rows.single;
    final feed = await repository.bookmarkPublicationChanges(
      cursor?['generation'] as String?,
      cursor?['revision'] as int?,
    );
    if (feed.revision != snapshotRevision) throw const SyncConflict();
    final current = {
      for (final source in _db.select('SELECT source, buckets FROM sources'))
        source['source'] as String: source['buckets'] as int,
    };
    final work = CooperativeWork();
    _db.execute('BEGIN IMMEDIATE');
    try {
      for (final source in current.keys.where((id) => !covered.contains(id))) {
        for (final table in ['sources', 'members', 'dirty', 'published']) {
          _db.execute('DELETE FROM $table WHERE source = ?', [source]);
        }
      }
      final changes = feed.changes;
      final editedMemberships = <String, Map<int, String?>>{};
      final recordIds = <int>{};
      if (changes != null) {
        for (final change in changes) {
          recordIds.addAll(change.records);
          for (final entry in change.memberships.entries) {
            if (covered.contains(entry.key) && current.containsKey(entry.key)) {
              (editedMemberships[entry.key] ??= {}).addAll(entry.value);
            }
          }
        }
      }
      for (final source in covered) {
        if (changes != null && current.containsKey(source)) continue;
        final group = await groups.getGroup(source);
        if (group == null) throw const SyncConflict();
        final count =
            current[source] ??
            syncBookmarkBucketCount(group.bookmarkIds.length);
        _db.execute('DELETE FROM members WHERE source = ?', [source]);
        _db.execute('INSERT OR REPLACE INTO sources VALUES (?, ?)', [
          source,
          count,
        ]);
        for (var bucket = 0; bucket < count; bucket++) {
          _markDirty(source, bucket);
        }
        final keys = await repository.readPublicationMemberKeys(
          group.bookmarkIds,
        );
        for (final entry in keys.entries) {
          final id = entry.key;
          final key = _portableKey(entry.value);
          final date =
              group.addedAt[id] ??
              bookmarkCreatedAt(
                await repository.read(id) ?? (throw const SyncConflict()),
              );
          _putMember(source, count, key, id, date.toUtc().toIso8601String());
          if (work.checkpoint() case final pause?) await pause;
        }
      }
      for (final entry in editedMemberships.entries) {
        for (final edit in entry.value.entries) {
          await _replaceMember(
            entry.key,
            current[entry.key]!,
            edit.key,
            edit.value,
          );
        }
      }
      for (final id in recordIds) {
        final memberships = _db.select(
          '''
          SELECT members.source, sources.buckets, members.added_at
          FROM members JOIN sources USING(source) WHERE local_id = ?
        ''',
          [id],
        );
        for (final membership in memberships) {
          await _replaceMember(
            membership['source'] as String,
            membership['buckets'] as int,
            id,
            membership['added_at'] as String,
          );
        }
      }
      await validateSnapshot();
      _db.execute('INSERT OR REPLACE INTO source_state VALUES (1, ?, ?)', [
        feed.generation,
        feed.revision,
      ]);
      _db.execute('COMMIT');
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  void _markDirty(String source, int bucket) => _db.execute(
    'INSERT OR IGNORE INTO dirty VALUES (?, ?)',
    [source, bucket],
  );

  int _putMember(String source, int count, String key, int id, String date) {
    final bucket = syncBookmarkBucket(key, count);
    _db.execute('INSERT INTO members VALUES (?, ?, ?, ?, ?)', [
      source,
      bucket,
      key,
      id,
      date,
    ]);
    return bucket;
  }

  Future<void> _replaceMember(
    String source,
    int count,
    int id,
    String? date,
  ) async {
    final rows = _db.select(
      'SELECT bucket FROM members WHERE source = ? AND local_id = ?',
      [source, id],
    );
    if (rows.isNotEmpty) _markDirty(source, rows.single['bucket'] as int);
    _db.execute('DELETE FROM members WHERE source = ? AND local_id = ?', [
      source,
      id,
    ]);
    if (date == null) return;
    final key = _portableKey(
      (await repository.readPublicationMemberKeys([id])).values.single,
    );
    final bucket = _putMember(
      source,
      count,
      key,
      id,
      date,
    );
    _markDirty(source, bucket);
  }

  Future<SyncRevision> publish({
    required SyncCollectionId collection,
    required SyncRevision? previous,
    required bool verifyExisting,
    required Future<void> Function() validateSnapshot,
  }) async {
    final source = collection.source;
    final count =
        _db.select('SELECT buckets FROM sources WHERE source = ?', [
              source,
            ]).single['buckets']
            as int;
    final dirty = {
      for (final row in _db.select(
        'SELECT bucket FROM dirty WHERE source = ?',
        [source],
      ))
        row['bucket'] as int,
    };
    SyncBookmarkManifest? prior;
    final repair = <int>{};
    if (previous != null &&
        previous.bookmarkManifest &&
        !writer.sequences.isWithdrawnRevision(previous)) {
      final saved = _db.select(
        '''
        SELECT manifest FROM published WHERE source = ? AND destination = ? AND revision = ?
      ''',
        [source, destination, previous.revision],
      );
      if (!verifyExisting && saved.isNotEmpty) {
        final cached = SyncBookmarkManifest.fromJson(
          contentMap(jsonDecode(saved.single['manifest'] as String)),
        );
        if (cached.collection == collection &&
            cached.semanticHash == previous.semanticHash &&
            syncDigest(cached.encode()) == previous.sha256) {
          prior = cached;
        }
      }
      if (prior == null) {
        try {
          prior = await SyncBookmarkManifest.read(writer.storage, previous);
        } on FormatException {
          // A damaged immutable path is replaced at a fresh revision.
        }
        if (prior != null) {
          for (final chunk in prior.chunks) {
            if (repair.contains(chunk.bucket)) continue;
            try {
              if (await readSyncBookmarkChunk(
                    writer.storage,
                    collection,
                    chunk,
                  ) !=
                  null) {
                continue;
              }
            } on FormatException {
              // A fresh revision leaves the inaccessible evidence untouched.
            }
            repair.add(chunk.bucket);
          }
        }
      }
    }
    if (prior?.bucketCount != count) {
      prior = null;
      dirty.addAll(Iterable.generate(count));
    }
    dirty.addAll(repair);
    if (dirty.isEmpty && prior != null) {
      _proposed[source] = prior;
      return previous!;
    }
    int? reserved;
    final references = [
      for (final chunk in prior?.chunks ?? const <SyncBookmarkChunk>[])
        if (!dirty.contains(chunk.bucket)) chunk,
    ];
    for (final bucket in dirty.toList()..sort()) {
      final members = <SyncBucketMember>[];
      for (final row in _db.select(
        '''
        SELECT member, local_id, added_at FROM members WHERE source = ? AND bucket = ?
      ''',
        [source, bucket],
      )) {
        final record = await repository.read(row['local_id'] as int);
        if (record == null) throw const SyncConflict();
        members.add((
          key: row['member'] as String,
          addedAt: DateTime.parse(row['added_at'] as String),
          record: record,
        ));
      }
      final parts = encodeSyncBookmarkBucket(
        members: members,
        codec: codec,
        bucket: bucket,
        revision: 1,
      ).toList();
      final old = prior?.bucket(bucket).toList() ?? const <SyncBookmarkChunk>[];
      if (!repair.contains(bucket) &&
          old.length == parts.length &&
          parts.asMap().entries.every(
            (part) =>
                part.value.reference.semanticHash == old[part.key].semanticHash,
          )) {
        references.addAll(old);
        continue;
      }
      reserved ??= await writer.sequences.reserve(
        collection.publisher,
        collection: collection,
      );
      for (final part in parts) {
        final ref = part.reference;
        final chunk = SyncBookmarkChunk(
          bucket: ref.bucket,
          part: ref.part,
          createdRevision: reserved,
          sha256: ref.sha256,
          semanticHash: ref.semanticHash,
          compressedBytes: ref.compressedBytes,
          expandedBytes: ref.expandedBytes,
          rows: ref.rows,
        );
        await writer.storage.writeImmutable(chunk.path(collection), part.bytes);
        if (await readSyncBookmarkChunk(writer.storage, collection, chunk) ==
            null) {
          throw const FormatException('Bookmark chunk was not written');
        }
        references.add(chunk);
      }
    }
    if (reserved == null && prior != null) {
      _proposed[source] = prior;
      return previous!;
    }
    reserved ??= await writer.sequences.reserve(
      collection.publisher,
      collection: collection,
    );
    references.sort(
      (a, b) => a.bucket == b.bucket
          ? a.part.compareTo(b.part)
          : a.bucket.compareTo(b.bucket),
    );
    final manifest = SyncBookmarkManifest(
      collection: collection,
      revision: reserved,
      bucketCount: count,
      chunks: references,
    );
    final bytes = manifest.encode();
    final revision = SyncRevision(
      collection: collection,
      revision: reserved,
      length: bytes.length,
      sha256: syncDigest(bytes),
      semanticHash: manifest.semanticHash,
      schema: kBookmarksBackupVersion,
      bookmarkManifest: true,
    );
    await validateSnapshot();
    await writer.storage.writeImmutable(revision.payloadPath, bytes);
    if (await SyncBookmarkManifest.read(writer.storage, revision) == null) {
      throw const FormatException('Bookmark manifest was not written');
    }
    _proposed[source] = manifest;
    return revision;
  }

  void acknowledge() {
    _db.execute('BEGIN IMMEDIATE');
    try {
      for (final entry in _proposed.entries) {
        _db.execute('INSERT OR REPLACE INTO published VALUES (?, ?, ?, ?)', [
          entry.key,
          destination,
          entry.value.revision,
          canonicalSyncJson(entry.value.toJson()),
        ]);
        _db.execute('DELETE FROM dirty WHERE source = ?', [entry.key]);
      }
      _db.execute('COMMIT');
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }
}
