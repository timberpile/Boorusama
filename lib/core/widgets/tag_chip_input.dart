// Package imports:
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

// Project imports:
import '../../foundation/platform.dart';

class TagChipInput extends StatelessWidget {
  const TagChipInput({
    required this.values,
    required this.onAdd,
    required this.onRemove,
    super.key,
    this.margin = const EdgeInsets.symmetric(horizontal: 12),
    this.displayValue,
  });

  final Iterable<String> values;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;
  final EdgeInsetsGeometry margin;
  final String Function(String value)? displayValue;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Kurumi.themeOf(context).colorScheme;

    return Container(
      margin: margin,
      child: Wrap(
        runAlignment: WrapAlignment.center,
        spacing: 5,
        runSpacing: isMobilePlatform() ? -4 : 8,
        children: [
          for (final value in values)
            KurumiMaterialChip(
              backgroundColor: colorScheme.surfaceContainerHighest,
              label: Text(
                displayValue?.call(value) ?? value.replaceAll('_', ' '),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              deleteIcon: Icon(
                Symbols.close,
                size: 16,
                color: colorScheme.error,
              ),
              onDeleted: () => onRemove(value),
            ),
          Semantics(
            label: context.t.generic.action.add,
            button: true,
            onTap: onAdd,
            excludeSemantics: true,
            child: IconButton(
              iconSize: 28,
              splashRadius: 20,
              onPressed: onAdd,
              icon: const Icon(Symbols.add),
            ),
          ),
        ],
      ),
    );
  }
}
