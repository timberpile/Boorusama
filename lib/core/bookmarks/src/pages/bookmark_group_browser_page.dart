import 'package:foundation/performance.dart';
import '../../../../foundation/performance/performance_navigation.dart';

// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../configs/config/providers.dart';
import '../../../configs/config/types.dart';
import '../../../images/booru_image.dart';
import '../providers/bookmark_group_selectors.dart';
import '../providers/bookmark_provider.dart';
import '../../../groups/folder_tree.dart';
import '../../../groups/folder_navigation.dart';
import '../services/bookmark_library_service.dart';
import '../providers/bookmark_shuffle_provider.dart';
import '../providers/local_providers.dart';
import '../routes/route_utils.dart';
import '../types/bookmark.dart';
import '../types/bookmark_group.dart';
import '../types/bookmark_view.dart';
import '../widgets/bookmark_group_name_dialog.dart';
import '../widgets/bookmark_collection_order.dart';

class BookmarkGroupBrowserPage extends ConsumerStatefulWidget {
  const BookmarkGroupBrowserPage({this.folderId, super.key})
    : _ancestorRoutes = const {};
  const BookmarkGroupBrowserPage._nested({
    required this.folderId,
    required Map<String?, Route<dynamic>> ancestorRoutes,
  }) : _ancestorRoutes = ancestorRoutes;
  final Map<String?, Route<dynamic>> _ancestorRoutes;
  final String? folderId;
  @override
  ConsumerState<BookmarkGroupBrowserPage> createState() =>
      _BookmarkGroupBrowserPageState();
}

class _BookmarkGroupBrowserPageState
    extends ConsumerState<BookmarkGroupBrowserPage> {
  // Imports or another browser can remove the open folder. Fall back to Home.
  String? get _folderId {
    final id = widget.folderId;
    final folders = ref.read(bookmarkProvider).valueOrNull?.folders;
    return folders?.any((f) => f.id == id) == true ? id : null;
  }

  final _selectedGroups = <String>{};
  final _selectedFolders = <String>{};
  bool get _selecting =>
      _selectedGroups.isNotEmpty || _selectedFolders.isNotEmpty;
  void _select(String id, {bool folder = false}) => setState(() {
    final ids = folder ? _selectedFolders : _selectedGroups;
    if (!ids.add(id)) ids.remove(id);
  });
  void _openFolder(String? id) {
    if (id == _folderId) return;
    final navigator = Navigator.of(context);
    final previous = widget._ancestorRoutes[id];
    if (previous != null) {
      navigator.popUntil((route) => route == previous);
      return;
    }
    final currentRoute = ModalRoute.of(context);
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => BookmarkGroupBrowserPage._nested(
          folderId: id,
          ancestorRoutes: {
            ...widget._ancestorRoutes,
            _folderId: ?currentRoute,
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(bookmarkProvider);
    return PerformanceScreenScope(screen: PerfScreen.bookmarkGroups, priority: 2, child: Scaffold(
      appBar: AppBar(
        title: Text(
          _selecting
              ? context.t.folders.selected.replaceAll(
                  '{count}',
                  '${_selectedGroups.length + _selectedFolders.length}',
                )
              : library.valueOrNull?.folders
                        .where((f) => f.id == _folderId)
                        .firstOrNull
                        ?.name ??
                    context.t.bookmark.groups.selector,
        ),
        actions: [
          if (_selecting) ...[
            IconButton(
              tooltip: context.t.folders.move,
              icon: const Icon(Icons.drive_file_move_outline),
              onPressed: () => _move(),
            ),
            IconButton(
              tooltip: context.t.generic.action.cancel,
              icon: const Icon(Icons.close),
              onPressed: () => setState(() {
                _selectedGroups.clear();
                _selectedFolders.clear();
              }),
            ),
          ] else
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (action) => switch (action) {
                'folder' => _createFolder(),
                'group' => _create(context, ref),
                _ => null,
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'folder',
                  child: Text(context.t.bookmark.groups.add_folder),
                ),
                PopupMenuItem(
                  value: 'group',
                  child: Text(context.t.bookmark.groups.add),
                ),
              ],
            ),
        ],
      ),
      body: library.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Icon(Icons.error_outline)),
        data: (state) {
          final sort = ref.watch(selectedBookmarkSortTypeProvider);
          final shuffle = ref.watch(bookmarkShuffleProvider);
          final tree = FolderTree(state.folders);
          final folders = bookmarkFoldersByName(tree.children(_folderId));
          final groups = bookmarkGroupsByName(
            state.groups.where((g) => g.folderId == _folderId),
          );
          List<Bookmark> previews(BookmarkView view) => selectBookmarkPreviews(
            state: state,
            view: view,
            sortType: sort,
            shuffleState: shuffle,
          );
          Widget specialView(String title, BookmarkView view) => _GroupCard(
            title: title,
            previews: previews(view),
            group: null,
            onTap: _selecting
                ? null
                : () => goToBookmarkGroupPage(ref, view, title: title),
            onRename: null,
            onDuplicate: null,
            onDelete: null,
          );
          return Column(
            children: [
              if (_folderId != null)
                FolderBreadcrumbs(
                  tree: tree,
                  currentId: _folderId,
                  onOpen: _openFolder,
                ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final delegate = SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: switch (constraints.maxWidth) {
                        < 500 => 2,
                        < 850 => 3,
                        _ => 4,
                      },
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    );
                    return CustomScrollView(
                      slivers: [
                        if (_folderId == null) ...[
                          SliverPadding(
                            padding: const EdgeInsets.all(12),
                            sliver: SliverGrid(
                              gridDelegate: delegate,
                              delegate: SliverChildListDelegate([
                                specialView(
                                  context.t.bookmark.groups.all,
                                  const BookmarkView.all(),
                                ),
                                specialView(
                                  context.t.bookmark.groups.ungrouped,
                                  const BookmarkView.ungrouped(),
                                ),
                              ]),
                            ),
                          ),
                          const SliverToBoxAdapter(
                            child: Divider(
                              indent: 12,
                              endIndent: 12,
                              height: 1,
                            ),
                          ),
                        ],
                        SliverPadding(
                          padding: const EdgeInsets.all(12),
                          sliver: SliverGrid(
                            gridDelegate: delegate,
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                if (index < folders.length) {
                                  final folder = folders[index];
                                  final descendants = tree.subtree(folder.id);
                                  final descendantsGroups =
                                      bookmarkGroupsByName(
                                        state.groups.where(
                                          (g) =>
                                              descendants.contains(g.folderId),
                                        ),
                                      );
                                  return _GroupCard(
                                    title: folder.name,
                                    previews: [
                                      for (final group
                                          in descendantsGroups.take(4))
                                        ...previews(
                                          BookmarkView.group(group.id),
                                        ).take(1),
                                    ],
                                    group: null,
                                    isFolder: true,
                                    selected: _selectedFolders.contains(
                                      folder.id,
                                    ),
                                    onSelect: () =>
                                        _select(folder.id, folder: true),
                                    onTap: () => _selecting
                                        ? _select(folder.id, folder: true)
                                        : _openFolder(folder.id),
                                    onRename: () => _renameFolder(folder),
                                    onDuplicate: null,
                                    onDelete: () => _deleteFolder(folder),
                                    onMove: () => _move(folderIds: {folder.id}),
                                  );
                                }
                                final group = groups[index - folders.length];
                                return _GroupCard(
                                  title: group.name,
                                  previews: previews(
                                    BookmarkView.group(group.id),
                                  ),
                                  group: group,
                                  selected: _selectedGroups.contains(group.id),
                                  onSelect: () => _select(group.id),
                                  onMove: () => _move(groupIds: {group.id}),
                                  onTap: () => _selecting
                                      ? _select(group.id)
                                      : goToBookmarkGroupPage(
                                          ref,
                                          BookmarkView.group(group.id),
                                          title: group.name,
                                        ),
                                  onRename: () => _rename(context, ref, group),
                                  onDuplicate: () =>
                                      _duplicate(context, ref, group),
                                  onDelete: () => _delete(context, ref, group),
                                );
                              },
                              childCount: folders.length + groups.length,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    ));
  }

  Future<void> _move({Set<String>? folderIds, Set<String>? groupIds}) async {
    final library = ref.read(bookmarkProvider).requireValue;
    final foldersToMove = folderIds ?? _selectedFolders;
    final groupsToMove = groupIds ?? _selectedGroups;
    final choice = await showFolderDestinationPicker(
      context,
      folders: library.folders,
      initialFolderId: _folderId,
      movingFolderIds: foldersToMove,
      sortByName: true,
      confirmationLabel: context.t.bookmark.groups.move_here,
      canMoveTo: (destination) =>
          library.folders.any(
            (f) => foldersToMove.contains(f.id) && f.parentId != destination,
          ) ||
          library.groups.any(
            (g) => groupsToMove.contains(g.id) && g.folderId != destination,
          ),
    );
    if (choice == null || !mounted) return;
    await _runGroupAction(
      context,
      () => ref
          .read(bookmarkProvider.notifier)
          .moveFolderItems(
            folderIds: folderIds ?? _selectedFolders,
            groupIds: groupIds ?? _selectedGroups,
            destination: choice.folderId,
          ),
    );
    if (mounted) {
      setState(() {
        _selectedFolders.clear();
        _selectedGroups.clear();
      });
    }
  }

  Future<void> _createFolder() async {
    final name = await showBookmarkGroupNameDialog(
      context,
      title: context.t.folders.create,
      hint: context.t.folders.name,
    );
    if (name == null || !mounted) return;
    await _runGroupAction(
      context,
      () => ref
          .read(bookmarkProvider.notifier)
          .createFolder(name, parentId: _folderId),
    );
  }

  Future<void> _renameFolder(CollectionFolder folder) async {
    final name = await showBookmarkGroupNameDialog(
      context,
      title: context.t.folders.rename,
      hint: context.t.folders.name,
      initialName: folder.name,
    );
    if (name == null || !mounted) return;
    await _runGroupAction(
      context,
      () => ref.read(bookmarkProvider.notifier).renameFolder(folder.id, name),
    );
  }

  Future<void> _deleteFolder(CollectionFolder folder) async {
    var preview = await ref
        .read(bookmarkProvider.notifier)
        .previewDeleteFolder(folder.id);
    while (mounted) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            context.t.folders.delete_title.replaceAll('{name}', folder.name),
          ),
          content: Text(
            context.t.folders.delete_bookmarks
                .replaceAll('{folders}', '${preview.folderIds.length}')
                .replaceAll('{groups}', '${preview.groupIds.length}')
                .replaceAll(
                  '{bookmarks}',
                  '${preview.orphanBookmarkIds.length}',
                ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.t.generic.action.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.t.generic.action.delete),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      try {
        await ref.read(bookmarkProvider.notifier).deleteFolder(preview);
        return;
      } on BookmarkFolderChangedException catch (e) {
        preview = e.preview;
      } catch (_) {
        if (mounted) {
          Kurumi.showErrorToast(
            context,
            context.t.bookmark.groups.operation_failed,
          );
        }
        return;
      }
    }
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final name = await showBookmarkGroupNameDialog(
      context,
      title: context.t.bookmark.groups.create,
    );
    if (name == null) return;
    if (!context.mounted) return;
    await _runGroupAction(
      context,
      () => ref
          .read(bookmarkProvider.notifier)
          .createGroup(name, folderId: _folderId),
    );
  }

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    BookmarkGroup group,
  ) async {
    final name = await showBookmarkGroupNameDialog(
      context,
      title: context.t.bookmark.groups.rename,
      initialName: group.name,
    );
    if (name == null) return;
    if (!context.mounted) return;
    await _runGroupAction(
      context,
      () => ref.read(bookmarkProvider.notifier).renameGroup(group.id, name),
    );
  }

  Future<void> _duplicate(
    BuildContext context,
    WidgetRef ref,
    BookmarkGroup group,
  ) async {
    final name = await showBookmarkGroupNameDialog(
      context,
      title: context.t.bookmark.groups.duplicate,
      initialName: group.name,
    );
    if (name == null) return;
    if (!context.mounted) return;
    await _runGroupAction(
      context,
      () => ref.read(bookmarkProvider.notifier).duplicateGroup(group.id, name),
    );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    BookmarkGroup group,
  ) async {
    final groups = ref.read(bookmarkProvider).valueOrNull?.groups ?? [group];
    var current = _deletionPreview(group, groups);
    while (true) {
      if (current.group.bookmarkIds.isNotEmpty) {
        if (!context.mounted) return;
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              context.t.bookmark.groups.delete_group_title.replaceAll(
                '{name}',
                current.group.name,
              ),
            ),
            content: Text(
              context.t.bookmark.groups.delete_group_message.replaceAll(
                '{bookmarks}',
                '${current.group.bookmarkIds.length}',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(context.t.generic.action.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(context.t.generic.action.delete),
              ),
            ],
          ),
        );
        if (confirmed != true || !context.mounted) return;
      }
      try {
        await ref
            .read(bookmarkProvider.notifier)
            .deleteGroup(
              current.group.id,
              expectedPreview: current,
            );
        return;
      } on BookmarkGroupChangedException catch (error) {
        current = error.preview;
      } catch (_) {
        if (context.mounted) {
          Kurumi.showErrorToast(
            context,
            context.t.bookmark.groups.operation_failed,
          );
        }
        return;
      }
    }
  }

  BookmarkGroupDeletionPreview _deletionPreview(
    BookmarkGroup group,
    Iterable<BookmarkGroup> groups,
  ) {
    final otherBookmarkIds = groups
        .where((other) => other.id != group.id)
        .expand((other) => other.bookmarkIds)
        .toSet();
    return BookmarkGroupDeletionPreview(
      group: group,
      orphanBookmarkIds: group.bookmarkIds.difference(otherBookmarkIds),
    );
  }

  Future<void> _runGroupAction(
    BuildContext context,
    Future<Object?> Function() action,
  ) async {
    try {
      await action();
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

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.title,
    required this.previews,
    required this.group,
    required this.onTap,
    required this.onRename,
    required this.onDuplicate,
    required this.onDelete,
    this.isFolder = false,
    this.selected = false,
    this.onSelect,
    this.onMove,
  });

  final bool isFolder;
  final bool selected;
  final VoidCallback? onSelect;
  final VoidCallback? onMove;
  final String title;
  final List<Bookmark> previews;
  final BookmarkGroup? group;
  final VoidCallback? onTap;
  final VoidCallback? onRename;
  final VoidCallback? onDuplicate;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(12);
    return Semantics(
      enabled: onTap != null,
      child: Opacity(
        opacity: onTap == null ? .38 : 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(
              color: Kurumi.themeOf(context).colorScheme.outlineVariant,
            ),
            borderRadius: borderRadius,
          ),
          child: ClipRRect(
            borderRadius: borderRadius,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                onLongPress: onSelect,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    BookmarkGroupPreviewGrid(
                      previews: previews,
                      itemBuilder: (_, bookmark) =>
                          _BookmarkGroupPreviewImage(bookmark: bookmark),
                    ),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0x99000000),
                            Color(0x00000000),
                            Color(0x66000000),
                          ],
                          stops: [0, 0.45, 1],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      left: 12,
                      right: onRename == null ? 12 : 52,
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Kurumi.themeOf(context).textTheme.titleMedium
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              shadows: const [Shadow(blurRadius: 4)],
                            ),
                      ),
                    ),
                    if (selected)
                      const Positioned(
                        bottom: 8,
                        right: 8,
                        child: Icon(Icons.check_circle, color: Colors.white),
                      ),
                    if (isFolder)
                      const Positioned(
                        bottom: 8,
                        left: 8,
                        child: Icon(Icons.folder, color: Colors.white),
                      ),
                    if (onRename != null)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: PopupMenuButton<String>(
                          onSelected: (action) => switch (action) {
                            'rename' => onRename?.call(),
                            'duplicate' => onDuplicate?.call(),
                            'delete' => onDelete?.call(),
                            'move' => onMove?.call(),
                            'select' => onSelect?.call(),
                            _ => null,
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'select',
                              child: Text(context.t.folders.select),
                            ),
                            PopupMenuItem(
                              value: 'move',
                              child: Text(context.t.folders.move),
                            ),
                            PopupMenuItem(
                              value: 'rename',
                              child: Text(context.t.bookmark.groups.rename),
                            ),
                            if (onDuplicate != null)
                              PopupMenuItem(
                                value: 'duplicate',
                                child: Text(
                                  context.t.bookmark.groups.duplicate,
                                ),
                              ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text(context.t.bookmark.groups.delete),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class BookmarkGroupPreviewGrid extends StatelessWidget {
  const BookmarkGroupPreviewGrid({
    required this.previews,
    required this.itemBuilder,
    super.key,
  });

  final List<Bookmark> previews;
  final Widget Function(BuildContext context, Bookmark bookmark) itemBuilder;

  @override
  Widget build(BuildContext context) => GridView.builder(
    physics: const NeverScrollableScrollPhysics(),
    padding: const EdgeInsets.all(2),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      crossAxisSpacing: 2,
      mainAxisSpacing: 2,
    ),
    itemCount: 4,
    itemBuilder: (context, index) => index < previews.length
        ? itemBuilder(context, previews[index])
        : const SizedBox.shrink(),
  );
}

String bookmarkGroupPreviewUrl(Bookmark bookmark) =>
    bookmark.isVideo ? bookmark.thumbnailUrl : bookmark.sampleUrl;

class _BookmarkGroupPreviewImage extends ConsumerWidget {
  const _BookmarkGroupPreviewImage({required this.bookmark});

  final Bookmark bookmark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final host = Uri.tryParse(bookmark.sourceUrl)?.host ?? '';
    final imageConfig = ref.watch(
      firstMatchingConfigByBooruTypeProvider((bookmark.booruId, host)),
    );
    return BooruImage(
      imageUrl: bookmarkGroupPreviewUrl(bookmark),
      config: imageConfig?.auth ?? ref.watchConfigAuth,

      fit: BoxFit.cover,
      placeholderWidget: const SizedBox.expand(),
    );
  }
}
