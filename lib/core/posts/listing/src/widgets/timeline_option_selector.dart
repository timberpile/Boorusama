// Package imports:
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

/// A composable timeline selector with the Bookmark anchored-menu interaction.
class TimelineOptionSelector<T> extends StatelessWidget {
  const TimelineOptionSelector({
    required this.label,
    required this.options,
    required this.value,
    required this.optionLabel,
    required this.onSelected,
    this.optionIcon,
    this.optionLeading,
    this.optionSemanticLabel,
    this.prefixLabel,
    super.key,
  });

  final String label;
  final List<T> options;
  final T value;
  final String Function(T) optionLabel;
  final ValueChanged<T> onSelected;
  final IconData Function(T)? optionIcon;
  final Widget Function(T)? optionLeading;
  final String Function(T)? optionSemanticLabel;
  final String? prefixLabel;

  Widget _optionTitle(T option) {
    final icon = optionIcon?.call(option);
    final leading = optionLeading?.call(option);
    if (icon == null && leading == null) return Text(optionLabel(option));
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (leading != null)
          leading
        else if (icon != null)
          Icon(icon, size: 18),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            optionLabel(option),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final selectedSemanticLabel = optionSemanticLabel?.call(value) ?? label;
    return KurumiPopupMenuButton(
      semanticLabel: selectedSemanticLabel,
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
                    label: optionSemanticLabel?.call(option),
                    selected: option == value,
                    child: KurumiPopupMenuItem(
                      title: optionSemanticLabel == null
                          ? _optionTitle(option)
                          : ExcludeSemantics(child: _optionTitle(option)),
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
        message: selectedSemanticLabel,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (prefixLabel case final prefix?) ...[
                Text('${prefix}:', maxLines: 1),
                const SizedBox(width: 6),
              ],
              if (optionLeading != null || optionIcon != null) ...[
                if (optionLeading != null)
                  optionLeading!(value)
                else
                  Icon(optionIcon!(value), size: 18),
                const SizedBox(width: 6),
              ],
              Text(label, maxLines: 1),
              const Icon(Icons.arrow_drop_down, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
