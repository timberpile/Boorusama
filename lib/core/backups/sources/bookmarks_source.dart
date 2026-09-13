// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

// Project imports:
import '../../../foundation/info/package_info.dart';
import '../../bookmarks/providers.dart';
import '../../bookmarks/types.dart';
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

const kBookmarksBackupVersion = 1;

class BookmarksBackupSource extends JsonBackupSource<BookmarkBackupData> {
  BookmarksBackupSource(Ref ref)
    : super(
        id: 'bookmarks',
        priority: 2,
        version: kBookmarksBackupVersion,
        appVersion: ref.read(appVersionProvider),
        dataGetter: () async {
          final bookmarks = await (await ref.read(bookmarkRepoProvider.future))
              .getAllBookmarksOrEmpty(
                imageUrlResolver: (booruId) =>
                    ref.read(bookmarkUrlResolverProvider(booruId)),
              );
          final groups = await (await ref.read(
            bookmarkGroupRepoProvider.future,
          )).getGroups();
          return buildBookmarkBackupData(
            bookmarks: bookmarks,
            groups: groups,
            scope: const BookmarkExportScope.all(),
          );
        },
        scopedDataGetter: (options) async {
          final state = await ref.read(bookmarkProvider.future);
          final scope = switch (options?.scope) {
            final BookmarkExportScope scope => scope,
            _ => const BookmarkExportScope.all(),
          };
          return buildBookmarkBackupData(
            bookmarks: state.items,
            groups: state.groups,
            scope: scope,
          );
        },
        executor: (_, _) async {},
        resultExecutor: (data, uiContext) async {
          final bookmarkRepository = await ref.read(
            bookmarkRepoProvider.future,
          );
          final groupRepository = await ref.read(
            bookmarkGroupRepoProvider.future,
          );
          final currentBookmarks = await bookmarkRepository
              .getAllBookmarksOrEmpty(
                imageUrlResolver: (booruId) =>
                    ref.read(bookmarkUrlResolverProvider(booruId)),
              );
          final plan = const BookmarkImportPlanner().plan(
            data: data,
            currentBookmarks: currentBookmarks,
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
            bookmarkRepository: bookmarkRepository,
            groupRepository: groupRepository,
            imageUrlResolver: (booruId) =>
                ref.read(bookmarkUrlResolverProvider(booruId)),
          ).apply(resolvedPlan);
          ref.invalidate(bookmarkProvider);
          return BackupOperationResult(
            bookmarkCount: result.totalCount,
            groupCount: result.groupCount,
            alreadyExistedCount: result.alreadyExistedCount,
          );
        },
        handler: BookmarkBackupCodec(
          bookmarkParser: (json) {
            final booruId = json['booruId'] as int?;
            final resolver = ref.read(bookmarkUrlResolverProvider(booruId));
            return Bookmark.fromJson(json, imageUrlResolver: resolver);
          },
        ),
        extraPayloadEncoder: (data) => data.extraFields,
        exportResultBuilder: (data) => BackupOperationResult(
          bookmarkCount: data.bookmarks.length,
          groupCount: data.groups.length,
        ),
        ref: ref,
      );

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
                data: (bookmarkState) => bookmarkState.bookmarks.isNotEmpty
                    ? context.t.bookmark.counter(
                        n: bookmarkState.bookmarks.length,
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
