// Dart imports:
import 'dart:convert';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

// Project imports:
import '../../../foundation/info/package_info.dart';
import '../../boorus/engine/providers.dart';
import '../../bookmarks/providers.dart';
import '../../bookmarks/types.dart';
import '../../content/providers.dart';
import '../preparation/preparation_pipeline.dart';
import '../types/backup_data_source.dart';
import '../types/types.dart';
import '../widgets/backup_restore_tile.dart';
import '../widgets/bookmark_group_conflict_dialog.dart';
import '../widgets/bookmark_export_scope_dialog.dart';
import 'bookmark_backup_codec.dart';
import 'bookmark_backup_data.dart';
import 'bookmark_import_planner.dart';
import 'bookmark_import_service.dart';
import 'json_source.dart';

const kBookmarksBackupVersion = 10;

class BookmarksBackupSource extends JsonBackupSource<BookmarkBackupData> {
  BookmarksBackupSource(Ref ref)
    : super(
        id: 'bookmarks',
        priority: 2,
        version: kBookmarksBackupVersion,
        appVersion: ref.read(appVersionProvider),
        dataGetter: () async {
          final state = await ref
              .read(bookmarkProvider.notifier)
              .snapshotForExport();
          return buildBookmarkBackupData(
            bookmarks: state.items,
            pools: state.pools,
            records: state.hasUnifiedRecords ? state.records : null,
            groups: state.groups,
            folders: state.folders,
            scope: const BookmarkExportScope.all(),
          );
        },
        scopedDataGetter: (options) async {
          final state = await ref
              .read(bookmarkProvider.notifier)
              .snapshotForExport();
          final scope = switch (options?.scope) {
            final BookmarkExportScope scope => scope,
            _ => const BookmarkExportScope.all(),
          };
          return buildBookmarkBackupData(
            bookmarks: state.items,
            pools: state.pools,
            records: state.hasUnifiedRecords ? state.records : null,
            groups: state.groups,
            folders: state.folders,
            scope: scope,
          );
        },
        executor: (_, _) async {},
        resultExecutor: (data, uiContext) async {
          final library = ref.read(bookmarkProvider.notifier);
          return library.runSerializedMutation(
            () async {
              final bookmarkRepository = await library.bookmarkRepository;
              final groupRepository = await library.bookmarkGroupRepository;
              final unifiedStore = unifiedBookmarkStorage(bookmarkRepository);
              final currentRecords = unifiedStore != null
                  ? await unifiedStore.readAll()
                  : await bookmarkRepository.getAllBookmarksOrThrow(
                      imageUrlResolver: (booruId) =>
                          ref.read(bookmarkUrlResolverProvider(booruId)),
                    );
              final plan = const BookmarkImportPlanner().plan(
                data: data,
                currentBookmarks: currentRecords,
                currentGroups: await groupRepository.getGroups(),
              );
              if (uiContext != null && !uiContext.mounted) {
                throw const ImportCancelledException();
              }
              final resolvedPlan = switch ((plan.conflicts, uiContext)) {
                ([], _) => plan,
                (_, final BuildContext context) =>
                  await resolveBookmarkGroupConflicts(context, plan),
                _ => null,
              };
              if (resolvedPlan == null) {
                throw const ImportCancelledException();
              }
              final result = await BookmarkImportService(
                importFolderName: Translations().folders.imported_groups,
                bookmarkRepository: bookmarkRepository,
                groupRepository: groupRepository,
                imageUrlResolver: (booruId) =>
                    ref.read(bookmarkUrlResolverProvider(booruId)),
              ).apply(resolvedPlan);
              return BackupOperationResult(
                bookmarkCount: result.totalCount,
                groupCount: result.groupCount,
                alreadyExistedCount: result.alreadyExistedCount,
              );
            },
          );
        },
        handler: BookmarkBackupCodec(
          groupMetadataResolver: () => ref.read(groupMetadataCodecProvider),
          postDataCodec: (type) =>
              ref.read(booruPostCapabilityProvider(type))?.codec,
        ),
        extraPayloadEncoder: (data) => data.extraFields,
        exportResultBuilder: (data) => BackupOperationResult(
          bookmarkCount: data.records.length,
          groupCount: data.groups.length,
        ),
        ref: ref,
      );

  @override
  Future<String> encodeRollbackSnapshot() async {
    final data = await dataGetter();
    return converter.encode(
      payload: (handler as BookmarkBackupCodec).encodeLocalRecovery(data),
      extraFields: data.extraFields,
    );
  }

  @override
  Future<String> encodeRevisionSnapshot() async {
    final data = await dataGetter();
    return jsonEncode({
      'data': (handler as BookmarkBackupCodec).encodeLocalRecovery(data),
      ...data.extraFields,
    });
  }

  @override
  String get displayName => 'Bookmarks';

  @override
  Widget buildTile(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        return DefaultBackupTile(
          source: this,
          title: context.t.bookmark.title,
          icon: Symbols.bookmark,
          subtitle: ref
              .watch(bookmarkProvider)
              .when(
                data: (bookmarkState) =>
                    (bookmarkState.hasUnifiedRecords
                        ? bookmarkState.records.isNotEmpty
                        : bookmarkState.bookmarks.isNotEmpty ||
                              bookmarkState.pools.isNotEmpty)
                    ? context.t.bookmark.counter(
                        n: bookmarkState.hasUnifiedRecords
                            ? bookmarkState.records.length
                            : bookmarkState.bookmarks.length +
                                  bookmarkState.pools.length,
                      )
                    : context.t.bookmark.none,
                loading: () => context.t.bookmark.loading,
                error: (_, _) => context.t.bookmark.load_failed,
              ),
          onPrepareExport: (context) async {
            final groups = ref.read(bookmarkProvider).valueOrNull?.groups;
            if (groups == null) return null;
            final scope = await showBookmarkExportScopeDialog(
              context,
              groups: groups,
              folders: ref.read(bookmarkProvider).valueOrNull?.folders ?? [],
            );
            return scope == null ? null : BackupExportOptions(scope: scope);
          },
          exportSuccessMessageBuilder: (result) => context
              .t
              .settings
              .backup_and_restore
              .bookmarks_export_success
              .replaceAll('{bookmarks}', '${result.bookmarkCount}')
              .replaceAll('{groups}', '${result.groupCount}'),
          importSuccessMessageBuilder: (result) =>
              (result.alreadyExistedCount > 0
                      ? context
                            .t
                            .settings
                            .backup_and_restore
                            .bookmarks_import_success
                      : context
                            .t
                            .settings
                            .backup_and_restore
                            .bookmarks_import_success_new)
                  .replaceAll('{bookmarks}', '${result.bookmarkCount}')
                  .replaceAll('{groups}', '${result.groupCount}')
                  .replaceAll(
                    '{existing}',
                    '${result.alreadyExistedCount}',
                  ),
        );
      },
    );
  }
}
