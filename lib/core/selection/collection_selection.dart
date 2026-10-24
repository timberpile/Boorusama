import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:selection_mode/selection_mode.dart';

import '../settings/providers.dart';
import 'ordered_selection_controller.dart';
import 'selection_input.dart';

enum CollectionSelectionKind { folder, group, topic }

typedef CollectionSelectionKey = (CollectionSelectionKind, String);

class CollectionSelection extends ConsumerWidget {
  const CollectionSelection({
    required this.controller,
    required this.scrollController,
    required this.child,
    super.key,
  });
  final OrderedSelectionController<CollectionSelectionKey> controller;
  final ScrollController scrollController;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) => SelectionMode(
    controller: controller,
    scrollController: scrollController,
    options: ref.watch(selectionOptionsProvider),
    child: SelectionInput(
      controller: controller,
      itemCount: controller.entries.length,
      child: KurumiContextMenuPolicy(
        touchLongPress: !controller.isActive,
        child: child,
      ),
    ),
  );
}

class CollectionSelectable extends StatelessWidget {
  const CollectionSelectable({
    required this.controller,
    required this.itemKey,
    required this.child,
    super.key,
  });
  final OrderedSelectionController<CollectionSelectionKey> controller;
  final CollectionSelectionKey itemKey;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final index = controller.indexOf(itemKey);
    if (index == null) return child;
    return SelectableBuilder(
      key: ValueKey(index),
      index: index,
      builder: (_, _) => child,
    );
  }
}
