// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:rich_text_controller/rich_text_controller.dart';

// Project imports:
import '../../../../../boorus/nhentai/search/query.dart';
import '../../../../boorus/booru/types.dart';
import '../../../../configs/config/providers.dart';
import '../../../queries/query_utils.dart';
import '../../../selected_tags/tag_search_item.dart';
import '../../../suggestions/suggestions_notifier.dart';
import '../../../suggestions/tag_suggestion_items.dart';
import '../../../syntax/providers.dart';

class SelectedTagEditDialog extends ConsumerStatefulWidget {
  const SelectedTagEditDialog({
    required this.tag,
    required this.onUpdated,
    super.key,
  });

  final TagSearchItem tag;
  final void Function(String tag)? onUpdated;

  @override
  ConsumerState<SelectedTagEditDialog> createState() =>
      _SelectedTagEditDialogState();
}

class _SelectedTagEditDialogState extends ConsumerState<SelectedTagEditDialog> {
  late final RichTextController controller;
  final showSuggestions = ValueNotifier(false);
  final focusNode = FocusNode();
  final suggestionsListbox = KurumiListboxController();

  @override
  void initState() {
    super.initState();

    final config = ref.readConfigAuth;
    final matcher = ref.read(queryMatcherProvider(config));

    controller = RichTextController(
      text: config.booruType == BooruType.nhentai
          ? widget.tag.originalTag
          : widget.tag.toString(),
      matchers: matcher != null ? [matcher] : [],
    );
  }

  @override
  void dispose() {
    controller.dispose();
    focusNode.dispose();
    suggestionsListbox.dispose();

    super.dispose();
  }

  void _submit(BuildContext context) {
    Navigator.of(context).pop();

    widget.onUpdated?.call(controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watchConfigAuth;
    final isNhentai = config.booruType == BooruType.nhentai;

    return Column(
      children: [
        Material(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: KurumiListboxKeys(
              controller: suggestionsListbox,
              child: KurumiTextField(
                focusNode: focusNode,
                autocorrect: false,
                autofocus: true,
                controller: controller,
                onSubmitted: (_) => _submit(context),
                onChanged: (value) {
                  suggestionsListbox.clear();
                  final query = isNhentai ? value : value.lastQuery;

                  if (query == null || query.isEmpty) return;

                  showSuggestions.value = true;

                  ref
                      .read(
                        suggestionsNotifierProvider(config).notifier,
                      )
                      .getSuggestions(query);
                },
                decoration: InputDecoration(
                  suffixIcon: IconButton(
                    tooltip: context.t.generic.action.ok,
                    icon: const Icon(Icons.check),
                    onPressed: () => _submit(context),
                  ),
                ),
              ),
            ),
          ),
        ),
        ValueListenableBuilder(
          valueListenable: controller,
          builder: (_, query, _) {
            final currentQuery = isNhentai ? query.text : query.text.lastQuery;

            if (currentQuery == null || currentQuery.isEmpty) {
              return const SizedBox.shrink();
            }

            final tags = ref.watch(suggestionProvider((config, currentQuery)));

            if (tags.isEmpty) return const SizedBox.shrink();

            return ValueListenableBuilder(
              valueListenable: showSuggestions,
              builder: (_, show, _) {
                if (!show) return const SizedBox.shrink();

                return Flexible(
                  child: TagSuggestionItems(
                    config: config,
                    tags: tags,
                    listbox: suggestionsListbox,
                    onItemTap: (tag) {
                      final term = isNhentai
                          ? NhentaiSearchTerm.trailing(query.text)
                          : null;
                      controller.text = term == null
                          ? query.text.replaceLastQuery(tag.value)
                          : '${term.before}${term.operator}${tag.value}';
                      showSuggestions.value = false;

                      focusNode.requestFocus();
                    },
                    currentQuery: currentQuery,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(8),
                      bottomRight: Radius.circular(8),
                    ),
                    elevation: 0,
                  ),
                );
              },
            );
          },
        ),
        const Expanded(
          child: SizedBox.shrink(),
        ),
      ],
    );
  }
}
