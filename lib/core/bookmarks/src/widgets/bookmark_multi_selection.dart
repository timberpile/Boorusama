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
                      .createGroup(name, parentGroupId: folderId);
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
    List<Bookmark> records = const [],
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
          .where(
            (p) => pool.bookmarkId != null
                ? p.bookmarkId == pool.bookmarkId
                : p.localId == pool.localId,
          )
          .firstOrNull;
      if (current == null) continue;
      bookmarked++;
      for (final groupId in current.groupIds) {
        counts.update(groupId, (value) => value + 1, ifAbsent: () => 1);
      }
    }
    for (final record in records) {
      if (state?.byId.containsKey(record.id) != true) continue;
      bookmarked++;
      for (final groupId in state!.membershipsForId(record.id)) {
        counts.update(groupId, (value) => value + 1, ifAbsent: () => 1);
      }
    }
    return BookmarkGroupSelectionSummary(
      totalPosts: posts.length + pools.length + records.length,
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
    this.sourceGroupIds,
    this.pools = const [],
    this.records = const [],
    super.key,
  });

  final List<Post> posts;
  final List<CollectionBookmark> pools;
  final List<Bookmark> records;
  final BooruConfigAuth config;
  final Future<void> Function() onCompleted;

  /// The listing's actual group, not the globally active bookmark target.
  /// Null keeps All Bookmarks and ordinary post selections unchanged.
  final String? currentGroupId;

  /// Aggregate views require an explicit direct source within this set.
  final Set<String>? sourceGroupIds;

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
    final current = ref.read(bookmarkProvider).valueOrNull;
    final selectedRecords = <Bookmark>[
      ...widget.records,
      if (widget.records.isNotEmpty) ...[
        for (final post in selectedPosts)
          if (current?.storedBookmarkForPost(post) case final saved?) saved,
        for (final pool in selectedPools)
          if (current?.byId[pool.bookmarkId] case final saved?) saved,
      ],
    ];
    final useRecords = selectedRecords.isNotEmpty;
    if (useRecords &&
        selectedRecords.length !=
            widget.records.length +
                selectedPosts.length +
                selectedPools.length) {
      throw StateError('The selected saved records changed');
    }
    final config = widget.config;
    final onCompleted = widget.onCompleted;
    final target = directGroupId == null
        ? await showBookmarkGroupSelectionDialog(
            navigator.context,
            operation: operation,
            posts: useRecords ? const [] : selectedPosts,
            pools: useRecords ? const [] : selectedPools,
            records: selectedRecords,
            config: config,
            allowedGroupIds: operation == BookmarkMultiSelectionOperation.remove
                ? widget.sourceGroupIds
                : null,
          )
        : BookmarkGroupSelectionTarget(directGroupId, '');
    if (target == null || !navigator.mounted) return;
    try {
      if (operation == BookmarkMultiSelectionOperation.add) {
        final changed =
            target.appliedCount ??
            (useRecords
                ? await notifier.addSavedRecordsToGroup(
                    selectedRecords,
                    target.id!,
                  )
                : await notifier.addPostsToGroup(
                    config,
                    selectedPosts,
                    target.id,
                    manual: true,
                    pools: selectedPools,
                  ));
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
        final result = useRecords
            ? await notifier.removeSavedRecordsFromGroup(
                selectedRecords,
                target.id!,
              )
            : await notifier.removePostsFromGroup(
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
  List<Bookmark> records = const [],
  Set<String>? allowedGroupIds,
}) => showDialog<BookmarkGroupSelectionTarget>(
  context: context,
  builder: (_) => _BookmarkGroupSelectionDialog(
    operation: operation,
    posts: posts,
    pools: pools,
    records: records,
    config: config,
    allowedGroupIds: allowedGroupIds,
  ),
);

class _BookmarkGroupSelectionDialog extends ConsumerWidget {
  const _BookmarkGroupSelectionDialog({
    required this.operation,
    required this.posts,
    required this.config,
    required this.pools,
    required this.records,
    this.allowedGroupIds,
  });

  final BookmarkMultiSelectionOperation operation;
  final List<Post> posts;
  final List<CollectionBookmark> pools;
  final List<Bookmark> records;
  final Set<String>? allowedGroupIds;
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
      records: records,
    );
    final add = operation == BookmarkMultiSelectionOperation.add;
    final applicable = {
      for (final group in groups)
        if (add ||
            (summary.countFor(group.id) > 0 &&
                (allowedGroupIds?.contains(group.id) ?? true)))
          group.id,
    };
    final visibleIds = {
      ...applicable,
      for (final id in applicable)
        ...?state?.groupTree.ancestors(id).map((group) => group.id),
    };
    final visibleGroups = groups
        .where((group) => visibleIds.contains(group.id))
        .toList();
    return BookmarkBatchDialog(
      title: add
          ? context.t.bookmark.bulk.add_title
          : context.t.bookmark.bulk.remove_title,
      child: BookmarkFolderPickerContents(
        folders: const [],
        selectableGroupIds: applicable,
        groups: visibleGroups,
        membershipGroupIds: posts.length + pools.length + records.length == 1
            ? records.isNotEmpty
                  ? state?.membershipsForId(records.single.id)
                  : pools.isNotEmpty
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

  BookmarkPickerMenuItem _tile(
    BuildContext context,
    BookmarkGroupSelectionTarget target,
    int count,
  ) => BookmarkPickerMenuItem(
    icon: Icon(
      target.id == null ? Symbols.bookmark : Symbols.bookmarks,
      fill: posts.length + pools.length + records.length == 1 && count > 0
          ? 1
          : 0,
    ),
    title: target.name,
    detail: context.t.bookmark.bulk.membership_count
        .replaceAll('{0}', '$count')
        .replaceAll('{1}', '${posts.length + pools.length + records.length}'),
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
      final notifier = ref.read(bookmarkProvider.notifier);
      final result = records.isNotEmpty
          ? await notifier.createGroupWithSavedRecords(
              name,
              records,
              parentGroupId: folderId,
            )
          : await notifier.createGroupWithPosts(
              name,
              config,
              posts,
              parentGroupId: folderId,
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
