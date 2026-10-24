// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../../../../core/configs/config/providers.dart';
import '../../../../../../core/search/options/collapsible_search_section.dart';
import '../../../../../../core/tags/tag/providers.dart';
import '../local_providers.dart';
import 'trending_tags.dart';

class TrendingSection extends ConsumerWidget {
  const TrendingSection({required this.onTagTap, super.key});

  final ValueChanged<String>? onTagTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watchConfigFilter;
    final tags = ref.watch(top15TrendingTagsProvider(config));
    if (tags.hasError && !tags.hasValue) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: CollapsibleSearchSection(
        title: context.t.search.trending,
        storageId: 'search-trending',
        child: tags.when(
          data: (tags) => TrendingTags(
            onTagTap: onTagTap,
            colorBuilder: (context, name) =>
                ref.watch(tagColorProvider((config.auth, name))),
            tags: tags,
          ),
          error: (error, stackTrace) => const SizedBox.shrink(),
          loading: () => TrendingTagsPlaceholder(
            tags: ref.watch(top15PlaceholderTagsProvider),
          ),
        ),
      ),
    );
  }
}
