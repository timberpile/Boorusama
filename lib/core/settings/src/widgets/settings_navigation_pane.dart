import 'package:flutter/services.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

import '../../../../foundation/platform.dart';
import '../search/settings_search.dart';
import '../search/settings_search_catalog.dart';
import 'settings_page_scaffold.dart';

/// Shared navigation for the mobile settings list and the desktop sidebar.
class SettingsNavigationPane extends StatelessWidget {
  const SettingsNavigationPane({
    required this.entries,
    required this.onSelected,
    super.key,
    this.selectedId,
    this.header,
    this.footer,
    this.scrollController,
    this.storageKey,
  });

  final List<SettingEntry> entries;
  final ValueChanged<SettingEntry> onSelected;
  final String? selectedId;
  final Widget? header;
  final Widget? footer;
  final ScrollController? scrollController;
  final PageStorageKey<String>? storageKey;

  @override
  Widget build(BuildContext context) {
    return SettingsSearchPane(
      showSearch: SettingsPageDynamicScope.of(context).options.showSearch,
      entries: entries,
      items: buildSettingsSearchCatalog(
        context.t,
        sections: {for (final entry in entries) entry.id: entry.title},
        isMobile: isAndroid() || isIOS(),
      ),
      labels: (
        hint: context.t.search.hint,
        clear: context.t.generic.action.clear,
        empty: context.t.generic.errors.no_data,
      ),
      onSelected: onSelected,
      selectedId: selectedId,
      header: header,
      footer: footer,
      scrollController: scrollController,
      storageKey: storageKey,
    );
  }
}

class SettingsSearchPane extends StatefulWidget {
  const SettingsSearchPane({
    required this.showSearch,
    required this.entries,
    required this.items,
    required this.labels,
    required this.onSelected,
    super.key,
    this.selectedId,
    this.header,
    this.footer,
    this.scrollController,
    this.storageKey,
  });

  final bool showSearch;
  final List<SettingEntry> entries;
  final List<SettingsSearchItem> items;
  final ({String hint, String clear, String empty}) labels;
  final ValueChanged<SettingEntry> onSelected;
  final String? selectedId;
  final Widget? header;
  final Widget? footer;
  final ScrollController? scrollController;
  final PageStorageKey<String>? storageKey;

  @override
  State<SettingsSearchPane> createState() => _SettingsSearchPaneState();
}

class _SettingsSearchPaneState extends State<SettingsSearchPane> {
  final _controller = TextEditingController();
  late final FocusNode _focus;
  final _fallbackScrollController = ScrollController();
  var _query = '';

  ScrollController get _scrollController =>
      widget.scrollController ?? _fallbackScrollController;

  @override
  void initState() {
    super.initState();
    _focus = FocusNode(onKeyEvent: _onSearchKeyEvent);
    _controller.addListener(_onQueryChanged);
  }

  KeyEventResult _onSearchKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.escape) {
      return KeyEventResult.ignored;
    }
    if (_controller.text.isNotEmpty) {
      _clear();
    } else {
      node.unfocus();
    }
    return KeyEventResult.handled;
  }

  void _onQueryChanged() {
    if (_query == _controller.text) return;
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    setState(() => _query = _controller.text);
  }

  void _clear() {
    _controller.clear();
    _focus.requestFocus();
  }

  void _select(SettingEntry entry) {
    _focus.unfocus();
    widget.onSelected(entry);
  }

  @override
  void didUpdateWidget(covariant SettingsSearchPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.showSearch && !widget.showSearch) {
      _focus.unfocus();
      _controller.clear();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onQueryChanged);
    _controller.dispose();
    _focus.dispose();
    _fallbackScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final options = SettingsPageScope.of(context).options;
    final entries = {for (final entry in widget.entries) entry.id: entry};
    final searching = widget.showSearch && _query.trim().isNotEmpty;
    final results = searchSettings(
      widget.items.where((item) => entries.containsKey(item.sectionId)),
      _query,
    );

    Widget tile(
      SettingEntry entry, {
      required String id,
      required String title,
      String? subtitle,
    }) => KurumiSettingsEntryTile(
      key: ValueKey('settings-navigation-$id'),
      title: title,
      subtitle: subtitle,
      leading: SettingEntryIcon(icon: entry.icon),
      showLeading: options.showIcon,
      dense: options.dense,
      selected: !searching && entry.id == widget.selectedId,
      onTap: () => _select(entry),
    );

    return Column(
      children: [
        if (widget.showSearch)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: KurumiSearchBar(
              controller: _controller,
              focus: _focus,
              autofocus: true,
              hintText: widget.labels.hint,
              leading: const Icon(Icons.search),
              trailing: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: widget.labels.clear,
                      onPressed: _clear,
                      icon: const Icon(Icons.clear),
                    ),
              onSubmitted: (_) {
                if (results.isNotEmpty) {
                  _select(entries[results.first.sectionId]!);
                }
              },
            ),
          ),
        Expanded(
          child: SingleChildScrollView(
            key: widget.storageKey,
            controller: _scrollController,
            // Unlike ListView, this scroll view does not consume media padding.
            padding: EdgeInsets.only(
              bottom: MediaQuery.paddingOf(context).bottom,
            ),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: searching
                  ? [
                      if (results.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            widget.labels.empty,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      for (final item in results)
                        tile(
                          entries[item.sectionId]!,
                          id: item.id,
                          title: item.title,
                          subtitle: item.title == item.sectionTitle
                              ? null
                              : item.sectionTitle,
                        ),
                    ]
                  : [
                      ?widget.header,
                      for (final entry in widget.entries)
                        tile(entry, id: entry.id, title: entry.title),
                      ?widget.footer,
                    ],
            ),
          ),
        ),
      ],
    );
  }
}
