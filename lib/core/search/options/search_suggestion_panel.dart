import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../boorus/engine/providers.dart';
import '../../configs/config/types.dart';
import '../../tags/autocompletes/types.dart';
import '../search/src/widgets/search_controller.dart';
import '../suggestions/providers.dart';
import '../suggestions/selected_tag_suggestions.dart';
import '../suggestions/tag_suggestion_item.dart';
import 'labels.dart';
import 'catalog/aliases.dart';
import 'providers.dart';
import 'search_option.dart';
import 'search_option_editor.dart';
import 'search_option_matching.dart';
import 'search_options_section.dart';

class SearchSuggestionPanel extends ConsumerWidget {
  const SearchSuggestionPanel({
    required this.config,
    required this.controller,
    this.reverse = false,
    super.key,
  });

  final BooruConfigAuth config;
  final SearchPageController controller;
  final bool reverse;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListenableBuilder(
    listenable: Listenable.merge([
      controller.textController,
      controller.inputIsRaw,
      controller.tagsController,
    ]),
    builder: (context, _) {
      final query = controller.textController.text;
      final capabilities = ref.watch(searchCapabilitiesProvider(config));
      final current = capabilities.contextFor(query);
      final rows = <({Widget child, VoidCallback pick, bool isOption})>[];

      void addRow({
        required String label,
        String? syntax,
        Widget? leading,
        Widget? trailing,
        required VoidCallback pick,
      }) {
        rows.add((
          pick: pick,
          isOption: true,
          child: InkWell(
            onTap: pick,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 40),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                child: Row(
                  children: [
                    if (leading != null) ...[
                      leading,
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (trailing != null) ...[
                      const SizedBox(width: 8),
                      trailing,
                    ],
                    if (syntax != null) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          syntax,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Kurumi.themeOf(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ));
      }

      if (current != null &&
          current.option.kind != SearchOptionKind.native &&
          (!current.exclude || current.option.supportsExclusion)) {
        final option = current.option;
        for (final choice in option.choices) {
          if (current.value.isNotEmpty &&
              !choice.value.startsWith(current.value)) {
            continue;
          }
          final expression = option.compose(
            choice.value,
            exclude: current.exclude,
          );
          if (expression == null) continue;
          addRow(
            label: searchOptionChoiceLabel(context, choice),
            syntax: expression,
            pick: () {
              controller.applyOption(option.key, expression);
            },
          );
        }
        if (option.input == SearchOptionInput.text) {
          final suggestions = ref.watch(suggestionProvider((config, query)));
          for (final suggestion in suggestions.where(
            (tag) => tag.type == AutocompleteData.user,
          )) {
            final value = suggestion.value.startsWith('${option.key}:')
                ? suggestion.value.substring(option.key.length + 1)
                : suggestion.value;
            final expression = option.compose(value);
            if (expression == null) continue;
            addRow(
              label: suggestion.label,
              pick: () {
                controller.applyOption(option.key, expression);
              },
            );
          }
        }
        addRow(
          label: context.t.search_options.choose_visually,
          leading: const Icon(Symbols.tune, size: 18),
          pick: () => editSearchOption(
            context,
            controller: controller,
            option: option,
            initial: current,
          ),
        );
      } else {
        final clean = query.trim().replaceFirst(RegExp('^-'), '').toLowerCase();
        if (clean.isNotEmpty && !clean.contains(':')) {
          final exclude = query.trim().startsWith('-');
          final matches = matchSearchOptions(
            options: ref
                .watch(searchOptionCatalogProvider(config))
                .where(
                  (option) => !exclude || option.supportsExclusion,
                ),
            query: clean,
            title: (option) => searchOptionTitle(context, option),
            aliases: searchOptionAliasesFor(config.booruType),
          );
          for (final option in matches.take(3)) {
            addRow(
              label: searchOptionTitle(context, option),
              syntax: '${option.key}:',
              leading: option.isFree ? const SearchOptionFreeBadge() : null,
              pick: () {
                final prefix = exclude ? '-' : '';
                controller.updateQuery('$prefix${option.key}:');
                controller.focus.requestFocus();
              },
            );
          }
        }
        final tags = withoutSelectedTagSuggestions(
          suggestions: ref.watch(suggestionProvider((config, query))),
          selectedTags: controller.tagsController.tags,
          extractor: controller.metatagExtractor,
          optionKeys: controller.optionKeys,
        );
        final builder = ref
            .watch(booruBuilderProvider(config))
            ?.tagSuggestionItemBuilder;
        for (final tag in tags) {
          void pick() {
            controller.tapTag(tag.value, category: tag.category);
          }

          rows.add((
            pick: pick,
            isOption: false,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 40),
              child:
                  builder?.call(config, tag, true, query, (_) => pick()) ??
                  DefaultTagSuggestionItem(
                    config: config,
                    tag: tag,
                    onItemTap: (_) => pick(),
                    currentQuery: query,
                    dense: true,
                  ),
            ),
          ));
        }
      }

      if (query.trim().isNotEmpty) {
        addRow(
          label: query,
          trailing: Semantics(
            label: context.t.search.raw_query,
            child: ExcludeSemantics(
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  shape: StadiumBorder(
                    side: BorderSide(
                      color: Kurumi.themeOf(context).colorScheme.outlineVariant,
                    ),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  child: Text(
                    context.t.favorite_tags.raw_badge,
                    style: Kurumi.themeOf(context).textTheme.labelSmall,
                  ),
                ),
              ),
            ),
          ),
          pick: controller.submitRaw,
        );
      }
      if (rows.isEmpty) return const SizedBox.shrink();
      final listbox = controller.suggestionsListbox;
      return KurumiListbox(
        controller: listbox,
        count: rows.length,
        reversed: reverse,
        onPick: (index) {
          if (controller.textController.value.composing.isCollapsed) {
            rows[index].pick();
          }
        },
        child: ListView.builder(
          reverse: reverse,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: rows.length,
          itemBuilder: (context, index) => ListenableBuilder(
            listenable: listbox,
            builder: (context, child) {
              final item = KurumiListboxItem(
                active: listbox.active == index,
                child: child!,
              );
              if (!rows[index].isOption) return item;
              final colors = Kurumi.themeOf(context).colorScheme;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Material(
                  color: colors.surfaceContainerLow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: colors.outlineVariant),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: item,
                ),
              );
            },
            child: rows[index].child,
          ),
        ),
      );
    },
  );
}
