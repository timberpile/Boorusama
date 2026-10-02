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
import '../package/staged_export_package.dart';
import 'import_coordinator.dart';
import 'collection_import_action.dart';
import 'import_change_summarizer.dart';
import 'import_item_labels.dart';
import 'import_source_integrity_validator.dart';
import 'import_journal.dart';
import 'import_plan.dart';
import 'import_planner.dart';
import 'import_preflight.dart';
import 'import_transaction.dart';
import 'legacy_import_stager.dart';
import 'profile_import_projection.dart';
import 'profile_dependency_planner.dart';

enum ImportFlowStatus { idle, checking, review, importing, complete, error }

final class ImportFlowState {
  const ImportFlowState({
    required this.status,
    this.proposed,
    this.resolved,
    this.preflight,
    this.profileMappings = const [],
    this.itemLabels = const {},
    this.alreadyPresentSearches = 0,
    this.error,
  });

  const ImportFlowState.initial() : this(status: ImportFlowStatus.idle);

  final ImportFlowStatus status;
  final ProposedImportPlan? proposed;
  final ResolvedImportPlan? resolved;
  final ImportPreflightResult? preflight;
  final List<ProfileDependencyMapping> profileMappings;
  final Map<String, String> itemLabels;
  final int alreadyPresentSearches;
  final Object? error;

  ImportFlowState copyWith({
    ImportFlowStatus? status,
    ProposedImportPlan? proposed,
    ResolvedImportPlan? resolved,
    ImportPreflightResult? preflight,
    List<ProfileDependencyMapping>? profileMappings,
    Map<String, String>? itemLabels,
    int? alreadyPresentSearches,
    Object? error,
  }) => ImportFlowState(
    status: status ?? this.status,
    proposed: proposed ?? this.proposed,
    resolved: resolved ?? this.resolved,
    preflight: preflight ?? this.preflight,
    profileMappings: profileMappings ?? this.profileMappings,
    itemLabels: itemLabels ?? this.itemLabels,
    alreadyPresentSearches:
        alreadyPresentSearches ?? this.alreadyPresentSearches,
    error: error,
  );
}

final importPackageStagerProvider = Provider<LegacyImportStager>((ref) {
  return LegacyImportStager(
    fs: ref.watch(appFileSystemProvider),
    sources: [
      for (final source in ref.watch(exportImportSourcesProvider))
        LegacyImportSourceDescriptor(
          id: source.id,
          schemaVersion: source.schemaVersion,
        ),
    ],
  );
});

final importFlowProvider =
    NotifierProvider.autoDispose<ImportFlowNotifier, ImportFlowState>(
      ImportFlowNotifier.new,
    );

class ImportFlowNotifier extends AutoDisposeNotifier<ImportFlowState> {
  StagedExportPackage? _package;
  Map<String, PackageTransactionSource> _sources = const {};
  var _warningsAcknowledged = false;
  var _availableBytes = 1 << 62;
  var _stagingBytes = 0;
  List<SourcePreflightSnapshot> _preflightSnapshots = const [];
  Map<String, ImportSourceChangeFacts> _changeFacts = const {};
  final Map<ProfileReferenceKey, int> _profileChoices = {};
  final Set<ProfileReferenceKey> _createdProfileChoices = {};

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
      final package = await ref.read(importPackageStagerProvider).stage(path);
      _package = package;
      _stagingBytes = package.manifest.sources.fold(
        0,
        (total, source) =>
            total + source.parts.fold(0, (sum, part) => sum + part.byteLength),
      );
      _profileChoices.clear();
      _createdProfileChoices.clear();
      final disk = await DiskSpaceInfo.fromTempDir(
        ref.read(appFileSystemProvider),
      );
      _availableBytes = disk.freeSpace > 0 ? disk.freeSpace : 1 << 62;
      final registry = ref.read(backupRegistryProvider);
      final exportSources = ref.read(exportImportSourcesProvider);
      final sourcesById = {
        for (final source in exportSources) source.id: source,
      };
      final descriptors = {
        for (final descriptor in exportSources.map(
          (s) => s.selectionDescriptor,
        ))
          descriptor.id: descriptor,
      };
      final wrappers = <String, PackageTransactionSource>{};
      final planning = <ImportSourcePlanningInput>[];
      final preflightSnapshots = <SourcePreflightSnapshot>[];
      final changeFacts = <String, ImportSourceChangeFacts>{};
      final itemLabels = <String, String>{};
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
        final wrapper = PackageTransactionSource(
          source: source,
          incomingPath: incomingPath,
          fs: ref.read(appFileSystemProvider),
          ref: ref,
          credentialsIncluded: package.manifest.containsCredentials ?? true,
        );
        await wrapper.prepare(null);
        await wrapper.measureRollback();
        itemLabels.addAll(importItemLabels(wrapper.preparedData));
        final selection =
            manifest.selection ?? ExportNodeSelection.all(manifest.id);
        final integrityIssues = const ImportSourceIntegrityValidator().validate(
          sourceId: manifest.id,
          packageSchemaVersion: manifest.schemaVersion,
          supportedSchemaVersion: sourcesById[manifest.id]!.schemaVersion,
          selection: selection,
          itemRecommendations: manifest.itemRecommendedActions,
          data: wrapper.preparedData,
        );
        final descriptor = descriptors[manifest.id];
        final isCollection = descriptor?.isCollection ?? false;
        final localIds = descriptor?.childIds ?? const <String>{};
        final incomingIds = _incomingItemIds(wrapper.preparedData, selection);
        final alreadyPresentSearchIds = <String>{};
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
              alreadyPresentSearchIds.add(record.id);
            }
          }
          alreadyPresentSearches += alreadyPresentSearchIds.length;
        }
        final items = switch (wrapper.preparedData) {
          final List<BooruConfig> profiles => _profilePlanningItems(
            profiles,
            ref.read(booruConfigProvider),
            manifest.itemRecommendedActions,
          ),
          _ => [
            for (final itemId in incomingIds)
              if (!(manifest.id == 'pinned_searches' &&
                  itemId.startsWith('search:') &&
                  alreadyPresentSearchIds.contains(itemId.substring(7))))
                ImportItemPlanningInput(
                  id: itemId,
                  matchingItemId: localIds.contains(itemId) ? itemId : null,
                  compatibleTargetIds: localIds.difference({itemId}),
                  recommendedAction: manifest.itemRecommendedActions[itemId],
                  availableActions:
                      manifest.id == 'pinned_searches' &&
                          itemId.startsWith('search:')
                      ? const {ImportAction.copy, ImportAction.skip}
                      : null,
                  fallbackAction:
                      manifest.id == 'pinned_searches' &&
                          itemId.startsWith('search:')
                      ? ImportAction.copy
                      : null,
                ),
          ],
        };
        changeFacts[source.id] = ImportSourceChangeFacts(
          sourceId: source.id,
          incomingIds: switch (wrapper.preparedData) {
            final List<BooruConfig> _ => items.map((item) => item.id).toSet(),
            _ => incomingIds,
          },
          existingIds: localIds,
          identicalIds: {
            for (final id in alreadyPresentSearchIds) 'search:$id',
          },
          isSingleValue: !isCollection,
        );
        planning.add(
          ImportSourcePlanningInput(
            id: manifest.id,
            kind: isCollection
                ? ImportSourceKind.collection
                : ImportSourceKind.value,
            selectionComplete: selection.kind == ExportNodeSelectionKind.all,
            recommendedAction: manifest.recommendedAction,
            items: items,
          ),
        );
        wrappers[source.id] = wrapper;
        preflightSnapshots.add(
          SourcePreflightSnapshot(
            sourceId: source.id,
            revisionToken: await wrapper.revisionToken(),
            rollbackBytes: wrapper.preflightRollbackBytes,
            errors: integrityIssues,
          ),
        );
      }
      if (wrappers['profiles'] == null) {
        final source = registry.getSource('profiles');
        if (source == null) {
          throw StateError('Profile import source is unavailable');
        }
        final wrapper = PackageTransactionSource(
          source: source,
          incomingPath: null,
          fs: ref.read(appFileSystemProvider),
          ref: ref,
          credentialsIncluded: false,
        );
        await wrapper.measureRollback();
        wrappers[source.id] = wrapper;
        preflightSnapshots.add(
          SourcePreflightSnapshot(
            sourceId: source.id,
            revisionToken: await wrapper.revisionToken(),
            rollbackBytes: wrapper.preflightRollbackBytes,
          ),
        );
        changeFacts[source.id] = ImportSourceChangeFacts(
          sourceId: source.id,
          existingIds: descriptors[source.id]?.childIds ?? const {},
        );
      }
      _sources = wrappers;
      _preflightSnapshots = preflightSnapshots;
      _changeFacts = changeFacts;
      final proposed = const ImportPlanner().plan(planning);
      final resolved = proposed.resolveDefaults();
      final dependencies = _profileDependencies(resolved);
      state = ImportFlowState(
        status: ImportFlowStatus.review,
        proposed: proposed,
        resolved: resolved,
        preflight: _preflightWithDependencies(
          proposed,
          resolved,
          dependencies,
        ),
        profileMappings: dependencies.mappings,
        itemLabels: Map.unmodifiable(itemLabels),
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
    final dependencies = _profileDependencies(resolved);
    state = state.copyWith(
      resolved: resolved,
      preflight: _preflightWithDependencies(
        proposed,
        resolved,
        dependencies,
      ),
      profileMappings: dependencies.mappings,
    );
  }

  void chooseProfileMapping(ProfileReferenceKey key, int profileId) {
    _createdProfileChoices.remove(key);
    _profileChoices[key] = profileId;
    final proposed = state.proposed;
    final resolved = state.resolved;
    if (proposed == null || resolved == null) return;
    final dependencies = _profileDependencies(resolved);
    state = state.copyWith(
      profileMappings: dependencies.mappings,
      preflight: _preflightWithDependencies(
        proposed,
        resolved,
        dependencies,
      ),
    );
  }

  void createProfileFor(ProfileReferenceKey key) {
    _profileChoices.remove(key);
    _createdProfileChoices.add(key);
    final proposed = state.proposed;
    final resolved = state.resolved;
    if (proposed == null || resolved == null) return;
    final dependencies = _profileDependencies(resolved);
    state = state.copyWith(
      profileMappings: dependencies.mappings,
      preflight: _preflightWithDependencies(
        proposed,
        resolved,
        dependencies,
      ),
    );
  }

  void acknowledgeWarnings(bool value) {
    _warningsAcknowledged = value;
    final proposed = state.proposed;
    final resolved = state.resolved;
    if (proposed == null || resolved == null) return;
    state = state.copyWith(
      preflight: _preflightWithDependencies(
        proposed,
        resolved,
        _profileDependencies(resolved),
      ),
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

  ImportPreflightResult _preflightWithDependencies(
    ProposedImportPlan proposed,
    ResolvedImportPlan resolved,
    ProfileDependencyPlan dependencies,
  ) {
    final resolvedMappings = <ProfileReferenceKey, int>{};
    for (final mapping in dependencies.mappings) {
      final id = mapping.profileId;
      if (id != null) {
        resolvedMappings[ProfileReferenceKey.fromReference(
              mapping.reference,
            )] =
            id;
      }
    }
    for (final source in _sources.values) {
      source.profileMappings = resolvedMappings;
      if (source.id == 'profiles') {
        source.additionalProfiles = dependencies.createdProfiles;
      }
    }
    final (effectiveProposed, effectiveResolved) = _withDependencyProfiles(
      proposed,
      resolved,
      dependencies.createdProfiles,
    );
    final resolvedById = {
      for (final source in effectiveResolved.sources) source.id: source,
    };
    final snapshots = [
      for (final snapshot in _preflightSnapshots)
        SourcePreflightSnapshot(
          sourceId: snapshot.sourceId,
          revisionToken: snapshot.revisionToken,
          summary: switch ((
            resolvedById[snapshot.sourceId],
            _changeFacts[snapshot.sourceId],
          )) {
            (final source?, final facts?) =>
              const ImportChangeSummarizer().summarize(
                source: source,
                facts: facts,
                additionalCreated: snapshot.sourceId == 'profiles'
                    ? dependencies.createdProfiles.length
                    : 0,
              ),
            _ => snapshot.summary,
          },
          warnings: snapshot.warnings,
          errors: snapshot.errors,
          rollbackBytes: snapshot.rollbackBytes,
        ),
    ];
    return _preflight(
      effectiveProposed,
      effectiveResolved,
      [
        ...snapshots,
        if (dependencies.errors.isNotEmpty)
          SourcePreflightSnapshot(
            sourceId: 'profile_dependencies',
            revisionToken: 'profile_dependencies',
            errors: dependencies.errors,
          ),
      ],
    );
  }

  ProfileDependencyPlan _profileDependencies(ResolvedImportPlan resolved) {
    final resolvedById = {
      for (final source in resolved.sources) source.id: source,
    };
    final importedProfiles = switch (_sources['profiles']?.preparedData) {
      final List<BooruConfig> profiles => profiles,
      _ => const <BooruConfig>[],
    };
    final references = <BackupProfileReference>[];
    if (resolvedById['pinned_searches']?.action != ImportAction.skip) {
      switch (_sources['pinned_searches']?.preparedData) {
        case final PinnedSearchBackupData data:
          final resolution = resolvedById['pinned_searches']!;
          references.addAll(
            data.records
                .where(
                  (record) => _includesDependencyItem(
                    resolution,
                    'search:${record.id}',
                  ),
                )
                .map((record) => record.profile),
          );
      }
    }
    if (resolvedById['following_feeds']?.action != ImportAction.skip) {
      switch (_sources['following_feeds']?.preparedData) {
        case final FollowingFeedBackupData data:
          final resolution = resolvedById['following_feeds']!;
          references.addAll(
            data.feeds
                .where(
                  (feed) => _includesDependencyItem(
                    resolution,
                    'feed:${feed.id}',
                  ),
                )
                .map((feed) => feed.profile),
          );
      }
    }
    return const ProfileDependencyPlanner().plan(
      references: references,
      localProfiles: ref.read(booruConfigProvider),
      importedProfiles: importedProfiles,
      profileResolution: resolvedById['profiles'],
      credentialsIncluded: _sources['profiles']?.credentialsIncluded ?? false,
      choices: _profileChoices,
      createFromReferences: _createdProfileChoices,
    );
  }

  bool _includesDependencyItem(
    ResolvedImportSource source,
    String itemId,
  ) {
    if (source.action == ImportAction.replace) return true;
    for (final item in source.items) {
      if (item.id == itemId) return item.action != ImportAction.skip;
    }
    return false;
  }

  (
    ProposedImportPlan,
    ResolvedImportPlan,
  )
  _withDependencyProfiles(
    ProposedImportPlan proposed,
    ResolvedImportPlan resolved,
    List<BooruConfig> createdProfiles,
  ) {
    if (createdProfiles.isEmpty) return (proposed, resolved);
    ProposedImportSource? proposedProfiles;
    for (final source in proposed.sources) {
      if (source.id == 'profiles') proposedProfiles = source;
    }
    ResolvedImportSource? resolvedProfiles;
    for (final source in resolved.sources) {
      if (source.id == 'profiles') resolvedProfiles = source;
    }
    final effectiveProposedProfiles =
        proposedProfiles ??
        ProposedImportSource(
          id: 'profiles',
          kind: ImportSourceKind.collection,
          selectionComplete: false,
          availableActions: const {
            ImportAction.configureItems,
            ImportAction.skip,
          },
          defaultAction: ImportAction.configureItems,
          items: const [],
        );
    final effectiveResolvedProfiles = switch (resolvedProfiles) {
      null => ResolvedImportSource(
        id: 'profiles',
        action: ImportAction.configureItems,
        items: const [],
      ),
      final source when source.action == ImportAction.skip => source.copyWith(
        action: ImportAction.configureItems,
        items: [
          for (final item in source.items)
            item.copyWith(action: ImportAction.skip),
        ],
      ),
      final source => source,
    };
    return (
      ProposedImportPlan(
        sources: [
          effectiveProposedProfiles,
          for (final source in proposed.sources)
            if (source.id != 'profiles') source,
        ],
        warnings: proposed.warnings,
        errors: proposed.errors,
      ),
      ResolvedImportPlan(
        sources: [
          effectiveResolvedProfiles,
          for (final source in resolved.sources)
            if (source.id != 'profiles') source,
        ],
      ),
    );
  }

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
}

Set<String> _incomingItemIds(
  Object? data,
  ExportNodeSelection selection,
) => switch (selection.kind) {
  ExportNodeSelectionKind.explicit => selection.childIds,
  ExportNodeSelectionKind.all => importedItemIds(data),
};

List<ImportItemPlanningInput> _profilePlanningItems(
  List<BooruConfig> imported,
  List<BooruConfig> local,
  Map<String, ImportAction> recommendations,
) => [
  for (final profile in imported)
    _profilePlanningItem(profile, local, recommendations),
];

ImportItemPlanningInput _profilePlanningItem(
  BooruConfig imported,
  List<BooruConfig> local,
  Map<String, ImportAction> recommendations,
) {
  final id = 'profile:${imported.id}';
  final candidates = portableProfileMatches(imported, local);
  final sameId = candidates.where((profile) => profile.id == imported.id);
  final match = sameId.length == 1
      ? sameId.single
      : candidates.length == 1
      ? candidates.single
      : null;
  if (match != null) {
    final targetId = 'profile:${match.id}';
    return ImportItemPlanningInput(
      id: id,
      matchingItemId: targetId,
      compatibleTargetIds: {targetId},
      availableActions: const {
        ImportAction.update,
        ImportAction.copy,
        ImportAction.skip,
      },
      defaultTargetId: targetId,
      recommendedAction: recommendations[id],
    );
  }
  if (candidates.length > 1) {
    return ImportItemPlanningInput(
      id: id,
      compatibleTargetIds: {
        for (final candidate in candidates) 'profile:${candidate.id}',
      },
      availableActions: const {
        ImportAction.update,
        ImportAction.copy,
        ImportAction.skip,
      },
      targetRequiredActions: const {ImportAction.update},
      fallbackAction: ImportAction.update,
      recommendedAction: recommendations[id],
    );
  }
  return ImportItemPlanningInput(
    id: id,
    availableActions: const {ImportAction.copy, ImportAction.skip},
    fallbackAction: ImportAction.copy,
    recommendedAction: recommendations[id],
  );
}

final class PackageTransactionSource implements ImportTransactionSource {
  PackageTransactionSource({
    required this.source,
    required this.incomingPath,
    required this.fs,
    required this.ref,
    required this.credentialsIncluded,
  });

  final BackupDataSource source;
  final String? incomingPath;
  final AppFileSystem fs;
  final Ref ref;
  final bool credentialsIncluded;
  Map<ProfileReferenceKey, int> profileMappings = const {};
  List<BooruConfig> additionalProfiles = const [];
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
    final path = incomingPath;
    if (path == null && id == 'profiles') {
      preflightRevision = await revisionToken();
      return;
    }
    if (path == null) throw StateError('Source $id has no incoming payload');
    _preparation = await capability.prepareImport(path, context);
    preflightRevision = await revisionToken();
  }

  @override
  Future<String> revisionToken() async {
    final digest = switch (source) {
      final JsonBackupSource jsonSource => sha256.convert(
        utf8.encode(await jsonSource.encodeRevisionSnapshot()),
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
    if (id == 'profiles' && additionalProfiles.isNotEmpty) {
      await _applyProfiles(const [], plan);
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
    if (resolution.action == ImportAction.skip) return;
    final repository = ref.read(booruConfigRepoProvider);
    final projection = const ProfileImportProjector().project(
      imported: imported,
      local: (await repository.getAll()).toList(),
      resolution: resolution,
      credentialsIncluded: credentialsIncluded,
    );
    final projected = projection.profiles.toList();
    final usedIds = projected.map((profile) => profile.id).toSet();
    for (final profile in additionalProfiles) {
      if (!usedIds.add(profile.id)) {
        throw StateError('Created profile ID is no longer available');
      }
      projected.add(profile);
    }
    await repository.clear();
    await repository.addAll(projected);
    await ref.read(booruConfigProvider.notifier).fetch();
  }

  Future<void> _applyPinnedSearches(
    PinnedSearchBackupData data,
    ResolvedImportSource resolution, {
    BackupProfileIdResolver? profileIdResolver,
  }) async {
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
              profileIdResolver: profileIdResolver ?? _profileId,
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
    final recordActions = <String, ImportAction>{};
    for (final item in resolution.items) {
      if (item.id.startsWith('search:')) {
        recordActions[item.id.substring(7)] = item.action;
        continue;
      }
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
                recordActions: recordActions,
                profileIdResolver: profileIdResolver ?? _profileId,
              ),
        );
  }

  Future<void> _applyFollowingFeeds(
    FollowingFeedBackupData data,
    ResolvedImportSource resolution, {
    BackupProfileIdResolver? profileIdResolver,
  }) async {
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
              profileIdResolver: profileIdResolver ?? _profileId,
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
                profileIdResolver: profileIdResolver ?? _profileId,
              ),
        );
  }

  String? _withoutPrefix(String? value, String prefix) => switch (value) {
    final String id when id.startsWith(prefix) => id.substring(prefix.length),
    final id => id,
  };

  int? _profileId(BackupProfileReference profile) =>
      profileMappings[ProfileReferenceKey.fromReference(profile)];

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
            await _applyPinnedSearches(
              data,
              replace,
              profileIdResolver: (profile) => profile.id,
            );
          case final FollowingFeedBackupData data:
            await _applyFollowingFeeds(
              data,
              replace,
              profileIdResolver: (profile) => profile.id,
            );
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
