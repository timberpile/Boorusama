// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:i18n/i18n.dart';

/// A deliberately low-emphasis marker for the current bookmark target.
class BookmarkActiveTargetBadge extends StatelessWidget {
  const BookmarkActiveTargetBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      context.t.bookmark.groups.active,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontSize: 10,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
