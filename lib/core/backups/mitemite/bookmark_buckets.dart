import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../../../foundation/cooperative_work.dart';
import '../../bookmarks/src/types/bookmark.dart';
import '../../bookmarks/src/types/bookmark_record_fields.dart';
import '../../content/content_map.dart';
import '../export_import/package/bookmark_transfer_format.dart';
import '../export_import/package/export_package_exception.dart';
import '../sources/bookmark_backup_codec.dart';
import '../sources/bookmark_transfer_rows.dart';
import 'bookmark_package.dart';
import 'protocol.dart';
import 'storage.dart';

const _bucketCounts = [1, 16, 64, 256];
const _maxChunkBytes = 16 * 1024 * 1024;
const _bucketStrategy = 'sha256-high-bits';

int syncBookmarkBucketCount(int members) => _bucketCounts.firstWhere(
  (count) => members <= count * 256,
  orElse: () => _bucketCounts.last,
);

int syncBookmarkBucket(String memberKey, int count) {
  if (!_bucketCounts.contains(count)) {
    throw const FormatException('Invalid Bookmark partition');
  }
  return (sha256.convert(utf8.encode(memberKey)).bytes.first * count) >> 8;
}

final class SyncBookmarkChunk {
  SyncBookmarkChunk({
    required this.bucket,
    required this.part,
    required this.createdRevision,
    required this.sha256,
    required this.semanticHash,
    required this.compressedBytes,
    required this.expandedBytes,
    required this.rows,
  }) {
    if (bucket < 0 ||
        bucket >= 256 ||
        part < 0 ||
        part >= miteMiteMaxEntries ||
        !isSyncDigest(sha256) ||
        !isSyncDigest(semanticHash)) {
      throw const FormatException('Invalid Bookmark chunk');
    }
    syncPositiveInteger(createdRevision);
    syncPositiveInteger(compressedBytes, maximum: miteMiteMaxBytes);
    syncPositiveInteger(expandedBytes, maximum: _maxChunkBytes);
    syncPositiveInteger(rows, maximum: expandedBytes);
  }

  factory SyncBookmarkChunk.fromJson(Object? value) {
    final json = contentMap(value);
    return SyncBookmarkChunk(
      bucket: _nonNegative(json['bucket']),
      part: _nonNegative(json['part']),
      createdRevision: syncPositiveInteger(json['createdRevision']),
      sha256: syncString(json['sha256']),
      semanticHash: syncString(json['semanticHash']),
      compressedBytes: syncPositiveInteger(json['compressedBytes']),
      expandedBytes: syncPositiveInteger(json['expandedBytes']),
      rows: syncPositiveInteger(json['rows']),
    );
  }

  final int bucket;
  final int part;
  final int createdRevision;
  final String sha256;
  final String semanticHash;
  final int compressedBytes;
  final int expandedBytes;
  final int rows;

  String path(SyncCollectionId collection) {
    final prefix = bucket.toRadixString(16).padLeft(2, '0');
    return '${collection.directory}/chunks/$createdRevision/'
        '$prefix-$part-$sha256.ndjson.gz';
  }

  Map<String, Object?> toJson() => {
    'bucket': bucket,
    'part': part,
    'createdRevision': createdRevision,
    'sha256': sha256,
    'semanticHash': semanticHash,
    'compressedBytes': compressedBytes,
    'expandedBytes': expandedBytes,
    'rows': rows,
  };
}

int _nonNegative(Object? value) {
  if (value is! int || value < 0) {
    throw const FormatException('Invalid Bookmark chunk ordinal');
  }
  return value;
}

final class SyncBookmarkManifest {
  SyncBookmarkManifest({
    required this.collection,
    required this.revision,
    required this.bucketCount,
    required Iterable<SyncBookmarkChunk> chunks,
  }) : chunks = List.unmodifiable(chunks) {
    syncPositiveInteger(revision);
    if (collection.kind != 'bookmarks' ||
        !_bucketCounts.contains(bucketCount) ||
        this.chunks.length > miteMiteMaxEntries) {
      throw const FormatException('Invalid Bookmark manifest');
    }
    var bucket = -1;
    var nextPart = 0;
    var compressed = 0;
    var expanded = 0;
    for (final chunk in this.chunks) {
      if (chunk.bucket > bucket) {
        bucket = chunk.bucket;
        nextPart = 0;
      }
      if (chunk.bucket != bucket ||
          chunk.bucket >= bucketCount ||
          chunk.part != nextPart++ ||
          chunk.createdRevision > revision) {
        throw const FormatException('Invalid Bookmark bucket ordering');
      }
      compressed += chunk.compressedBytes;
      expanded += chunk.expandedBytes;
    }
    if (compressed > miteMiteMaxBookmarkArchiveBytes ||
        expanded > bookmarkTransferExpandedBytes) {
      throw const ExportPackageLimitException(
        'Bookmark manifest exceeds byte budget',
      );
    }
  }

  factory SyncBookmarkManifest.fromJson(Map<String, Object?> json) {
    final format = json['version'];
    if (format is! int ||
        format != miteMiteBookmarkManifestVersion ||
        json['partition'] != _bucketStrategy) {
      throw const SyncUpdateRequired();
    }
    final raw = json['chunks'];
    if (raw is! List || raw.length > miteMiteMaxEntries) {
      throw const FormatException('Invalid Bookmark chunk list');
    }
    return SyncBookmarkManifest(
      collection: SyncCollectionId(
        publisher: syncString(json['publisher']),
        kind: 'bookmarks',
        source: syncString(json['source']),
      ),
      revision: syncPositiveInteger(json['revision']),
      bucketCount: syncPositiveInteger(json['bucketCount']),
      chunks: raw.map(SyncBookmarkChunk.fromJson),
    );
  }

  final SyncCollectionId collection;
  final int revision;
  final int bucketCount;
  final List<SyncBookmarkChunk> chunks;

  Set<int> get occupied => {for (final chunk in chunks) chunk.bucket};
  Iterable<SyncBookmarkChunk> bucket(int index) =>
      chunks.where((chunk) => chunk.bucket == index);

  int get expandedBytes =>
      chunks.fold(0, (sum, chunk) => sum + chunk.expandedBytes);
  int get compressedBytes =>
      chunks.fold(0, (sum, chunk) => sum + chunk.compressedBytes);
  String get semanticHash => syncDigest(
    syncJsonBytes([
      bucketCount,
      for (final chunk in chunks)
        [chunk.bucket, chunk.part, chunk.semanticHash],
    ]),
  );

  Map<String, Object?> toJson() => {
    'version': miteMiteBookmarkManifestVersion,
    'publisher': collection.publisher,
    'source': collection.source,
    'revision': revision,
    'partition': _bucketStrategy,
    'bucketCount': bucketCount,
    'chunks': [for (final chunk in chunks) chunk.toJson()],
  };

  Uint8List encode() {
    final bytes = syncJsonBytes(toJson());
    if (bytes.length > miteMiteMaxBookmarkManifestBytes) {
      throw const ExportPackageLimitException('Bookmark manifest is too large');
    }
    return bytes;
  }

  static Future<SyncBookmarkManifest?> read(
    MiteMiteStorage storage,
    SyncRevision expected,
  ) async {
    if (!expected.bookmarkManifest) throw const SyncUpdateRequired();
    final bytes = await storage.read(
      expected.payloadPath,
      maxBytes: expected.length,
    );
    if (bytes == null) return null;
    expected.verifyPayload(bytes);
    final value = SyncBookmarkManifest.fromJson(
      contentMap(jsonDecode(utf8.decode(bytes))),
    );
    if (value.collection != expected.collection ||
        value.revision != expected.revision ||
        value.semanticHash != expected.semanticHash) {
      throw const FormatException('Bookmark manifest does not match catalog');
    }
    return value;
  }
}

typedef SyncBucketMember = ({String key, DateTime addedAt, Bookmark record});
typedef SyncEncodedChunk = ({SyncBookmarkChunk reference, Uint8List bytes});

String _semanticRow(String key, DateTime date, String fragment) =>
    jsonEncode([key, date.toUtc().toIso8601String(), fragment]);

/// Only one bucket is assembled at a time. Bytes from its parts stay scoped to
/// that bucket, with a fixed limit per expanded object.
Iterable<SyncEncodedChunk> encodeSyncBookmarkBucket({
  required List<SyncBucketMember> members,
  required BookmarkBackupCodec codec,
  required int bucket,
  required int revision,
}) sync* {
  final ordered = members.toList()..sort((a, b) => a.key.compareTo(b.key));
  var part = 0;
  var rows = 0;
  final body = BytesBuilder(copy: false);
  final semantic = BytesBuilder(copy: false);
  SyncEncodedChunk finish() {
    final raw = body.takeBytes();
    final bytes = Uint8List.fromList(gzip.encode(raw));
    final reference = SyncBookmarkChunk(
      bucket: bucket,
      part: part++,
      createdRevision: revision,
      sha256: syncDigest(bytes),
      semanticHash: syncDigest(semantic.takeBytes()),
      compressedBytes: bytes.length,
      expandedBytes: raw.length,
      rows: rows,
    );
    rows = 0;
    return (reference: reference, bytes: bytes);
  }

  String? previous;
  for (final member in ordered) {
    final record = bookmarkWithId(member.record, 0);
    final wire = syncBookmarkPublicationRecord(
      codec.records.encodeForTransfer(record),
    );
    final (key, fragment) = syncBookmarkSemanticEntry(
      codec.records.decode(wire),
      codec,
    );
    if (key != member.key || key == previous) {
      throw const FormatException('Duplicate or inconsistent Bookmark key');
    }
    previous = key;
    final line = utf8.encode(
      '${canonicalSyncJson({
        'key': key,
        'addedAt': member.addedAt.toUtc().toIso8601String(),
        'record': wire,
      })}\n',
    );
    if (line.length - 1 > bookmarkTransferRowBytes) {
      throw const ExportPackageLimitException('Bookmark row is too large');
    }
    if (body.length + line.length > _maxChunkBytes) yield finish();
    body.add(line);
    semantic.add(
      utf8.encode('${_semanticRow(key, member.addedAt, fragment)}\n'),
    );
    rows++;
  }
  if (rows != 0) yield finish();
}

Future<Uint8List?> readSyncBookmarkChunk(
  MiteMiteStorage storage,
  SyncCollectionId collection,
  SyncBookmarkChunk chunk,
) async {
  final bytes = await storage.read(
    chunk.path(collection),
    maxBytes: chunk.compressedBytes,
  );
  if (bytes != null &&
      (bytes.length != chunk.compressedBytes ||
          syncDigest(bytes) != chunk.sha256)) {
    throw const FormatException('Bookmark chunk authentication failed');
  }
  return bytes;
}

Stream<SyncBucketMember> visitSyncBookmarkChunk({
  required Uint8List bytes,
  required SyncBookmarkChunk chunk,
  required int bucketCount,
  required BookmarkBackupCodec codec,
  void Function()? ensureCurrent,
}) async* {
  var expanded = 0;
  // Check the expanded size between slices of compressed input.
  Iterable<Uint8List> slices() sync* {
    const sliceBytes = 8 * 1024;
    for (var offset = 0; offset < bytes.length; offset += sliceBytes) {
      yield Uint8List.sublistView(
        bytes,
        offset,
        min(bytes.length, offset + sliceBytes),
      );
    }
  }

  final compressed = Stream<List<int>>.fromIterable(slices())
      .transform(gzip.decoder);
  Stream<List<int>> bounded() async* {
    await for (final block in compressed) {
      expanded += block.length;
      if (expanded > chunk.expandedBytes) {
        throw const ExportPackageLimitException(
          'Bookmark chunk exceeds expanded length',
        );
      }
      yield block;
    }
  }

  final semantic = BytesBuilder(copy: false);
  var rows = 0;
  String? previous;
  final work = CooperativeWork();
  await for (final wire in readBookmarkTransferRows(bounded())) {
    ensureCurrent?.call();
    final key = syncString(wire['key']);
    final rawDate = syncString(wire['addedAt']);
    final addedAt = DateTime.parse(rawDate).toUtc();
    final record = codec.records.decode(wire['record']);
    final (actual, fragment) = syncBookmarkSemanticEntry(record, codec);
    if (previous != null && previous.compareTo(key) >= 0 ||
        addedAt.toIso8601String() != rawDate ||
        record.id != 0 ||
        actual != key ||
        syncBookmarkBucket(key, bucketCount) != chunk.bucket ||
        ++rows > chunk.rows) {
      throw const FormatException('Invalid Bookmark chunk member');
    }
    previous = key;
    semantic.add(utf8.encode('${_semanticRow(key, addedAt, fragment)}\n'));
    yield (key: key, addedAt: addedAt, record: record);
    if (work.checkpoint() case final pause?) await pause;
  }
  if (expanded != chunk.expandedBytes ||
      rows != chunk.rows ||
      syncDigest(semantic.takeBytes()) != chunk.semanticHash) {
    throw const FormatException(
      'Bookmark chunk counts or semantics do not match',
    );
  }
}
