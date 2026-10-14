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
  });

  final List<SettingEntry> entries;
  final ValueChanged<SettingEntry> onSelected;
  final String? selectedId;
  final Widget? header;
  final Widget? footer;
  final ScrollController? scrollController;

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

  @override
  State<SettingsSearchPane> createState() => _SettingsSearchPaneState();
}

class _SettingsSearchPaneState extends State<SettingsSearchPane> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  final _fallbackScrollController = ScrollController();
  String _query = '';

  ScrollController get _scrollController =>
      widget.scrollController ?? _fallbackScrollController;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onQueryChanged);
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
            child: CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.escape): () {
                  if (_controller.text.isNotEmpty) {
                    _clear();
                  } else {
                    _focus.unfocus();
                  }
                },
              },
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
          ),
        Expanded(
          child: SingleChildScrollView(
            controller: _scrollController,
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
                      if (widget.header case final header?) header,
                      for (final entry in widget.entries)
                        tile(entry, id: entry.id, title: entry.title),
                      if (widget.footer case final footer?) footer,
                    ],
            ),
          ),
        ),
      ],
    );
  }
}
