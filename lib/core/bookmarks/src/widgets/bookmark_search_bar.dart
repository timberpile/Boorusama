import 'package:selection_mode/selection_mode.dart';

// Dart imports:
import 'dart:math';

// Flutter imports:
import 'package:flutter/services.dart';

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
import '../../../search/search/widgets.dart';
import '../../../search/suggestions/tag_suggestion_item.dart';
import '../../../tags/autocompletes/types.dart';
import '../providers/bookmark_search_controller.dart';
import '../providers/suggestion_provider.dart';
import '../types/bookmark_search_token.dart';
import '../types/bookmark_tag_index.dart';
import '../types/bookmark_view.dart';

class BookmarkSearchBar extends ConsumerStatefulWidget {
  const BookmarkSearchBar({
    required this.controller,
    required this.postController,
    super.key,
    this.view = const BookmarkView.all(),
  });

  final TextEditingController controller;
  final PostGridController postController;
  final BookmarkView view;

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

  @override
  Widget build(BuildContext context) {
    // Retain the scoped index while the bar is mounted, not only while an
    // overlay is visible. Typing never scans or fetches the bookmark library.
    ref.watch(bookmarkTagIndexProvider(widget.view));
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
                      triggerMode: AnchorTriggerMode.focus(
                        focusNode: _focusNode,
                      ),
                      spacing: 4,
                      arrowShape: const NoArrow(),
                      backdropBuilder: (context) => isMobilePlatform()
                          ? ClipPath(
                              clipper: _SearchBackdropClipper(
                                AnchorData.of(context).geometry.childBounds,
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
                          maxHeight: min(
                            300,
                            max(
                                  0,
                                  MediaQuery.heightOf(context) -
                                      MediaQuery.viewInsetsOf(context).bottom,
                                ) *
                                0.4,
                          ),
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
                      child: BooruSearchBar(
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
  const _SearchBackdropClipper(this.fieldBounds);

  final Rect? fieldBounds;

  @override
  Path getClip(Size size) {
    final path = Path()..addRect(Offset.zero & size);
    if (fieldBounds case final bounds?) {
      // The popover covers the screen, but the field's controls must remain
      // reachable while autocomplete is open.
      path
        ..fillType = PathFillType.evenOdd
        ..addRect(bounds);
    }
    return path;
  }

  @override
  bool shouldReclip(_SearchBackdropClipper oldClipper) =>
      fieldBounds != oldClipper.fieldBounds;
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
