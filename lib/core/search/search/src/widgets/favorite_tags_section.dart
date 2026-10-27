// Package imports:
import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

// Project imports:
import '../../../../../foundation/platform.dart';
import '../../../../cache/providers.dart';
import '../../../../router.dart';
import '../../../../tags/favorites/types.dart';
import '../../../../tags/favorites/widgets.dart';
import '../../../../themes/colors/providers.dart';
import '../../../options/collapsible_search_section.dart';
import '../../../selected_tags/types.dart';
import 'constants.dart';

class FavoriteTagsSection extends ConsumerWidget {
  const FavoriteTagsSection({
    required this.selectedLabel,
    required this.onTagTap,
    super.key,
  });

  final String selectedLabel;
  final ValueChanged<FavoriteTag>? onTagTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.watch(
      miscDataProvider(kSearchSelectedFavoriteTagLabelKey).notifier,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: FavoriteTagsFilterScope(
        initialValue: selectedLabel,
        sortType: FavoriteTagsSortType.nameAZ,
        builder: (_, tags, labels, selected) => OptionTagsArenaNoEdit(
          title: context.t.favorite_tags.favorites,
          titleTrailing: FavoriteTagLabelSelectorField(
            selected: selected,
            labels: labels,
            onSelect: (value) => notifier.put(value),
          ),
          children: _buildFavoriteTags(ref, tags),
        ),
      ),
    );
  }

  List<Widget> _buildFavoriteTags(
    WidgetRef ref,
    List<FavoriteTag> tags,
  ) {
    return [
      ...tags.mapIndexed((index, tag) {
        final colors = ref
            .watch(booruChipColorsProvider)
            .fromColor(
              Kurumi.themeOf(ref.context).colorScheme.onSurface,
            );

        return KurumiMaterialRawChip(
          visualDensity: VisualDensity.compact,
          onPressed: () => onTagTap?.call(tag),
          avatar: tag.queryType == QueryType.simple
              ? Icon(
                  Symbols.code,
                  size: 16,
                  color: colors?.foregroundColor,
                )
              : null,
          label: Text(
            tag.name,
            style: TextStyle(
              color: colors?.foregroundColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: colors?.backgroundColor,
          side: colors != null
              ? BorderSide(
                  color: colors.borderColor,
                )
              : null,
          deleteIcon: Icon(
            Symbols.close,
            size: 18,
            color: colors?.foregroundColor,
          ),
        );
      }),
    ];
  }
}

class OptionTagsArenaNoEdit extends ConsumerWidget {
  const OptionTagsArenaNoEdit({
    required this.title,
    required this.children,
    super.key,
    this.titleTrailing,
  });

  final String title;
  final Widget? titleTrailing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context, WidgetRef ref) => CollapsibleSearchSection(
    title: title,
    storageId: 'search-favorites',
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: context.t.favorite_tags.title,
          icon: const Icon(Symbols.settings, size: 20),
          onPressed: () => ref.pushRoute('/favorite_tags'),
        ),
        if (titleTrailing != null) Flexible(child: titleTrailing!),
      ],
    ),
    child: Wrap(
      spacing: 4,
      runSpacing: ref.watch(appPlatformProvider).isDesktop ? 4 : 0,
      children: children,
    ),
  );
}

class ImportTagButton extends StatelessWidget {
  const ImportTagButton({super.key});

  @override
  Widget build(BuildContext context) => FilledButton(
    style: FilledButton.styleFrom(shape: const StadiumBorder()),
    onPressed: () => goToFavoriteTagImportPage(context),
    child: Text(context.t.settings.backup_and_restore.import),
  );
}
