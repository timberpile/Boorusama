import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../foundation/info/package_info.dart';
import '../../configs/config/types.dart';
import '../../configs/manage/providers.dart';
import '../../search/subscriptions/providers.dart';
import '../preparation/preparation_pipeline.dart';
import '../types/types.dart';
import '../widgets/backup_restore_tile.dart';
import '../widgets/pinned_search_missing_profiles_dialog.dart';
import 'following_feed_backup_codec.dart';
import 'following_feed_backup_data.dart';
import 'following_feed_import_service.dart';
import 'json_source.dart';
import 'pinned_search_import_preflight.dart';
import 'search_backup_profile.dart';

class FollowingFeedsBackupSource
    extends JsonBackupSource<FollowingFeedBackupData> {
  FollowingFeedsBackupSource(Ref ref)
    : super(
        id: 'following_feeds',
        priority: 100001,
        version: 1,
        appVersion: ref.read(appVersionProvider),
        extraPayloadEncoder: (_) => const {'source': 'following_feeds'},
        dataGetter: () async {
          final repository = await ref.read(
            searchSubscriptionRepositoryProvider.future,
          );
          final profiles = {
            for (final profile
                in await ref.read(booruConfigRepoProvider).getAll())
              profile.id: profile,
          };
          final sources = {
            for (final source in await repository.getAll()) source.id: source,
          };
          return FollowingFeedBackupData(
            feeds: [
              for (final feed in await repository.getFeeds())
                if (profiles[feed.profileId] case final profile?)
                  FollowingFeedBackupRecord(
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
            _applyApproved(ref, data, approval as PinnedSearchImportApproval),
        handler: FollowingFeedBackupCodec(),
        exportResultBuilder: (data) => BackupOperationResult(
          bookmarkCount: 0,
          feedCount: data.feeds.length,
        ),
        ref: ref,
      );

  Future<PinnedSearchImportApproval> confirmImportPreview(
    FollowingFeedBackupData data,
    Future<List<BooruConfig>> Function() projectedProfilesGetter,
    BuildContext? context,
  ) => _confirmImportPreview(ref, data, projectedProfilesGetter, context);

  @override
  String get displayName => Translations().following_feeds_backup.title;

  @override
  Widget buildTile(BuildContext context) => Consumer(
    builder: (context, ref, child) => DefaultBackupTile(
      source: this,
      title: context.t.following_feeds_backup.title,
      icon: Symbols.dynamic_feed,
      subtitle: ref
          .watch(searchSubscriptionsProvider)
          .when(
            data: (state) => context.t.following_feeds_backup.backup_count(
              n: state.feeds.length,
            ),
            loading: () => context.t.following_feeds_backup.backup_loading,
            error: (_, _) => context.t.following_feeds_backup.load_failed,
          ),
      exportSuccessMessageBuilder: (result) => context
          .t
          .following_feeds_backup
          .backup_export_success
          .replaceAll('{count}', '${result.feedCount ?? 0}'),
      importSuccessMessageBuilder: (result) =>
          (switch (result.skippedProfileCount) {
                final count? when count > 0 =>
                  context.t.following_feeds_backup.backup_import_skipped,
                _ => context.t.following_feeds_backup.backup_import_success,
              })
              .replaceAll('{count}', '${result.feedCount ?? 0}')
              .replaceAll('{existing}', '${result.alreadyExistedCount}')
              .replaceAll('{skipped}', '${result.skippedProfileCount ?? 0}'),
    ),
  );
}

Future<PinnedSearchImportApproval> _confirmImportPreview(
  Ref ref,
  FollowingFeedBackupData data,
  Future<List<BooruConfig>> Function() projectedProfilesGetter,
  BuildContext? context,
) async {
  final repository = await ref.read(
    searchSubscriptionRepositoryProvider.future,
  );
  final service = FollowingFeedImportService(repository: repository);
  final projected = service.preview(
    data,
    profiles: await projectedProfilesGetter(),
  );
  if (projected.unmatchedRecordIds.isNotEmpty) {
    if (context == null || !context.mounted) {
      throw const ImportCancelledException();
    }
    final accepted = await showPinnedSearchMissingProfilesDialog(
      context,
      projected.unmatchedRecordIds.length,
    );
    if (accepted != true || !context.mounted) {
      throw const ImportCancelledException();
    }
  }
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
  return PinnedSearchImportApproval(projected.unmatchedRecordIds);
}

Future<BackupOperationResult> _applyApproved(
  Ref ref,
  FollowingFeedBackupData data,
  PinnedSearchImportApproval approval,
) => ref.read(searchSubscriptionsProvider.notifier).runSerializedMutation((
  repository,
) async {
  final profiles = await ref.read(booruConfigRepoProvider).getAll();
  final service = FollowingFeedImportService(repository: repository);
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
    feedCount: result.importedCount,
    alreadyExistedCount: result.alreadyExistedCount,
    skippedProfileCount: result.skippedProfileCount,
  );
});
