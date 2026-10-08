// Package imports:
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

/// A selector using the same anchored menu as the bookmark grid actions.
class BookmarkOptionSelector<T> extends StatelessWidget {
  const BookmarkOptionSelector({
    required this.label,
    required this.options,
    required this.value,
    required this.optionLabel,
    required this.onSelected,
    super.key,
  });

  final String label;
  final List<T> options;
  final T value;
  final String Function(T) optionLabel;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return KurumiPopupMenuButton(
      semanticLabel: label,
      maxWidth: 320,
      items: [
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight:
                ((media.size.height -
                            media.viewInsets.bottom -
                            media.padding.vertical) *
                        0.6)
                    .clamp(48, 320),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final option in options)
                  Semantics(
                    selected: option == value,
                    child: KurumiPopupMenuItem(
                      title: Text(optionLabel(option)),
                      trailing: option == value
                          ? const Icon(Icons.check, size: 18)
                          : null,
                      onTap: () => onSelected(option),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
      child: Tooltip(
        message: label,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, maxLines: 1),
              const Icon(Icons.arrow_drop_down, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
