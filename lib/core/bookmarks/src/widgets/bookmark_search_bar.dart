import 'package:selection_mode/selection_mode.dart';

// Dart imports:
import 'dart:math';

// Flutter imports:
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';

// Package imports:
import 'package:anchor_ui/anchor_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

// Project imports:
import '../../../../foundation/platform.dart';
import '../../../posts/listing/providers.dart';
import '../../../settings/providers.dart';
import '../../../search/search/widgets.dart';
import '../../../search/suggestions/tag_suggestion_item.dart';
import '../../../tags/autocompletes/types.dart';
import '../providers/bookmark_search_controller.dart';
import '../providers/suggestion_provider.dart';
import '../types/bookmark_search_token.dart';
import '../types/bookmark_tag_index.dart';
import '../types/bookmark_view.dart';

// Diagnostic A/B only: the normal build retains its eager subscription.
const _skipIdleIndex = bool.fromEnvironment(
  'BOORUSAMA_PERF_SKIP_IDLE_BOOKMARK_INDEX',
);

class BookmarkSearchBar extends ConsumerStatefulWidget {
  const BookmarkSearchBar({
    required this.controller,
    required this.postController,
    super.key,
    this.view = const BookmarkView.all(),
    this.revealTimelineOnFocus = false,
  });

  final TextEditingController controller;
  final PostGridController postController;
  final BookmarkView view;
  final bool revealTimelineOnFocus;

  @override
  ConsumerState<BookmarkSearchBar> createState() => _BookmarkSearchBarState();
}

class _BookmarkSearchBarState extends ConsumerState<BookmarkSearchBar> {
  final _focusNode = FocusNode();
  late BookmarkSearchController _search;

  @override
  void initState() {
    super.initState();
    _search = BookmarkSearchController(widget.controller);
    _focusNode.addListener(_onFocusChanged);
  }

  var _revealScheduled = false;

  void _onFocusChanged() {
    setState(() {});
    if (_focusNode.hasFocus) {
      _revealSearch();
    }
  }

  void _revealSearch() {
    if (!widget.revealTimelineOnFocus || _revealScheduled) return;
    _revealScheduled = true;
    final view = widget.view;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _revealScheduled = false;
      if (!mounted ||
          !_focusNode.hasFocus ||
          widget.view != view ||
          !widget.revealTimelineOnFocus) {
        return;
      }
      final scrollable = Scrollable.maybeOf(context);
      final header = context.findAncestorRenderObjectOfType<RenderSliver>();
      if (scrollable == null || header?.geometry == null) return;
      final position = scrollable.position;
      final offset = header!.constraints.precedingScrollExtent.clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      // Only advance past subgroup cards. Never rewind a timeline the user
      // has already entered just because its floating search field is focused.
      if (offset <= position.pixels) return;
      position.animateTo(
        offset,
        duration:
            MediaQuery.disableAnimationsOf(context) ||
                ref.read(settingsProvider).reduceAnimations
            ? Duration.zero
            : Durations.short4,
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void didUpdateWidget(covariant BookmarkSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _focusNode.unfocus();
      _search.dispose();
      _search = BookmarkSearchController(widget.controller);
    }
  }

  @override
  void dispose() {
    _search.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    final index = ref.read(bookmarkTagIndexProvider(widget.view)).valueOrNull;
    _search.submit(knownTags: index?.byName.keys.toSet() ?? const {});
    _focusNode.unfocus();
    SelectionMode.maybeOf(context)?.disable();
    widget.postController.refresh();
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || !_search.draft.value.composing.isCollapsed) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.backspace &&
        _search.editLastTag()) {
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _cancelEdit() {
    _search.cancelEdit();
    _focusNode.unfocus();
  }

  double _navigationHeaderBottom() {
    if (widget.view.kind == BookmarkViewKind.all) return 0;
    final scaffold = Scaffold.maybeOf(context);
    final box = scaffold?.context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) {
      return scaffold?.appBarMaxHeight ?? 0;
    }
    return box.localToGlobal(Offset.zero).dy + (scaffold?.appBarMaxHeight ?? 0);
  }

  double _suggestionHeight(BuildContext context) {
    final visibleBottom = max(
      0.0,
      MediaQuery.heightOf(context) - MediaQuery.viewInsetsOf(context).bottom,
    );
    final usualHeight = min(300.0, visibleBottom * .4);
    if (widget.view.kind == BookmarkViewKind.all) return usualHeight;
    final field = AnchorData.of(context).geometry.childBounds;
    if (field == null) return 0;
    final above = max(0.0, field.top - _navigationHeaderBottom() - 4);
    final below = max(0.0, visibleBottom - field.bottom - 4);
    final available = min(usualHeight, max(above, below));
    // Do not flip a suggestion over navigation or offer a clipped sliver of a
    // row when a landscape keyboard leaves no room beside the search field.
    return available < kMinInteractiveDimension ? 0 : available;
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    // Retain the scoped index while the bar is mounted, not only while an
    // overlay is visible. Typing never scans or fetches the bookmark library.
    if (!_skipIdleIndex ||
        _focusNode.hasFocus ||
        widget.controller.text.isNotEmpty) {
      ref.watch(bookmarkTagIndexProvider(widget.view));
    }
    return AnimatedBuilder(
      // KurumiSearchBar retains its initial controller. Recreate the field
      // and its popover when the owning query controller changes.
      key: ObjectKey(_search),
      animation: _search,
      builder: (context, _) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Focus(
                    onKeyEvent: _onKeyEvent,
                    child: AnchorPopover(
                      // Opening the keyboard can scroll a Structure header
                      // into view. Keep autocomplete attached during that move.
                      scrollBehavior: AnchorScrollBehavior.reposition,
                      triggerMode: AnchorTriggerMode.focus(
                        focusNode: _focusNode,
                      ),
                      spacing: 4,
                      arrowShape: const NoArrow(),
                      viewPadding: widget.view.kind == BookmarkViewKind.all
                          ? null
                          : EdgeInsets.only(
                              top: _navigationHeaderBottom(),
                              bottom: media.viewInsets.bottom,
                            ),
                      backdropBuilder: (context) => isMobilePlatform()
                          ? ClipPath(
                              clipper: _SearchBackdropClipper(
                                AnchorData.of(context).geometry.childBounds,
                                headerBottom: _navigationHeaderBottom(),
                              ),
                              child: const ColoredBox(color: Colors.black54),
                            )
                          : const SizedBox.shrink(),
                      placement: Placement.bottom,
                      overlayBuilder: (context) => ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth:
                              AnchorData.of(
                                context,
                              ).geometry.childBounds?.width ??
                              double.infinity,
                          maxHeight: _suggestionHeight(context),
                        ),
                        child: _BookmarkSuggestions(
                          search: _search,
                          view: widget.view,
                          onSelected: (tag) {
                            final index = ref
                                .read(
                                  bookmarkTagIndexProvider(widget.view),
                                )
                                .valueOrNull;
                            _search.selectSuggestion(
                              tag.tag,
                              knownTags: index?.byName.keys.toSet() ?? const {},
                            );
                            _focusNode.unfocus();
                            SelectionMode.maybeOf(context)?.disable();
                            widget.postController.refresh();
                          },
                        ),
                      ),
                      child: _VisibleSearchField(
                        child: BooruSearchBar(
                          onTap: _revealSearch,
                          hintText: switch (widget.view.kind) {
                            BookmarkViewKind.all => context.t.search.hint,
                            BookmarkViewKind.group =>
                              context.t.bookmark.groups.search_direct,
                            BookmarkViewKind.subtree =>
                              context.t.bookmark.groups.search_subtree,
                          },
                          focus: _focusNode,
                          controller: _search.draft,
                          // The popover handles outside taps, including keeping
                          // focus while scrolling its suggestion list.
                          onTapOutside: () {},
                          leading: IconButton(
                            icon: const Icon(Symbols.search),
                            onPressed: _submit,
                          ),
                          trailing:
                              _search.draft.text.isNotEmpty ||
                                  _search.selectedTags.tags.isNotEmpty
                              ? IconButton(
                                  tooltip: context.t.search.remove_all_selected,
                                  icon: const Icon(Symbols.clear),
                                  onPressed: () {
                                    _search.clear();
                                    _focusNode.unfocus();
                                    SelectionMode.maybeOf(context)?.disable();
                                    widget.postController.refresh();
                                  },
                                )
                              : null,
                          onSubmitted: (_) => _submit(),
                          onEscape: _cancelEdit,
                        ),
                      ),
                    ),
                  ),
                  if (_search.selectedTags.tags.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: LayoutBuilder(
                        builder: (context, constraints) => Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            for (final tag in _search.selectedTags.tags)
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: constraints.maxWidth,
                                ),
                                child: Consumer(
                                  builder: (context, ref, _) => SelectedTagChip(
                                    key: ValueKey(tag.toString()),
                                    tagSearchItem: tag,
                                    tagColor: ref
                                        .watch(
                                          bookmarkTagColorProvider((
                                            widget.view,
                                            tag.rawTag,
                                            Kurumi.themeOf(
                                              context,
                                            ).colorScheme.brightness,
                                          )),
                                        )
                                        .valueOrNull,
                                    textScaler: MediaQuery.textScalerOf(
                                      context,
                                    ),
                                    onTap: () {
                                      _search.edit(tag);
                                      _focusNode.requestFocus();
                                    },
                                    onDeleted: () {
                                      _search.remove(tag);
                                      SelectionMode.maybeOf(context)?.disable();
                                      widget.postController.refresh();
                                    },
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBackdropClipper extends CustomClipper<Path> {
  const _SearchBackdropClipper(this.fieldBounds, {this.headerBottom = 0});

  final Rect? fieldBounds;
  final double headerBottom;

  @override
  Path getClip(Size size) {
    final top = headerBottom.clamp(0.0, size.height);
    final area = Rect.fromLTWH(0, top, size.width, size.height - top);
    final path = Path()..addRect(area);
    if (fieldBounds case final bounds?) {
      // The popover covers the screen, but the field's controls must remain
      // reachable while autocomplete is open.
      final field = bounds.intersect(area);
      if (!field.isEmpty) {
        path
          ..fillType = PathFillType.evenOdd
          ..addRect(field);
      }
    }
    return path;
  }

  @override
  bool shouldReclip(_SearchBackdropClipper oldClipper) =>
      fieldBounds != oldClipper.fieldBounds ||
      headerBottom != oldClipper.headerBottom;
}

class _BookmarkSuggestions extends StatelessWidget {
  const _BookmarkSuggestions({
    required this.search,
    required this.view,
    required this.onSelected,
  });

  final BookmarkSearchController search;
  final BookmarkView view;
  final ValueChanged<BookmarkTagEntry> onSelected;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: search,
    builder: (context, _) => Consumer(
      builder: (context, ref, _) {
        final colorScheme = Kurumi.themeOf(context).colorScheme;
        final selectedQuery = search.selectedTags.tags
            .where((tag) => tag != search.editingTag)
            .join(' ');
        final suggestions = ref.watch(
          bookmarkTagSuggestionsProvider((
            view,
            search.draft.text,
            selectedQuery,
          )),
        );
        return Material(
          color: colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(8),
          clipBehavior: Clip.antiAlias,
          child: switch (suggestions) {
            AsyncData(:final value) when value.isNotEmpty => ListView.builder(
              padding: const EdgeInsets.all(4),
              shrinkWrap: true,
              itemCount: value.length,
              itemBuilder: (context, index) {
                final tag = value[index];
                final query = bookmarkSuggestionQueries(
                  search.draft.text,
                ).firstWhere((query) => tag.tag.contains(query.token.tag));
                return Consumer(
                  builder: (context, ref, _) => TagSuggestionItem(
                    key: ValueKey('bookmark-suggestion-${tag.tag}'),
                    tag: AutocompleteData(
                      label: tag.tag,
                      value: tag.tag,
                      postCount: tag.count,
                    ),
                    currentQuery: query.token.tag,
                    textColor:
                        ref
                            .watch(
                              bookmarkTagColorProvider((
                                view,
                                tag.tag,
                                colorScheme.brightness,
                              )),
                            )
                            .valueOrNull ??
                        colorScheme.onSurface,
                    showCount: true,
                    dense: true,
                    metatagExtractor: null,
                    onItemTap: (_) => onSelected(tag),
                  ),
                );
              },
            ),
            _ => Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                context.t.generic.no_content,
                style: TextStyle(color: colorScheme.hintColor),
              ),
            ),
          },
        );
      },
    ),
  );
}

/// Floating headers already paint the field at the viewport's leading edge.
/// Implicit caret reveal otherwise uses its original sliver position and rewinds
/// the timeline. Still delegate when the field is clipped (for example by IME).
class _VisibleSearchField extends SingleChildRenderObjectWidget {
  const _VisibleSearchField({required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderVisibleSearchField();
}

class _RenderVisibleSearchField extends RenderProxyBox {
  @override
  void showOnScreen({
    RenderObject? descendant,
    Rect? rect,
    Duration duration = Duration.zero,
    Curve curve = Curves.ease,
  }) {
    final viewport = switch (RenderAbstractViewport.maybeOf(this)) {
      final RenderBox box => box,
      _ => null,
    };
    if (viewport != null && hasSize) {
      final bounds = MatrixUtils.transformRect(
        getTransformTo(viewport),
        paintBounds,
      );
      if (viewport.paintBounds.contains(bounds.topLeft) &&
          viewport.paintBounds.contains(bounds.bottomRight)) {
        return;
      }
    }
    super.showOnScreen(
      descendant: descendant,
      rect: rect,
      duration: duration,
      curve: curve,
    );
  }
}
