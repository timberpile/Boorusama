import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../foundation/data_mutation_coordinator.dart';
import '../../../foundation/filesystem.dart';
import '../../bookmarks/providers.dart';
import '../../bookmarks/types.dart';
import '../../bookmarks/src/types/bookmark_record_fields.dart';
import '../../configs/manage/providers.dart';
import '../../configs/config/types.dart';
import '../../groups/folder_tree.dart';
import '../../search/following_topics/providers.dart';
import '../../search/following_topics/types.dart';
import '../export_import/import/import_coordinator.dart';
import '../export_import/import/bookmark_profile_dependency.dart';
import '../export_import/import/import_flow_notifier.dart'
    show PackageTransactionSource;
import '../export_import/import/import_journal.dart';
import '../export_import/import/import_plan.dart';
import '../export_import/import/import_preflight.dart';
import '../export_import/import/import_transaction.dart';
import '../export_import/models/import_action.dart';
import '../export_import/package/export_package_reader.dart';
import '../export_import/package/export_package_writer.dart';
import '../sources/bookmark_backup_data.dart';
import '../sources/bookmark_import_planner.dart';
import '../sources/bookmark_import_service.dart';
import '../sources/following_topic_backup_data.dart';
import '../sources/providers.dart';
import '../sources/json_source.dart';
import '../sources/search_backup_profile.dart';
import 'mirror_guard.dart';
import 'protocol.dart';
import 'service.dart';
import 'storage.dart';

/// One collection per payload prevents a subscription from importing unrelated
/// sources/settings, even if the shared folder contains an otherwise valid backup.
final class AppSyncCollectionPort implements SyncCollectionPort {
  const AppSyncCollectionPort(this.ref);
  final Ref ref;
  AppFileSystem get _fs => ref.read(appFileSystemProvider);

  Future<T> _withCollectionLock<T>(
    String kind,
    Future<T> Function() operation,
  ) => kind == 'bookmarks'
      ? ref.read(bookmarkProvider.notifier).runWithLibrary(operation)
      : ref.read(dataMutationCoordinatorProvider).runExclusive(operation);

  @override
  Future<List<SyncSourceCollection>> sources() async {
    final bookmarks = await ref
        .read(bookmarkProvider.notifier)
        .snapshotForExport();
    final topics = await ref.read(followingTopicsProvider.future);
    return [
      for (final group in bookmarks.groups)
        SyncSourceCollection(
          kind: 'bookmarks',
          id: group.id,
          name: group.name,
          parentId: group.parentGroupId,
          container: bookmarks.groups.any(
            (child) => child.parentGroupId == group.id,
          ),
        ),
      for (final folder in topics.organization.folders)
        SyncSourceCollection(
          kind: 'following_topics',
          id: folder.id,
          name: folder.name,
          parentId: folder.parentId,
          container: true,
        ),
      for (final topic in topics.topics)
        SyncSourceCollection(
          kind: 'following_topics',
          id: topic.id,
          name: topic.displayName,
          parentId: topics.organization.placements
              .where((p) => p.itemId == topic.id)
              .firstOrNull
              ?.folderId,
        ),
    ];
  }

  JsonBackupSource<dynamic> _source(String kind) => kind == 'bookmarks'
      ? ref.read(bookmarksBackupSourceProvider)
      : ref.read(followingTopicsBackupSourceProvider);

  Future<Object> _data(SyncSourceCollection source) async {
    if (source.kind == 'bookmarks') {
      final library = await ref
          .read(bookmarkProvider.notifier)
          .snapshotForExport();
      final group = library.groupsById[source.id];
      if (group == null) throw StateError('Published Group no longer exists');
      return BookmarkBackupData.unified(
        records: [for (final id in group.bookmarkIds) library.byId[id]!],
        groups: [
          BookmarkGroupBackup(
            id: group.id,
            name: group.name,
            bookmarkIds: group.bookmarkIds.toList()..sort(),
            addedAt: group.addedAt,
          ),
        ],
      );
    }
    final data = await ref
        .read(followingTopicsBackupSourceProvider)
        .dataGetter();
    final folder = data.folders.where((f) => f.id == source.id).firstOrNull;
    if (folder != null) {
      return FollowingTopicBackupData(
        records: const [],
        folders: [
          FollowingTopicFolderBackupRecord(
            id: folder.id,
            name: folder.name,
            position: 0,
            searchIds: const [],
            feedEnabled: folder.feedEnabled,
            feedMaxPosts: folder.feedMaxPosts,
          ),
        ],
      );
    }
    final topic = data.records.where((r) => r.id == source.id).firstOrNull;
    if (topic == null) throw StateError('Published Topic no longer exists');
    return FollowingTopicBackupData(
      records: [
        FollowingTopicBackupRecord(
          id: topic.id,
          name: topic.name,
          query: topic.query,
          queryStructure: topic.queryStructure,
          position: 0,
          profile: BackupProfileReference(
            id: const Uuid().v5(
              Namespace.url.value,
              '${topic.profile.booruType}:${normalizeBackupProfileUrl(topic.profile.url)}',
            ),
            booruType: topic.profile.booruType,
            url: normalizeBackupProfileUrl(topic.profile.url),
            name: Uri.parse(topic.profile.url).host,
          ),
          autoUpdateEnabled: topic.autoUpdateEnabled,
        ),
      ],
      homeSearchIds: [topic.id],
    );
  }

  Map<String, Object?> _facts(Object data, JsonBackupSource<dynamic> source) {
    if (data is BookmarkBackupData) {
      final encoded = source.handler.encode(data);
      final values = <String, Object?>{};
      final members = <String>{};
      for (final (index, record) in data.records.indexed) {
        final identity = bookmarkContentIdentity(record);
        if (identity == null) {
          throw const FormatException(
            'Unaddressable content cannot be synchronized',
          );
        }
        final key =
            '${bookmarkEngine(record).id}/${identity.siteNamespace}/${identity.kind.name}/${identity.sourceKey}';
        members.add(key);
        final value = Map<String, dynamic>.from(
          _withoutLocalHints(encoded[index]) as Map,
        );
        value.remove('id');
        value.remove('createdAt');
        value.remove('observedAt');
        // A local actor hint cannot create a semantic change on another device.
        values[key] = value;
      }
      return {'members': members.toList()..sort(), 'records': values};
    }
    final following = data as FollowingTopicBackupData;
    if (following.records.isNotEmpty) {
      final topic = following.records.single;
      return {
        'members': <String>[],
        'definition': {
          'query': topic.query,
          'queryStructure': topic.queryStructure?.toJson(),
          'engine': topic.profile.booruType,
          'site': normalizeBackupProfileUrl(topic.profile.url),
          'autoUpdateEnabled': topic.autoUpdateEnabled,
        },
      };
    }
    final folder = following.folders.single;
    return {
      'members': <String>[],
      'definition': {
        'feedEnabled': folder.feedEnabled,
        'feedMaxPosts': folder.feedMaxPosts,
      },
    };
  }

  Object? _withoutLocalHints(Object? value) {
    if (value is Map)
      return {
        for (final entry in value.entries)
          if (entry.key != 'profileIdHint' && entry.key != 'sourceProfileHint')
            entry.key: _withoutLocalHints(entry.value),
      };
    if (value is List) return value.map(_withoutLocalHints).toList();
    return value;
  }

  @override
  Future<SyncCapturedCollection> capture(
    SyncSourceCollection source,
  ) => _withCollectionLock(source.kind, () async {
    final backup = _source(source.kind);
    final data = await _data(source);
    final facts = _facts(data, backup);
    final directory =
        '${await _fs.getAppStoragePath()}/folder_sync/staging/${const Uuid().v4()}';
    await _fs.createDirectory(directory, recursive: true);
    try {
      final encoded = backup.converter.encode(
        payload: backup.handler.encode(data),
        extraFields: data is BookmarkBackupData
            ? data.extraFields
            : const {'source': 'pinned_searches'},
      );
      final path = await ExportPackageWriter(fs: _fs).write(
        ExportPackageBuild(
          createdAt: DateTime.now().toUtc(),
          appVersion: backup.appVersion?.toString() ?? 'unknown',
          sources: [
            ExportPackageSourceBuild(
              id: backup.id,
              schemaVersion: backup.version,
              parts: [
                ExportPackagePartBuild(
                  path: 'sources/${backup.id}/data.json',
                  write: (path) => _fs.writeString(path, encoded),
                ),
              ],
            ),
          ],
        ),
        '$directory/collection.bsexport',
      );
      final bytes = await _fs.readBytes(path);
      if (bytes.length > folderSyncMaxBytes) {
        throw const FormatException('Collection exceeds sync limit');
      }
      return SyncCapturedCollection(
        bytes: bytes,
        semanticHash: syncDigest(syncJsonBytes(facts)),
        members: (facts['members']! as List).cast<String>().toSet(),
        schema: backup.version,
      );
    } finally {
      await _fs.deleteDirectory(directory, recursive: true);
    }
  });

  @override
  Future<SyncAppliedCollection?> inspect(String kind, String localId) async {
    if (kind == 'following_topics') {
      final repository = await ref.read(
        followingTopicRepositoryProvider.future,
      );
      final topic = await repository.getById(localId);
      if (topic != null &&
          !ref
              .read(booruConfigProvider)
              .any((profile) => profile.id == topic.profileId))
        throw const SyncProfileRequired();
    }
    final source = (await sources())
        .where((s) => s.kind == kind && s.id == localId)
        .firstOrNull;
    if (source == null) return null;
    final facts = _facts(await _data(source), _source(kind));
    return SyncAppliedCollection(
      localId: localId,
      members: (facts['members']! as List).cast<String>().toSet(),
      semanticHash: syncDigest(syncJsonBytes(facts)),
    );
  }

  @override
  Future<SyncAppliedCollection> apply({
    required SyncRevision revision,
    required Uint8List bytes,
    required String localId,
    required String name,
    String? parentId,
  }) async {
    revision.verifyPayload(bytes);
    final backup = _source(revision.collection.kind);
    if (revision.schema != backup.version) throw const SyncUpdateRequired();
    final directory =
        '${await _fs.getAppStoragePath()}/folder_sync/staging/${const Uuid().v4()}';
    await _fs.createDirectory(directory, recursive: true);
    final input = '$directory/incoming.bsexport';
    await _fs.writeBytes(input, bytes);
    final staged = await ExportPackageReader(fs: _fs)
        .stage(input)
        .onError((Object error, StackTrace stack) async {
          await _fs.deleteDirectory(directory, recursive: true);
          Error.throwWithStackTrace(error, stack);
        });
    try {
      final manifest = staged.manifest;
      if ((manifest.containsCredentials ?? true) ||
          manifest.sources.length != 1 ||
          manifest.sources.single.id != backup.id ||
          manifest.sources.single.schemaVersion != backup.version ||
          manifest.sources.single.parts.length != 1) {
        throw const FormatException(
          'Sync payload must contain one credential-free collection',
        );
      }
      final wrapper = PackageTransactionSource(
        source: backup,
        incomingPath: staged.pathFor(manifest.sources.single.parts.single.path),
        fs: _fs,
        ref: ref,
        credentialsIncluded: false,
      );
      await wrapper.prepare(null);
      final data = wrapper.preparedData;
      if (data == null ||
          syncDigest(syncJsonBytes(_facts(data, backup))) !=
              revision.semanticHash) {
        throw const FormatException('Collection semantic hash mismatch');
      }
      await _withCollectionLock(revision.collection.kind, () async {
        await wrapper.captureLocalSnapshot();
        final revisionToken = await wrapper.revisionToken();
        final transactionSource = _CollectionTransactionSource(
          wrapper,
          () async {
            if (data is BookmarkBackupData &&
                revision.collection.kind == 'bookmarks') {
              await _applyBookmarks(data, revision, localId, name, parentId);
            } else if (data is FollowingTopicBackupData &&
                revision.collection.kind == 'following_topics') {
              await ref
                  .read(followingTopicsProvider.notifier)
                  .runSerializedMutation(
                    (_) => _applyFollowing(
                      data,
                      revision,
                      localId,
                      name,
                      parentId,
                    ),
                  );
            } else {
              throw const FormatException('Unexpected sync payload');
            }
          },
        );
        final sourcePlan = ResolvedImportSource(
          id: backup.id,
          action: ImportAction.update,
          items: const [],
        );
        final journalRoot =
            '${await _fs.getAppStoragePath()}/import_transactions';
        await ref
            .read(collectionMirrorGuardProvider)
            .applyReceived(
              () => ImportCoordinator().apply(
                plan: ValidatedImportPlan(
                  plan: ResolvedImportPlan(sources: [sourcePlan]),
                  revisionTokens: {backup.id: revisionToken},
                  summary: const PlannedChangeSummary(updated: 1),
                ),
                transaction: ImportTransaction(
                  fs: _fs,
                  store: ImportJournalStore(fs: _fs, rootPath: journalRoot),
                ),
                sources: {backup.id: transactionSource},
              ),
            );
        await wrapper.restart();
      });
      return (await inspect(revision.collection.kind, localId)) ??
          (throw StateError('Received collection was not committed'));
    } finally {
      await staged.dispose();
      await _fs.deleteDirectory(directory, recursive: true);
    }
  }

  Future<void> _applyBookmarks(
    BookmarkBackupData data,
    SyncRevision revision,
    String localId,
    String name,
    String? parentId,
  ) async {
    if (data.groups.length != 1 ||
        data.groups.single.id != revision.collection.source ||
        data.groups.single.parentGroupId != null ||
        data.folders.isNotEmpty ||
        data.records.any(
          (r) => !data.groups.single.bookmarkIds.contains(r.id),
        )) {
      throw const FormatException('Sync Bookmark scope mismatch');
    }
    final repository = await ref
        .read(bookmarkProvider.notifier)
        .bookmarkRepository;
    final groups = await ref
        .read(bookmarkProvider.notifier)
        .bookmarkGroupRepository;
    final store =
        unifiedBookmarkStorage(repository) ??
        (throw StateError('Unified storage required'));
    final existing = await groups.getGroup(localId);
    final incoming = data.groups.single;
    final receiverRecords = <Bookmark>[];
    for (final incomingRecord in data.records) {
      final identity = bookmarkContentIdentity(incomingRecord);
      final current = identity == null
          ? null
          : await store.lookupContent(
              identity,
              engine: bookmarkEngine(incomingRecord),
            );
      final hint = current == null ? null : bookmarkRecordProfileHint(current);
      receiverRecords.add(
        hint == null
            ? incomingRecord
            : bookmarkRecordWithProfileHint(incomingRecord, hint),
      );
    }
    final mapped = BookmarkBackupData.unified(
      records: receiverRecords,
      groups: [
        BookmarkGroupBackup(
          id: localId,
          name: existing?.name ?? name,
          bookmarkIds: incoming.bookmarkIds,
          addedAt: incoming.addedAt,
          parentGroupId: existing?.parentGroupId,
          position: existing?.position ?? 0,
        ),
      ],
    );
    final plan = const BookmarkImportPlanner().plan(
      data: mapped,
      currentBookmarks: await store.readAll(),
      currentGroups: await groups.getGroups(),
    );
    await BookmarkImportService(
      bookmarkRepository: repository,
      groupRepository: groups,
      imageUrlResolver: (id) => ref.read(bookmarkUrlResolverProvider(id)),
    ).apply(
      plan.resolveActions({
        for (final group in plan.groups)
          group.id: group.resolveAction(ImportAction.update),
      }),
    );
    final snapshots = <Bookmark>[];
    for (final incomingRecord in receiverRecords) {
      final identity = bookmarkContentIdentity(incomingRecord);
      if (identity == null) {
        throw const FormatException('Unaddressable sync member');
      }
      final current = await store.lookupContent(
        identity,
        engine: bookmarkEngine(incomingRecord),
      );
      if (current == null) throw StateError('Imported sync member unavailable');
      var updated = bookmarkWithId(incomingRecord, current.id);
      if (incomingRecord is ContentGroupBookmark &&
          current is ContentGroupBookmark) {
        updated = current.copyWith(
          snapshot: StoredGroupSnapshot(
            summary: incomingRecord.snapshot.summary,
            details:
                incomingRecord.snapshot.details?.mergeWithPrevious(
                  current.snapshot.details,
                ) ??
                current.snapshot.details,
            index: incomingRecord.snapshot.index ?? current.snapshot.index,
          ),
          observedAt: incomingRecord.observedAt,
        );
      } else if (updated is PostBookmark && current is PostBookmark) {
        updated = updated.copyWith(createdAt: current.createdAt);
      }
      snapshots.add(store.normalizeRecord(updated, previous: current));
    }
    if (snapshots.isNotEmpty) {
      await store.commitOrganization(records: snapshots);
    }
    if (existing == null && parentId != null) {
      final saved = await groups.getGroup(localId);
      if (saved != null && await groups.getGroup(parentId) != null) {
        await store.commitOrganization(
          groups: [saved.copyWith(parentGroupId: parentId)],
        );
      }
    }
  }

  Future<void> _applyFollowing(
    FollowingTopicBackupData data,
    SyncRevision revision,
    String localId,
    String name,
    String? parentId,
  ) async {
    if (data.records.length + data.folders.length != 1 ||
        (data.records.isNotEmpty
                ? data.records.single.id
                : data.folders.single.id) !=
            revision.collection.source) {
      throw const FormatException('Sync Following scope mismatch');
    }
    final repository = await ref.read(followingTopicRepositoryProvider.future);
    if (data.records.isNotEmpty) {
      final record = data.records.single;
      final profiles = ref
          .read(booruConfigProvider)
          .where(
            (profile) =>
                profile.auth.booruType.name == record.profile.booruType &&
                normalizeBackupProfileUrl(profile.url) ==
                    normalizeBackupProfileUrl(record.profile.url),
          )
          .toList();
      final profileId = profiles.length == 1 ? profiles.single.id : null;
      if (profileId == null) throw const SyncProfileRequired();
      final existing = await repository.getById(localId);
      if (existing == null) {
        await repository.create(
          profileId: profileId,
          query: record.query,
          queryStructure: record.queryStructure,
          name: name,
          id: localId,
        );
        await repository.setAutoUpdate([localId], record.autoUpdateEnabled);
      } else {
        await repository.edit(
          localId,
          profileId: profileId,
          query: record.query,
          name: existing.name,
          queryStructure: () => record.queryStructure,
          autoUpdateEnabled: record.autoUpdateEnabled,
          expectedTopic: existing,
        );
      }
      if (existing == null && parentId != null) {
        final organization = await repository.getOrganization();
        if (organization.folders.any((f) => f.id == parentId)) {
          await repository.replaceOrganization(
            TopicOrganization(
              folders: organization.folders,
              placements: [
                for (final placement in organization.placements)
                  placement.itemId == localId
                      ? FolderPlacement(
                          itemId: localId,
                          folderId: parentId,
                          position: placement.position,
                        )
                      : placement,
              ],
            ),
          );
        }
      }
    } else {
      final folder = data.folders.single;
      if (folder.searchIds.isNotEmpty || folder.parentId != null) {
        throw const FormatException('Unexpected Following membership');
      }
      final organization = await repository.getOrganization();
      final existing = organization.folders
          .where((f) => f.id == localId)
          .firstOrNull;
      final value = TopicFolder(
        id: localId,
        name: existing?.name ?? name,
        parentId:
            existing?.parentId ??
            (organization.folders.any((f) => f.id == parentId)
                ? parentId
                : null),
        position: existing?.position ?? organization.folders.length,
        feedEnabled: folder.feedEnabled,
        feedMaxPosts: folder.feedMaxPosts,
      );
      await repository.replaceOrganization(
        TopicOrganization(
          folders: [
            for (final current in organization.folders)
              if (current.id != localId) current,
            value,
          ],
          placements: organization.placements,
        ),
      );
    }
  }
}

final class _CollectionTransactionSource implements ImportTransactionSource {
  const _CollectionTransactionSource(this.delegate, this.applyCollection);
  final PackageTransactionSource delegate;
  final Future<void> Function() applyCollection;
  @override
  String get id => delegate.id;
  @override
  Future<String> revisionToken() => delegate.revisionToken();
  @override
  Future<void> captureRollback(String path) => delegate.captureRollback(path);
  @override
  Future<void> restore(String path) => delegate.restore(path);
  @override
  Future<void> durableSync() => delegate.durableSync();
  @override
  Future<void> apply(ResolvedImportSource plan) => applyCollection();
}
