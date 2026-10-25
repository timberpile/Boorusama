// Package imports:
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

class FileDetailTile extends StatelessWidget {
  const FileDetailTile({
    required this.title,
    super.key,
    this.valueLabel,
    this.value,
    this.valueTrailing,
  }) : assert(
         valueLabel != null || value != null,
         'valueLabel or value must be provided',
       );

  final String title;
  final String? valueLabel;
  final Widget? value;
  final Widget? valueTrailing;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Kurumi.themeOf(context).colorScheme;

    final label = Text(
      title,
      style: Kurumi.themeOf(context).textTheme.titleLarge
          ?.copyWith(fontSize: 14, fontWeight: FontWeight.w700),
    );
    final content = Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: const BorderRadius.all(Radius.circular(4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value case final widget?)
            Expanded(child: widget)
          else if (valueLabel case final text?)
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: colorScheme.onSecondaryContainer,
                  fontSize: 14,
                ),
              ),
            ),
          ?valueTrailing,
        ],
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked =
            constraints.maxWidth < 360 &&
            MediaQuery.textScalerOf(context).scale(14) > 20;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: stacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [label, const SizedBox(height: 4), content],
                )
              : Row(
                  children: [
                    Expanded(flex: 45, child: label),
                    const SizedBox(width: 8),
                    Expanded(flex: 55, child: content),
                  ],
                ),
        );
      },
    );
  }
}
