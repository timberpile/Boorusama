// Flutter imports:
import 'package:kurumi/material.dart';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:material_symbols_icons/symbols.dart';

// Project imports:
import '../../../navigation/app_navigation.dart';
import 'bookmark_group_label.dart';
import '../../../groups/folder_tree.dart';
import 'bookmark_batch_dialog.dart';
import '../providers/bookmark_provider.dart';
import '../data/bookmark_convert.dart';
import '../types/bookmark_group.dart';
import '../types/bookmark_library_state.dart';
import '../../../configs/config/types.dart';
import '../../../posts/post/types.dart';
import '../types/bookmark.dart';
import '../types/pool_bookmark.dart';
import 'bookmark_group_name_dialog.dart';
import 'bookmark_folder_picker_contents.dart';

Future<bool> showBookmarkMultiSelectionActions(
  BuildContext context, {
  required WidgetRef ref,
  required List<PostBookmark> bookmarks,
}) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final action = await Kurumi.showAppModalBottomSheet<String>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BookmarkPickerMenuItem(
            icon: const Icon(Symbols.bookmark_add),
            title: context.t.bookmark.bulk.add,
            hideOnTap: false,
            onTap: () => Navigator.pop(context, 'add'),
          ),
          BookmarkPickerMenuItem(
            icon: const Icon(Symbols.bookmark_remove),
            title: context.t.bookmark.bulk.remove,
            hideOnTap: false,
            onTap: () => Navigator.pop(context, 'remove'),
          ),
        ],
      ),
    ),
  );
  if (!context.mounted) return false;
  return switch (action) {
    'add' => _add(context, container, bookmarks),
    'remove' => _remove(context, container, bookmarks),
    _ => false,
  };
}

Future<bool> _add(
  BuildContext context,
  ProviderContainer container,
  List<PostBookmark> bookmarks,
) async {
  final groupId = await _selectGroup(context, bookmarks, allowCreate: true);
  if (groupId == null) return false;
  await container
      .read(bookmarkProvider.notifier)
      .addExistingBookmarksToGroup(bookmarks, groupId);
  return false;
}

Future<bool> _remove(
  BuildContext context,
  ProviderContainer container,
  List<PostBookmark> bookmarks,
) async {
  final groupId = await _selectGroup(context, bookmarks);
  if (groupId == null) return false;
  await container
      .read(bookmarkProvider.notifier)
      .removeFromGroup(
        bookmarks,
        groupId,
        onRemoved: (r) {
          if (context.mounted)
            container
                .read(bookmarkProvider.notifier)
                .showRemovalUndo(context, r);
        },
      );
  return false;
}

Future<String?> _selectGroup(
  BuildContext context,
  List<PostBookmark> bookmarks, {
  bool allowCreate = false,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _ExistingBookmarkGroupSelectionDialog(
      allowCreate: allowCreate,
      bookmarks: bookmarks,
    ),
  );
}

class _ExistingBookmarkGroupSelectionDialog extends ConsumerWidget {
  const _ExistingBookmarkGroupSelectionDialog({
    required this.allowCreate,
    required this.bookmarks,
  });
  final bool allowCreate;
  final List<PostBookmark> bookmarks;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(bookmarkProvider).valueOrNull;
    final singleMemberships = bookmarks.length == 1
        ? library?.membershipsFor(bookmarks.single.uniqueId)
        : null;
    return BookmarkBatchDialog(
      title: context.t.bookmark.groups.selector,
      child: BookmarkFolderPickerContents(
        folders: library?.folders ?? const [],
        groups: library?.groups ?? const [],
        membershipGroupIds: singleMemberships,
        groupBuilder: (context, group) => BookmarkPickerMenuItem(
          icon: Icon(
            Symbols.bookmarks,
            fill: (singleMemberships?.contains(group.id) ?? false) ? 1 : 0,
          ),
          title: group.displayName(context),
          hideOnTap: false,
          onTap: () => Navigator.pop(context, group.id),
        ),
        onCreateGroup: allowCreate
            ? (folderId) async {
                final name = await showBookmarkGroupNameDialog(
                  context,
                  title: context.t.bookmark.groups.create,
                );
                if (name == null || !context.mounted) return;
                try {
                  final group = await ref
                      .read(bookmarkProvider.notifier)
                      .createGroup(name, folderId: folderId);
                  if (context.mounted) Navigator.pop(context, group.id);
                } catch (_) {
                  if (context.mounted) {
                    Kurumi.showErrorToast(
                      context,
                      context.t.bookmark.groups.operation_failed,
                    );
                  }
                }
              }
            : null,
      ),
    );
  }
}

class BookmarkGroupSelectionSummary {
  const BookmarkGroupSelectionSummary({
    required this.totalPosts,
    required this.bookmarkedPosts,
    required this.membershipCounts,
  });

  factory BookmarkGroupSelectionSummary.fromPosts({
    required Iterable<Post> posts,
    required BookmarkLibraryState? state,
    required int booruId,
    List<CollectionBookmark> pools = const [],
  }) {
    var bookmarked = 0;
    final counts = <String, int>{};
    for (final post in posts) {
      final id = bookmarkIdentityForPost(post, booruId);
      final record = state?.storedBookmarkForPost(post);
      if (record == null) continue;
      bookmarked++;
      final memberships = state!.hasUnifiedRecords
          ? state.membershipsForId(record.id)
          : state.membershipsFor(id);
      for (final groupId in memberships) {
        counts.update(groupId, (value) => value + 1, ifAbsent: () => 1);
      }
    }
    for (final pool in pools) {
      final current = state?.pools
          .where((p) => p.identity == pool.identity)
          .firstOrNull;
      if (current == null) continue;
      bookmarked++;
      for (final groupId in current.groupIds) {
        counts.update(groupId, (value) => value + 1, ifAbsent: () => 1);
      }
    }
    return BookmarkGroupSelectionSummary(
      totalPosts: posts.length + pools.length,
      bookmarkedPosts: bookmarked,
      membershipCounts: Map.unmodifiable(counts),
    );
  }

  final int totalPosts;
  final int bookmarkedPosts;
  final Map<String, int> membershipCounts;

  int countFor(String groupId) => membershipCounts[groupId] ?? 0;
}

enum BookmarkMultiSelectionOperation { add, remove }

class BookmarkGroupSelectionTarget {
  const BookmarkGroupSelectionTarget(
    this.id,
    this.name, {
    this.appliedCount,
  });

  final String? id;
  final String name;
  final int? appliedCount;
}

class BookmarkMultiSelectionMenu extends ConsumerStatefulWidget {
  const BookmarkMultiSelectionMenu({
    required this.posts,
    required this.config,
    required this.onCompleted,
    this.currentGroupId,
    this.pools = const [],
    super.key,
  });

  final List<Post> posts;
  final List<CollectionBookmark> pools;
  final BooruConfigAuth config;
  final Future<void> Function() onCompleted;

  /// The listing's actual group, not the globally active bookmark target.
  /// Null keeps All Bookmarks and ordinary post selections unchanged.
  final String? currentGroupId;

  @override
  ConsumerState<BookmarkMultiSelectionMenu> createState() =>
      _BookmarkMultiSelectionMenuState();
}

class _BookmarkMultiSelectionMenuState
    extends ConsumerState<BookmarkMultiSelectionMenu> {
  var _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.currentGroupId != null)
          KurumiPopupMenuItem(
            key: const Key('bookmark-remove-current-group'),
            title: Text(context.t.generic.action.remove),
            onTap: () => _select(
              context,
              ref,
              BookmarkMultiSelectionOperation.remove,
              directGroupId: widget.currentGroupId,
            ),
          ),
        KurumiPopupMenuItem(
          title: Text(context.t.bookmark.bulk.add),
          trailing: const Icon(Icons.chevron_right),
          onTap: () =>
              _select(context, ref, BookmarkMultiSelectionOperation.add),
        ),
        KurumiPopupMenuItem(
          title: Text(context.t.bookmark.bulk.remove),
          trailing: const Icon(Icons.chevron_right),
          onTap: () =>
              _select(context, ref, BookmarkMultiSelectionOperation.remove),
        ),
      ],
    );
  }

  Future<void> _select(
    BuildContext context,
    WidgetRef ref,
    BookmarkMultiSelectionOperation operation, {
    String? directGroupId,
  }) async {
    if (_isProcessing) return;
    _isProcessing = true;
    try {
      await _performSelection(
        context,
        ref,
        operation,
        directGroupId: directGroupId,
      );
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> _performSelection(
    BuildContext context,
    WidgetRef ref,
    BookmarkMultiSelectionOperation operation, {
    String? directGroupId,
  }) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    final navigation = ref.read(appNavigationProvider);
    final notifier = ref.read(bookmarkProvider.notifier);
    final selectedPosts = List<Post>.unmodifiable(widget.posts);
    final selectedPools = List<CollectionBookmark>.unmodifiable(widget.pools);
    final config = widget.config;
    final onCompleted = widget.onCompleted;
    final target = directGroupId == null
        ? await showBookmarkGroupSelectionDialog(
            navigator.context,
            operation: operation,
            posts: selectedPosts,
            pools: selectedPools,
            config: config,
          )
        : BookmarkGroupSelectionTarget(directGroupId, '');
    if (target == null || !navigator.mounted) return;
    try {
      if (operation == BookmarkMultiSelectionOperation.add) {
        final changed =
            target.appliedCount ??
            await notifier.addPostsToGroup(
              config,
              selectedPosts,
              target.id,
              manual: true,
              pools: selectedPools,
            );
        if (!navigator.mounted) return;
        final feedback =
            navigation.feedbackKey.currentContext ?? navigator.context;
        Kurumi.showSuccessToast(
          feedback,
          navigator.context.t.bookmark.bulk.add_success
              .replaceAll('{0}', '$changed')
              .replaceAll('{1}', target.name),
        );
      } else {
        final result = await notifier.removePostsFromGroup(
          config,
          selectedPosts,
          target.id!,
          poolLocalIds: selectedPools.map((p) => p.localId).toSet(),
        );
        if (!navigator.mounted) return;
        notifier.showRemovalUndo(navigator.context, result);
      }
      await onCompleted();
    } catch (_) {
      if (!navigator.mounted) return;
      Kurumi.showErrorToast(
        navigator.context,
        operation == BookmarkMultiSelectionOperation.add
            ? navigator.context.t.bookmark.bulk.failed_to_add
            : navigator.context.t.bookmark.bulk.failed_to_remove,
      );
    }
  }
}

Future<BookmarkGroupSelectionTarget?> showBookmarkGroupSelectionDialog(
  BuildContext context, {
  required BookmarkMultiSelectionOperation operation,
  required List<Post> posts,
  required BooruConfigAuth config,
  List<CollectionBookmark> pools = const [],
}) => showDialog<BookmarkGroupSelectionTarget>(
  context: context,
  builder: (_) => _BookmarkGroupSelectionDialog(
    operation: operation,
    posts: posts,
    pools: pools,
    config: config,
  ),
);

class _BookmarkGroupSelectionDialog extends ConsumerWidget {
  const _BookmarkGroupSelectionDialog({
    required this.operation,
    required this.posts,
    required this.config,
    required this.pools,
  });

  final BookmarkMultiSelectionOperation operation;
  final List<Post> posts;
  final List<CollectionBookmark> pools;
  final BooruConfigAuth config;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bookmarkProvider).valueOrNull;
    final groups = state?.groups ?? const <BookmarkGroup>[];
    final summary = BookmarkGroupSelectionSummary.fromPosts(
      posts: posts,
      state: state,
      booruId: config.booruIdHint,
      pools: pools,
    );
    final add = operation == BookmarkMultiSelectionOperation.add;
    final visibleGroups = groups
        .where((group) => add || summary.countFor(group.id) > 0)
        .toList();
    final allFolders = state?.folders ?? const <CollectionFolder>[];
    final tree = FolderTree(allFolders);
    final relevantFolderIds = {
      for (final group in visibleGroups)
        for (final folder in tree.ancestors(group.folderId)) folder.id,
    };
    final visibleFolders = add
        ? allFolders
        : allFolders
              .where((folder) => relevantFolderIds.contains(folder.id))
              .toList();
    return BookmarkBatchDialog(
      title: add
          ? context.t.bookmark.bulk.add_title
          : context.t.bookmark.bulk.remove_title,
      child: BookmarkFolderPickerContents(
        folders: visibleFolders,
        groups: visibleGroups,
        membershipGroupIds: posts.length + pools.length == 1
            ? pools.isNotEmpty
                  ? state?.pools
                        .where((p) => p.identity == pools.single.identity)
                        .firstOrNull
                        ?.groupIds
                  : state?.membershipsFor(
                      bookmarkIdentityForPost(posts.single, config.booruIdHint),
                    )
            : null,
        groupBuilder: (context, group) => _tile(
          context,
          BookmarkGroupSelectionTarget(group.id, group.displayName(context)),
          summary.countFor(group.id),
        ),
        onCreateGroup: add
            ? (folderId) => _create(context, ref, folderId)
            : null,
        footerBuilder: !add && visibleGroups.isEmpty
            ? (context, folderId) => Padding(
                padding: const EdgeInsets.all(8),
                child: Text(context.t.bookmark.bulk.no_applicable),
              )
            : null,
      ),
    );
  }

  Widget _tile(
    BuildContext context,
    BookmarkGroupSelectionTarget target,
    int count,
  ) => BookmarkPickerMenuItem(
    icon: Icon(
      target.id == null ? Symbols.bookmark : Symbols.bookmarks,
      fill: posts.length + pools.length == 1 && count > 0 ? 1 : 0,
    ),
    title: target.name,
    detail: context.t.bookmark.bulk.membership_count
        .replaceAll('{0}', '$count')
        .replaceAll('{1}', '${posts.length + pools.length}'),
    hideOnTap: false,
    onTap: () => Navigator.pop(context, target),
  );

  Future<void> _create(
    BuildContext context,
    WidgetRef ref,
    String? folderId,
  ) async {
    final name = await showBookmarkGroupNameDialog(
      context,
      title: context.t.bookmark.groups.create,
    );
    if (name == null || !context.mounted) return;
    try {
      final result = await ref
          .read(bookmarkProvider.notifier)
          .createGroupWithPosts(
            name,
            config,
            posts,
            folderId: folderId,
            pools: pools,
          );
      if (context.mounted) {
        Navigator.pop(
          context,
          BookmarkGroupSelectionTarget(
            result.group.id,
            result.group.name,
            appliedCount: result.addedCount,
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        Kurumi.showErrorToast(
          context,
          context.t.bookmark.groups.operation_failed,
        );
      }
    }
  }
}
