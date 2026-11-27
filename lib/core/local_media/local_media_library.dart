// File operations can wait on provider bytes or storage on the Android UI isolate.
// ignore_for_file: avoid_slow_async_io

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import '../../foundation/filesystem/io_file_system.dart';
import '../../foundation/utils/file_utils.dart';
import '../bookmarks/src/types/bookmark_search_token.dart';
import '../posts/post/types.dart';
import '../posts/rating/types.dart';
import '../search/options/catalog/local_media.dart';
import 'local_media_models.dart';
import 'local_media_reference.dart';

typedef LocalMediaInspector = Future<LocalMediaProbe> Function(
  File file,
  LocalMediaFormat format,
);

enum LocalMediaFaultPoint { staged, importPublished, deletionStaged, committed }

/// Owns the app's only writer. The pending row and committed media record
/// determine whether recovery rolls a file operation back or finishes it.
class LocalMediaLibrary {
  LocalMediaLibrary._(this._root, this._db, this._onFault);

  static const schemaVersion = 1;
  static const _fs = IoFileSystem();
  static final _tagCountValue = RegExp(r'^(<=|>=|<|>)?([0-9]+)$');

  final Directory _root;
  final Database _db;
  final void Function(LocalMediaFaultPoint)? _onFault;
  final _changes = StreamController<LocalMediaReference>.broadcast();
  Future<void> _mutationTail = Future.value();

  Stream<LocalMediaReference> get changes => _changes.stream;
  String get _stagePath => p.join(_root.path, 'staging');
  File get _incoming => File(p.join(_stagePath, 'incoming'));
  File get _trash => File(p.join(_stagePath, 'trash'));

  static Future<LocalMediaLibrary> open(
    Directory root, {
    void Function(LocalMediaFaultPoint)? onFault,
  }) async {
    final media = Directory(p.join(root.path, 'media'));
    final file = File(p.join(root.path, 'library.db'));
    final existing = await file.exists();
    if (!existing && await media.exists() && !await media.list().isEmpty) {
      throw StateError('Local Media database is missing');
    }
    await Directory(p.join(root.path, 'staging')).create(recursive: true);
    final db = sqlite3.open(file.path);
    final library = LocalMediaLibrary._(root, db, onFault);
    try {
      db.execute('PRAGMA foreign_keys = ON');
      db.execute('PRAGMA synchronous = FULL');
      final version = db.userVersion;
      if (version == 0 && !await media.exists()) {
        library._transaction(() {
          db.execute(_schema);
          db.execute(_matchSchema);
          db.userVersion = schemaVersion;
        });
        await _fs.syncDirectory(root.path);
      } else {
        if (version != schemaVersion) {
          throw StateError('Unsupported Local Media database');
        }
        final hasReviewFilenameColumn = db
            .select(
              "SELECT 1 FROM pragma_table_info('media') WHERE name = 'original_name'",
            )
            .isNotEmpty;
        if (hasReviewFilenameColumn) {
          // Earlier review builds used this column before the first release.
          db.execute('PRAGMA secure_delete = ON');
          library._transaction(() {
            db.execute('ALTER TABLE media DROP COLUMN original_name');
          });
        }
        db.select('SELECT sha256 FROM media LIMIT 1');
        final columns = db
            .select("SELECT name FROM pragma_table_info('media')")
            .map((row) => row['name'])
            .toSet();
        // Keep installations with the original v1 library readable in place.
        library._transaction(() {
          if (!columns.contains('metadata_revision')) {
            db.execute(
              'ALTER TABLE media ADD metadata_revision INTEGER NOT NULL DEFAULT 0',
            );
          }
          db.execute(_matchSchema);
        });
      }
      await library._recover();
      return library;
    } catch (_) {
      db.close();
      await library._changes.close();
      rethrow;
    }
  }

  static const _schema = '''
    CREATE TABLE media (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      sha256 TEXT NOT NULL UNIQUE,
      md5 TEXT NOT NULL,
      format TEXT NOT NULL,
      mime TEXT NOT NULL,
      relative_path TEXT NOT NULL,
      byte_size INTEGER NOT NULL,
      width INTEGER NOT NULL,
      height INTEGER NOT NULL,
      duration_ms INTEGER,
      imported_at INTEGER NOT NULL,
      created_at INTEGER,
      rating TEXT NOT NULL DEFAULT 'unknown',
      source TEXT,
      source_md5 TEXT,
      editor_made INTEGER NOT NULL DEFAULT 0,
      damaged INTEGER NOT NULL DEFAULT 0,
      metadata_revision INTEGER NOT NULL DEFAULT 0
    );
    CREATE INDEX media_md5 ON media(md5);
    CREATE INDEX media_imported ON media(imported_at DESC, id DESC);
    CREATE TABLE media_tag (
      media_id INTEGER NOT NULL REFERENCES media(id) ON DELETE CASCADE,
      name TEXT NOT NULL,
      category TEXT NOT NULL,
      PRIMARY KEY(media_id, name)
    );
    CREATE INDEX media_tag_name ON media_tag(name, media_id);
    CREATE TABLE pending (
      id INTEGER PRIMARY KEY CHECK (id = 1),
      sha256 TEXT NOT NULL,
      format TEXT NOT NULL,
      operation TEXT NOT NULL CHECK (operation IN ('import', 'delete'))
    );
  ''';

  static const _matchSchema = '''
    CREATE TABLE IF NOT EXISTS media_exact_match (
      media_id INTEGER NOT NULL REFERENCES media(id) ON DELETE CASCADE,
      type_id INTEGER NOT NULL,
      booru_id INTEGER NOT NULL,
      host TEXT NOT NULL,
      profile_id TEXT NOT NULL,
      post_id TEXT NOT NULL,
      PRIMARY KEY (media_id, type_id, booru_id, host, profile_id, post_id)
    );
    CREATE TABLE IF NOT EXISTS media_similar_match (
      media_id INTEGER NOT NULL REFERENCES media(id) ON DELETE CASCADE,
      type_id INTEGER NOT NULL,
      booru_id INTEGER NOT NULL,
      host TEXT NOT NULL,
      profile_id TEXT NOT NULL,
      post_id TEXT NOT NULL,
      score REAL NOT NULL CHECK(score BETWEEN 0 AND 100),
      PRIMARY KEY (media_id, type_id, booru_id, host, profile_id, post_id)
    );
  ''';

  Future<void> close() async {
    await _mutationTail;
    _db.close();
    await _changes.close();
  }

  T _transaction<T>(T Function() operation) {
    _db.execute('BEGIN IMMEDIATE');
    try {
      final result = operation();
      _db.execute('COMMIT');
      return result;
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  Future<T> _mutate<T>(Future<T> Function() operation) {
    final next = _mutationTail.then((_) => operation());
    _mutationTail = next.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return next;
  }

  static String _relativePath(
    LocalMediaReference reference,
    LocalMediaFormat format,
  ) => 'media/${reference.shard}/${reference.sha256}.${format.extension}';

  File _file(LocalMediaReference reference, LocalMediaFormat format) =>
      File(p.join(_root.path, _relativePath(reference, format)));

  Row? _row(LocalMediaReference reference) => _db.select(
    'SELECT * FROM media WHERE sha256 = ?',
    [reference.sha256],
  ).firstOrNull;

  LocalMediaItem? find(LocalMediaReference reference) {
    final row = _row(reference);
    return row == null ? null : _item(row);
  }

  List<LocalMediaItem> list({
    String query = '',
    int limit = 60,
    int offset = 0,
  }) {
    final filters = _queryFilters(query);
    if (filters == null) return const [];
    return _db
        .select(
          '''
          SELECT * FROM media WHERE ${filters.condition}
          ORDER BY ${filters.order} LIMIT ? OFFSET ?
          ''',
          [...filters.arguments, limit, offset],
        )
        .map(_item)
        .toList(growable: false);
  }

  List<({String name, String category, int count})> suggestTags(
    String draft, {
    String query = '',
  }) {
    final term = BookmarkSearchToken.parse(canonicalBookmarkTag(draft)).tag;
    final filters = _queryFilters(query);
    if (term.isEmpty || filters == null) return const [];
    return [
      for (final row in _db.select(
        '''
        SELECT suggestion.name, COUNT(*) AS count,
          COALESCE(MIN(NULLIF(suggestion.category, 'general')), 'general') AS category
        FROM media_tag AS suggestion JOIN media ON media.id = suggestion.media_id
        WHERE instr(suggestion.name, ?) > 0 AND ${filters.condition}
        GROUP BY suggestion.name
        ORDER BY (suggestion.name = ?) DESC, (instr(suggestion.name, ?) = 1) DESC,
          count DESC, suggestion.name
        LIMIT 20
        ''',
        [term, ...filters.arguments, term, term],
      ))
        (
          name: row['name'] as String,
          category: row['category'] as String,
          count: row['count'] as int,
        ),
    ];
  }

  ({String condition, List<Object> arguments, String order})? _queryFilters(
    String query,
  ) {
    final clauses = <String>[];
    final arguments = <Object>[];
    var order = 'imported_at DESC, id DESC';
    for (final text in parseBookmarkSearchInput(query)) {
      final token = BookmarkSearchToken.parse(text);
      final separator = token.tag.indexOf(':');
      final key = separator < 0 ? '' : token.tag.substring(0, separator);
      final value = token.tag.substring(separator + 1);
      final equality = token.isNegative ? '!=' : '=';
      switch (key) {
        case localMediaRatingKey:
          final rating = Rating.parse(value);
          if (rating == Rating.unknown && value != 'unknown') return null;
          clauses.add('rating $equality ?');
          arguments.add(rating.name);
        case localMediaFormatKey:
          final format = LocalMediaFormat.values
              .where(
                (format) => format.extension == value || format.name == value,
              )
              .firstOrNull;
          if (format == null) return null;
          clauses.add('format $equality ?');
          arguments.add(format.name);
        case localMediaTagCountKey:
          final match = _tagCountValue.firstMatch(value);
          if (match == null) return null;
          final count = int.tryParse(match[2]!);
          if (count == null) return null;
          final operator = match[1] ?? '=';
          const tagRows = 'FROM media_tag WHERE media_id = media.id';
          if (count == 0 && (operator == '=' || operator == '>')) {
            final exclude = (operator == '=') != token.isNegative;
            clauses.add("${exclude ? 'NOT ' : ''}EXISTS (SELECT 1 $tagRows)");
          } else {
            final exclude = token.isNegative ? 'NOT ' : '';
            clauses.add('$exclude((SELECT COUNT(*) $tagRows) $operator ?)');
            arguments.add(count);
          }
        case localMediaOrderKey:
          final selected = switch (value) {
            'newest' => 'imported_at DESC, id DESC',
            'oldest' => 'imported_at ASC, id ASC',
            'largest' => 'byte_size DESC, imported_at DESC, id DESC',
            'smallest' => 'byte_size ASC, imported_at DESC, id DESC',
            _ => null,
          };
          if (selected == null || token.isNegative) return null;
          order = selected;
        default:
          clauses.add(
            "${token.isNegative ? 'NOT ' : ''}EXISTS "
            '(SELECT 1 FROM media_tag WHERE media_id = media.id AND name = ?)',
          );
          arguments.add(token.tag);
      }
    }
    return (
      condition: clauses.isEmpty ? '1' : clauses.join(' AND '),
      arguments: arguments,
      order: order,
    );
  }

  LocalMediaItem _item(Row row) {
    final id = row['id'] as int;
    return LocalMediaItem(
      id: id,
      reference: LocalMediaReference.parse(row['sha256'] as String),
      md5: row['md5'] as String,
      format: LocalMediaFormat.values.byName(row['format'] as String),
      byteSize: row['byte_size'] as int,
      importedAt: DateTime.fromMillisecondsSinceEpoch(
        row['imported_at'] as int,
        isUtc: true,
      ),
      createdAt: switch (row['created_at']) {
        final int time => DateTime.fromMillisecondsSinceEpoch(
          time,
          isUtc: true,
        ),
        _ => null,
      },
      probe: (
        width: row['width'] as int,
        height: row['height'] as int,
        durationMs: row['duration_ms'] as int?,
      ),
      tags: [
        for (final tag in _db.select(
          'SELECT name, category FROM media_tag WHERE media_id = ? ORDER BY name',
          [id],
        ))
          (name: tag['name'] as String, category: tag['category'] as String),
      ],
      rating: Rating.values.byName(row['rating'] as String),
      source: row['source'] as String?,
      sourceMd5: row['source_md5'] as String?,
      editorMade: row['editor_made'] == 1,
      metadataRevision: row['metadata_revision'] as int,
    );
  }

  Future<File?> resolve(LocalMediaReference reference) async {
    final row = _row(reference);
    if (row == null || row['damaged'] == 1) return null;
    return _completeFile(reference, row);
  }

  Future<File?> _completeFile(LocalMediaReference reference, Row row) async {
    final format = LocalMediaFormat.values.byName(row['format'] as String);
    final file = _file(reference, format);
    if (await FileSystemEntity.type(file.path, followLinks: false) !=
        FileSystemEntityType.file) {
      return null;
    }
    try {
      return await file.length() == row['byte_size'] ? file : null;
    } on PathNotFoundException {
      return null;
    }
  }

  Future<bool> _matchesHash(File file, LocalMediaReference reference) async {
    try {
      return (await sha256.bind(file.openRead()).first).toString() ==
          reference.sha256;
    } on FileSystemException {
      return false;
    }
  }

  Future<void> edit(
    LocalMediaReference reference, {
    required Iterable<LocalMediaTag> tags,
    required Rating rating,
  }) => _mutate(() async {
    final normalized = {
      for (final tag in tags.map(normalizeLocalMediaTag))
        tag.name: tag.category,
    };
    final row = _row(reference);
    if (row == null) return;
    final id = row['id'] as int;
    _transaction(() {
      _db.execute(
        'UPDATE media SET rating = ?, metadata_revision = metadata_revision + 1 WHERE id = ?',
        [rating.name, id],
      );
      _replaceTags(id, normalized);
    });
    _changes.add(reference);
  });

  List<LocalMediaExactMatch> exactMatches(int itemId) => [
    for (final row in _db.select(
      'SELECT * FROM media_exact_match WHERE media_id = ? ORDER BY host, profile_id, post_id',
      [itemId],
    ))
      (
        origin: _matchOrigin(row),
        postId: row['post_id'] as String,
      ),
  ];

  List<LocalMediaSimilarMatch> similarMatches(int itemId) => [
    for (final row in _db.select(
      'SELECT * FROM media_similar_match WHERE media_id = ? ORDER BY score DESC, host, profile_id, post_id',
      [itemId],
    ))
      (
        origin: _matchOrigin(row),
        postId: row['post_id'] as String,
        score: row['score'] as double,
      ),
  ];

  PostOrigin _matchOrigin(Row row) => PostOrigin.fromSnapshot(
    PostOriginSnapshot(
      booruTypeId: row['type_id'] as int,
      booruId: row['booru_id'] as int,
      sourceHost: row['host'] as String,
      profileIdHint: row['profile_id'] as String,
    ),
  );

  /// Rechecks the item and lookup state inside the same writer as local edits.
  Future<LocalMediaEnrichmentResult> applyEnrichment(
    LocalMediaItem original,
    LocalMediaEnrichment? Function() resolve, {
    LocalMediaSimilarMatch? similarMatch,
  }) => _mutate(() async {
    final row = _row(original.reference);
    if (row == null ||
        row['id'] != original.id ||
        row['damaged'] == 1 ||
        await _completeFile(original.reference, row) == null) {
      return LocalMediaEnrichmentResult.skipped;
    }
    final enrichment = resolve();
    if (enrichment == null) return LocalMediaEnrichmentResult.skipped;
    var updated = false;
    var matchesUpdated = false;
    _transaction(() {
      if (row['metadata_revision'] == original.metadataRevision) {
        for (final tag in enrichment.tags) {
          _db.execute(
            'INSERT OR IGNORE INTO media_tag VALUES (?, ?, ?)',
            [original.id, tag.name, tag.category],
          );
          updated |= _db.updatedRows > 0;
        }
        final rating = row['rating'] == Rating.unknown.name
            ? enrichment.rating.name
            : row['rating'];
        final originalSource = row['source'] as String?;
        final source = (originalSource?.trim().isEmpty ?? true)
            ? enrichment.source ?? originalSource
            : originalSource;
        if (rating != row['rating'] || source != originalSource) {
          _db.execute('UPDATE media SET rating = ?, source = ? WHERE id = ?', [
            rating,
            source,
            original.id,
          ]);
          updated = true;
        }
        if (similarMatch case final match?) {
          final origin = match.origin;
          _db.execute(
            'INSERT OR IGNORE INTO media_similar_match VALUES (?, ?, ?, ?, ?, ?, ?)',
            [
              original.id,
              origin.booruType.id,
              origin.booruId,
              origin.sourceHost,
              origin.profileIdHint,
              match.postId,
              match.score,
            ],
          );
          matchesUpdated |= _db.updatedRows > 0;
        }
      }
      for (final match in enrichment.matches) {
        final origin = match.origin;
        _db.execute(
          'INSERT OR IGNORE INTO media_exact_match VALUES (?, ?, ?, ?, ?, ?)',
          [
            original.id,
            origin.booruType.id,
            origin.booruId,
            origin.sourceHost,
            origin.profileIdHint,
            match.postId,
          ],
        );
        matchesUpdated |= _db.updatedRows > 0;
      }
    });
    if (updated || matchesUpdated) _changes.add(original.reference);
    return (updated || (similarMatch != null && matchesUpdated))
        ? LocalMediaEnrichmentResult.updated
        : LocalMediaEnrichmentResult.unchanged;
  });

  void _replaceTags(int id, Map<String, String> tags) {
    _db.execute('DELETE FROM media_tag WHERE media_id = ?', [id]);
    for (final entry in tags.entries) {
      _db.execute('INSERT INTO media_tag VALUES (?, ?, ?)', [
        id,
        entry.key,
        entry.value,
      ]);
    }
  }

  Future<LocalMediaImportResult> import(
    Stream<Uint8List> bytes, {
    required LocalMediaInspector inspect,
    required LocalMediaCancellation cancellation,
    required LocalMediaImportBudget budget,
    DateTime? createdAt,
    Iterable<LocalMediaTag> tags = const [],
    Rating rating = Rating.unknown,
    String? source,
    String? sourceMd5,
    bool editorMade = false,
    DateTime Function()? clock,
    void Function(LocalMediaItem)? onImported,
  }) => _mutate(() async {
    await _recover();
    try {
      final staged = await _copy(bytes, cancellation, budget);
      _onFault?.call(LocalMediaFaultPoint.staged);
      final reference = staged.reference;
      final row = _row(reference);
      final existingFile = row == null ? null : await resolve(reference);
      if (existingFile != null && await _matchesHash(existingFile, reference)) {
        return LocalMediaImportResult.duplicate;
      }
      final normalized = {
        for (final tag in tags.map(normalizeLocalMediaTag))
          tag.name: tag.category,
      };
      final probe = await inspect(_incoming, staged.format);
      cancellation.check();
      final destination = _file(reference, staged.format);
      await destination.parent.create(recursive: true);
      await _fs.syncDirectory(p.dirname(destination.parent.path));
      await _fs.syncDirectory(_root.path);
      await _fs.syncDirectory(_stagePath);
      cancellation.check();
      _setPending(reference, staged.format, 'import');
      // Stage and destination are on the same private volume. The proven hash
      // makes it safe to replace a known damaged copy at the destination.
      await _incoming.rename(destination.path);
      await _syncParents(destination);
      _onFault?.call(LocalMediaFaultPoint.importPublished);
      _transaction(() {
        if (row == null) {
          _db.execute(
            '''
            INSERT INTO media (
              sha256, md5, format, mime, relative_path, byte_size, width,
              height, duration_ms, imported_at, created_at,
              rating, source, source_md5, editor_made
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ''',
            [
              reference.sha256,
              staged.md5,
              staged.format.name,
              staged.format.mime,
              _relativePath(reference, staged.format),
              staged.byteSize,
              probe.width,
              probe.height,
              probe.durationMs,
              (clock?.call() ?? DateTime.now()).millisecondsSinceEpoch,
              createdAt?.millisecondsSinceEpoch,
              rating.name,
              source,
              sourceMd5,
              editorMade ? 1 : 0,
            ],
          );
          _replaceTags(_db.lastInsertRowId, normalized);
        } else {
          _db.execute('UPDATE media SET damaged = 0 WHERE sha256 = ?', [
            reference.sha256,
          ]);
        }
        _clearPending();
      });
      _changes.add(reference);
      _onFault?.call(LocalMediaFaultPoint.committed);
      if (row != null) return LocalMediaImportResult.repaired;
      if (onImported != null && !staged.format.isVideo && normalized.isEmpty) {
        onImported(_item(_row(reference)!));
      }
      return LocalMediaImportResult.imported;
    } finally {
      await _deleteIfPresent(_incoming);
    }
  });

  Future<
    ({
      LocalMediaReference reference,
      String md5,
      LocalMediaFormat format,
      int byteSize,
    })
  >
  _copy(
    Stream<Uint8List> bytes,
    LocalMediaCancellation cancellation,
    LocalMediaImportBudget budget,
  ) async {
    final sha = _DigestSink();
    final md = _DigestSink();
    final shaInput = sha256.startChunkedConversion(sha);
    final mdInput = md5.startChunkedConversion(md);
    final prefix = BytesBuilder();
    final output = await _incoming.open(mode: FileMode.write);
    LocalMediaFormat? format;
    var size = 0;
    try {
      await for (final chunk in bytes) {
        cancellation.check();
        budget.record(chunk.length);
        size += chunk.length;
        if (format == null && prefix.length < 16) {
          final remaining = 16 - prefix.length;
          prefix.add(
            chunk.length <= remaining ? chunk : chunk.sublist(0, remaining),
          );
          if (prefix.length == 16) {
            format = LocalMediaFormat.detect(prefix.toBytes());
            if (format == null) throw const LocalMediaUnsupported();
          }
        }
        final max = (format?.isVideo ?? false)
            ? LocalMediaImportBudget.videoBytes
            : LocalMediaImportBudget.imageBytes;
        if (size > max) throw const LocalMediaLimit();
        await output.writeFrom(chunk);
        shaInput.add(chunk);
        mdInput.add(chunk);
      }
      cancellation.check();
      format ??= LocalMediaFormat.detect(prefix.toBytes());
      if (format == null) throw const LocalMediaUnsupported();
      await output.flush();
      shaInput.close();
      mdInput.close();
      return (
        reference: LocalMediaReference.parse(sha.digest!.toString()),
        md5: md.digest!.toString(),
        format: format,
        byteSize: size,
      );
    } finally {
      await output.close();
    }
  }

  Future<({int bytes, int items})> storageUsage() async {
    final usage = await getDirectorySize(_fs, _root.path);
    final rows = _db.select('SELECT COUNT(*) AS count FROM media');
    return (bytes: usage.size, items: rows.single['count'] as int);
  }

  Future<void> clear() => _mutate(() async {
    await _recover();
    final rows = _db.select('SELECT sha256 FROM media');
    for (final row in rows) {
      await _delete(LocalMediaReference.parse(row['sha256'] as String));
    }
    _db.execute('VACUUM');
  });

  Future<void> delete(LocalMediaReference reference) => _mutate(() async {
    await _recover();
    await _delete(reference);
  });

  Future<void> _delete(LocalMediaReference reference) async {
    final row = _row(reference);
    if (row == null) return;
    final format = LocalMediaFormat.values.byName(row['format'] as String);
    final file = _file(reference, format);
    _setPending(reference, format, 'delete');
    if (await file.exists()) {
      await file.rename(_trash.path);
      await _syncParents(file);
    }
    _onFault?.call(LocalMediaFaultPoint.deletionStaged);
    // Retain the journal until trash removal is durable.
    _db.execute('DELETE FROM media WHERE sha256 = ?', [reference.sha256]);
    _changes.add(reference);
    _onFault?.call(LocalMediaFaultPoint.committed);
    await _deleteIfPresent(_trash);
    await _fs.syncDirectory(_stagePath);
    _clearPending();
  }

  Future<void> _syncParents(File file) async {
    await _fs.syncDirectory(file.parent.path);
    await _fs.syncDirectory(_stagePath);
  }

  void _setPending(
    LocalMediaReference reference,
    LocalMediaFormat format,
    String operation,
  ) => _db.execute('INSERT INTO pending VALUES (1, ?, ?, ?)', [
    reference.sha256,
    format.name,
    operation,
  ]);

  void _clearPending() => _db.execute('DELETE FROM pending WHERE id = 1');

  Future<void> _recover() async {
    final pending = _db.select('SELECT * FROM pending').firstOrNull;
    if (pending != null) {
      final reference = LocalMediaReference.parse(pending['sha256'] as String);
      final format = LocalMediaFormat.values.byName(
        pending['format'] as String,
      );
      final file = _file(reference, format);
      final exists = _row(reference) != null;
      if (pending['operation'] == 'delete') {
        if (exists && await _trash.exists() && !await file.exists()) {
          await _trash.rename(file.path);
          await _syncParents(file);
        } else {
          await _deleteIfPresent(_trash);
          await _fs.syncDirectory(_stagePath);
        }
      } else if (!exists && await file.exists()) {
        await file.delete();
        await _fs.syncDirectory(file.parent.path);
      }
      _clearPending();
    }
    await _deleteIfPresent(_incoming);
  }

  static Future<void> _deleteIfPresent(File file) async {
    if (await file.exists()) await file.delete();
  }
}

final class _DigestSink implements Sink<Digest> {
  Digest? digest;

  @override
  void add(Digest data) => digest = data;

  @override
  void close() {}
}
