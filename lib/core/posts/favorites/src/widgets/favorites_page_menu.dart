import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../bookmarks/src/server_favorites/dialog.dart';

class FavoritesPageMenu extends ConsumerWidget {
  const FavoritesPageMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return KurumiPopupMenuButton(
      key: const ValueKey('favorites-page-menu'),
      items: [
        KurumiPopupMenuItem(
          icon: const Icon(Symbols.bookmarks),
          title: Text(context.t.bookmark.server_favorites.title),
          onTap: () => showServerFavoritesDialog(context),
        ),
      ],
    );
  }
}
