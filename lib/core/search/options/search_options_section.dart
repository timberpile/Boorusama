import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';
import 'package:kurumi/kurumi.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../cache/providers.dart';
import '../../configs/config/providers.dart';
import '../search/src/widgets/search_controller.dart';
import '../search/src/widgets/search_landing_viewport.dart';
import 'catalog/aliases.dart';
import 'search_option_choices.dart';
import 'collapsible_search_section.dart';
import 'labels.dart';
import 'providers.dart';
import 'search_modal_back_handler.dart';
import 'search_option.dart';
import 'search_option_editor.dart';

Future<void> editSearchOption(
  BuildContext context, {
  required SearchPageController controller,
  required SearchOption option,
  SearchOptionContext? initial,
}) async {
  if (option.kind == SearchOptionKind.native) {
    controller.tapRawMetaTag(option.key);
    return;
  }
  final sourceText = controller.textController.text;
  final sourceItem = controller.editingTag.value;
  final wasRaw = controller.inputIsRaw.value;
  final hadFocus = controller.focus.hasFocus;
  final query = await showSearchOptionEditor(
    context,
    option: option,
    initialValue: initial?.value,
    exclude: initial?.exclude ?? false,
  );
  if (!context.mounted) return;
  // Do not apply a sheet belonging to a replaced input/profile session.
  if (controller.textController.text != sourceText ||
      controller.editingTag.value != sourceItem ||
      controller.inputIsRaw.value != wasRaw) {
    return;
  }
  if (query != null) controller.applyOption(option.key, query);
  if (query == null && hadFocus) controller.focus.requestFocus();
}

class SearchOptionsSection extends ConsumerWidget {
  const SearchOptionsSection({
    required this.controller,
    this.pinnedKeys,
    this.onPin,
    this.onUnpin,
    this.onHelpRequest,
    super.key,
  });

  final SearchPageController controller;
  final List<String>? pinnedKeys;
  final Future<void> Function(String)? onPin;
  final Future<void> Function(String)? onUnpin;
  final VoidCallback? onHelpRequest;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watchConfigAuth;
    final capabilities = ref.watch(searchCapabilitiesProvider(config));
    final catalog = ref.watch(searchOptionCatalogProvider(config));
    if (catalog.isEmpty) return const SizedBox.shrink();
    final storageKey = 'search_options.pins.${ref.watchConfig.id}';
    final saved = ref.watch(miscDataProvider(storageKey));
    final defaults = catalog
        .where((option) => option.kind != SearchOptionKind.native)
        .map((option) => option.key)
        .toList();
    final aliases = searchOptionAliasesFor(config.booruType);
    final storedKeys = pinnedKeys ?? _readPins(saved) ?? defaults;
    final keys = [
      ...{
        for (final key in storedKeys) aliases[key] ?? key,
      },
    ];
    final options = [
      for (final key in keys.toSet()) ?capabilities.byKey(key),
      ...catalog.where((option) => !keys.contains(option.key)),
    ];

    Future<void> showCatalog() async {
      final localPins = keys.toSet();
      var busy = false;
      final selected = await showModalBottomSheet<SearchOption>(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        useSafeArea: true,
        constraints: const BoxConstraints(maxWidth: 640),
        builder: (sheetContext) => SearchModalBackHandler(
          child: StatefulBuilder(
            builder: (sheetContext, setState) => SafeArea(
              top: false,
              child: SizedBox(
                height: MediaQuery.sizeOf(sheetContext).height * 0.75,
                child: Column(
                  children: [
                    ListTile(
                      title: Text(context.t.search_options.all_options),
                      trailing: IconButton(
                        tooltip: context.t.search_options.cancel,
                        icon: const Icon(Symbols.close),
                        onPressed: () => Navigator.of(sheetContext).pop(),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: catalog.length,
                        itemBuilder: (context, index) {
                          final option = catalog[index];
                          final pinned = localPins.contains(option.key);
                          return ListTile(
                            title: Wrap(
                              spacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(searchOptionTitle(context, option)),
                                if (option.isFree)
                                  const SearchOptionFreeBadge(),
                              ],
                            ),
                            subtitle: Text(option.key),
                            onTap: () => Navigator.of(sheetContext).pop(option),
                            trailing: IconButton(
                              tooltip: pinned
                                  ? context.t.search_options.unpin
                                  : context.t.search_options.pin,
                              icon: Icon(
                                pinned ? Symbols.push_pin : Symbols.add,
                              ),
                              onPressed: busy
                                  ? null
                                  : () async {
                                      setState(() => busy = true);
                                      final next = {...localPins};
                                      if (pinned) {
                                        next.remove(option.key);
                                      } else {
                                        next.add(option.key);
                                      }
                                      try {
                                        if (pinned && onUnpin != null) {
                                          for (final key in {
                                            option.key,
                                            for (final key in storedKeys)
                                              if (aliases[key] == option.key)
                                                key,
                                          }) {
                                            await onUnpin!(key);
                                          }
                                        } else if (!pinned && onPin != null) {
                                          await onPin!(option.key);
                                        } else {
                                          await Future.sync(
                                            () => ref
                                                .read(
                                                  miscDataProvider(storageKey)
                                                      .notifier,
                                                )
                                                .put(jsonEncode(next.toList())),
                                          );
                                        }
                                        if (!sheetContext.mounted) return;
                                        setState(() {
                                          localPins
                                            ..clear()
                                            ..addAll(next);
                                        });
                                      } catch (_) {
                                        if (sheetContext.mounted) {
                                          ScaffoldMessenger.maybeOf(
                                            sheetContext,
                                          )?.showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                context
                                                    .t
                                                    .search_options
                                                    .save_failed,
                                              ),
                                            ),
                                          );
                                        }
                                      } finally {
                                        if (sheetContext.mounted) {
                                          setState(() => busy = false);
                                        }
                                      }
                                    },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      if (!context.mounted || selected == null) return;
      await editSearchOption(context, controller: controller, option: selected);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: CollapsibleSearchSection(
        title: context.t.search_options.title,
        storageId: 'search-options.${config.booruType.name}.${config.url}',
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: context.t.search_options.all_options,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Symbols.tune),
              onPressed: showCatalog,
            ),
            if (onHelpRequest != null)
              IconButton(
                icon: const Icon(Symbols.help_outline),
                onPressed: onHelpRequest,
              ),
          ],
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: SearchLandingViewport.heightOf(context) / 2,
          ),
          child: FocusTraversalGroup(
            policy: WidgetOrderTraversalPolicy(),
            child: ListView.separated(
              key: PageStorageKey('search-option-list.${config.url}'),
              primary: false,
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: 4),
              itemCount: options.length,
              separatorBuilder: (_, _) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final option = options[index];
                final colors = Kurumi.themeOf(context).colorScheme;
                return Material(
                  key: ValueKey('search-option.${option.key}'),
                  color: colors.surfaceContainerLow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: colors.outlineVariant),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      InkWell(
                        onTap: () => editSearchOption(
                          context,
                          controller: controller,
                          option: option,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: LayoutBuilder(
                            builder: (context, constraints) => Row(
                              children: [
                                ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth: constraints.maxWidth * 0.4,
                                  ),
                                  child: Text(
                                    searchOptionTitle(context, option),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Kurumi.themeOf(context)
                                        .textTheme
                                        .labelLarge,
                                  ),
                                ),
                                if (option.isFree) ...[
                                  const SizedBox(width: 6),
                                  const SearchOptionFreeBadge(),
                                ],
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Tooltip(
                                    message: searchOptionDescription(
                                      context,
                                      option,
                                    ),
                                    child: Text(
                                      searchOptionDescription(context, option),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: Kurumi.themeOf(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: colors.onSurfaceVariant,
                                          ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Symbols.chevron_right, size: 20),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (option.choices.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
                          child: SearchOptionChoices(
                            children: [
                              for (final choice in option.choices)
                                ActionChip(
                                  label: Text(
                                    searchOptionChoiceLabel(context, choice),
                                  ),
                                  onPressed: () {
                                    final query = option.compose(choice.value);
                                    if (query != null) {
                                      controller.applyOption(option.key, query);
                                    }
                                  },
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

List<String>? _readPins(String value) {
  if (value.isEmpty) return null;
  try {
    final decoded = jsonDecode(value);
    return decoded is List && decoded.every((entry) => entry is String)
        ? decoded.cast<String>()
        : null;
  } on FormatException {
    return null;
  }
}
