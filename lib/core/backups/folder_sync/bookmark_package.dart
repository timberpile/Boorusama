import 'dart:convert';
import 'dart:typed_data';

import '../../../foundation/filesystem.dart';
import '../export_import/models/package_manifest.dart';
import '../export_import/package/export_package_writer.dart';
import '../export_import/models/export_selection.dart';
import '../export_import/package/export_package_reader.dart';
import '../sources/bookmark_backup_codec.dart';
import '../sources/bookmark_backup_data.dart';
import '../utils/data_converter.dart';
import 'protocol.dart';
import 'reading_state.dart';

/// A bounded v10 package for exactly one source Group's direct membership.
/// Hierarchy and current names come from its signed catalog, not an old archive.
/// It grants no subscription, profile binding, mirror ownership or apply right.
final class ValidatedSyncBookmarkPackage {
  ValidatedSyncBookmarkPackage._(
    this.collection,
    this._payload,
    this._codec,
    this.semanticHash,
    Uint8List bytes, {
    this.forPublication = false,
  }) : bytes = Uint8List.fromList(bytes).asUnmodifiableView();
  final bool forPublication;
  final SyncCollectionId collection;
  final String _payload;
  final BookmarkBackupCodec _codec;
  // Each consumer owns a detached decode. Edits cannot change prepared evidence
  // or the data another consumer later materializes for transactional apply.
  BookmarkBackupData get data => _codec.parse(decodeData(data: _payload));
  final String semanticHash;
  final Uint8List bytes;
  static const schema = 10;
}

final class SyncBookmarkPackageValidator {
  const SyncBookmarkPackageValidator({required this.fs, required this.codec});
  final AppFileSystem fs;
  final BookmarkBackupCodec codec;

  Future<ValidatedSyncBookmarkPackage> validate({
    required SyncCollectionId collection,
    required Uint8List bytes,
  }) async {
    if (collection.kind != 'bookmarks' ||
        bytes.isEmpty ||
        bytes.length > folderSyncMaxBytes) {
      throw const FormatException('Invalid Bookmark sync package');
    }
    final captured = Uint8List.fromList(bytes);
    final scratch = await fs.createTempDirectory('boorusama_sync_validate_');
    try {
      final path = '$scratch/revision.bsexport';
      await fs.writeBytes(path, captured);
      final staged = await ExportPackageReader(fs: fs).stage(path);
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
            source.schemaVersion != ValidatedSyncBookmarkPackage.schema) {
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

/// File-local IDs, local profile hints, save/observation clocks and Group labels
/// do not cause payload churn. Actual source dates inside snapshots remain facts.
String syncBookmarkSemanticHash(
  BookmarkBackupData data,
  BookmarkBackupCodec codec,
) {
  final content = <String, Object?>{};
  for (final record in data.records) {
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
    if (content.containsKey(key)) {
      throw const FormatException('Duplicate sync member');
    }
    content[key] = portable(_withoutBrowsingContext(wire));
  }
  return syncDigest(utf8.encode(canonicalSyncJson(content)));
}

/// Build a fresh credential-free archive through the existing transfer codec.
/// A caller supplies a consistent source snapshot; incoming packages cannot be
/// passed through to publication. Domain ownership still must be checked before
/// this builder is connected to publication rules.
final class SyncBookmarkPackageBuilder {
  const SyncBookmarkPackageBuilder({required this.fs, required this.codec});
  final AppFileSystem fs;
  final BookmarkBackupCodec codec;

  Future<ValidatedSyncBookmarkPackage> build({
    required SyncCollectionId collection,
    required BookmarkBackupData data,
    required String appVersion,
    required DateTime createdAt,
  }) async {
    final scratch = await fs.createTempDirectory('boorusama_sync_build_');
    try {
      final path = await ExportPackageWriter(fs: fs).write(
        ExportPackageBuild(
          createdAt: createdAt,
          appVersion: appVersion,
          sources: [
            ExportPackageSourceBuild(
              id: 'bookmarks',
              schemaVersion: ValidatedSyncBookmarkPackage.schema,
              selection: ExportNodeSelection.explicit('bookmarks', {
                collection.source,
              }),
              parts: [
                ExportPackagePartBuild(
                  path: 'bookmarks.json',
                  write: (path) => fs.writeString(
                    path,
                    jsonEncode({
                      'version': ValidatedSyncBookmarkPackage.schema,
                      'data': codec
                          .encode(data)
                          .map(_withoutBrowsingContext)
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
      ).validate(collection: collection, bytes: await fs.readBytes(path));
      return ValidatedSyncBookmarkPackage._(
        validated.collection,
        validated._payload,
        codec,
        validated.semanticHash,
        validated.bytes,
        forPublication: true,
      );
    } finally {
      await fs.deleteDirectory(scratch, recursive: true);
    }
  }
}
