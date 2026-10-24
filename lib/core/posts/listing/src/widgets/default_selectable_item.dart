// Package imports:
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:selection_mode/selection_mode.dart';

// Project imports:
import '../../../../configs/config/types.dart';
import '../../../post/types.dart';
import '../routes/route_utils.dart';

class DefaultSelectableItem<T extends Post> extends StatelessWidget {
  const DefaultSelectableItem({
    required this.index,
    required this.post,
    required this.item,
    required this.config,
    super.key,
    this.indicatorSize,
  });

  final int index;
  final T post;
  final Widget item;
  final double? indicatorSize;
  final BooruConfigAuth config;

  @override
  Widget build(BuildContext context) {
    return SelectableBuilder(
      key: ValueKey(index),
      index: index,
      builder: (context, isSelected) {
        return KurumiSelectableItem(
          item: item,
          indicatorSize: indicatorSize,
          isInSelectionMode: SelectionMode.of(context).isActive,
          isSelected: isSelected,
          onPreview: () => goToImagePreviewPage(
            context,
            post,
            config,
          ),
        );
      },
    );
  }
}
