import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/material.dart';
import 'package:uuid/uuid.dart';

import '../../../../foundation/filesystem.dart';
import '../../../../foundation/utils/file_utils.dart';
import '../../../configs/config/types.dart';
import '../../../configs/manage/providers.dart';
import '../../../bookmarks/providers.dart';
import '../../../bookmarks/types.dart';
import '../../../posts/post/types.dart';
import '../../../search/subscriptions/providers.dart';
import '../../../search/subscriptions/types.dart';
import '../../preparation/version_checking.dart';
import '../../sources/bookmark_backup_data.dart';
import '../../sources/bookmark_import_planner.dart';
import '../../sources/bookmark_import_service.dart';
import '../../sources/following_feed_backup_data.dart';
import '../../sources/following_feed_import_service.dart';
import '../../sources/pinned_search_backup_data.dart';
import '../../sources/pinned_search_import_service.dart';
import '../../sources/json_source.dart';
import '../../sources/providers.dart';
import '../../sources/search_backup_profile.dart';
import '../../sources/sqlite_source.dart';
import '../../types/backup_data_source.dart';
import '../models/export_selection.dart';
import '../models/import_action.dart';
import '../models/package_manifest.dart';
import '../package/export_package_reader.dart';
import '../package/staged_export_package.dart';
import 'import_coordinator.dart';
import 'collection_import_action.dart';
import 'import_journal.dart';
import 'import_plan.dart';
import 'import_planner.dart';
import 'import_preflight.dart';
import 'import_transaction.dart';
import 'profile_mapping.dart';

enum ImportFlowStatus { idle, checking, review, importing, complete, error }

final class ImportFlowState {
  const ImportFlowState({
    required this.status,
    this.proposed,
    this.resolved,
    this.preflight,
    this.alreadyPresentSearches = 0,
    this.error,
  });

  const ImportFlowState.initial() : this(status: ImportFlowStatus.idle);

  final ImportFlowStatus status;
  final ProposedImportPlan? proposed;
  final ResolvedImportPlan? resolved;
  final ImportPreflightResult? preflight;
  final int alreadyPresentSearches;
  final Object? error;

  ImportFlowState copyWith({
    ImportFlowStatus? status,
    ProposedImportPlan? proposed,
    ResolvedImportPlan? resolved,
    ImportPreflightResult? preflight,
    int? alreadyPresentSearches,
    Object? error,
  }) => ImportFlowState(
    status: status ?? this.status,
    proposed: proposed ?? this.proposed,
    resolved: resolved ?? this.resolved,
    preflight: preflight ?? this.preflight,
    alreadyPresentSearches:
        alreadyPresentSearches ?? this.alreadyPresentSearches,
    error: error,
  );
}

final exportPackageReaderProvider = Provider<ExportPackageReader>((ref) {
  return ExportPackageReader(fs: ref.watch(appFileSystemProvider));
});

final importFlowProvider =
    NotifierProvider.autoDispose<ImportFlowNotifier, ImportFlowState>(
      ImportFlowNotifier.new,
    );

class ImportFlowNotifier extends AutoDisposeNotifier<ImportFlowState> {
  StagedExportPackage? _package;
  Map<String, _PackageTransactionSource> _sources = const {};
  var _warningsAcknowledged = false;
  var _availableBytes = 1 << 62;
  var _stagingBytes = 0;

  @override
  ImportFlowState build() {
    ref.onDispose(() {
      final package = _package;
      if (package != null) unawaited(package.dispose());
    });
    return const ImportFlowState.initial();
  }

  Future<void> load(String path) async {
    state = const ImportFlowState(status: ImportFlowStatus.checking);
    try {
      await _package?.dispose();
      final package = await ref.read(exportPackageReaderProvider).stage(path);
      _package = package;
      _stagingBytes = package.manifest.sources.fold(
        0,
        (total, source) =>
            total + source.parts.fold(0, (sum, part) => sum + part.byteLength),
      );
      final disk = await DiskSpaceInfo.fromTempDir(
        ref.read(appFileSystemProvider),
      );
      _availableBytes = disk.freeSpace > 0 ? disk.freeSpace : 1 << 62;
      final registry = ref.read(backupRegistryProvider);
      final descriptors = {
        for (final descriptor
            in ref
                .read(exportImportSourcesProvider)
                .map((s) => s.selectionDescriptor))
          descriptor.id: descriptor,
      };
      final wrappers = <String, _PackageTransactionSource>{};
      final planning = <ImportSourcePlanningInput>[];
      final preflightSnapshots = <SourcePreflightSnapshot>[];
      var alreadyPresentSearches = 0;
      for (final manifest in package.manifest.sources) {
        final source = registry.getSource(manifest.id);
        if (source == null) {
          throw StateError('Import source is unavailable: ${manifest.id}');
        }
        if (manifest.parts.length != 1) {
          throw FormatException(
            'Source ${manifest.id} has an unsupported part layout',
          );
        }
        final incomingPath = package.pathFor(manifest.parts.single.path);
        await _preserveProfileCredentials(
          package.manifest,
          manifest,
          incomingPath,
        );
        final selection =
            manifest.selection ?? ExportNodeSelection.all(manifest.id);
        final descriptor = descriptors[manifest.id];
        final isCollection = descriptor?.isCollection ?? false;
        final localIds = descriptor?.childIds ?? const <String>{};
        final incomingIds = switch (selection.kind) {
          ExportNodeSelectionKind.all => const <String>{},
          ExportNodeSelectionKind.explicit => selection.childIds,
        };
        planning.add(
          ImportSourcePlanningInput(
            id: manifest.id,
            kind: isCollection
                ? ImportSourceKind.collection
                : ImportSourceKind.value,
            selectionComplete: selection.kind == ExportNodeSelectionKind.all,
            recommendedAction: manifest.recommendedAction,
            items: [
              for (final itemId in incomingIds)
                if (!(manifest.id == 'pinned_searches' &&
                    itemId.startsWith('search:')))
                  ImportItemPlanningInput(
                    id: itemId,
                    matchingItemId: localIds.contains(itemId) ? itemId : null,
                    compatibleTargetIds: localIds.difference({itemId}),
                    recommendedAction: manifest.itemRecommendedActions[itemId],
                  ),
            ],
          ),
        );
        final wrapper = _PackageTransactionSource(
          source: source,
          incomingPath: incomingPath,
          fs: ref.read(appFileSystemProvider),
          ref: ref,
        );
        await wrapper.prepare(null);
        await wrapper.measureRollback();
        if (wrapper.preparedData case final PinnedSearchBackupData data) {
          final repository = await ref.read(
            searchSubscriptionRepositoryProvider.future,
          );
          final profiles = ref.read(booruConfigProvider);
          for (final record in data.records) {
            final profile = resolveBackupProfile(record.profile, profiles);
            if (profile != null &&
                await repository.findByQuery(profile.id, record.query) !=
                    null) {
              alreadyPresentSearches++;
            }
          }
        }
        wrappers[source.id] = wrapper;
        preflightSnapshots.add(
          SourcePreflightSnapshot(
            sourceId: source.id,
            revisionToken: await wrapper.revisionToken(),
            rollbackBytes: wrapper.preflightRollbackBytes,
          ),
        );
      }
      _sources = wrappers;
      final proposed = const ImportPlanner().plan(planning);
      final resolved = proposed.resolveDefaults();
      state = ImportFlowState(
        status: ImportFlowStatus.review,
        proposed: proposed,
        resolved: resolved,
        preflight: _preflight(
          proposed,
          resolved,
          preflightSnapshots,
        ),
        alreadyPresentSearches: alreadyPresentSearches,
      );
    } catch (error) {
      state = ImportFlowState(status: ImportFlowStatus.error, error: error);
    }
  }

  void replaceSource(ResolvedImportSource source) {
    final proposed = state.proposed;
    final resolved = state.resolved?.replaceSource(source);
    if (proposed == null || resolved == null) return;
    state = state.copyWith(
      resolved: resolved,
      preflight: _preflightFromCurrent(proposed, resolved),
    );
  }

  void acknowledgeWarnings(bool value) {
    _warningsAcknowledged = value;
    final proposed = state.proposed;
    final resolved = state.resolved;
    if (proposed == null || resolved == null) return;
    state = state.copyWith(
      preflight: _preflightFromCurrent(proposed, resolved),
    );
  }

  Future<void> apply(BuildContext context) async {
    final validated = state.preflight?.validatedPlan;
    if (validated == null) return;
    state = state.copyWith(status: ImportFlowStatus.importing);
    try {
      for (final sourcePlan in validated.plan.sources) {
        if (sourcePlan.action != ImportAction.skip) {
          await _sources[sourcePlan.id]!.prepare(context);
        }
      }
      final fs = ref.read(appFileSystemProvider);
      final root = await fs.getAppStoragePath();
      final coordinator = ImportCoordinator(
        transaction: ImportTransaction(
          store: ImportJournalStore(
            fs: fs,
            rootPath: '$root/import_transactions',
          ),
          fs: fs,
        ),
        sources: () => Map.unmodifiable(_sources),
      );
      await coordinator.apply(validated);
      for (final sourcePlan in validated.plan.sources) {
        if (sourcePlan.action != ImportAction.skip) {
          await _sources[sourcePlan.id]!.restart();
        }
      }
      state = state.copyWith(status: ImportFlowStatus.complete);
    } catch (error) {
      state = state.copyWith(status: ImportFlowStatus.error, error: error);
    }
  }

  ImportPreflightResult _preflightFromCurrent(
    ProposedImportPlan proposed,
    ResolvedImportPlan resolved,
  ) => _preflight(
    proposed,
    resolved,
    [
      for (final entry in _sources.entries)
        SourcePreflightSnapshot(
          sourceId: entry.key,
          revisionToken: entry.value.preflightRevision,
          rollbackBytes: entry.value.preflightRollbackBytes,
        ),
    ],
  );

  ImportPreflightResult _preflight(
    ProposedImportPlan proposed,
    ResolvedImportPlan resolved,
    List<SourcePreflightSnapshot> snapshots,
  ) => const ImportPreflight().validate(
    proposed: proposed,
    resolved: resolved,
    sources: snapshots,
    availableBytes: _availableBytes,
    stagingBytes: _stagingBytes,
    warningsAcknowledged: _warningsAcknowledged,
  );

  Future<void> _preserveProfileCredentials(
    ExportPackageManifest packageManifest,
    ExportSourceManifest sourceManifest,
    String path,
  ) async {
    if (sourceManifest.id != 'profiles' ||
        (packageManifest.containsCredentials ?? true)) {
      return;
    }
    final fs = ref.read(appFileSystemProvider);
    final decoded = jsonDecode(await fs.readString(path));
    if (decoded is! Map<String, dynamic> || decoded['data'] is! List<dynamic>) {
      throw const FormatException('Invalid profile export payload');
    }
    final existing = ref.read(booruConfigProvider);
    decoded['data'] = [
      for (final raw in decoded['data'] as List<dynamic>)
        if (raw case final Map<String, dynamic> json)
          _profileWithPreservedCredentials(json, existing)
        else
          throw const FormatException('Invalid profile export entry'),
    ];
    await fs.writeString(path, jsonEncode(decoded));
  }

  Map<String, dynamic> _profileWithPreservedCredentials(
    Map<String, dynamic> json,
    List<BooruConfig> existing,
  ) {
    final imported = BooruConfig.fromJson(json);
    final matches = existing.where(
      (profile) =>
          profile.auth.booruType == imported.auth.booruType &&
          normalizeBackupProfileUrl(profile.url) ==
              normalizeBackupProfileUrl(imported.url),
    );
    final current = matches.length == 1 ? matches.single : null;
    return current == null
        ? imported.toJson()
        : mergeImportedProfile(
            imported: imported,
            existing: current,
            credentialsIncluded: false,
          ).toJson();
  }
}

final class _PackageTransactionSource implements ImportTransactionSource {
  _PackageTransactionSource({
    required this.source,
    required this.incomingPath,
    required this.fs,
    required this.ref,
  });

  final BackupDataSource source;
  final String incomingPath;
  final AppFileSystem fs;
  final Ref ref;
  ImportPreparation? _preparation;
  var preflightRevision = '';
  var preflightRollbackBytes = 0;

  Object? get preparedData => _preparation?.preparedData;

  @override
  String get id => source.id;

  Future<void> prepare(BuildContext? context) async {
    final capability = source.capabilities.file;
    if (capability == null) {
      throw StateError('Source $id cannot import files');
    }
    _preparation = await capability.prepareImport(incomingPath, context);
    preflightRevision = await revisionToken();
  }

  @override
  Future<String> revisionToken() async {
    final digest = switch (source) {
      final JsonBackupSource jsonSource => sha256.convert(
        utf8.encode(await jsonSource.encodeForExport()),
      ),
      final SqliteBackupSource sqliteSource => await _fileDigest(
        await sqliteSource.dbPathGetter(),
      ),
      _ => throw StateError('Unsupported import source: $id'),
    };
    return digest.toString();
  }

  Future<Digest> _fileDigest(String path) async {
    if (!await fs.fileExists(path)) return sha256.convert(const []);
    return sha256.bind(fs.openRead(path)).first;
  }

  Future<void> measureRollback() async {
    preflightRollbackBytes = switch (source) {
      final JsonBackupSource jsonSource =>
        utf8.encode(await jsonSource.encodeForExport()).length,
      final SqliteBackupSource sqliteSource => await () async {
        final path = await sqliteSource.dbPathGetter();
        return await fs.fileExists(path) ? await fs.fileSize(path) : 0;
      }(),
      _ => 0,
    };
  }

  @override
  Future<void> captureRollback(String outputPath) async {
    switch (source) {
      case final JsonBackupSource jsonSource:
        await fs.writeString(outputPath, await jsonSource.encodeForExport());
      case final SqliteBackupSource sqliteSource:
        final dbPath = await sqliteSource.dbPathGetter();
        if (await fs.fileExists(dbPath)) {
          await fs.copyFile(dbPath, outputPath);
        } else {
          await fs.writeBytes(outputPath, Uint8List(0));
        }
      default:
        throw StateError('Unsupported import source: $id');
    }
  }

  @override
  Future<void> apply(ResolvedImportSource plan) async {
    final preparedData = _preparation?.preparedData;
    if (id == 'profiles' && preparedData is List<BooruConfig>) {
      await _applyProfiles(preparedData, plan);
      return;
    }
    if (id == 'bookmarks' && preparedData is BookmarkBackupData) {
      await _applyBookmarks(preparedData, plan);
      return;
    }
    if (id == 'pinned_searches' && preparedData is PinnedSearchBackupData) {
      await _applyPinnedSearches(preparedData, plan);
      return;
    }
    if (id == 'following_feeds' && preparedData is FollowingFeedBackupData) {
      await _applyFollowingFeeds(preparedData, plan);
      return;
    }
    await _preparation!.executeImport(deferRestart: true);
  }

  Future<void> _applyProfiles(
    List<BooruConfig> imported,
    ResolvedImportSource resolution,
  ) async {
    if (resolution.action == ImportAction.replace) {
      await _preparation!.executeImport(deferRestart: true);
      return;
    }
    if (resolution.action == ImportAction.skip) return;
    final repository = ref.read(booruConfigRepoProvider);
    final profiles = (await repository.getAll()).toList();
    final actions = {for (final item in resolution.items) item.id: item};
    var nextId =
        profiles.fold<int>(0, (max, item) => item.id > max ? item.id : max) + 1;
    for (final profile in imported) {
      final action = actions['profile:${profile.id}']?.action;
      if (action == ImportAction.skip) continue;
      final index = profiles.indexWhere(
        (local) =>
            local.auth.booruType == profile.auth.booruType &&
            normalizeBackupProfileUrl(local.url) ==
                normalizeBackupProfileUrl(profile.url),
      );
      if (action == ImportAction.copy || index < 0) {
        final usedIds = profiles.map((item) => item.id).toSet();
        final id = usedIds.contains(profile.id) ? nextId++ : profile.id;
        profiles.add(_withProfileId(profile, id));
      } else {
        profiles[index] = _withProfileId(profile, profiles[index].id);
      }
    }
    await repository.clear();
    await repository.addAll(profiles);
    await ref.read(booruConfigProvider.notifier).fetch();
  }

  BooruConfig _withProfileId(BooruConfig profile, int id) =>
      BooruConfig.fromJson({...profile.toJson(), 'id': id});

  Future<void> _applyPinnedSearches(
    PinnedSearchBackupData data,
    ResolvedImportSource resolution,
  ) async {
    if (resolution.action == ImportAction.replace) {
      await ref
          .read(searchSubscriptionsProvider.notifier)
          .runSerializedMutation((repository) async {
            final internalIds = {
              for (final feed in await repository.getFeeds()) ...feed.sourceIds,
            };
            for (final search in await repository.getAll()) {
              if (!internalIds.contains(search.id)) {
                await repository.delete(search.id);
              }
            }
            final current = await repository.getOrganization();
            await repository.replaceOrganization(
              SearchOrganization(
                folders: const [],
                homeSearchIds: current.homeSearchIds
                    .where(internalIds.contains)
                    .toList(),
              ),
            );
            await PinnedSearchImportService(repository: repository).apply(
              data,
              profiles: ref.read(booruConfigProvider),
            );
          });
      return;
    }
    if (resolution.action == ImportAction.skip) return;
    final repository = await ref.read(
      searchSubscriptionRepositoryProvider.future,
    );
    final currentFolderIds = {
      for (final folder in (await repository.getOrganization()).folders)
        folder.id,
    };
    final actions = <String, CollectionImportAction>{};
    for (final item in resolution.items) {
      if (!item.id.startsWith('folder:')) continue;
      final id = item.id.substring(7);
      actions[id] = CollectionImportAction(
        itemId: id,
        action: item.action,
        targetId: _withoutPrefix(item.targetId, 'folder:'),
        destinationId:
            item.action == ImportAction.copy && currentFolderIds.contains(id)
            ? const Uuid().v4().toLowerCase()
            : null,
      );
    }
    await ref
        .read(searchSubscriptionsProvider.notifier)
        .runSerializedMutation(
          (repository) =>
              PinnedSearchImportService(
                repository: repository,
              ).apply(
                data,
                profiles: ref.read(booruConfigProvider),
                folderActions: actions,
              ),
        );
  }

  Future<void> _applyFollowingFeeds(
    FollowingFeedBackupData data,
    ResolvedImportSource resolution,
  ) async {
    if (resolution.action == ImportAction.replace) {
      await ref
          .read(searchSubscriptionsProvider.notifier)
          .runSerializedMutation((repository) async {
            for (final feed in await repository.getFeeds()) {
              await repository.deleteFeed(feed.id);
            }
            await FollowingFeedImportService(repository: repository).apply(
              data,
              profiles: ref.read(booruConfigProvider),
            );
          });
      return;
    }
    if (resolution.action == ImportAction.skip) return;
    final repository = await ref.read(
      searchSubscriptionRepositoryProvider.future,
    );
    final currentFeedIds = {
      for (final feed in await repository.getFeeds()) feed.id,
    };
    final actions = <String, CollectionImportAction>{};
    for (final item in resolution.items) {
      if (!item.id.startsWith('feed:')) continue;
      final id = item.id.substring(5);
      actions[id] = CollectionImportAction(
        itemId: id,
        action: item.action,
        targetId: _withoutPrefix(item.targetId, 'feed:'),
        destinationId:
            item.action == ImportAction.copy && currentFeedIds.contains(id)
            ? const Uuid().v4().toLowerCase()
            : null,
      );
    }
    await ref
        .read(searchSubscriptionsProvider.notifier)
        .runSerializedMutation(
          (repository) =>
              FollowingFeedImportService(
                repository: repository,
              ).apply(
                data,
                profiles: ref.read(booruConfigProvider),
                feedActions: actions,
              ),
        );
  }

  String? _withoutPrefix(String? value, String prefix) => switch (value) {
    final String id when id.startsWith(prefix) => id.substring(prefix.length),
    final id => id,
  };

  Future<void> _applyBookmarks(
    BookmarkBackupData data,
    ResolvedImportSource resolution,
  ) async {
    final bookmarkRepository = await ref.read(bookmarkRepoProvider.future);
    final groupRepository = await ref.read(bookmarkGroupRepoProvider.future);
    ImageUrlResolver resolver(int? booruId) =>
        ref.read(bookmarkUrlResolverProvider(booruId));
    if (resolution.action == ImportAction.replace) {
      final currentGroups = await groupRepository.getGroups();
      for (final group in currentGroups) {
        await groupRepository.deleteGroup(group.id);
      }
      final currentBookmarks = await bookmarkRepository.getAllBookmarksOrThrow(
        imageUrlResolver: resolver,
      );
      if (currentBookmarks.isNotEmpty) {
        await bookmarkRepository.removeBookmarks(currentBookmarks);
      }
      final saved = await bookmarkRepository.addBookmarkWithBookmarks(
        data.bookmarks,
      );
      final localIds = {
        for (final bookmark in saved) bookmark.transferIdentity: bookmark.id,
      };
      final importedIds = {
        for (final bookmark in data.bookmarks)
          bookmark.id: localIds[bookmark.transferIdentity],
      };
      for (final group in data.groups) {
        final id = group.id ?? const Uuid().v4().toLowerCase();
        await groupRepository.createGroup(group.name, id: id);
        await groupRepository.replaceMemberships(id, {
          for (final bookmarkId in group.bookmarkIds) ?importedIds[bookmarkId],
        });
      }
      return;
    }
    if (resolution.action == ImportAction.skip) return;

    final actions = {for (final item in resolution.items) item.id: item};
    final allGroupedIds = {
      for (final group in data.groups) ...group.bookmarkIds,
    };
    final ungroupedAction = actions['ungrouped']?.action;
    final chosenGroups = [
      for (final group in data.groups)
        if (actions['group:${group.id}']?.action != ImportAction.skip) group,
    ];
    final chosenBookmarkIds = {
      for (final group in chosenGroups) ...group.bookmarkIds,
      if (ungroupedAction != null && ungroupedAction != ImportAction.skip)
        for (final bookmark in data.bookmarks)
          if (!allGroupedIds.contains(bookmark.id)) bookmark.id,
    };
    final selected = BookmarkBackupData(
      bookmarks: data.bookmarks
          .where((bookmark) => chosenBookmarkIds.contains(bookmark.id))
          .toList(),
      groups: chosenGroups,
    );
    final currentBookmarks = await bookmarkRepository.getAllBookmarksOrThrow(
      imageUrlResolver: resolver,
    );
    if (ungroupedAction == ImportAction.update) {
      final groupedLocalIds = {
        for (final group in await groupRepository.getGroups())
          ...group.bookmarkIds,
      };
      final incomingUngrouped = {
        for (final bookmark in selected.bookmarks)
          if (!allGroupedIds.contains(bookmark.id)) bookmark.transferIdentity,
      };
      final removed = currentBookmarks
          .where(
            (bookmark) =>
                !groupedLocalIds.contains(bookmark.id) &&
                !incomingUngrouped.contains(bookmark.transferIdentity),
          )
          .toList();
      if (removed.isNotEmpty) await bookmarkRepository.removeBookmarks(removed);
    }
    final planned = const BookmarkImportPlanner().plan(
      data: selected,
      currentBookmarks: await bookmarkRepository.getAllBookmarksOrThrow(
        imageUrlResolver: resolver,
      ),
      currentGroups: await groupRepository.getGroups(),
    );
    final resolvedGroups = {
      for (final group in planned.groups)
        group.id: group.resolveAction(
          actions['group:${group.id}']?.action ??
              (group.conflicts ? ImportAction.update : ImportAction.copy),
          targetId: _groupId(actions['group:${group.id}']?.targetId),
          destinationId:
              actions['group:${group.id}']?.action == ImportAction.copy &&
                  group.conflicts
              ? const Uuid().v4().toLowerCase()
              : group.id,
        ),
    };
    await BookmarkImportService(
      bookmarkRepository: bookmarkRepository,
      groupRepository: groupRepository,
      imageUrlResolver: resolver,
    ).apply(planned.resolveActions(resolvedGroups));
  }

  String? _groupId(String? id) => switch (id) {
    final String id when id.startsWith('group:') => id.substring(6),
    final id => id,
  };

  @override
  Future<void> restore(String rollbackPath) async {
    switch (source) {
      case final JsonBackupSource jsonSource:
        final preparation = await jsonSource.capabilities.file!.prepareImport(
          rollbackPath,
          null,
        );
        final replace = ResolvedImportSource(
          id: id,
          action: ImportAction.replace,
          items: const [],
        );
        switch (preparation.preparedData) {
          case final BookmarkBackupData data:
            await _applyBookmarks(data, replace);
          case final PinnedSearchBackupData data:
            await _applyPinnedSearches(data, replace);
          case final FollowingFeedBackupData data:
            await _applyFollowingFeeds(data, replace);
          default:
            await preparation.executeImport(deferRestart: true);
        }
      case final SqliteBackupSource sqliteSource:
        final dbPath = await sqliteSource.dbPathGetter();
        if (await fs.fileSize(rollbackPath) == 0) {
          if (await fs.fileExists(dbPath)) await fs.deleteFile(dbPath);
        } else {
          await fs.copyFile(rollbackPath, dbPath);
        }
        sqliteSource.onImportComplete();
      default:
        throw StateError('Unsupported import source: $id');
    }
  }

  Future<void> restart() => _preparation?.restartApp?.call() ?? Future.value();
}
