// Package imports:
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

// Project imports:
import '../../../../../foundation/utils/flutter_utils.dart';
import '../../../../tags/tag/colors.dart';
import '../../../queries/types.dart';
import '../../../selected_tags/types.dart';
import '../pages/selected_tag_edit_dialog.dart';

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
    final hasOperator = tagSearchItem.operator != FilterOperator.none;
    final hasMeta = tagSearchItem.metatag != null;
    final isRaw = tagSearchItem.isRaw;

    final colorScheme = Kurumi.themeOf(context).colorScheme;
    final tagColors = TagColors.fromBrightness(colorScheme.brightness);

    return GestureDetector(
      onTap:
          onTap ??
          () {
            showDialog(
              context: context,
              routeSettings: const RouteSettings(name: 'selected_tag_edit'),
              builder: (c) {
                return SelectedTagEditDialog(
                  tag: tagSearchItem,
                  onUpdated: (tag) {
                    if (tag.isNotEmpty) {
                      onUpdated?.call(tag);
                    } else {
                      onDeleted?.call();
                    }
                  },
                );
              },
            );
          },
      child: KurumiMaterialChip(
        visualDensity: const ShrinkVisualDensity(),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        backgroundColor: colorScheme.secondaryContainer,
        deleteIcon: Icon(
          Symbols.close,
          color: colorScheme.error,
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
              fontWeight: FontWeight.w500,
            ),
            children: [
              if (isRaw) ...[
                TextSpan(
                  text: 'RAW   ',
                  style: TextStyle(
                    color: tagColors.character,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                    fontSize: 13,
                  ),
                ),
              ] else if (hasOperator)
                TextSpan(
                  text: switch (tagSearchItem.operator) {
                    FilterOperator.none => '',
                    FilterOperator.not => '—',
                    FilterOperator.or => '⁓',
                  },
                  style: TextStyle(
                    color: tagColors.copyright,
                  ),
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
                  color: tagColor ?? colorScheme.onSecondaryContainer,
                ),
              ),
              const TextSpan(
                text: ' ',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
