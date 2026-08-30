// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

// Project imports:
import '../../../configs/config/providers.dart';
import '../../../posts/listing/providers.dart';
import '../data/bookmark_convert.dart';
import '../providers/bookmark_provider.dart';
import '../providers/bookmark_group_providers.dart';
import '../providers/local_providers.dart';

class BookmarkAppBar extends ConsumerWidget {
  const BookmarkAppBar({
    required this.controller,
    super.key,
  });

  final PostGridController<BookmarkPost> controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final edit = ref.watch(bookmarkEditProvider);
    final selectedGroupId = ref.watch(selectedBookmarkGroupIdProvider);
    final groups = ref.watch(bookmarkGroupsProvider).valueOrNull;
    final auth = ref.watchConfigAuth;
    final download = ref.watchConfigDownload;

    return AppBar(
      title: Text(
        switch (selectedGroupId) {
          null => context.t.bookmark.groups.all,
          kUngroupedBookmarkGroupId => context.t.bookmark.groups.ungrouped,
          final id =>
            groups?.firstWhereOrNull((group) => group.id == id)?.name ??
                context.t.bookmark.groups.all,
        },
      ),
      automaticallyImplyLeading: !edit,
      leading: edit
          ? IconButton(
              onPressed: () =>
                  ref.read(bookmarkEditProvider.notifier).state = false,
              icon: Icon(
                Symbols.check,
                color: Kurumi.themeOf(context).colorScheme.primary,
              ),
            )
          : null,
      actions: [
        if (!edit)
          ValueListenableBuilder(
            valueListenable: controller.itemsNotifier,
            builder: (context, posts, child) => posts.isNotEmpty
                ? KurumiPopupMenuButton(
                    items: [
                      KurumiPopupMenuItem(
                        title: Text(context.t.generic.action.edit),
                        onTap: () {
                          ref.read(bookmarkEditProvider.notifier).state = true;
                        },
                      ),
                      KurumiPopupMenuItem(
                        title: Text('Download ${posts.length} bookmarks'.hc),
                        onTap: () {
                          ref.bookmarks.downloadBookmarks(
                            auth,
                            download,
                            controller.items.map((e) => e.bookmark).toList(),
                          );
                        },
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
      ],
    );
  }
}
