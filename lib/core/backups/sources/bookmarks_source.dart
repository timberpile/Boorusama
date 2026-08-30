// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

// Project imports:
import '../../../foundation/info/package_info.dart';
import '../../bookmarks/providers.dart';
import '../../bookmarks/types.dart';
import '../types/backup_data_source.dart';
import 'bookmark_backup_data.dart';
import 'bookmark_backup_importer.dart';
import 'bookmark_backup_messages.dart';
import '../widgets/backup_restore_tile.dart';
import '../widgets/bookmark_export_scope_dialog.dart';
import 'json_source.dart';

const kBookmarksBackupVersion = 1;

class BookmarksBackupSource extends JsonBackupSource<BookmarkBackupData> {
  BookmarksBackupSource(Ref ref)
    : super(
        id: 'bookmarks',
        priority: 2,
        version: kBookmarksBackupVersion,
        appVersion: ref.read(appVersionProvider),
        dataGetter: (options) async {
          final bookmarks = await (await ref.read(bookmarkRepoProvider.future))
              .getAllBookmarksOrEmpty(
                imageUrlResolver: (booruId) =>
                    ref.read(bookmarkUrlResolverProvider(booruId)),
              );
          final groupRepository = await ref.read(
            bookmarkGroupRepoProvider.future,
          );
          final groups = await groupRepository.getGroups();
          final membershipsByBookmark = await groupRepository
              .getMembershipsByBookmark();

          final scope = switch (options?.scope) {
            null => const BookmarkExportScope.all(),
            final BookmarkExportScope scope => scope,
            _ => throw ArgumentError('Unsupported bookmark export scope'),
          };

          return buildBookmarkBackupData(
            bookmarks: bookmarks,
            groups: groups,
            membershipsByBookmark: membershipsByBookmark,
            scope: scope,
          );
        },
        exportResultBuilder: buildBookmarkExportResult,
        executor: (data, _) async {
          final bookmarkRepository = await ref.read(
            bookmarkRepoProvider.future,
          );
          final groupRepository = await ref.read(
            bookmarkGroupRepoProvider.future,
          );
          final result = await importBookmarkBackup(
            data: data,
            bookmarkRepository: bookmarkRepository,
            bookmarkGroupRepository: groupRepository,
            imageUrlResolver: (booruId) =>
                ref.read(bookmarkUrlResolverProvider(booruId)),
          );
          ref.invalidate(bookmarkGroupsProvider);
          ref.invalidate(bookmarkProvider);
          return result;
        },
        handler: BookmarkBackupHandler(
          parser: (json) {
            final booruId = json['booruId'] as int?;
            final resolver = ref.read(bookmarkUrlResolverProvider(booruId));
            return Bookmark.fromJson(json, imageUrlResolver: resolver);
          },
        ),
        extraPayloadEncoder: (data) => data.extraFields,
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
                    ? '${bookmarkState.bookmarks.length} bookmarks'
                    : 'No bookmarks',
                loading: () => 'Loading...',
                error: (_, _) => 'Error loading bookmarks',
              ),
          onPrepareExport: (context) async {
            final groupRepository = await ref.read(
              bookmarkGroupRepoProvider.future,
            );
            if (!context.mounted) return null;
            final groups = await groupRepository.getGroups();
            if (!context.mounted) return null;
            final scope = await showBookmarkExportScopeDialog(
              context,
              groups: groups,
            );

            return scope == null ? null : BackupExportOptions(scope: scope);
          },
          exportSuccessMessageBuilder: (result) => formatBookmarkExportSuccess(
            result: result,
            template:
                context.t.settings.backup_and_restore.bookmarks_export_success,
          ),
          importSuccessMessageBuilder: (result) => formatBookmarkImportSuccess(
            result: result,
            template:
                context.t.settings.backup_and_restore.bookmarks_import_success,
            existingTemplate: context
                .t
                .settings
                .backup_and_restore
                .bookmarks_import_success_existing,
          ),
        );
      },
    );
  }
}
