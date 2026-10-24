// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../../../../core/tags/tag/types.dart';
import '../../../../../../core/widgets/booru_chip.dart';
import '../../../../../../foundation/platform.dart';
import '../../../../tags/tag/widgets.dart';

class TrendingTags extends ConsumerWidget {
  const TrendingTags({
    required this.onTagTap,
    required this.tags,
    required this.colorBuilder,
    super.key,
  });

  final ValueChanged<String>? onTagTap;
  final List<Tag>? tags;
  final Color? Function(BuildContext context, String name)? colorBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return tags != null && tags!.isNotEmpty
        ? Wrap(
            spacing: 6,
            runSpacing: isMobilePlatform() ? -2 : 8,
            children: tags!.map((e) {
              final color = colorBuilder?.call(context, e.category.name);

              return DanbooruTagContextMenu(
                tag: e.name,
                child: BooruChip(
                  visualDensity: VisualDensity.compact,
                  color: color,
                  onPressed: () => onTagTap?.call(e.name),
                  label: Text(
                    e.displayName,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Kurumi.themeOf(context).brightness.isDark
                          ? color
                          : null,
                    ),
                  ),
                ),
              );
            }).toList(),
          )
        : const SizedBox.shrink();
  }
}

class TrendingTagsPlaceholder extends StatelessWidget {
  const TrendingTagsPlaceholder({
    required this.tags,
    super.key,
  });

  final List<Tag> tags;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: isMobilePlatform() ? -2 : 8,
      children: tags.map((e) {
        return BooruChip(
          chipColors: KurumiChipColors(
            backgroundColor: Kurumi.themeOf(
              context,
            ).colorScheme.surfaceContainerLow,
            borderColor: Colors.transparent,
            foregroundColor: Colors.transparent,
          ),
          visualDensity: VisualDensity.compact,
          onPressed: () {},
          label: Text(
            e.name,
            style: const TextStyle(
              color: Colors.transparent,
            ),
          ),
        );
      }).toList(),
    );
  }
}
