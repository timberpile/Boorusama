// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

// Project imports:
import 'bookmark_group_label.dart';
import '../../../configs/config/types.dart';
import '../../../posts/post/types.dart';
import '../data/bookmark_convert.dart';
import '../providers/bookmark_provider.dart';
import '../types/bookmark_target.dart';
import '../types/bookmark_library_state.dart';
import 'bookmark_folder_picker_contents.dart';
import 'bookmark_group_name_dialog.dart';

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
    final container = ProviderScope.containerOf(context, listen: false);
    final navigator = Navigator.of(context, rootNavigator: true);

    return KurumiContextMenuTile(
      title: context.t.post.action.bookmark,
      hideOnTap: false,
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        KurumiContextMenuPageController.maybeOf(context)?.show(
          (pageContext) => _BookmarkContextGroupPage(
            post: post,
            config: config,
            container: container,
            navigator: navigator,
          ),
        );
      },
    );
  }
}

class _BookmarkContextGroupPage extends StatefulWidget {
  const _BookmarkContextGroupPage({
    required this.post,
    required this.config,
    required this.container,
    required this.navigator,
  });

  final Post post;
  final BooruConfigAuth config;
  final ProviderContainer container;
  final NavigatorState navigator;

  @override
  State<_BookmarkContextGroupPage> createState() =>
      _BookmarkContextGroupPageState();
}

class _BookmarkContextGroupPageState extends State<_BookmarkContextGroupPage> {
  ProviderContainer get container => widget.container;
  NavigatorState get navigator => widget.navigator;
  Post get post => widget.post;
  BooruConfigAuth get config => widget.config;
  ProviderSubscription<AsyncValue<BookmarkLibraryState>>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = container.listen(bookmarkProvider, (_, _) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _subscription?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final library = container.read(bookmarkProvider).valueOrNull;
    final id = bookmarkIdentityForPost(post, config.booruIdHint);
    final memberships = library?.membershipsFor(id) ?? const <String>{};
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.heightOf(context) * .6),
      child: BookmarkFolderPickerContents(
        compact: true,
        folders: library?.folders ?? const [],
        groups: library?.groups ?? const [],
        membershipGroupIds: memberships,
        onRootBack: KurumiContextMenuPageController.maybeOf(context)?.reset,
        groupBuilder: (context, group) => _item(
          context,
          groupId: group.id,
          name: group.displayName(context),
          selected: memberships.contains(group.id),
        ),
        footerBuilder: (context, folderId) => BookmarkPickerMenuItem(
          icon: const Icon(Icons.add),
          title: context.t.bookmark.groups.create_new,
          onTap: () =>
              _afterDismiss(() => _createGroup(navigator.context, folderId)),
        ),
      ),
    );
  }

  Widget _item(
    BuildContext context, {
    required String? groupId,
    required String name,
    required bool selected,
  }) => BookmarkPickerMenuItem(
    icon: Icon(
      groupId == null ? Symbols.bookmark : Symbols.bookmarks,
      fill: selected ? 1 : 0,
    ),
    title: name,
    onTap: () => _afterDismiss(() => _toggle(groupId)),
  );

  void _afterDismiss(Future<void> Function() action) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (navigator.mounted) await action();
    });
  }

  Future<void> _toggle(String? groupId) async {
    final notifier = container.read(bookmarkProvider.notifier);
    try {
      final outcome = await notifier.togglePostTarget(
        config,
        post,
        target: groupId == null
            ? const BookmarkTarget.defaultGroup()
            : BookmarkTarget.group(groupId),
        activateTarget: true,
        onRemoved: (r) {
          if (navigator.mounted) notifier.showRemovalUndo(navigator.context, r);
        },
      );
      switch (outcome) {
        case BookmarkToggleOutcome.added:
          _added();
        case BookmarkToggleOutcome.removed:
          break;
        case BookmarkToggleOutcome.missingPostIdentity:
          if (navigator.mounted) {
            Kurumi.showErrorToast(
              navigator.context,
              navigator.context.t.bookmark.missing_post_identity,
            );
          }
        case BookmarkToggleOutcome.unavailable || BookmarkToggleOutcome.failed:
          _error();
      }
    } catch (_) {
      _error();
    }
  }

  Future<void> _createGroup(BuildContext context, String? folderId) async {
    final name = await showBookmarkGroupNameDialog(
      context,
      title: context.t.bookmark.groups.create,
    );
    if (name == null) return;
    try {
      final notifier = container.read(bookmarkProvider.notifier);
      await notifier.createGroupWithPosts(name, config, [
        post,
      ], folderId: folderId);
      _added();
    } catch (_) {
      _error();
    }
  }

  void _added() {
    if (navigator.mounted) {
      Kurumi.showSuccessToast(
        navigator.context,
        navigator.context.t.bookmark.added,
      );
    }
  }

  void _error() {
    if (navigator.mounted) {
      Kurumi.showErrorToast(
        navigator.context,
        navigator.context.t.bookmark.groups.operation_failed,
      );
    }
  }
}
