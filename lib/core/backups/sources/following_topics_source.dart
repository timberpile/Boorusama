// Package imports:
import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

// Project imports:
import '../../../foundation/info/package_info.dart';
import '../../configs/config/types.dart';
import '../../configs/manage/providers.dart';
import '../../search/following_topics/providers.dart';
import '../preparation/preparation_pipeline.dart';
import '../widgets/search_backup_missing_profiles_dialog.dart';
import '../types/types.dart';
import '../widgets/backup_restore_tile.dart';
import 'json_source.dart';
import 'following_topic_backup_codec.dart';
import 'following_topic_backup_data.dart';
import 'following_topic_import_service.dart';
import 'search_backup_import_preflight.dart';
import 'search_backup_profile.dart';
import '../../search/following_topics/src/compatibility/topic_storage_contract.dart';

class FollowingTopicsBackupSource
    extends JsonBackupSource<FollowingTopicBackupData> {
  FollowingTopicsBackupSource(Ref ref)
    : super(
        id: followingTopicsBackupSourceId,
        priority: 100000,
        version: 2,
        extraPayloadEncoder: (_) => const {
          'source': followingTopicsBackupSourceId,
        },
        appVersion: ref.read(appVersionProvider),
        dataGetter: () => _loadFollowingTopicData(ref),
        scopedDataGetter: (options) async {
          final data = await _loadFollowingTopicData(ref);
          final scope = switch (options?.scope) {
            final FollowingTopicExportScope scope => scope,
            _ => const FollowingTopicExportScope.all(),
          };
          return filterFollowingTopicBackupData(data, scope);
        },
        executor: (_, _) async {},
        resultExecutor: (data, context) async {
          final approval = await _confirmImportPreview(
            ref,
            data,
            () => ref.read(booruConfigRepoProvider).getAll(),
            context,
          );
          return _applyApproved(ref, data, approval);
        },
        approvedResultExecutor: (data, context, approval) =>
            _applyApproved(ref, data, approval as SearchBackupImportApproval),
        handler: FollowingTopicBackupCodec(),
        exportResultBuilder: (data) => BackupOperationResult(
          bookmarkCount: 0,
          followingTopicCount: data.records.length,
        ),
        ref: ref,
      );

  Future<SearchBackupImportApproval> confirmImportPreview(
    FollowingTopicBackupData data,
    Future<List<BooruConfig>> Function() projectedProfilesGetter,
    BuildContext? context,
  ) => _confirmImportPreview(ref, data, projectedProfilesGetter, context);

  Future<Set<String>> unmatchedRecordIds(
    FollowingTopicBackupData data,
    List<BooruConfig> profiles,
  ) async {
    final repository = await ref.read(
      followingTopicRepositoryProvider.future,
    );
    return FollowingTopicImportService(
      repository: repository,
    ).preview(data, profiles: profiles).unmatchedRecordIds;
  }

  @override
  String get displayName => Translations().following_topics.title;

  @override
  Widget buildTile(BuildContext context) => Consumer(
    builder: (context, ref, child) => DefaultBackupTile(
      source: this,
      title: context.t.following_topics.title,
      icon: Symbols.rss_feed,
      subtitle: ref
          .watch(followingTopicsProvider)
          .when(
            data: (state) {
              final folderIds = state.organization.folders
                  .map((folder) => folder.id)
                  .toSet();
              final internalIds = {
                for (final feed in state.feeds)
                  if (!folderIds.contains(feed.id)) ...feed.sourceIds,
              };
              return '${context.t.following_topics.backup_count(
                n: state.topics.where((search) => !internalIds.contains(search.id)).length,
              )} · ${context.t.following_topics.backup_contents}';
            },
            loading: () => context.t.following_topics.backup_loading,
            error: (_, _) => context.t.following_topics.load_failed,
          ),
      exportSuccessMessageBuilder: (result) => context
          .t
          .following_topics
          .backup_export_success
          .replaceAll('{count}', '${result.followingTopicCount ?? 0}'),
      importSuccessMessageBuilder: (result) =>
          (switch (result.skippedProfileCount) {
                final count? when count > 0 =>
                  context.t.following_topics.backup_import_skipped,
                _ => context.t.following_topics.backup_import_success,
              })
              .replaceAll('{count}', '${result.followingTopicCount ?? 0}')
              .replaceAll('{existing}', '${result.alreadyExistedCount}')
              .replaceAll('{skipped}', '${result.skippedProfileCount ?? 0}'),
    ),
  );
}

Future<FollowingTopicBackupData> _loadFollowingTopicData(Ref ref) async {
  final repository = await ref.read(
    followingTopicRepositoryProvider.future,
  );
  final profiles = {
    for (final profile in await ref.read(booruConfigRepoProvider).getAll())
      profile.id: profile,
  };
  final topics = await repository.getAll();
  final feeds = await repository.getFeeds();
  final organization = await repository.getOrganization();
  final folderIds = organization.folders.map((folder) => folder.id).toSet();
  final internalIds = {
    for (final feed in feeds)
      if (!folderIds.contains(feed.id)) ...feed.sourceIds,
  };
  final exportedIds = topics
      .where(
        (topic) =>
            !internalIds.contains(topic.id) &&
            profiles.containsKey(topic.profileId),
      )
      .map((topic) => topic.id)
      .toSet();
  return FollowingTopicBackupData(
    homeSearchIds: organization.homeSearchIds
        .where(exportedIds.contains)
        .toList(),
    folders: [
      for (final folder in organization.folders)
        FollowingTopicFolderBackupRecord(
          id: folder.id,
          name: folder.name,
          position: folder.position,
          parentId: folder.parentId,
          searchIds: folder.searchIds.where(exportedIds.contains).toList(),
          feedEnabled: folder.feedEnabled,
          feedMaxPosts: folder.feedMaxPosts,
        ),
    ],
    records: [
      for (final subscription in topics.where(
        (search) => !internalIds.contains(search.id),
      ))
        if (profiles[subscription.profileId] case final profile?)
          FollowingTopicBackupRecord(
            id: subscription.id,
            name: subscription.name,
            query: subscription.query,
            queryStructure: subscription.queryStructure,
            position: subscription.position,
            autoUpdateEnabled: subscription.autoUpdateEnabled,
            folderId: organization.placements
                .firstWhere((p) => p.itemId == subscription.id)
                .folderId,
            folderPosition: organization.placements
                .firstWhere((p) => p.itemId == subscription.id)
                .position,
            profile: BackupProfileReference(
              id: profile.id,
              booruType: profile.auth.booruType.name,
              url: normalizeBackupProfileUrl(profile.url),
              name: profile.name,
            ),
          ),
    ],
  );
}

Future<SearchBackupImportApproval> _confirmImportPreview(
  Ref ref,
  FollowingTopicBackupData data,
  Future<List<BooruConfig>> Function() projectedProfilesGetter,
  BuildContext? context,
) async {
  final repository = await ref.read(
    followingTopicRepositoryProvider.future,
  );
  final service = FollowingTopicImportService(
    repository: repository,
    importFolderName: Translations().folders.imported_searches,
  );
  final projected = service.preview(
    data,
    profiles: await projectedProfilesGetter(),
  );
  if (context != null && !context.mounted) {
    throw const ImportCancelledException();
  }
  await confirmSearchBackupProfiles(
    unmatchedRecordIds: projected.unmatchedRecordIds,
    topicCount: projected.unmatchedRecordIds.length,
    feedCount: 0,
    context: context,
  );
  final latest = service.preview(
    data,
    profiles: await projectedProfilesGetter(),
  );
  if (!const SetEquality<String>().equals(
    projected.unmatchedRecordIds,
    latest.unmatchedRecordIds,
  )) {
    throw const ImportCancelledException();
  }
  return SearchBackupImportApproval(projected.unmatchedRecordIds);
}

Future<BackupOperationResult> _applyApproved(
  Ref ref,
  FollowingTopicBackupData data,
  SearchBackupImportApproval approval,
) => ref.read(followingTopicsProvider.notifier).runSerializedMutation((
  repository,
) async {
  final profiles = await ref.read(booruConfigRepoProvider).getAll();
  final service = FollowingTopicImportService(
    repository: repository,
    importFolderName: Translations().folders.imported_searches,
  );
  final preview = service.preview(data, profiles: profiles);
  if (!const SetEquality<String>().equals(
    preview.unmatchedRecordIds,
    approval.unmatchedRecordIds,
  )) {
    throw const ImportCancelledException();
  }
  final result = await service.apply(
    data,
    profiles: profiles,
    allowMissingProfiles: true,
  );
  return BackupOperationResult(
    bookmarkCount: 0,
    followingTopicCount: result.importedCount,
    alreadyExistedCount: result.alreadyExistedCount,
    skippedProfileCount: result.skippedProfileCount,
  );
});
