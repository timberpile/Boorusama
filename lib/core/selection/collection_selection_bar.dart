import 'package:kurumi/material.dart';

import '../posts/listing/src/widgets/post_selection_controls.dart';
import '../widgets/multi_selection_action_bar.dart';
import 'ordered_selection_controller.dart';

/// Uses the post selection controls while Scaffold reserves the footer height.
class CollectionSelectionBar extends StatelessWidget {
  const CollectionSelectionBar({
    required this.controller,
    required this.actions,
    super.key,
  });
  final OrderedSelectionController controller;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    child: SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PostSelectionControls(
            controller: controller,
            itemCount: controller.entries.length,
          ),
          if (actions.isNotEmpty) MultiSelectionActionBar(children: actions),
        ],
      ),
    ),
  );
}
