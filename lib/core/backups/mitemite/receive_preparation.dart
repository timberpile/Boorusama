import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import '../../../foundation/cooperative_work.dart';
import '../../../foundation/filesystem.dart';
import '../../bookmarks/src/types/bookmark.dart';
import '../../content/content_map.dart';
import '../export_import/import/import_progress.dart';
import '../export_import/models/export_selection.dart';
import '../export_import/package/bookmark_transfer_format.dart';
import '../export_import/package/export_package_exception.dart';
import '../export_import/package/export_package_limits.dart';
import '../export_import/package/export_package_reader.dart';
import '../sources/bookmark_backup_codec.dart';
import '../sources/bookmark_backup_data.dart';
import '../sources/bookmark_transfer_database.dart';
import '../sources/detached_bookmark_codec.dart';
import '../utils/data_converter.dart';
import 'bookmark_package.dart';
import 'bookmark_buckets.dart';
import 'following_package.dart';
import 'catalog.dart';
import 'catalog_gate.dart';
import 'protocol.dart';
import 'seen_state.dart';
import 'revision_transport.dart';
import 'storage.dart';

/// Prepared outside the shared mutation lock. Apply MUST recheck [catalog]
/// through SyncCatalogGate.withCurrentCatalog and journal domain ownership and
/// last-applied state together. This object cannot remove any local data.
final class PreparedSyncBookmarkRevision {
  const PreparedSyncBookmarkRevision._(
    this.catalog,
    this.revision,
    this.package,
  );
  final VerifiedSyncCatalog catalog;
  final SyncRevision revision;
  final ValidatedSyncBookmarkPackage package;
}

/// One verified revision, backed by a private file until its receive unit has
/// either committed or failed.
final class StagedSyncBookmarkRevision {
  const StagedSyncBookmarkRevision._({
    required this.stagedBytes,
    required this.recordCount,
    required AppFileSystem fs,
    required BookmarkBackupCodec codec,
    required String directory,
    required String path,
    required bool streamed,
    this.manifest,
    this.partialBuckets = false,
    this.privateChunkCache,
    this.stagedChunkCache,
  }) : _fs = fs,
       _codec = codec,
       _directory = directory,
       _path = path,
       _streamed = streamed;

  final int stagedBytes;
  final int recordCount;
  final AppFileSystem _fs;
  final BookmarkBackupCodec _codec;
  final String _directory;
  final String _path;
  final bool _streamed;
  final SyncBookmarkManifest? manifest;
  final bool partialBuckets;
  final String? privateChunkCache;
  final String? stagedChunkCache;

  Future<void> visitRecords(
    Future<void> Function(Bookmark record, DateTime? addedAt) visit, {
    void Function()? ensureCurrent,
  }) async {
    if (!_streamed) {
      final task = _ReadLegacySyncPayload(
        _fs.runtimeType == IoFileSystem ? const IoFileSystem() : _fs,
        detachBookmarkBackupCodec(_codec),
        _path,
      );
      final payload = _fs.runtimeType == IoFileSystem
          ? await Isolate.run(task.run)
          : await task.run();
      final addedAt = payload.groups.single.addedAt;
      final work = CooperativeWork();
      for (final record in payload.records) {
        ensureCurrent?.call();
        await visit(record, addedAt[record.id]);
        if (work.checkpoint() case final pause?) await pause;
      }
      return;
    }

    final db = manifest == null
        ? BookmarkTransferDatabase(_path).open(preimage: false)
        : sqlite3.open(_path, mode: OpenMode.readOnly);
    try {
      final statement = db.prepare('''
        SELECT r.wire, m.added_at
        FROM records r JOIN members m ON m.bookmark_id = r.id
        ORDER BY r.id
      ''');
      try {
        final codec = _codec.records;
        final cursor = statement.selectCursor();
        final work = CooperativeWork();
        while (cursor.moveNext()) {
          ensureCurrent?.call();
          final row = cursor.current;
          final record = codec.decode(jsonDecode(row['wire'] as String));
          await visit(record, DateTime.parse(row['added_at'] as String));
          if (work.checkpoint() case final pause?) await pause;
        }
      } finally {
        statement.close();
      }
    } finally {
      db.close();
    }
  }

  Future<void> visitReplacedMembers(
    Future<void> Function(Bookmark record) visit,
  ) async {
    if (!partialBuckets) return;
    final db = sqlite3.open(_path, mode: OpenMode.readOnly);
    try {
      final select = db.prepare('SELECT wire FROM replaced');
      try {
        final cursor = select.selectCursor();
        while (cursor.moveNext()) {
          await visit(
            _codec.records.decode(jsonDecode(cursor.current['wire'] as String)),
          );
        }
      } finally {
        select.close();
      }
    } finally {
      db.close();
    }
  }

  Future<void> dispose() => _fs.deleteDirectory(_directory, recursive: true);

  Future<void> pruneCommittedCache() async {
    final current = manifest;
    final cache = privateChunkCache;
    if (current == null || cache == null) return;
    final retained = {for (final chunk in current.chunks) chunk.sha256};
    if (stagedChunkCache case final staging?) {
      await _fs.createDirectory(cache, recursive: true);
      await for (final file in _fs.listDirectoryStream(
        staging,
        followLinks: false,
      )) {
        final name = p.basename(file.path);
        if (file.isFile && retained.contains(name)) {
          await _fs.copyFile(file.path, p.join(cache, name));
        }
      }
    }
    await for (final file in _fs.listDirectoryStream(
      cache,
      followLinks: false,
    )) {
      final name = p.basename(file.path);
      if (file.isFile && isSyncDigest(name) && !retained.contains(name)) {
        await _fs.deleteFileIfExists(file.path);
      }
    }
  }
}

final class _ReadLegacySyncPayload {
  const _ReadLegacySyncPayload(this.fs, this.codec, this.path);
  final AppFileSystem fs;
  final BookmarkBackupCodec codec;
  final String path;

  Future<BookmarkBackupData> run() async =>
      codec.parse(decodeData(data: await fs.readString(path)));
}

final class SyncReceivePreparation {
  const SyncReceivePreparation({
    required this.storage,
    required this.fs,
    required this.codec,
  });
  final MiteMiteStorage storage;
  final AppFileSystem fs;
  final BookmarkBackupCodec codec;

  Future<ValidatedSyncFollowingPackage?> prepareFollowing({
    required VerifiedSyncCatalog catalog,
    required SyncCollectionId collection,
    required List<int> publisherKey,
    int maxPreparedBytes = 64 * 1024 * 1024,
  }) async {
    final key = List<int>.unmodifiable(publisherKey);
    if (collection.publisher != catalog.publisher ||
        syncDigest(key) != catalog.fingerprint) {
      throw const FormatException('Publisher does not match approved catalog');
    }
    final entry = SyncCatalog.fromJson(catalog.content).entries
        .where((entry) => entry.id == collection)
        .firstOrNull;
    if (entry == null || entry.state != SyncPublicationState.active) {
      throw const FormatException('No active advertised sync collection');
    }
    final expected = entry.revision!;
    if (collection.kind != 'following_topics' ||
        expected.schema != ValidatedSyncFollowingPackage.schema) {
      throw const SyncUpdateRequired();
    }
    final transported = await SyncRevisionTransport(storage)
        .read(expected: expected, publisherKey: key);
    if (transported == null) return null;
    final package = await SyncFollowingPackageValidator(fs: fs).validate(
      collection: collection,
      bytes: transported.bytes,
      maxPreparedBytes: maxPreparedBytes,
    );
    if (package.semanticHash != expected.semanticHash) {
      throw const FormatException(
        'Sync semantic content does not match descriptor',
      );
    }
    return package;
  }

  Future<PreparedSyncBookmarkRevision?> prepare({
    required VerifiedSyncCatalog catalog,
    required SyncCollectionId collection,
    required List<int> publisherKey,
    int maxPreparedBytes = miteMiteMaxBookmarkPackagePreparationBytes,
  }) async {
    final key = List<int>.unmodifiable(publisherKey);
    final expected = _bookmarkRevision(catalog, collection, key);
    if (expected.bookmarkTables || expected.bookmarkManifest) {
      throw const SyncUpdateRequired();
    }
    final package = await _readLegacy(expected, key, maxPreparedBytes);
    if (package == null) return null;
    return PreparedSyncBookmarkRevision._(catalog, expected, package);
  }

  Future<StagedSyncBookmarkRevision?> stageBookmark({
    required VerifiedSyncCatalog catalog,
    required SyncCollectionId collection,
    required List<int> publisherKey,
    required int maxStagedBytes,
    String? previousManifest,
    String? privateChunkCache,
    void Function()? ensureCurrent,
    ImportProgress? progress,
  }) async {
    ensureCurrent?.call();
    if (maxStagedBytes <= 0) {
      throw const ExportPackageLimitException(
        'Expanded Bookmark sync unit exceeds its staging limit',
      );
    }
    final key = List<int>.unmodifiable(publisherKey);
    final revision = _bookmarkRevision(catalog, collection, key);
    final streamed = revision.bookmarkTables || revision.bookmarkManifest;
    final directory = await fs.createTempDirectory('boorusama_sync_bookmarks_');
    var retained = false;
    final chunkStaging = revision.bookmarkManifest && privateChunkCache != null
        ? p.join(directory, 'chunks')
        : null;
    try {
      final path = p.join(
        directory,
        streamed ? 'members.sqlite' : 'members.json',
      );
      final (int stagedBytes, int recordCount) details;
      SyncBookmarkManifest? manifest;
      var partial = false;
      if (revision.bookmarkManifest) {
        manifest = await SyncBookmarkManifest.read(storage, revision);
        if (manifest == null) return null;
        final staged = await _stageBuckets(
          manifest,
          path,
          maxStagedBytes,
          previousManifest: previousManifest,
          privateChunkCache: privateChunkCache,
          stagedChunkCache: chunkStaging,
          ensureCurrent: ensureCurrent,
          progress: progress,
        );
        if (staged == null) return null;
        details = (staged.bytes, staged.records);
        partial = staged.partial;
      } else if (streamed) {
        progress?.show(ImportProgressPhase.extracting);
        final archivePath = p.join(directory, 'revision.bsexport');
        final available = await SyncRevisionTransport(storage).readToFile(
          expected: revision,
          publisherKey: key,
          destination: archivePath,
        );
        if (!available) return null;
        ensureCurrent?.call();
        details = await _stageStreamed(
          revision,
          archivePath,
          BookmarkTransferDatabase(path),
          maxStagedBytes,
          ensureCurrent: ensureCurrent,
          report: progress,
        );
        await fs.deleteFile(archivePath);
      } else {
        progress?.show(ImportProgressPhase.verifying);
        final validated = await _readLegacy(
          revision,
          key,
          miteMiteMaxBookmarkPackagePreparationBytes,
        );
        if (validated == null) return null;
        ensureCurrent?.call();
        if (validated.payloadByteLength > maxStagedBytes) {
          throw const ExportPackageLimitException(
            'Expanded Bookmark sync unit exceeds its staging limit',
          );
        }
        await validated.writeStagedPayload(fs, path);
        details = (validated.payloadByteLength, validated.recordCount);
      }
      ensureCurrent?.call();
      final result = StagedSyncBookmarkRevision._(
        stagedBytes: details.$1,
        recordCount: details.$2,
        fs: fs,
        codec: codec,
        directory: directory,
        path: path,
        streamed: streamed,
        manifest: manifest,
        partialBuckets: partial,
        privateChunkCache: privateChunkCache,
        stagedChunkCache: chunkStaging,
      );
      retained = true;
      return result;
    } finally {
      if (!retained) await fs.deleteDirectory(directory, recursive: true);
    }
  }

  Future<({int bytes, int records, bool partial})?> _stageBuckets(
    SyncBookmarkManifest manifest,
    String path,
    int maxStagedBytes, {
    required String? previousManifest,
    required String? privateChunkCache,
    required String? stagedChunkCache,
    void Function()? ensureCurrent,
    ImportProgress? progress,
  }) async {
    final cache = privateChunkCache == null
        ? null
        : Directory(privateChunkCache);
    if (stagedChunkCache != null) {
      await fs.createDirectory(stagedChunkCache, recursive: true);
    }
    File? cached(SyncBookmarkChunk chunk) =>
        cache == null ? null : File(p.join(cache.path, chunk.sha256));
    Future<Uint8List?> cachedBytes(SyncBookmarkChunk chunk) async {
      final file = cached(chunk);
      if (file == null ||
          !await fs.fileExists(file.path) ||
          await fs.fileSize(file.path) != chunk.compressedBytes) {
        return null;
      }
      final bytes = await file.readAsBytes();
      return syncDigest(bytes) == chunk.sha256 ? bytes : null;
    }

    final prior = previousManifest == null
        ? null
        : SyncBookmarkManifest.fromJson(
            contentMap(jsonDecode(previousManifest)),
          );
    final comparable =
        prior != null &&
        prior.collection == manifest.collection &&
        prior.bucketCount == manifest.bucketCount;
    final changed = <int>{};
    if (comparable) {
      for (final bucket in {...prior.occupied, ...manifest.occupied}) {
        if (!const DeepCollectionEquality().equals(
          prior.bucket(bucket).map((chunk) => chunk.toJson()),
          manifest.bucket(bucket).map((chunk) => chunk.toJson()),
        )) {
          changed.add(bucket);
        }
      }
    }
    final replaced = comparable
        ? prior.chunks.where((chunk) => changed.contains(chunk.bucket)).toList()
        : const <SyncBookmarkChunk>[];
    final changedChunks = manifest.chunks.where(
      (chunk) => changed.contains(chunk.bucket),
    );
    // The incremental plan also writes the old rows to SQLite for removals.
    // A full snapshot may fit even when staging both generations would not.
    int stagingBytes(Iterable<SyncBookmarkChunk> chunks) => chunks.fold(
      0,
      (sum, chunk) =>
          sum + math.max(chunk.expandedBytes, chunk.compressedBytes),
    );
    final deltaBytes = stagingBytes(replaced) + stagingBytes(changedChunks);
    var partial = comparable && deltaBytes <= maxStagedBytes;
    if (partial) {
      for (final chunk in replaced) {
        ensureCurrent?.call();
        if (await cachedBytes(chunk) == null) {
          partial = false;
          break;
        }
      }
    }
    final incoming = partial ? changedChunks : manifest.chunks;
    final bytes = partial ? deltaBytes : stagingBytes(incoming);
    if (bytes > maxStagedBytes) {
      throw const ExportPackageLimitException(
        'Expanded Bookmark sync unit exceeds its staging limit',
      );
    }
    final totalChunks = incoming.length;
    var verifiedChunks = 0;
    progress?.show(ImportProgressPhase.verifying, total: totalChunks);
    final db = sqlite3.open(path);
    try {
      db.execute('''
        BEGIN;
        CREATE TABLE records(id INTEGER PRIMARY KEY, member TEXT NOT NULL UNIQUE, wire TEXT NOT NULL);
        CREATE TABLE members(bookmark_id INTEGER PRIMARY KEY, added_at TEXT NOT NULL);
        CREATE TABLE replaced(member TEXT PRIMARY KEY, wire TEXT NOT NULL) WITHOUT ROWID;
      ''');
      var rows = 0;
      Future<void> stage(
        SyncBookmarkChunk chunk,
        Uint8List bytes, {
        required bool old,
      }) async {
        await for (final member in visitSyncBookmarkChunk(
          bytes: bytes,
          chunk: chunk,
          bucketCount: manifest.bucketCount,
          codec: codec,
          ensureCurrent: ensureCurrent,
        )) {
          final encoded = jsonEncode(
            codec.records.encodeForTransfer(member.record),
          );
          if (old) {
            db.execute('INSERT INTO replaced VALUES (?, ?)', [
              member.key,
              encoded,
            ]);
          } else {
            db.execute('INSERT INTO records VALUES (?, ?, ?)', [
              ++rows,
              member.key,
              encoded,
            ]);
            db.execute('INSERT INTO members VALUES (?, ?)', [
              rows,
              member.addedAt.toIso8601String(),
            ]);
          }
        }
      }

      if (partial) {
        for (final chunk in replaced) {
          final content = await cachedBytes(chunk);
          if (content == null) return null;
          await stage(chunk, content, old: true);
        }
      }
      for (final chunk in incoming) {
        ensureCurrent?.call();
        final content = await readSyncBookmarkChunk(
          storage,
          manifest.collection,
          chunk,
        );
        if (content == null) return null;
        await stage(chunk, content, old: false);
        if (stagedChunkCache != null) {
          await File(p.join(stagedChunkCache, chunk.sha256))
              .writeAsBytes(content, flush: true);
        }
        progress?.show(
          ImportProgressPhase.verifying,
          completed: ++verifiedChunks,
          total: totalChunks,
        );
      }
      db.execute('COMMIT');
      return (
        bytes: bytes,
        records: rows,
        partial: partial,
      );
    } on SqliteException catch (error) {
      if (error.extendedResultCode & 0xff == 19) {
        throw const FormatException('Duplicate Bookmark bucket member');
      }
      rethrow;
    } finally {
      db.close();
    }
  }

  SyncRevision _bookmarkRevision(
    VerifiedSyncCatalog catalog,
    SyncCollectionId collection,
    List<int> key,
  ) {
    if (collection.publisher != catalog.publisher ||
        syncDigest(key) != catalog.fingerprint) {
      throw const FormatException('Publisher does not match approved catalog');
    }
    final metadata = SyncCatalog.fromJson(catalog.content);
    final entry = metadata.entries
        .where((entry) => entry.id == collection)
        .firstOrNull;
    if (entry == null || entry.state != SyncPublicationState.active) {
      throw const FormatException('No active advertised sync collection');
    }
    final revision = entry.revision!;
    if (collection.kind != 'bookmarks' ||
        !ValidatedSyncBookmarkPackage.supportsSchema(revision.schema)) {
      throw const SyncUpdateRequired();
    }
    return revision;
  }

  Future<ValidatedSyncBookmarkPackage?> _readLegacy(
    SyncRevision expected,
    List<int> key,
    int maxPreparedBytes,
  ) async {
    final transported = await SyncRevisionTransport(storage)
        .read(expected: expected, publisherKey: key);
    if (transported == null) return null;
    final package =
        await SyncBookmarkPackageValidator(
          fs: fs,
          codec: codec,
        ).validate(
          collection: expected.collection,
          bytes: transported.bytes,
          maxPreparedBytes: maxPreparedBytes,
        );
    if (package.schemaVersion != expected.schema ||
        package.semanticHash != expected.semanticHash) {
      throw const FormatException(
        'Sync Bookmark content does not match descriptor',
      );
    }
    return package;
  }

  Future<(int, int)> _stageStreamed(
    SyncRevision revision,
    String archivePath,
    BookmarkTransferDatabase database,
    int maxStagedBytes, {
    void Function()? ensureCurrent,
    ImportProgress? report,
  }) async {
    final progress = ImportProgress(
      (sample) => report?.show(
        sample.phase,
        completed: sample.completed,
        total: sample.total,
      ),
      cancelled: () {
        try {
          ensureCurrent?.call();
          return false;
        } catch (_) {
          return true;
        }
      },
    );
    final reader = ExportPackageReader(
      fs: fs,
      limits: ExportPackageLimits(
        maxFileCount: bookmarkTransferPartCount + 1,
        maxPartBytes: bookmarkTransferPartBytes,
        maxExpandedBytes: maxStagedBytes,
      ),
    );
    final staged = await progress.run(() => reader.stage(archivePath));
    try {
      final manifest = staged.manifest;
      if ((manifest.containsCredentials ?? true) ||
          manifest.sources.length != 1) {
        throw const FormatException(
          'Sync requires one credential-free export source',
        );
      }
      final source = manifest.sources.single;
      final selection = ExportNodeSelection.explicit(
        revision.collection.kind,
        {revision.collection.source},
      );
      final parts = bookmarkTransferParts(source);
      if (parts == null || source.selection != selection) {
        throw const FormatException(
          'Sync package does not match advertised source scope',
        );
      }
      ensureCurrent?.call();
      await progress.run(
        () => database.stage(
          package: staged,
          parts: parts,
          codec: codec.records,
          cancelled: () => progress.cancelled,
        ),
      );
      ensureCurrent?.call();
      final validation = _ValidateStagedSyncBookmarks(
        database,
        detachBookmarkBackupCodec(codec),
        revision,
      );
      final recordCount = await Isolate.run(validation.run);
      ensureCurrent?.call();
      final stagedBytes = source.parts.fold(
        0,
        (bytes, part) => bytes + part.byteLength,
      );
      return (stagedBytes, recordCount);
    } finally {
      await staged.dispose();
    }
  }
}

final class _ValidateStagedSyncBookmarks {
  const _ValidateStagedSyncBookmarks(this.database, this.codec, this.revision);

  final BookmarkTransferDatabase database;
  final BookmarkBackupCodec codec;
  final SyncRevision revision;

  Future<int> run() async {
    final db = database.open(preimage: false, writable: true);
    try {
      final groups = BookmarkTransferDatabase.groupDefinitions(db);
      if (groups.length != 1 ||
          groups.single.id != revision.collection.source ||
          groups.single.parentGroupId != null ||
          BookmarkTransferDatabase.hasUngrouped(db)) {
        throw const FormatException(
          'Sync package does not match advertised source scope',
        );
      }

      // Store the key for each row on disk so the canonical hash uses Dart's
      // UTF-16 ordering without collecting all payloads or keys in memory.
      db.execute('''
        PRAGMA journal_mode = OFF;
        PRAGMA cache_size = -8192;
        BEGIN;
        CREATE TABLE semantic_order (
          key BLOB PRIMARY KEY, bookmark_id INTEGER NOT NULL
        ) WITHOUT ROWID;
      ''');
      final records = codec.records;
      final insert = db.prepare('INSERT INTO semantic_order VALUES (?, ?)');
      var count = 0;
      try {
        final rows = db.prepare('SELECT id, wire FROM records');
        try {
          final cursor = rows.selectCursor();
          while (cursor.moveNext()) {
            final row = cursor.current;
            final record = records.decode(jsonDecode(row['wire'] as String));
            final key = syncBookmarkSemanticSortKey(
              syncBookmarkMemberKey(record),
            );
            insert.execute([key, row['id']]);
            count++;
          }
        } finally {
          rows.close();
        }
      } finally {
        insert.close();
      }
      db.execute('COMMIT');

      Iterable<String> fragments() sync* {
        final sorted = db.prepare('''
          SELECT r.wire FROM semantic_order o
          CROSS JOIN records r ON r.id = o.bookmark_id
          ORDER BY o.key
        ''');
        try {
          final cursor = sorted.selectCursor();
          while (cursor.moveNext()) {
            final record = records.decode(
              jsonDecode(cursor.current['wire'] as String),
            );
            yield syncBookmarkSemanticEntry(record, codec).$2;
          }
        } finally {
          sorted.close();
        }
      }

      if (await hashSyncBookmarkSemanticEntries(fragments()) !=
          revision.semanticHash) {
        throw const FormatException(
          'Sync Bookmark content does not match descriptor',
        );
      }
      db.execute('DROP TABLE semantic_order');
      return count;
    } finally {
      db.close();
    }
  }
}
