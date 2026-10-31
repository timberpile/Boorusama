// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../../../../core/tags/tag/widgets.dart';
import '../../../../../../core/configs/config/providers.dart';
import '../../../../../../core/search/selected_tags/providers.dart';
import '../../../../../../core/search/suggestions/providers.dart';
import '../../../../../../core/search/suggestions/selected_tag_suggestions.dart';
import '../../../../../../core/tags/autocompletes/types.dart';
import '../../../../../../core/tags/metatag/types.dart';
import '../../../../tags/related/providers.dart';
import '../../../../tags/related/types.dart';
import '../../../../tags/related/widgets.dart';

class RelatedTagSection extends ConsumerWidget {
  const RelatedTagSection({
    required this.query,
    required this.selectedTags,
    this.extractor,
    required this.onAdded,
    required this.onNegated,
    super.key,
    this.backgroundColor,
  });

  final String query;
  final SelectedTagController selectedTags;
  final MetatagExtractor? extractor;
  final void Function(DanbooruRelatedTagItem tag) onAdded;
  final void Function(DanbooruRelatedTagItem tag) onNegated;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (query.isEmpty) return const SizedBox();

    final aliases = ref
        .watch(suggestionsNotifierProvider(ref.watchConfigAuth))
        .suggestions
        .values
        .expand((rows) => rows)
        .toList(growable: false);
    final related = ref.watch(danbooruRelatedTagProvider(query));
    return ValueListenableBuilder(
      valueListenable: selectedTags,
      builder: (context, selected, _) => related.when(
        data: (tag) {
          final visible = withoutSelectedTagSuggestions(
            suggestions: tag.tags.map(
              (item) => AutocompleteData(label: item.tag, value: item.tag),
            ),
            selectedTags: selected,
            extractor: extractor,
            knownAliases: aliases,
          ).map((suggestion) => suggestion.value).toSet();
          final filtered = tag.copyWith(
            tags: tag.tags.where((item) => visible.contains(item.tag)).toList(),
          );
          return filtered.tags.isNotEmpty
              ? RelatedTagHeader(
                  backgroundColor: backgroundColor,
                  relatedTag: filtered,
                  onAdded: onAdded,
                  onNegated: onNegated,
                )
              : const SizedBox.shrink();
        },
        loading: () =>
            TagChipsPlaceholder(backgroundColor: backgroundColor, height: 44),
        error: (e, s) => const SizedBox.shrink(),
      ),
    );
  }
}
