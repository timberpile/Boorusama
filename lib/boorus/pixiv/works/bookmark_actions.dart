import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/bookmarks/providers.dart';
import '../../../core/bookmarks/src/data/bookmark_convert.dart';
import '../../../core/bookmarks/src/types/bookmark_library_state.dart';
import '../../../core/bookmarks/src/widgets/bookmark_group_picker.dart';
import '../../../core/configs/config/types.dart';
import '../../../core/content/content_access_provider.dart';
import '../../../core/content/groups/group_capability.dart';
import '../../../core/navigation/destination_activity.dart';
import '../../../core/themes/theme/types.dart';
import '../posts/types.dart';
import 'bookmark_targets.dart';

BookmarkPickerRequest _workRequest(
  ProviderContainer container,
  GroupBookmarkPresentationData data,
) => ContentGroupBookmarkPickerRequest(
  source: data.access.config!,
  access: data.access.key,
  draft:
      PixivWorkBookmarkTarget(
        access: data.access,
        summary: data.summary,
        details: data.details,
      ).draft(
        currentAccess: container.read(
          contentAccessContextProvider(data.access.key),
        ),
        at: DateTime.now().toUtc(),
      ),
);

bool _isSinglePage(GroupBookmarkPresentationData data) =>
    (data.details?.summary.memberCount ?? data.summary.memberCount) == 1;

BookmarkPickerRequest? _pageRequest(GroupBookmarkPresentationData data) {
  final page = data.page;
  if (page == null || _isSinglePage(data)) return null;
  try {
    // A loaded Post is not sufficient: it must be an available real Page of
    // this Work and the captured actor, never a neighboring Work's fallback.
    PixivPageBookmarkTarget(access: data.access, post: page);
    if (data.summary.reference.sourceKey !=
        'work:${page.pixivData!.illustId}') {
      return null;
    }
    return PostBookmarkPickerRequest(
      config: data.access.config!.auth,
      source: data.access.config,
      access: data.access.key,
      post: page,
    );
  } on FormatException {
    return null;
  }
}

bool _current(ProviderContainer container, GroupBookmarkPresentationData data) {
  final access = container.read(contentAccessContextProvider(data.access.key));
  return access != null && data.access.hasSameAuthorization(access);
}

Set<String> _memberships(
  BookmarkLibraryState? library,
  BookmarkPickerRequest request,
) {
  if (library == null) return const {};
  if (request case ContentGroupBookmarkPickerRequest(:final draft)) {
    final id = library.idByContent[draft.reference.identity];
    return id == null ? const {} : library.membershipsForId(id);
  }
  if (request case PostBookmarkPickerRequest(:final post)) {
    if (library.hasUnifiedRecords) {
      final saved = library.storedBookmarkForPost(post);
      return saved == null ? const {} : library.membershipsForId(saved.id);
    }
    return library.membershipsFor(
      bookmarkIdentityForPost(post, request.config.booruIdHint),
    );
  }
  return const {};
}

Future<void> _showPicker(
  BuildContext context,
  GroupBookmarkPresentationData data,
) async {
  if (!context.mounted) return;
  final container = ProviderScope.containerOf(context, listen: false);
  if (!_current(container, data)) return;
  await showBookmarkPickerDialog(
    context,
    request: _workRequest(container, data),
  );
}

class PixivWorkBookmarkButton extends ConsumerStatefulWidget {
  const PixivWorkBookmarkButton({required this.data, super.key});
  final GroupBookmarkPresentationData data;
  @override
  ConsumerState<PixivWorkBookmarkButton> createState() =>
      _PixivWorkBookmarkButtonState();
}

class _PixivWorkBookmarkButtonState
    extends ConsumerState<PixivWorkBookmarkButton> {
  late BookmarkPickerRequest _owner;
  var _choosing = false;

  void _captureOwner() {
    final data = widget.data;
    _owner = ContentGroupBookmarkPickerRequest(
      source: data.access.config!,
      access: data.access.key,
      draft: PixivWorkBookmarkTarget(
        access: data.access,
        summary: data.summary,
      ).draft(currentAccess: data.access, at: DateTime.now().toUtc()),
    );
  }

  @override
  void initState() {
    super.initState();
    _captureOwner();
  }

  @override
  void didUpdateWidget(PixivWorkBookmarkButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data.summary.reference != widget.data.summary.reference ||
        !oldWidget.data.access.hasSameAuthorization(widget.data.access)) {
      _captureOwner();
    }
  }

  bool _isCurrent(
    GroupBookmarkPresentationData data,
    BookmarkPickerRequest owner,
  ) =>
      mounted &&
      identical(_owner, owner) &&
      widget.data.summary.reference == data.summary.reference &&
      widget.data.access.hasSameAuthorization(data.access) &&
      _current(ProviderScope.containerOf(context, listen: false), data);

  Future<void> _choose() async {
    final captured = widget.data;
    final owner = _owner;
    if (_choosing ||
        _isSinglePage(captured) ||
        !_isCurrent(captured, owner) ||
        !NavigationActivity.of(context)) {
      return;
    }
    _choosing = true;
    try {
      final work = _workRequest(
        ProviderScope.containerOf(context, listen: false),
        captured,
      );
      final page = _pageRequest(captured);
      TransitionRoute<dynamic>? choiceRoute;
      final selected = await showDialog<BookmarkPickerRequest>(
        context: context,
        builder: (context) {
          choiceRoute = ModalRoute.of(context);
          return _BookmarkChoices(work: work, page: page);
        },
      );
      if (selected == null || !_isCurrent(captured, owner)) return;
      if (choiceRoute case final route?) await route.completed;
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      // The Page request stays frozen across inner Page changes, while a new
      // outer Work, revoked actor, or disposed owner cancels the handoff.
      if (_isCurrent(captured, owner) && NavigationActivity.of(context)) {
        await showBookmarkPickerDialog(context, request: selected);
      }
    } finally {
      _choosing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final owner = _owner;
    final library = ref.watch(bookmarkProvider);
    ref.watch(contentAccessContextProvider(data.access.key));
    final groups = _memberships(library.valueOrNull, owner);
    final enabled = !library.isLoading && _isCurrent(data, owner);
    final alternatives = !_isSinglePage(data);
    return BookmarkGroupPickerAnchor(
      request: owner,
      requestBuilder: () => _workRequest(
        ProviderScope.containerOf(context, listen: false),
        widget.data,
      ),
      builder: (context, show) => IgnorePointer(
        // Inactive neighbors and covered routes retain their own appearance.
        // Navigation suppresses input, not the identity of the rendered action.
        ignoring: !NavigationActivity.of(context),
        child: KurumiActionIconButton(
          key: const ValueKey('pixiv-work-bookmark-trigger'),
          tooltip: context.t.content_viewer.bookmark_work,
          showDropdown: alternatives,
          onLongPress: alternatives && enabled ? _choose : null,
          onPressed: enabled
              ? () {
                  if (_isCurrent(data, owner) &&
                      NavigationActivity.of(context)) {
                    show();
                  }
                }
              : null,
          icon: Semantics(
            selected: groups.isNotEmpty,
            value: groups.length > 1 ? '${groups.length}' : null,
            child: Badge(
              isLabelVisible: groups.length > 1,
              label: Text('${groups.length}'),
              child: Icon(
                Symbols.bookmark,
                fill: groups.isNotEmpty ? 1 : 0,
                color: groups.isNotEmpty ? context.colors.upvoteColor : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BookmarkChoices extends ConsumerWidget {
  const _BookmarkChoices({required this.work, required this.page});
  final BookmarkPickerRequest work;
  final BookmarkPickerRequest? page;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(bookmarkProvider).valueOrNull;
    Widget choice(String key, String title, BookmarkPickerRequest request) {
      final groups = _memberships(library, request);
      final saved = groups.isNotEmpty;
      return Semantics(
        selected: saved,
        child: KurumiPopupMenuItem(
          key: ValueKey(key),
          hideOnTap: false,
          title: Text(title),
          icon: Icon(
            Symbols.bookmark,
            fill: saved ? 1 : 0,
            color: saved ? context.colors.upvoteColor : null,
          ),
          trailing: groups.length > 1 ? Text('${groups.length}') : null,
          onTap: () => Navigator.pop(context, request),
        ),
      );
    }

    return KurumiDialog(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          choice(
            'pixiv-bookmark-work-choice',
            context.t.content_viewer.bookmark_work,
            work,
          ),
          if (page case final request?)
            choice(
              'pixiv-bookmark-page-choice',
              context.t.content_viewer.bookmark_page,
              request,
            ),
        ],
      ),
    );
  }
}

class PixivWorkBookmarkContextMenu extends ConsumerWidget {
  const PixivWorkBookmarkContextMenu({
    required this.data,
    required this.child,
    super.key,
  });
  final GroupBookmarkPresentationData data;
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) => KurumiContextMenu(
    menuItemsBuilder: (_) => [
      KurumiContextMenuTile(
        title: context.t.content_viewer.bookmark_work,
        onTap: () => _showPicker(context, data),
      ),
    ],
    child: child,
  );
}
