// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../../search/queries/providers.dart';
import '../../../config/data.dart';
import '../../../config/types.dart';
import '../../../create/providers.dart';
import 'tag_list_preview.dart';
import 'tag_search_config_chip.dart';

class EffectiveTagPreview extends ConsumerWidget {
  const EffectiveTagPreview({
    required this.configData,
    super.key,
  });

  final BooruConfigData configData;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Kurumi.themeOf(context).colorScheme;

    final tags = ref.watch(
      editBooruConfigProvider(
        ref.watch(editBooruConfigIdProvider),
      ).select((value) => value.alwaysIncludeTags),
    );

    final effectiveConfigData = configData.copyWith(
      alwaysIncludeTags: () => tags,
    );

    final config = effectiveConfigData.toBooruConfig(id: '');

    if (config == null) return const SizedBox.shrink();

    final tagComposer = ref.watch(tagQueryComposerProvider(config.search));

    final rawTags = tagComposer.compose([]);

    return TagListPreview(
      header: Text(
        context.t.booru.search.preview_tags,
        style: Kurumi.themeOf(context).textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      content: Wrap(
        runAlignment: WrapAlignment.center,
        spacing: 5,
        runSpacing: 5,
        children: [
          IgnorePointer(
            child: KurumiRawCompactChip(
              backgroundColor: Colors.transparent,
              label: Text(
                context.t.booru.search.any_search_query,
                style: TextStyle(
                  color: Kurumi.themeOf(
                    context,
                  ).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ),
          ...rawTags.map(
            (e) => TagSearchConfigChip(tag: e),
          ),
        ],
      ),
    );
  }
}
