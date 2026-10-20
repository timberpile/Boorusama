import 'package:material_symbols_icons/symbols.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';
import 'package:selection_mode/selection_mode.dart';

class PostSelectionControls extends StatelessWidget {
  const PostSelectionControls({
    required this.controller,
    required this.itemCount,
    super.key,
  });
  final SelectionModeController controller;
  final int itemCount;

  @override
  Widget build(BuildContext context) => KurumiAppBar(
    automaticallyImplyLeading: false,
    leading: IconButton(
      tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
      icon: const Icon(Icons.close),
      onPressed: controller.disable,
    ),
    title: KurumiFittedText(
      Text(context.t.select.items_selected(n: controller.selection.length)),
    ),
    actions: [
      IconButton(
        tooltip: controller.selection.length == itemCount && itemCount > 0
            ? context.t.select.deselect_all
            : context.t.select.select_all,
        icon: Icon(
          controller.selection.length == itemCount && itemCount > 0
              ? Icons.deselect
              : Symbols.select_all,
        ),
        onPressed: () {
          if (controller.selection.length == itemCount && itemCount > 0) {
            controller.deselectAll();
          } else {
            controller.selectAll(List.generate(itemCount, (i) => i));
          }
        },
      ),
    ],
  );
}
