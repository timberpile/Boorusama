import 'dart:math' as math;

import 'package:anchor_ui/anchor_ui.dart' show AnchorData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../navigation/app_navigation.dart';
import '../../../configs/config/types.dart';
import '../../../posts/post/types.dart';
import '../data/bookmark_convert.dart';
import '../providers/bookmark_provider.dart';
import '../providers/bookmark_picker_actions.dart';
import '../providers/recent_bookmark_groups_provider.dart';
import '../types/bookmark_group.dart';
import '../types/bookmark_picker_request.dart';
import 'bookmark_batch_dialog.dart';
import 'bookmark_folder_picker_contents.dart';
import 'bookmark_group_label.dart';
import 'bookmark_picker_group_creation.dart';

export '../types/bookmark_picker_request.dart';

Future<void> showBookmarkGroupPicker(
  BuildContext context, {
  required BooruConfigAuth config,
  required Post post,
}) => showBookmarkPickerDialog(
  context,
  request: PostBookmarkPickerRequest(config: config, post: post),
);

Future<void> showBookmarkPickerDialog(
  BuildContext context, {
  required BookmarkPickerRequest request,
}) => showDialog<void>(
  context: context,
  builder: (_) => BookmarkGroupPickerDialog(request: request),
);

/// The non-anchored presenter owns exactly its route, even during a handoff.
class BookmarkGroupPickerDialog extends StatelessWidget {
  const BookmarkGroupPickerDialog({required this.request, super.key});
  final BookmarkPickerRequest request;

  @override
  Widget build(BuildContext context) {
    final route = ModalRoute.of(context)!;
    final navigator = Navigator.of(context);
    return BookmarkBatchDialog(
      title: context.t.bookmark.groups.selector,
      child: BookmarkGroupPicker(
        request: request,
        isActive: () => route.isCurrent,
        onDismiss: () {
          if (route.isCurrent) {
            navigator.pop();
          } else if (route.isActive) {
            // A creation route already owns the workflow above this one.
            navigator.removeRoute(route);
          }
        },
      ),
    );
  }
}

/// Shared trigger presentation for Posts and every collection reference type.
class BookmarkGroupPickerAnchor extends StatefulWidget {
  const BookmarkGroupPickerAnchor({
    required this.request,
    required this.builder,
    this.requestBuilder,
    super.key,
  });
  final BookmarkPickerRequest request;

  /// Capture optional newly loaded facts once, at opening, without replacing
  /// the already open picker's target during an unrelated parent rebuild.
  final BookmarkPickerRequest Function()? requestBuilder;
  final Widget Function(BuildContext, VoidCallback show) builder;

  @override
  State<BookmarkGroupPickerAnchor> createState() =>
      _BookmarkGroupPickerAnchorState();
}

class _BookmarkGroupPickerAnchorState extends State<BookmarkGroupPickerAnchor> {
  final _controller = AnchorController();
  final _navigation = BookmarkPickerNavigation();
  BookmarkPickerRequest? _presentedRequest;

  void _show() {
    if (_controller.isShowing) return;
    _presentedRequest = widget.requestBuilder?.call() ?? widget.request;
    _controller.show();
  }

  @override
  void didUpdateWidget(BookmarkGroupPickerAnchor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.request != widget.request) _controller.hide();
  }

  @override
  void dispose() {
    _controller.dispose();
    _navigation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final owner = widget.request;
    return KurumiAnchor(
      controller: _controller,
      onBack: () {
        if (!_navigation.back()) _controller.hide();
      },
      overlayBuilder: (context) => Padding(
        padding: EdgeInsets.zero,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: math.min(420, MediaQuery.sizeOf(context).width - 24),
            maxHeight: _maxHeight(context),
          ),
          child: BookmarkGroupPicker(
            key: ValueKey(_presentedRequest ?? owner),
            request: _presentedRequest ?? owner,
            navigation: _navigation,
            ownsBack: false,
            onDismiss: _controller.hide,
            // hide() revokes writes synchronously, before the fade completes.
            isActive: () => _controller.isShowing && widget.request == owner,
          ),
        ),
      ),
      child: widget.builder(context, _show),
    );
  }

  double _maxHeight(BuildContext context) {
    final media = MediaQuery.of(context);
    final bounds = AnchorData.of(context).geometry.childBounds;
    final top = media.padding.top + 12;
    final bottom =
        media.size.height -
        math.max(media.padding.bottom, media.viewInsets.bottom) -
        12;
    final above = bounds == null ? 0.0 : bounds.top - top;
    final below = bounds == null ? bottom - top : bottom - bounds.bottom;
    final available = math.max(above, below) - 4 - 16;
    final cap =
        (media.size.height - media.viewInsets.bottom - media.padding.vertical) *
        .75;
    return math.min(available, cap).clamp(0.0, double.infinity);
  }
}

void _showPickerSuccess(NavigatorState navigator, {required bool added}) {
  if (!navigator.mounted) return;
  final container = ProviderScope.containerOf(navigator.context, listen: false);
  final feedback =
      container.read(appNavigationProvider).feedbackKey.currentContext ??
      navigator.context;
  Kurumi.showSuccessToast(
    feedback,
    added
        ? navigator.context.t.bookmark.added
        : navigator.context.t.bookmark.removed,
  );
}

void _showPickerMissingIdentity(NavigatorState navigator) {
  if (!navigator.mounted) return;
  Kurumi.showErrorToast(
    navigator.context,
    navigator.context.t.bookmark.missing_post_identity,
  );
}

void _showPickerError(NavigatorState navigator) {
  if (!navigator.mounted) return;
  Kurumi.showErrorToast(
    navigator.context,
    navigator.context.t.bookmark.groups.operation_failed,
  );
}

bool _handleToggleOutcome(
  NavigatorState navigator,
  BookmarkToggleOutcome outcome,
) => switch (outcome) {
  BookmarkToggleOutcome.added => (() {
    _showPickerSuccess(navigator, added: true);
    return true;
  })(),
  BookmarkToggleOutcome.removed => (() {
    // The serialized removal publishes its Undo toast.
    return true;
  })(),
  BookmarkToggleOutcome.missingPostIdentity => (() {
    _showPickerMissingIdentity(navigator);
    return false;
  })(),
  BookmarkToggleOutcome.unavailable || BookmarkToggleOutcome.failed => (() {
    _showPickerError(navigator);
    return false;
  })(),
};

/// Shared content, navigation and selection; presenters supply ownership only.
class BookmarkGroupPicker extends ConsumerStatefulWidget {
  const BookmarkGroupPicker({
    required this.request,
    required this.onDismiss,
    required this.isActive,
    this.onRootBack,
    this.navigation,
    this.ownsBack = true,
    super.key,
  });
  final BookmarkPickerRequest request;
  final VoidCallback onDismiss;
  final bool Function() isActive;
  final VoidCallback? onRootBack;
  final BookmarkPickerNavigation? navigation;
  final bool ownsBack;
  @override
  ConsumerState<BookmarkGroupPicker> createState() =>
      _BookmarkGroupPickerState();
}

class _BookmarkGroupPickerState extends ConsumerState<BookmarkGroupPicker> {
  final _localNavigation = BookmarkPickerNavigation();
  BookmarkPickerNavigation get _navigation =>
      widget.navigation ?? _localNavigation;
  var _dismissed = false;
  var _creating = false;
  bool get _active => mounted && !_dismissed && widget.isActive();
  late final BookmarkPickerActions _actions;
  @override
  void initState() {
    super.initState();
    _actions = BookmarkPickerActions(
      container: ProviderScope.containerOf(context, listen: false),
      request: widget.request,
      isActive: () => _active,
    );
  }

  @override
  void dispose() {
    _actions.dispose();
    _localNavigation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    watchBookmarkPickerDraft(ref, request);
    final library = ref.watch(bookmarkProvider).valueOrNull;
    final identity = request.collectionIdentity;
    final savedRecordId = request.savedRecordId;
    final Set<String> memberships;
    if (savedRecordId != null) {
      memberships = library?.membershipsForId(savedRecordId) ?? const {};
    } else if (identity != null) {
      memberships =
          library?.pools
              .where((p) => p.identity == identity)
              .firstOrNull
              ?.groupIds ??
          const {};
    } else if (request case ContentGroupBookmarkPickerRequest(:final draft)) {
      final id = library?.idByContent[draft.reference.identity];
      memberships = id == null ? const {} : library!.membershipsForId(id);
    } else if (request case PostBookmarkPickerRequest(:final post)) {
      final saved = library?.storedBookmarkForPost(post);
      memberships = library?.hasUnifiedRecords == true
          ? saved == null
                ? const {}
                : library!.membershipsForId(saved.id)
          : library?.membershipsFor(
                  bookmarkIdentityForPost(post, request.config.booruIdHint),
                ) ??
                const {};
    } else {
      memberships = const {};
    }
    final tree = library?.groupTree;
    final nestedMemberships = tree == null
        ? const <String, int>{}
        : bookmarkNestedMembershipCounts(tree, memberships);
    final recentGroups =
        ref
            .watch(recentBookmarkGroupsProvider)
            .valueOrNull
            ?.where(
              (group) => !(library?.mirrors.isReceived(group.id) ?? false),
            )
            .toList() ??
        const <BookmarkGroup>[];
    BookmarkPickerMenuItem row(
      BookmarkGroup group, {
      bool recent = false,
      bool here = false,
    }) => BookmarkPickerMenuItem(
      icon: Icon(
        Symbols.bookmarks,
        fill: memberships.contains(group.id) ? 1 : 0,
      ),
      title: here
          ? memberships.contains(group.id)
                ? context.t.bookmark.groups.remove_here
                : context.t.bookmark.groups.save_here
          : group.displayName(context),
      detail: recent
          ? tree
                ?.ancestors(group.id)
                .map((g) => g.displayName(context))
                .join(' / ')
          : null,
      hideOnTap: false,
      onTap: () => _toggle(group.id),
    );
    return BookmarkFolderPickerContents(
      folders: library?.folders ?? const [],
      groups:
          library?.groups
              .where((group) => !library.mirrors.isReceived(group.id))
              .toList() ??
          const [],
      membershipGroupIds: memberships,
      onRootBack: widget.onRootBack ?? _dismiss,
      navigation: _navigation,
      ownsBack: widget.ownsBack,
      currentGroupBuilder: (context, group) => row(group, here: true),
      groupBuilder: (context, group) => row(group),
      pinnedFooter: recentGroups.isEmpty
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                KurumiContextMenuDivider(
                  title: context.t.bookmark.groups.recent,
                ),
                for (final group in recentGroups)
                  BookmarkPickerSplitRow(
                    selected: memberships.contains(group.id),
                    nestedMembershipCount: nestedMemberships[group.id] ?? 0,
                    navigationLabel:
                        '${context.t.bookmark.groups.open_group}: ${group.displayName(context)}',
                    onOpen: () => _navigation.open(group.id),
                    hasChildren: tree?.childrenOf(group.id).isNotEmpty == true,
                    child: row(group, recent: true),
                  ),
              ],
            ),
      onCreateGroup: _create,
      createGroupEnabled: !_creating,
    );
  }

  Future<void> _toggle(String groupId) async {
    if (!_active || _creating) return;
    final navigator = Navigator.of(context, rootNavigator: true);
    final notifier = ref.read(bookmarkProvider.notifier);
    try {
      final outcome = await _actions.toggle(
        groupId,
        onRemoved: (removal) {
          if (navigator.mounted)
            notifier.showRemovalUndo(navigator.context, removal);
        },
      );
      if (outcome == null) return;
      final completed = _handleToggleOutcome(navigator, outcome);
      if (completed && _active) _dismiss();
    } catch (_) {
      if (_active) _showPickerError(navigator);
    }
  }

  void _create(String? folderId) {
    if (!_active || _creating || _actions.pending) return;
    _creating = true;
    final navigator = Navigator.of(context, rootNavigator: true);
    final request = _actions.request;
    // Install the next owner before releasing this anchor or dialog. Its
    // immutable request and ProviderContainer survive the old widget's disposal.
    final result = showDialog<String>(
      context: navigator.context,
      builder: (_) => BookmarkPickerGroupCreation(
        request: request,
        parentGroupId: folderId,
      ),
    );
    _dismiss();
    result.then((name) {
      if (name != null) _showPickerSuccess(navigator, added: true);
    });
  }

  void _dismiss() {
    _dismissed = true;
    widget.onDismiss();
  }
}
