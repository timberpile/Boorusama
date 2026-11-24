import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import '../../../foundation/filesystem.dart';
import '../../search/following_topics/src/compatibility/topic_storage_contract.dart';
import '../export_import/models/export_selection.dart';
import '../export_import/models/package_manifest.dart';
import '../export_import/package/export_package_limits.dart';
import '../export_import/package/export_package_reader.dart';
import '../export_import/package/export_package_writer.dart';
import '../sources/following_topic_backup_codec.dart';
import '../sources/following_topic_backup_data.dart';
import '../sources/search_backup_profile.dart';
import '../utils/data_converter.dart';
import 'protocol.dart';

/// One Topic or folder/Feed definition. Hierarchy and recursive coverage are
/// authenticated by the catalog; caches and receiver operational state never
/// enter this credential-free .bsexport source.
final class ValidatedSyncFollowingPackage {
  ValidatedSyncFollowingPackage._({
    required this.collection,
    required String payload,
    required this.semanticHash,
    required Uint8List bytes,
    this.forPublication = false,
  }) : _payload = payload,
       bytes = Uint8List.fromList(bytes).asUnmodifiableView();
  static const schema = 2;
  final SyncCollectionId collection;
  final String _payload;
  Future<FollowingTopicBackupData> materialize() =>
      Isolate.run(_FollowingDecodeTask(_payload).run);
  final String semanticHash;
  final Uint8List bytes;
  final bool forPublication;
  // Include detached materialization retained before transaction admission.
  int get retainedByteLength => bytes.length * 2 + _payload.length * 8;
  FollowingTopicBackupData get data => FollowingTopicBackupCodec().parse(
    decodeData(data: _payload),
  );
}

void requireSyncFollowingScope(
  FollowingTopicBackupData data,
  SyncCollectionId collection,
) {
  if (collection.kind != 'following_topics') {
    throw const FormatException('Invalid Following Sync source kind');
  }
  if (data.records.length == 1 && data.folders.isEmpty) {
    final topic = data.records.single;
    if (topic.id == collection.source &&
        topic.folderId == null &&
        data.homeSearchIds.length == 1 &&
        data.homeSearchIds.single == topic.id) {
      return;
    }
  }
  if (data.folders.length == 1 &&
      data.records.isEmpty &&
      data.homeSearchIds.isEmpty) {
    final folder = data.folders.single;
    if (folder.id == collection.source &&
        folder.parentId == null &&
        folder.searchIds.isEmpty) {
      return;
    }
  }
  throw const FormatException(
    'Following package contains unrelated definitions',
  );
}

FollowingTopicBackupData _portableDefinition(FollowingTopicBackupData data) =>
    FollowingTopicBackupData(
      records: [
        for (final topic in data.records)
          FollowingTopicBackupRecord(
            id: topic.id,
            name: topic.name,
            query: topic.query,
            queryStructure: topic.queryStructure,
            position: 0,
            folderPosition: 0,
            // A reference is not a saved profile. Strip private profile labels
            // and use the canonical credential-free site identity.
            profile: BackupProfileReference(
              id: topic.profile.id,
              booruType: topic.profile.booruType,
              url: normalizeBackupProfileUrl(topic.profile.url),
              name: topic.profile.booruType,
            ),
          ),
      ],
      folders: [
        for (final folder in data.folders)
          FollowingTopicFolderBackupRecord(
            id: folder.id,
            name: folder.name,
            position: 0,
            searchIds: const [],
            feedEnabled: folder.feedEnabled,
            feedMaxPosts: folder.feedMaxPosts,
          ),
      ],
      homeSearchIds: data.records.map((topic) => topic.id).toList(),
    );

String syncFollowingSemanticHash(FollowingTopicBackupData data) {
  final rows = FollowingTopicBackupCodec().encode(_portableDefinition(data));
  return syncDigest(
    syncJsonBytes([
      for (final value in rows)
        if (value is Map)
          {
            ...value,
            if (value['profile'] case final Map profile)
              'profile': {
                'booruType': profile['booruType'],
                'url': profile['url'],
              },
          },
    ]),
  );
}

final class SyncFollowingPackageValidator {
  const SyncFollowingPackageValidator({
    required this.fs,
    this.useWorker = true,
  });
  final bool useWorker;
  final AppFileSystem fs;

  Future<ValidatedSyncFollowingPackage> validate({
    required SyncCollectionId collection,
    required Uint8List bytes,
    int maxPreparedBytes = 64 * 1024 * 1024,
  }) async {
    if (useWorker && fs.runtimeType == IoFileSystem) {
      return Isolate.run(
        _FollowingValidateTask(
          collection,
          TransferableTypedData.fromList([bytes]),
          maxPreparedBytes,
        ).run,
      );
    }
    if (collection.kind != 'following_topics' ||
        bytes.isEmpty ||
        bytes.length > miteMiteMaxBytes) {
      throw const FormatException('Invalid Following Sync package');
    }
    final expandedBudget = (maxPreparedBytes - bytes.length * 2) ~/ 8;
    if (expandedBudget <= 0) {
      throw const FormatException(
        'Following package exceeds preparation budget',
      );
    }
    final captured = Uint8List.fromList(bytes);
    final scratch = await fs.createTempDirectory(
      'boorusama_following_validate_',
    );
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
            'Following Sync requires one credential-free source',
          );
        }
        final source = manifest.sources.single;
        if (source.id != followingTopicsBackupSourceId ||
            source.schemaVersion != ValidatedSyncFollowingPackage.schema) {
          throw const SyncUpdateRequired();
        }
        if (source.parts.length != 1) {
          throw const FormatException('Invalid Following Sync parts');
        }
        final encoded = await fs.readString(
          staged.pathFor(source.parts.single.path),
        );
        final payload = decodeData(data: encoded);
        if (payload.version != source.schemaVersion) {
          throw const SyncUpdateRequired();
        }
        if (payload.data.any(
          (row) =>
              row is Map &&
              !{'folder', 'search', 'organization'}.contains(row['kind']),
        )) {
          throw const SyncUpdateRequired();
        }
        final data = FollowingTopicBackupCodec().parse(payload);
        requireSyncFollowingScope(data, collection);
        if (data.records.any((topic) => !topic.autoUpdateEnabled)) {
          throw const FormatException(
            'Publisher refresh preferences are not Sync definitions',
          );
        }
        return ValidatedSyncFollowingPackage._(
          collection: collection,
          payload: encoded,
          semanticHash: syncFollowingSemanticHash(data),
          bytes: captured,
        );
      } finally {
        await staged.dispose();
      }
    } finally {
      await fs.deleteDirectory(scratch, recursive: true);
    }
  }
}

final class SyncFollowingPackageBuilder {
  const SyncFollowingPackageBuilder({required this.fs, this.useWorker = true});
  final bool useWorker;
  Future<String> semanticHash(FollowingTopicBackupData data) =>
      Isolate.run(_FollowingHashTask(data).run);
  final AppFileSystem fs;
  Future<ValidatedSyncFollowingPackage> build({
    required SyncCollectionId collection,
    required FollowingTopicBackupData data,
    required String appVersion,
    required DateTime createdAt,
  }) async {
    requireSyncFollowingScope(data, collection);
    if (useWorker && fs.runtimeType == IoFileSystem) {
      return Isolate.run(
        _FollowingBuildTask(collection, data, appVersion, createdAt).run,
      );
    }
    final portable = _portableDefinition(data);
    final scratch = await fs.createTempDirectory('boorusama_following_build_');
    try {
      final path = await ExportPackageWriter(fs: fs).write(
        ExportPackageBuild(
          createdAt: createdAt,
          appVersion: appVersion,
          sources: [
            ExportPackageSourceBuild(
              id: followingTopicsBackupSourceId,
              schemaVersion: ValidatedSyncFollowingPackage.schema,
              selection: ExportNodeSelection.explicit(
                followingTopicsBackupSourceId,
                {
                  collection.source,
                },
              ),
              parts: [
                ExportPackagePartBuild(
                  path: 'following_topics.json',
                  write: (path) => fs.writeString(
                    path,
                    jsonEncode({
                      'version': ValidatedSyncFollowingPackage.schema,
                      'source': followingTopicsBackupSourceId,
                      'data': FollowingTopicBackupCodec().encode(portable),
                    }),
                  ),
                ),
              ],
            ),
          ],
        ),
        '$scratch/revision.bsexport',
      );
      final validated =
          await SyncFollowingPackageValidator(
            fs: fs,
            useWorker: false,
          ).validate(
            collection: collection,
            bytes: await fs.readBytes(path),
          );
      return ValidatedSyncFollowingPackage._(
        collection: collection,
        payload: validated._payload,
        semanticHash: validated.semanticHash,
        bytes: validated.bytes,
        forPublication: true,
      );
    } finally {
      await fs.deleteDirectory(scratch, recursive: true);
    }
  }
}

final class _FollowingHashTask {
  const _FollowingHashTask(this.data);
  final FollowingTopicBackupData data;
  String run() => syncFollowingSemanticHash(data);
}

final class _FollowingDecodeTask {
  const _FollowingDecodeTask(this.payload);
  final String payload;
  FollowingTopicBackupData run() =>
      FollowingTopicBackupCodec().parse(decodeData(data: payload));
}

final class _FollowingBuildTask {
  const _FollowingBuildTask(this.collection, this.data, this.version, this.at);
  final SyncCollectionId collection;
  final FollowingTopicBackupData data;
  final String version;
  final DateTime at;
  Future<ValidatedSyncFollowingPackage> run() =>
      const SyncFollowingPackageBuilder(
        fs: IoFileSystem(),
        useWorker: false,
      ).build(
        collection: collection,
        data: data,
        appVersion: version,
        createdAt: at,
      );
}

final class _FollowingValidateTask {
  const _FollowingValidateTask(this.collection, this.bytes, this.budget);
  final SyncCollectionId collection;
  final TransferableTypedData bytes;
  final int budget;
  Future<ValidatedSyncFollowingPackage> run() =>
      const SyncFollowingPackageValidator(
        fs: IoFileSystem(),
        useWorker: false,
      ).validate(
        collection: collection,
        bytes: bytes.materialize().asUint8List(),
        maxPreparedBytes: budget,
      );
}
