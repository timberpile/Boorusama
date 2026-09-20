// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

// Project imports:
import '../../../foundation/info/package_info.dart';
import '../../configs/config/types.dart';
import '../../configs/manage/providers.dart';
import '../../search/subscriptions/providers.dart';
import '../types/types.dart';
import '../widgets/backup_restore_tile.dart';
import 'json_source.dart';
import 'pinned_search_backup_codec.dart';
import 'pinned_search_backup_data.dart';
import 'pinned_search_import_service.dart';

class PinnedSearchesBackupSource
    extends JsonBackupSource<PinnedSearchBackupData> {
  PinnedSearchesBackupSource(Ref ref)
    : super(
        id: 'pinned_searches',
        priority: 100000,
        version: 2,
        appVersion: ref.read(appVersionProvider),
        dataGetter: () async {
          final repository = await ref.read(
            searchSubscriptionRepositoryProvider.future,
          );
          final profiles = {
            for (final profile
                in await ref.read(booruConfigRepoProvider).getAll())
              profile.id: profile,
          };
          return PinnedSearchBackupData(
            folders: [
              for (final folder in await repository.getFolders())
                if (profiles[folder.profileId] case final profile?)
                  PinnedSearchFolderBackupRecord(
                    id: folder.id,
                    name: folder.name,
                    position: folder.position,
                    searchIds: folder.searchIds.toList(),
                    profile: PinnedSearchProfileReference(
                      id: profile.id,
                      booruType: profile.auth.booruType.name,
                      url: normalizePinnedSearchProfileUrl(profile.url),
                      name: profile.name,
                    ),
                  ),
            ],
            records: [
              for (final subscription in await repository.getAll())
                if (profiles[subscription.profileId] case final profile?)
                  PinnedSearchBackupRecord(
                    id: subscription.id,
                    name: subscription.name,
                    query: subscription.query,
                    position: subscription.position,
                    profile: PinnedSearchProfileReference(
                      id: profile.id,
                      booruType: profile.auth.booruType.name,
                      url: normalizePinnedSearchProfileUrl(profile.url),
                      name: profile.name,
                    ),
                  ),
            ],
          );
        },
        executor: (_, _) async {},
        resultExecutor: (data, _) => ref
            .read(searchSubscriptionsProvider.notifier)
            .runSerializedMutation((repository) async {
              final profiles = await ref.read(booruConfigRepoProvider).getAll();
              final result = await PinnedSearchImportService(
                repository: repository,
              ).apply(data, profiles: profiles);
              return BackupOperationResult(
                bookmarkCount: 0,
                pinnedSearchCount: result.importedCount,
                alreadyExistedCount: result.alreadyExistedCount,
                skippedProfileCount: result.skippedProfileCount,
              );
            }),
        handler: PinnedSearchBackupCodec(),
        exportResultBuilder: (data) => BackupOperationResult(
          bookmarkCount: 0,
          pinnedSearchCount: data.records.length,
        ),
        ref: ref,
      );

  @override
  String get displayName => Translations().pinned_searches.title;

  @override
  Widget buildTile(BuildContext context) => Consumer(
    builder: (context, ref, child) => DefaultBackupTile(
      source: this,
      title: context.t.pinned_searches.title,
      icon: Symbols.push_pin,
      subtitle: ref
          .watch(searchSubscriptionsProvider)
          .when(
            data: (state) => context.t.pinned_searches.backup_count(
              n: state.subscriptions.length,
            ),
            loading: () => context.t.pinned_searches.backup_loading,
            error: (_, _) => context.t.pinned_searches.load_failed,
          ),
      exportSuccessMessageBuilder: (result) => context
          .t
          .pinned_searches
          .backup_export_success
          .replaceAll('{count}', '${result.pinnedSearchCount ?? 0}'),
      importSuccessMessageBuilder: (result) =>
          (switch (result.skippedProfileCount) {
                final count? when count > 0 =>
                  context.t.pinned_searches.backup_import_skipped,
                _ => context.t.pinned_searches.backup_import_success,
              })
              .replaceAll('{count}', '${result.pinnedSearchCount ?? 0}')
              .replaceAll('{existing}', '${result.alreadyExistedCount}')
              .replaceAll('{skipped}', '${result.skippedProfileCount ?? 0}'),
    ),
  );
}
