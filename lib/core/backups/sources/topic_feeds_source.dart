import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../foundation/info/package_info.dart';
import '../../configs/config/types.dart';
import '../../configs/manage/providers.dart';
import '../../search/following_topics/providers.dart';
import '../preparation/preparation_pipeline.dart';
import '../types/types.dart';
import '../widgets/backup_restore_tile.dart';
import '../widgets/search_backup_missing_profiles_dialog.dart';
import 'topic_feed_backup_codec.dart';
import 'topic_feed_backup_data.dart';
import 'topic_feed_import_service.dart';
import 'json_source.dart';
import 'search_backup_import_preflight.dart';
import 'search_backup_profile.dart';
import '../../search/following_topics/src/compatibility/topic_storage_contract.dart';

class TopicFeedsBackupSource extends JsonBackupSource<TopicFeedBackupData> {
  TopicFeedsBackupSource(Ref ref)
    : super(
        id: topicFeedsBackupSourceId,
        priority: 100001,
        version: 1,
        appVersion: ref.read(appVersionProvider),
        extraPayloadEncoder: (_) => const {'source': topicFeedsBackupSourceId},
        dataGetter: () => _loadTopicFeedData(ref),
        scopedDataGetter: (options) async {
          final data = await _loadTopicFeedData(ref);
          final scope = switch (options?.scope) {
            final TopicFeedExportScope scope => scope,
            _ => const TopicFeedExportScope.all(),
          };
          return filterTopicFeedBackupData(data, scope);
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
        handler: TopicFeedBackupCodec(),
        exportResultBuilder: (data) => BackupOperationResult(
          bookmarkCount: 0,
          feedCount: data.feeds.length,
        ),
        ref: ref,
      );

  Future<SearchBackupImportApproval> confirmImportPreview(
    TopicFeedBackupData data,
    Future<List<BooruConfig>> Function() projectedProfilesGetter,
    BuildContext? context,
  ) => _confirmImportPreview(ref, data, projectedProfilesGetter, context);

  Future<Set<String>> unmatchedRecordIds(
    TopicFeedBackupData data,
    List<BooruConfig> profiles,
  ) async {
    final repository = await ref.read(
      followingTopicRepositoryProvider.future,
    );
    return TopicFeedImportService(
      repository: repository,
    ).preview(data, profiles: profiles).unmatchedRecordIds;
  }

  @override
  String get displayName => Translations().topic_feeds_backup.title;

  @override
  Widget buildTile(BuildContext context) => Consumer(
    builder: (context, ref, child) => DefaultBackupTile(
      source: this,
      title: context.t.topic_feeds_backup.title,
      icon: Symbols.dynamic_feed,
      subtitle: ref
          .watch(followingTopicsProvider)
          .when(
            data: (state) {
              final folderIds = state.organization.folders
                  .map((folder) => folder.id)
                  .toSet();
              return context.t.topic_feeds_backup.backup_count(
                n: state.feeds
                    .where((feed) => !folderIds.contains(feed.id))
                    .length,
              );
            },
            loading: () => context.t.topic_feeds_backup.backup_loading,
            error: (_, _) => context.t.topic_feeds_backup.load_failed,
          ),
      exportSuccessMessageBuilder: (result) => context
          .t
          .topic_feeds_backup
          .backup_export_success
          .replaceAll('{count}', '${result.feedCount ?? 0}'),
      importSuccessMessageBuilder: (result) =>
          (switch (result.skippedProfileCount) {
                final count? when count > 0 =>
                  context.t.topic_feeds_backup.backup_import_skipped,
                _ => context.t.topic_feeds_backup.backup_import_success,
              })
              .replaceAll('{count}', '${result.feedCount ?? 0}')
              .replaceAll('{existing}', '${result.alreadyExistedCount}')
              .replaceAll('{skipped}', '${result.skippedProfileCount ?? 0}'),
    ),
  );
}

Future<TopicFeedBackupData> _loadTopicFeedData(Ref ref) async {
  final repository = await ref.read(
    followingTopicRepositoryProvider.future,
  );
  final profiles = {
    for (final profile in await ref.read(booruConfigRepoProvider).getAll())
      profile.id: profile,
  };
  final sources = {
    for (final source in await repository.getAll()) source.id: source,
  };
  final folderIds = (await repository.getOrganization()).folders
      .map((folder) => folder.id)
      .toSet();
  return TopicFeedBackupData(
    feeds: [
      for (final feed in await repository.getFeeds())
        if (!folderIds.contains(feed.id))
          if (profiles[feed.profileId] case final profile?)
            TopicFeedBackupRecord(
              id: feed.id,
              name: feed.name,
              position: feed.position,
              queries: [
                for (final id in feed.sourceIds)
                  switch (sources[id]) {
                    final source? => source.query,
                    null => throw StateError('Missing feed source $id'),
                  },
              ],
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
  TopicFeedBackupData data,
  Future<List<BooruConfig>> Function() projectedProfilesGetter,
  BuildContext? context,
) async {
  final repository = await ref.read(
    followingTopicRepositoryProvider.future,
  );
  final service = TopicFeedImportService(repository: repository);
  final projected = service.preview(
    data,
    profiles: await projectedProfilesGetter(),
  );
  if (context != null && !context.mounted) {
    throw const ImportCancelledException();
  }
  await confirmSearchBackupProfiles(
    unmatchedRecordIds: projected.unmatchedRecordIds,
    topicCount: 0,
    feedCount: projected.unmatchedRecordIds.length,
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
  TopicFeedBackupData data,
  SearchBackupImportApproval approval,
) => ref.read(followingTopicsProvider.notifier).runSerializedMutation((
  repository,
) async {
  final profiles = await ref.read(booruConfigRepoProvider).getAll();
  final service = TopicFeedImportService(repository: repository);
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
  // Restore older standalone feeds as topic folders immediately, even if the
  // initial on-device migration has already run.
  await repository.migrateLegacyTopicFeeds();
  return BackupOperationResult(
    bookmarkCount: 0,
    feedCount: result.importedCount,
    alreadyExistedCount: result.alreadyExistedCount,
    skippedProfileCount: result.skippedProfileCount,
  );
});
