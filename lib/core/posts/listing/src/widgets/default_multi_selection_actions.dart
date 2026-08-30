// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:selection_mode/selection_mode.dart';

// Project imports:
import '../../../../../../core/widgets/widgets.dart';
import '../../../../bookmarks/widgets.dart';
import '../../../../configs/config/providers.dart';
import '../../../../downloads/downloader/providers.dart';
import '../../../post/types.dart';
import 'post_grid_controller.dart';

class DefaultMultiSelectionActions<T extends Post> extends ConsumerWidget {
  const DefaultMultiSelectionActions({
    required this.postController,
    super.key,
    this.extraActions,
    this.onBulkDownload,
    this.onBookmarkOperationCompleted,
    this.bookmark = true,
  });

  final PostGridController<T> postController;
  final bool bookmark;
  final void Function(List<T> selectedPosts)? onBulkDownload;
  final Future<void> Function()? onBookmarkOperationCompleted;
  final List<Widget> Function(List<T> selectedPosts)? extraActions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = SelectionMode.of(context);
    final booruConfig = ref.watchConfigAuth;
    final notifier = ref.watch(
      downloadNotifierProvider(
        ref.watch(
          downloadNotifierParamsProvider((
            booruConfig,
            ref.watchConfigDownload,
          )),
        ),
      ).notifier,
    );

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final selectedPosts = controller
            .selectedFrom(postController.items.toList())
            .toList();

        return MultiSelectionActionBar(
          children: [
            MultiSelectButton(
              onPressed: selectedPosts.isNotEmpty
                  ? () {
                      if (onBulkDownload != null) {
                        onBulkDownload!(selectedPosts);
                      } else {
                        notifier.bulkDownload(selectedPosts);
                      }

                      controller.disable();
                    }
                  : null,
              icon: const Icon(Symbols.download),
              name: context.t.download.download,
            ),
            if (bookmark)
              MultiSelectPopupButton(
                name: context.t.bookmark.bulk.title,
                enabled: selectedPosts.isNotEmpty,
                menuBuilder: (_) => BookmarkMultiSelectionMenu(
                  posts: selectedPosts.cast<Post>(),
                  config: booruConfig,
                  onCompleted: onBookmarkOperationCompleted,
                ),
                icon: const Icon(Symbols.bookmark_add),
              ),
            if (extraActions != null) ...extraActions!(selectedPosts),
          ],
        );
      },
    );
  }
}
