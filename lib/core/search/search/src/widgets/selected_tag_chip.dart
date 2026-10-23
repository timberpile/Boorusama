// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

// Project imports:
import '../../../../../foundation/utils/flutter_utils.dart';
import '../../../../configs/config/types.dart';
import '../../../../tags/categories/providers.dart';
import '../../../../tags/tag/colors.dart';
import '../../../../tags/tag/providers.dart';
import '../../../../themes/colors/providers.dart';
import '../../../queries/types.dart';
import '../../../selected_tags/types.dart';
import '../pages/selected_tag_edit_dialog.dart';
import 'search_controller.dart';

class SelectedTagChip extends StatelessWidget {
  const SelectedTagChip({
    required this.tagSearchItem,
    super.key,
    this.onDeleted,
    this.onUpdated,
    this.onTap,
    this.tagColor,
    this.textScaler,
  });

  final TagSearchItem tagSearchItem;
  final VoidCallback? onDeleted;
  final void Function(String tag)? onUpdated;
  final VoidCallback? onTap;
  final Color? tagColor;
  final TextScaler? textScaler;

  @override
  Widget build(BuildContext context) {
    if (tagColor == null) return _buildChip(context, null);
    return Consumer(
      builder: (context, ref, _) => _buildChip(
        context,
        ref.watch(booruChipColorsProvider).fromColor(tagColor),
      ),
    );
  }

  Widget _buildChip(BuildContext context, KurumiChipColors? colors) {
    final hasOperator = tagSearchItem.operator != FilterOperator.none;
    final hasMeta = tagSearchItem.metatag != null;
    final isRaw = tagSearchItem.isRaw;
    final colorScheme = Kurumi.themeOf(context).colorScheme;
    final tagColors = TagColors.fromBrightness(colorScheme.brightness);

    return GestureDetector(
      onTap:
          onTap ??
          () {
            final search = InheritedSearchPageController.maybeOf(context);
            if (search != null) {
              search.editTag(tagSearchItem);
              return;
            }
            // Other consumers keep their explicit-confirmation editor semantics.
            showDialog(
              context: context,
              routeSettings: const RouteSettings(name: 'selected_tag_edit'),
              builder: (c) => SelectedTagEditDialog(
                tag: tagSearchItem,
                onUpdated: (tag) {
                  if (tag.isNotEmpty) {
                    onUpdated?.call(tag);
                  } else {
                    onDeleted?.call();
                  }
                },
              ),
            );
          },
      child: KurumiMaterialChip(
        visualDensity: const ShrinkVisualDensity(),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        backgroundColor:
            colors?.backgroundColor ?? colorScheme.surfaceContainerHighest,
        side: BorderSide(
          color: colors?.borderColor ?? colorScheme.outlineVariant,
        ),
        deleteIcon: Icon(
          Symbols.close,
          color: colors?.foregroundColor ?? colorScheme.error,
          size: 18,
          weight: 600,
        ),
        onDeleted: () => onDeleted?.call(),
        labelPadding: const EdgeInsets.symmetric(horizontal: 2),
        label: RichText(
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textScaler: textScaler ?? TextScaler.noScaling,
          text: TextSpan(
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
            children: [
              if (isRaw)
                TextSpan(
                  text: 'RAW   ',
                  style: TextStyle(
                    color: tagColors.character,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                    fontSize: 13,
                  ),
                )
              else if (hasOperator)
                TextSpan(
                  text: switch (tagSearchItem.operator) {
                    FilterOperator.none => '',
                    FilterOperator.not => '—',
                    FilterOperator.or => '⁓',
                  },
                  style: TextStyle(color: tagColors.copyright),
                ),
              if (hasMeta)
                TextSpan(
                  text: '${tagSearchItem.metatag}: ',
                  style: TextStyle(
                    color: tagColors.meta,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    fontSize: 15,
                  ),
                ),
              TextSpan(
                text: isRaw
                    ? tagSearchItem.tag
                    : tagSearchItem.tag.replaceAll('_', ' '),
                style: TextStyle(
                  color:
                      colors?.foregroundColor ?? colorScheme.onSurfaceVariant,
                ),
              ),
              const TextSpan(text: ' '),
            ],
          ),
        ),
      ),
    );
  }
}

/// Uses supplied metadata or the local category cache for this exact profile.
/// Raw syntax and metatag values are not ordinary tags and remain neutral.
class CategoryAwareSelectedTagChip extends ConsumerWidget {
  const CategoryAwareSelectedTagChip({
    required this.auth,
    required this.tagSearchItem,
    this.onDeleted,
    this.onUpdated,
    this.onTap,
    this.textScaler,
    super.key,
  });

  final BooruConfigAuth auth;
  final TagSearchItem tagSearchItem;
  final VoidCallback? onDeleted;
  final void Function(String tag)? onUpdated;
  final VoidCallback? onTap;
  final TextScaler? textScaler;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordinary = !tagSearchItem.isRaw && tagSearchItem.metatag == null;
    final category = !ordinary
        ? null
        : tagSearchItem.category ??
              ref
                  .watch(booruTagTypeProvider((auth, tagSearchItem.rawTag)))
                  .valueOrNull;
    final color = category == null
        ? null
        : ref.watch(tagColorProvider((auth, category)));
    return SelectedTagChip(
      tagSearchItem: tagSearchItem,
      tagColor: color,
      textScaler: textScaler,
      onDeleted: onDeleted,
      onUpdated: onUpdated,
      onTap: onTap,
    );
  }
}
