import 'dart:math';

import 'package:anchor_ui/anchor_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../bookmarks/src/providers/bookmark_search_controller.dart';
import '../../../../bookmarks/src/providers/suggestion_provider.dart';
import '../../../../bookmarks/src/types/bookmark_tag_index.dart';
import '../../../../bookmarks/src/widgets/bookmark_option_selector.dart';
import '../../../../posts/post/types.dart';
import '../../../../config_widgets/website_logo.dart';
import '../../../../tags/autocompletes/types.dart';
import '../../../options/labels.dart';
import '../../../options/search_option.dart';
import '../../../search/widgets.dart';
import '../../../suggestions/tag_suggestion_item.dart';
import '../providers/cached_feed_tag_index_provider.dart';
import '../types/cached_topic_feed_filter.dart';

class CachedFeedFilterBar extends ConsumerStatefulWidget {
  const CachedFeedFilterBar({
    required this.snapshots,
    required this.onChanged,
    super.key,
  });

  final List<StoredPostSnapshot> snapshots;
  final ValueChanged<CachedTopicFeedFilter> onChanged;

  @override
  ConsumerState<CachedFeedFilterBar> createState() =>
      _CachedFeedFilterBarState();
}

class _CachedFeedFilterBarState extends ConsumerState<CachedFeedFilterBar> {
  final _query = TextEditingController();
  final _focus = FocusNode();
  late final BookmarkSearchController _search;
  String? _sourceHost;
  var _sort = CachedTopicFeedSort.stored;
  var _published = const CachedTopicFeedFilter();

  @override
  void initState() {
    super.initState();
    _search = BookmarkSearchController(_query);
    _query.addListener(_publish);
  }

  BookmarkTagIndex get _index => ref.read(
    cachedFeedTagIndexProvider((
      widget.snapshots,
      CachedTopicFeedFilter(sourceHost: _sourceHost),
    )),
  );

  void _publish() {
    final filter = CachedTopicFeedFilter(
      query: _query.text,
      sourceHost: _sourceHost,
      sort: _sort,
    );
    if (filter == _published) return;
    _published = filter;
    widget.onChanged(filter);
  }

  void _submit() {
    if (!_search.draft.value.composing.isCollapsed) return;
    _search.submit(knownTags: _index.byName.keys.toSet());
    _focus.unfocus();
  }

  void _clear() {
    setState(() {
      _sourceHost = null;
      _sort = CachedTopicFeedSort.stored;
      _search.clear();
      _publish();
    });
    _focus.unfocus();
  }

  @override
  void dispose() {
    _query.removeListener(_publish);
    _search.dispose();
    _query.dispose();
    _focus.dispose();
    super.dispose();
  }

  Color? _tagColor(
    WidgetRef ref,
    BookmarkTagEntry? entry,
    Brightness brightness,
  ) => entry == null
      ? null
      : ref.watch(localTagEntryColorProvider((entry, brightness))).valueOrNull;

  String _sortLabel(CachedTopicFeedSort value) => switch (value) {
    CachedTopicFeedSort.stored => context.t.generic.action.clear,
    CachedTopicFeedSort.newest => context.t.explore.newest,
    CachedTopicFeedSort.oldest => context.t.explore.oldest,
    CachedTopicFeedSort.scoreDescending => searchOptionChoiceLabel(
      context,
      const SearchOptionChoice('score:desc', 'score:desc'),
    ),
    CachedTopicFeedSort.scoreAscending => searchOptionChoiceLabel(
      context,
      const SearchOptionChoice('score:asc', 'score:asc'),
    ),
  };

  @override
  Widget build(BuildContext context) {
    final strings = context.t.following_topics;
    final index = ref.watch(
      cachedFeedTagIndexProvider((
        widget.snapshots,
        CachedTopicFeedFilter(sourceHost: _sourceHost),
      )),
    );
    final colorScheme = Kurumi.themeOf(context).colorScheme;
    final hosts = {
      ...cachedTopicFeedSourceHosts(widget.snapshots),
      // Keep a selected source even when a refresh removes its last snapshot.
      // Otherwise the filter would silently clear and resume remote history.
      ?_sourceHost,
    }.toList()..sort();
    return AnimatedBuilder(
      animation: _search,
      builder: (context, _) => Align(
        alignment: Alignment.topCenter,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Focus(
                onKeyEvent: (_, event) {
                  if (event is KeyDownEvent &&
                      _search.draft.value.composing.isCollapsed &&
                      event.logicalKey == LogicalKeyboardKey.backspace &&
                      _search.editLastTag()) {
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: AnchorPopover(
                  triggerMode: AnchorTriggerMode.focus(focusNode: _focus),
                  spacing: 4,
                  arrowShape: const NoArrow(),
                  placement: Placement.bottom,
                  overlayBuilder: (context) => ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth:
                          AnchorData.of(context).geometry.childBounds?.width ??
                          600,
                      maxHeight: min(
                        240,
                        max(
                              0,
                              MediaQuery.heightOf(context) -
                                  MediaQuery.viewInsetsOf(context).bottom,
                            ) *
                            0.4,
                      ),
                    ),
                    child: AnimatedBuilder(
                      animation: _search,
                      builder: (context, _) => Consumer(
                        builder: (context, ref, _) {
                          // Keep replacement suggestions scoped to the other committed tags.
                          final query = _search.selectedTags.tags
                              .where((tag) => tag != _search.editingTag)
                              .join(' ');
                          final index = ref.watch(
                            cachedFeedTagIndexProvider((
                              widget.snapshots,
                              CachedTopicFeedFilter(
                                query: query,
                                sourceHost: _sourceHost,
                              ),
                            )),
                          );
                          final suggestions = index
                              .suggestions(
                                _search.draft.text,
                                limit: index.entries.length,
                                selectedTags: {
                                  for (final tag in _search.selectedTags.tags)
                                    if (tag != _search.editingTag)
                                      tag.toString(),
                                },
                              )
                              .toList();
                          return Material(
                            color: Kurumi.themeOf(context)
                                .colorScheme
                                .surfaceContainer,
                            borderRadius: BorderRadius.circular(8),
                            clipBehavior: Clip.antiAlias,
                            child: ListView.builder(
                              shrinkWrap: true,
                              primary: false,
                              padding: const EdgeInsets.all(4),
                              itemCount: suggestions.length,
                              itemBuilder: (context, i) {
                                final tag = suggestions[i];
                                return Consumer(
                                  builder: (context, ref, _) =>
                                      TagSuggestionItem(
                                        key: ValueKey(
                                          'feed-filter-suggestion-${tag.tag}',
                                        ),
                                        tag: AutocompleteData(
                                          label: tag.tag,
                                          value: tag.tag,
                                          postCount: tag.count,
                                        ),
                                        currentQuery: _search.draft.text,
                                        textColor:
                                            _tagColor(
                                              ref,
                                              tag,
                                              colorScheme.brightness,
                                            ) ??
                                            colorScheme.onSurface,
                                        showCount: true,
                                        dense: true,
                                        metatagExtractor: null,
                                        onItemTap: (_) {
                                          _search.selectSuggestion(
                                            tag.tag,
                                            knownTags: _index.byName.keys
                                                .toSet(),
                                          );
                                          _focus.unfocus();
                                        },
                                      ),
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  child: BooruSearchBar(
                    key: const ValueKey('cached-feed-filter-input'),
                    focus: _focus,
                    controller: _search.draft,
                    hintText: strings.feed_filter_hint,
                    onTapOutside: () {},
                    trailing:
                        _search.draft.text.isNotEmpty || _published.isActive
                        ? IconButton(
                            tooltip: context.t.search.remove_all_selected,
                            icon: const Icon(Symbols.clear),
                            onPressed: _clear,
                          )
                        : null,
                    onSubmitted: (_) => _submit(),
                    onEscape: () {
                      _search.cancelEdit();
                      _focus.unfocus();
                    },
                  ),
                ),
              ),
              if (_search.selectedTags.tags.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 112),
                    child: SingleChildScrollView(
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
                                    tagSearchItem: tag,
                                    tagColor: _tagColor(
                                      ref,
                                      index.byName[tag.rawTag],
                                      colorScheme.brightness,
                                    ),
                                    textScaler: MediaQuery.textScalerOf(
                                      context,
                                    ),
                                    onDeleted: () => _search.remove(tag),
                                    onTap: () {
                                      _search.edit(tag);
                                      _focus.requestFocus();
                                    },
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    BookmarkOptionSelector<String?>(
                      label: _sourceHost ?? context.t.bookmark.groups.all,
                      prefixLabel: context.t.post.detail.source_label,
                      options: [null, ...hosts],
                      value: _sourceHost,
                      optionLabel: (host) =>
                          host ?? context.t.bookmark.groups.all,
                      optionLeading: (host) => host == null
                          ? const Icon(Icons.public, size: 20)
                          : ConfigAwareWebsiteLogo(
                              url: 'https://$host',
                              width: 20,
                              height: 20,
                            ),
                      onSelected: (host) => setState(() {
                        _focus.unfocus();
                        _sourceHost = host;
                        _publish();
                      }),
                    ),
                    const SizedBox(width: 8),
                    BookmarkOptionSelector<CachedTopicFeedSort>(
                      key: const ValueKey('cached-feed-sort'),
                      label: _sort == CachedTopicFeedSort.stored
                          ? context.t.sort.short
                          : _sortLabel(_sort),
                      options: CachedTopicFeedSort.values,
                      value: _sort,
                      optionLabel: _sortLabel,
                      optionSemanticLabel: (value) =>
                          '${strings.feed_filter_hint}: ${_sortLabel(value)}',
                      onSelected: (value) => setState(() {
                        _focus.unfocus();
                        _sort = value;
                        _publish();
                      }),
                    ),
                  ],
                ),
              ),
              if (_sort != CachedTopicFeedSort.stored)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    strings.feed_filter_hint,
                    style: Kurumi.themeOf(context).textTheme.bodySmall,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
