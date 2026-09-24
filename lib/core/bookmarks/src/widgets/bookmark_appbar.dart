// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

// Project imports:
import '../../../configs/config/providers.dart';
import '../../../posts/listing/providers.dart';
import '../../../posts/post/types.dart';
import '../providers/bookmark_provider.dart';
import '../providers/local_providers.dart';

class BookmarkAppBar extends ConsumerWidget {
  const BookmarkAppBar({
    required this.controller,
    this.title,
    super.key,
  });

  final PostGridController<Post> controller;
  final String? title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final edit = ref.watch(bookmarkEditProvider);
    final auth = ref.watchConfigAuth;
    final download = ref.watchConfigDownload;

    return AppBar(
      title: Text(title ?? context.t.bookmark.title),
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
                          final library = ref
                              .read(bookmarkProvider)
                              .valueOrNull;
                          ref.bookmarks.downloadBookmarks(
                            auth,
                            download,
                            controller.items
                                .map((post) => library?.bookmarkForPost(post))
                                .nonNulls
                                .toList(),
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
