import 'package:anchor_ui/anchor_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

import '../../../configs/config/types.dart';
import '../../../posts/post/types.dart';
import 'bookmark_group_picker.dart';
import '../providers/bookmark_provider.dart';

class BookmarkContextMenuSection extends ConsumerWidget {
  const BookmarkContextMenuSection({
    required this.post,
    required this.config,
    super.key,
  });
  final Post post;
  final BooruConfigAuth config;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(bookmarkProvider).valueOrNull;
    final saved = library?.storedBookmarkForPost(post);
    final request = library?.hasUnifiedRecords == true && saved != null
        ? SavedBookmarkPickerRequest(config: config, record: saved)
        : PostBookmarkPickerRequest(config: config, post: post);
    final container = ProviderScope.containerOf(context, listen: false);
    final anchor = AnchorData.maybeOf(context)?.controller;
    final pages = KurumiContextMenuPageController.maybeOf(context);
    return KurumiContextMenuTile(
      title: context.t.post.action.bookmark,
      hideOnTap: false,
      trailing: const Icon(Icons.chevron_right),
      onTap: () => pages?.show(
        (pageContext) => UncontrolledProviderScope(
          container: container,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.heightOf(pageContext) * .6,
            ),
            child: BookmarkGroupPicker(
              request: request,
              onRootBack: pages.reset,
              isActive: () => anchor?.isShowing ?? false,
              onDismiss: () => anchor?.hide(),
            ),
          ),
        ),
      ),
    );
  }
}
