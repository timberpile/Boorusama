import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/bookmarks/providers.dart';
import '../../../core/configs/config/types.dart';
import '../../../core/bookmarks/src/widgets/bookmark_group_picker.dart';
import '../../../core/content/content_access_provider.dart';
import '../../../core/content/groups/group_capability.dart';
import '../../../core/widgets/adaptive_button_row.dart';
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

BookmarkPickerRequest _pageRequest(GroupBookmarkPresentationData data) {
  final page = data.page!;
  // Validate the real source Page before passing the unchanged Post to the
  // established Post mutation path. No Work draft accompanies this request.
  PixivPageBookmarkTarget(access: data.access, post: page);
  return PostBookmarkPickerRequest(
    config: data.access.config!.auth,
    source: data.access.config,
    access: data.access.key,
    post: page,
  );
}

bool _current(ProviderContainer container, GroupBookmarkPresentationData data) {
  final access = container.read(contentAccessContextProvider(data.access.key));
  return access != null && data.access.hasSameAuthorization(access);
}

Future<void> _showPicker(
  BuildContext context,
  GroupBookmarkPresentationData data, {
  bool page = false,
}) async {
  if (!context.mounted || (page && data.page == null)) return;
  final container = ProviderScope.containerOf(context, listen: false);
  if (!_current(container, data)) return;
  final request = page ? _pageRequest(data) : _workRequest(container, data);
  await showBookmarkPickerDialog(context, request: request);
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
        !oldWidget.data.access.hasSameAuthorization(widget.data.access))
      _captureOwner();
  }

  bool _isCurrent(GroupBookmarkPresentationData data) =>
      mounted && _current(ProviderScope.containerOf(context), data);

  Future<void> _choose() async {
    final captured = widget.data;
    if (!_isCurrent(captured)) return;
    final work = _workRequest(ProviderScope.containerOf(context), captured);
    final page = captured.page == null ? null : _pageRequest(captured);
    final strings = context.t.content_viewer;
    TransitionRoute<dynamic>? choiceRoute;
    final selected = await showDialog<BookmarkPickerRequest>(
      context: context,
      builder: (context) {
        choiceRoute = ModalRoute.of(context);
        return KurumiDialog(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              KurumiPopupMenuItem(
                title: Text(strings.bookmark_work),
                icon: const Icon(Symbols.bookmarks),
                onTap: () => Navigator.pop(context, work),
              ),
              if (page != null)
                KurumiPopupMenuItem(
                  title: Text(strings.bookmark_page),
                  icon: const Icon(Symbols.bookmark),
                  onTap: () => Navigator.pop(context, page),
                ),
            ],
          ),
        );
      },
    );
    if (!mounted || selected == null) return;
    if (choiceRoute case final route?) await route.completed;
    await WidgetsBinding.instance.endOfFrame;
    if (_isCurrent(captured)) {
      await showBookmarkPickerDialog(context, request: selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(bookmarkProvider).valueOrNull;
    final id = library?.idByContent[widget.data.summary.reference.identity];
    final groups = id == null
        ? const <String>{}
        : library!.membershipsForId(id);
    return BookmarkGroupPickerAnchor(
      request: _owner,
      requestBuilder: () =>
          _workRequest(ProviderScope.containerOf(context), widget.data),
      builder: (context, show) => TooltipTheme(
        data: TooltipTheme.of(context)
            .copyWith(triggerMode: TooltipTriggerMode.manual),
        child: GestureDetector(
          onLongPress: _isCurrent(widget.data) ? _choose : null,
          child: IconButton(
            tooltip: context.t.content_viewer.bookmark_work,
            onPressed: _isCurrent(widget.data)
                ? () {
                    if (_isCurrent(widget.data)) show();
                  }
                : null,
            icon: Badge(
              isLabelVisible: groups.length > 1,
              label: Text('${groups.length}'),
              child: SizedBox.square(
                dimension: 24,
                child: Stack(
                  children: [
                    Center(
                      child: Icon(
                        Symbols.bookmark,
                        fill: groups.isNotEmpty ? 1 : 0,
                      ),
                    ),
                    const Positioned(
                      right: 0,
                      bottom: 0,
                      child: Icon(Icons.arrow_drop_down, size: 10),
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

/// The normal toolbar owns overflow presentation; these callbacks freeze its
/// source Work and selected real Page when the menu is built.
List<ButtonData> pixivWorkBookmarkMenuButtons(
  BuildContext context,
  GroupBookmarkPresentationData data,
) => [
  for (final page in [false, true])
    ButtonData(
      title: page
          ? context.t.content_viewer.bookmark_page
          : context.t.content_viewer.bookmark_work,
      icon: Icon(page ? Symbols.bookmark : Symbols.bookmarks),
      widget: const SizedBox.shrink(),
      enabled: !page || data.page != null,
      placement: ButtonPlacement.menuOnly,
      onTap: page && data.page == null
          ? null
          : () => _showPicker(context, data, page: page),
    ),
];

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
