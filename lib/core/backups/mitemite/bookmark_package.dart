import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../../../foundation/filesystem.dart';
import '../../bookmarks/src/types/bookmark.dart';
import '../export_import/models/package_manifest.dart';
import '../export_import/package/export_package_writer.dart';
import '../export_import/models/export_selection.dart';
import '../export_import/package/export_package_reader.dart';
import '../export_import/package/export_package_limits.dart';
import '../export_import/package/export_package_exception.dart';
import '../sources/bookmark_backup_codec.dart';
import '../sources/bookmark_backup_schema.dart';
import '../sources/detached_bookmark_codec.dart';
import '../sources/bookmark_backup_data.dart';
import '../utils/data_converter.dart';
import 'protocol.dart';
import 'seen_state.dart';

/// A bounded Bookmark package for exactly one source Group's direct membership.
/// Hierarchy and current names come from its signed catalog, not an old archive.
/// It grants no subscription, profile binding, mirror ownership or apply right.
final class ValidatedSyncBookmarkPackage {
  ValidatedSyncBookmarkPackage._(
    this.collection,
    this._payload,
    this._codec,
    this.semanticHash,
    this.schemaVersion,
    this.recordCount,
    this.payloadByteLength,
    Uint8List bytes, {
    this.forPublication = false,
  }) : bytes = Uint8List.fromList(bytes).asUnmodifiableView();
  // Include detached materialization retained before transaction admission.
  int get retainedByteLength => bytes.length * 2 + _payload.length * 8;
  final bool forPublication;
  final SyncCollectionId collection;
  final String _payload;
  final BookmarkBackupCodec _codec;
  // Each consumer owns a detached decode. Edits cannot change prepared evidence
  // or the data another consumer later materializes for transactional apply.
  BookmarkBackupData get data => _codec.parse(decodeData(data: _payload));
  Future<BookmarkBackupData> materialize() => Isolate.run(
    _BookmarkDecodeTask(_payload, detachBookmarkBackupCodec(_codec)).run,
  );
  Future<void> writeStagedPayload(AppFileSystem fs, String path) =>
      fs.writeString(path, _payload);

  final String semanticHash;
  final int recordCount;
  final int payloadByteLength;
  final Uint8List bytes;
  final int schemaVersion;

  // Existing remote-only revisions retain the published version.
  static const schema = kRemoteBookmarksBackupVersion;
  static bool supportsSchema(int version) => isNestedBookmarkBackup(version);
}

final class SyncBookmarkPackageValidator {
  const SyncBookmarkPackageValidator({
    required this.fs,
    required this.codec,
    this.useWorker = true,
  });
  final bool useWorker;
  final AppFileSystem fs;
  final BookmarkBackupCodec codec;

  Future<ValidatedSyncBookmarkPackage> validate({
    required SyncCollectionId collection,
    required Uint8List bytes,
    int maxPreparedBytes = miteMiteMaxBookmarkPackagePreparationBytes,
  }) async {
    if (useWorker && fs.runtimeType == IoFileSystem) {
      return Isolate.run(
        _BookmarkValidateTask(
          collection,
          TransferableTypedData.fromList([bytes]),
          detachBookmarkBackupCodec(codec),
          maxPreparedBytes,
        ).run,
      );
    }
    if (collection.kind != 'bookmarks' || bytes.isEmpty) {
      throw const FormatException('Invalid Bookmark sync package');
    }
    if (bytes.length > miteMiteMaxBytes) {
      throw const ExportPackageLimitException(
        'Bookmark sync archive is too large',
      );
    }
    // Bound expansion before reading JSON, including space for detached input,
    // UTF-16 text and the parsed domain snapshot. The transport limit alone
    // cannot constrain a small, highly compressed archive.
    final budget = maxPreparedBytes.clamp(
      0,
      miteMiteMaxBookmarkPackagePreparationBytes,
    );
    final expandedBudget = (budget - bytes.length * 2) ~/ 8;
    if (expandedBudget <= 0) {
      throw const ExportPackageLimitException(
        'Sync package exceeds preparation budget',
      );
    }
    final captured = Uint8List.fromList(bytes);
    final scratch = await fs.createTempDirectory('boorusama_sync_validate_');
    try {
      final path = '$scratch/revision.bsexport';
      await fs.writeBytes(path, captured);
      final staged = await ExportPackageReader(
        fs: fs,
        limits: ExportPackageLimits(
          maxFileCount: 2,
          maxManifestBytes: expandedBudget.clamp(0, 1024 * 1024),
          maxPartBytes: expandedBudget,
          maxExpandedBytes: expandedBudget,
        ),
      ).stage(path);
      try {
        final manifest = staged.manifest;
        if (manifest.format != kExportPackageFormat ||
            (manifest.containsCredentials ?? true) ||
            manifest.sources.length != 1) {
          throw const FormatException(
            'Sync requires one credential-free export source',
          );
        }
        final source = manifest.sources.single;
        if (source.id != collection.kind ||
            !isNestedBookmarkBackup(source.schemaVersion)) {
          throw const SyncUpdateRequired();
        }
        if (source.parts.length != 1) {
          throw const FormatException('Invalid sync source parts');
        }
        final encoded = await fs.readString(
          staged.pathFor(source.parts.single.path),
        );
        final payload = decodeData(data: encoded);
        if (payload.version != source.schemaVersion) {
          throw const SyncUpdateRequired();
        }
        final data = codec.parse(payload);
        requireSyncBookmarkScope(data, collection);
        return ValidatedSyncBookmarkPackage._(
          collection,
          encoded,
          codec,
          syncBookmarkSemanticHash(data, codec),
          source.schemaVersion,
          data.records.length,
          source.parts.single.byteLength,
          captured,
        );
      } finally {
        await staged.dispose();
      }
    } finally {
      await fs.deleteDirectory(scratch, recursive: true);
    }
  }
}

void requireSyncBookmarkScope(
  BookmarkBackupData data,
  SyncCollectionId collection,
) {
  if (collection.kind != 'bookmarks' ||
      data.folders.isNotEmpty ||
      data.groups.length != 1) {
    throw const FormatException('Sync package contains unrelated organization');
  }
  final group = data.groups.single;
  if (group.id != collection.source ||
      group.parentGroupId != null ||
      group.folderId != null ||
      group.bookmarkIds.toSet().length != data.records.length ||
      !group.bookmarkIds.toSet().containsAll(
        data.records.map((record) => record.id),
      )) {
    throw const FormatException(
      'Sync package does not match advertised source scope',
    );
  }
}

// Sharing selected content must not disclose local queries or listing positions.
Object? _withoutBrowsingContext(Object? value) => switch (value) {
  Map() => {
    for (final entry in value.entries)
      entry.key as String: entry.key == 'common' && entry.value is Map
          ? {
              for (final field in (entry.value as Map).entries)
                if (field.key != 'metadata')
                  field.key as String: _withoutBrowsingContext(field.value),
            }
          : _withoutBrowsingContext(entry.value),
  },
  List() => value.map(_withoutBrowsingContext).toList(),
  _ => value,
};

/// Only MiteMite publication strips these local locators. Personal backups and
/// durable local records keep their existing codec contract.
Object? _withoutLocalProfileHints(Object? value) => switch (value) {
  Map() => {
    for (final entry in value.entries)
      if (entry.key != 'profileIdHint' && entry.key != 'sourceProfileHint')
        entry.key as String: _withoutLocalProfileHints(entry.value),
  },
  List() => value.map(_withoutLocalProfileHints).toList(),
  _ => value,
};

/// Use the same portable representation in legacy and streamed publications.
Map<String, Object?> syncBookmarkPublicationRecord(
  Map<String, Object?> record,
) => Map<String, Object?>.from(
  _withoutLocalProfileHints(_withoutBrowsingContext(record))! as Map,
);

/// File-local IDs, local profile hints, save/observation clocks and Group labels
/// do not cause payload churn. Actual source dates inside snapshots remain facts.
(String, String) syncBookmarkSemanticEntry(
  Bookmark record,
  BookmarkBackupCodec codec,
) {
  final key = syncBookmarkMemberKey(record);
  final wire = codec.records.encodeForTransfer(record)
    ..remove('id')
    ..remove('createdAt')
    ..remove('updatedAt')
    ..remove('observedAt')
    ..remove('sourceProfileHint');
  if (wire['kind'] == 'post') {
    final snapshot = wire['snapshot']! as Map;
    final common = Map<String, Object?>.from(snapshot['common'] as Map);
    for (final field in [
      'tags',
      'artistTags',
      'characterTags',
      'copyrightTags',
    ]) {
      if (common[field] case final List values) {
        common[field] = values.cast<String>().toList()..sort();
      }
    }
    wire['snapshot'] = {...snapshot, 'common': common};
  }
  Object? portable(Object? value) => switch (value) {
    Map() => {
      for (final entry in value.entries)
        if (entry.key != 'profileIdHint' && entry.key != 'localId')
          entry.key as String: portable(entry.value),
    },
    List() => value.map(portable).toList(),
    _ => value,
  };
  final object = canonicalSyncJson({
    key: portable(_withoutBrowsingContext(wire)),
  });
  return (key, object.substring(1, object.length - 1));
}

/// SQLite BLOB ordering reproduces Dart's UTF-16 string ordering, including
/// keys with non-BMP characters.
Uint8List syncBookmarkSemanticSortKey(String key) {
  final bytes = ByteData(key.length * 2);
  for (var i = 0; i < key.length; i++) {
    bytes.setUint16(i * 2, key.codeUnitAt(i));
  }
  return bytes.buffer.asUint8List();
}

Iterable<List<int>> _semanticChunks(Iterable<String> sortedFragments) sync* {
  yield const [123]; // {
  var separator = false;
  for (final fragment in sortedFragments) {
    if (separator) yield const [44]; // ,
    yield utf8.encode(fragment);
    separator = true;
  }
  yield const [125]; // }
}

Future<String> hashSyncBookmarkSemanticEntries(
  Iterable<String> sortedFragments,
) async =>
    (await sha256
            .bind(
              Stream.fromIterable(_semanticChunks(sortedFragments)),
            )
            .first)
        .toString();

String syncBookmarkSemanticHash(
  BookmarkBackupData data,
  BookmarkBackupCodec codec,
) {
  final fragments = <String, String>{};
  for (final record in data.records) {
    final (key, fragment) = syncBookmarkSemanticEntry(record, codec);
    if (fragments.containsKey(key)) {
      throw const FormatException('Duplicate sync member');
    }
    fragments[key] = fragment;
  }
  final keys = fragments.keys.toList()..sort();
  late Digest digest;
  final input = sha256.startChunkedConversion(
    ChunkedConversionSink<Digest>.withCallback(
      (result) => digest = result.single,
    ),
  );
  _semanticChunks(keys.map((key) => fragments[key]!)).forEach(input.add);
  input.close();
  return digest.toString();
}

/// Build a fresh credential-free archive through the existing transfer codec.
/// A caller supplies a consistent source snapshot; incoming packages cannot be
/// passed through to publication. Domain ownership still must be checked before
/// this builder is connected to publication rules.
final class SyncBookmarkPackageBuilder {
  const SyncBookmarkPackageBuilder({
    required this.fs,
    required this.codec,
    this.useWorker = true,
  });
  final bool useWorker;
  Future<String> semanticHash(BookmarkBackupData data) => Isolate.run(
    _BookmarkHashTask(data, detachBookmarkBackupCodec(codec)).run,
  );
  final AppFileSystem fs;
  final BookmarkBackupCodec codec;

  Future<ValidatedSyncBookmarkPackage> build({
    required SyncCollectionId collection,
    required BookmarkBackupData data,
    required String appVersion,
    required DateTime createdAt,
  }) async {
    if (useWorker && fs.runtimeType == IoFileSystem) {
      return Isolate.run(
        _BookmarkBuildTask(
          collection,
          data,
          detachBookmarkBackupCodec(codec),
          appVersion,
          createdAt,
        ).run,
      );
    }
    final schemaVersion = bookmarkTransferVersion(data.records);
    final scratch = await fs.createTempDirectory('boorusama_sync_build_');
    try {
      final path = await ExportPackageWriter(fs: fs).write(
        ExportPackageBuild(
          createdAt: createdAt,
          appVersion: appVersion,
          sources: [
            ExportPackageSourceBuild(
              id: 'bookmarks',
              schemaVersion: schemaVersion,
              selection: ExportNodeSelection.explicit('bookmarks', {
                collection.source,
              }),
              parts: [
                ExportPackagePartBuild(
                  path: 'bookmarks.json',
                  write: (path) => fs.writeString(
                    path,
                    jsonEncode({
                      'version': schemaVersion,
                      'data': codec
                          .encode(data)
                          .map(
                            (value) => syncBookmarkPublicationRecord(
                              Map<String, Object?>.from(value as Map),
                            ),
                          )
                          .toList(),
                      ...data.extraFields,
                    }),
                  ),
                ),
              ],
            ),
          ],
        ),
        '$scratch/revision.bsexport',
      );
      final validated = await SyncBookmarkPackageValidator(
        fs: fs,
        codec: codec,
        useWorker: false,
      ).validate(collection: collection, bytes: await fs.readBytes(path));
      return ValidatedSyncBookmarkPackage._(
        validated.collection,
        validated._payload,
        codec,
        validated.semanticHash,
        validated.schemaVersion,
        validated.recordCount,
        validated.payloadByteLength,
        validated.bytes,
        forPublication: true,
      );
    } finally {
      await fs.deleteDirectory(scratch, recursive: true);
    }
  }
}

final class _BookmarkHashTask {
  const _BookmarkHashTask(this.data, this.codec);
  final BookmarkBackupData data;
  final BookmarkBackupCodec codec;
  String run() => syncBookmarkSemanticHash(data, codec);
}

final class _BookmarkDecodeTask {
  const _BookmarkDecodeTask(this.payload, this.codec);
  final String payload;
  final BookmarkBackupCodec codec;
  BookmarkBackupData run() => codec.parse(decodeData(data: payload));
}

final class _BookmarkBuildTask {
  const _BookmarkBuildTask(
    this.collection,
    this.data,
    this.codec,
    this.version,
    this.at,
  );
  final SyncCollectionId collection;
  final BookmarkBackupData data;
  final BookmarkBackupCodec codec;
  final String version;
  final DateTime at;
  Future<ValidatedSyncBookmarkPackage> run() =>
      SyncBookmarkPackageBuilder(
        fs: const IoFileSystem(),
        codec: codec,
        useWorker: false,
      ).build(
        collection: collection,
        data: data,
        appVersion: version,
        createdAt: at,
      );
}

final class _BookmarkValidateTask {
  const _BookmarkValidateTask(
    this.collection,
    this.bytes,
    this.codec,
    this.budget,
  );
  final SyncCollectionId collection;
  final TransferableTypedData bytes;
  final BookmarkBackupCodec codec;
  final int budget;
  Future<ValidatedSyncBookmarkPackage> run() =>
      SyncBookmarkPackageValidator(
        fs: const IoFileSystem(),
        codec: codec,
        useWorker: false,
      ).validate(
        collection: collection,
        bytes: bytes.materialize().asUint8List(),
        maxPreparedBytes: budget,
      );
}
