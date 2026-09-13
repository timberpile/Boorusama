// Flutter imports:
import 'package:flutter/material.dart';

class BookmarkActiveTargetBadge extends StatelessWidget {
  const BookmarkActiveTargetBadge({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(label, style: Theme.of(context).textTheme.labelSmall),
  );
}
