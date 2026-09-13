// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:i18n/i18n.dart';

// Project imports:
import '../sources/bookmark_import_plan.dart';
import '../../bookmarks/src/widgets/bookmark_group_label.dart';

class BookmarkGroupConflictDecision {
  const BookmarkGroupConflictDecision({
    required this.choice,
    required this.applyToRemaining,
  });

  final BookmarkGroupConflictChoice choice;
  final bool applyToRemaining;
}

Future<BookmarkGroupConflictDecision?> showBookmarkGroupConflictDialog(
  BuildContext context, {
  required BookmarkGroupImport conflict,
}) => showDialog<BookmarkGroupConflictDecision>(
  context: context,
  barrierDismissible: false,
  builder: (_) => BookmarkGroupConflictDialog(conflict: conflict),
);

Future<BookmarkImportPlan?> resolveBookmarkGroupConflicts(
  BuildContext context,
  BookmarkImportPlan plan,
) async {
  final choices = <String, BookmarkGroupConflictChoice>{};
  BookmarkGroupConflictChoice? remainingChoice;
  for (final conflict in plan.conflicts) {
    if (remainingChoice case final choice?) {
      choices[conflict.id] = choice;
      continue;
    }
    final decision = await showBookmarkGroupConflictDialog(
      context,
      conflict: conflict,
    );
    if (decision == null ||
        decision.choice == BookmarkGroupConflictChoice.cancel) {
      return null;
    }
    choices[conflict.id] = decision.choice;
    if (decision.applyToRemaining) remainingChoice = decision.choice;
  }
  return plan.resolve(choices);
}

class BookmarkGroupConflictDialog extends StatefulWidget {
  const BookmarkGroupConflictDialog({required this.conflict, super.key});

  final BookmarkGroupImport conflict;

  @override
  State<BookmarkGroupConflictDialog> createState() =>
      _BookmarkGroupConflictDialogState();
}

class _BookmarkGroupConflictDialogState
    extends State<BookmarkGroupConflictDialog> {
  var _applyToRemaining = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.t.bookmark.groups.import_conflict_title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t.bookmark.groups.import_conflict_message.replaceAll(
              '{name}',
              bookmarkGroupConflictLabel(
                widget.conflict.name,
                widget.conflict.id,
              ),
            ),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _applyToRemaining,
            onChanged: (value) =>
                setState(() => _applyToRemaining = value ?? false),
            title: Text(
              context.t.bookmark.groups.apply_to_remaining_conflicts,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(
            context,
            const BookmarkGroupConflictDecision(
              choice: BookmarkGroupConflictChoice.cancel,
              applyToRemaining: false,
            ),
          ),
          child: Text(context.t.generic.action.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(
            context,
            BookmarkGroupConflictDecision(
              choice: BookmarkGroupConflictChoice.merge,
              applyToRemaining: _applyToRemaining,
            ),
          ),
          child: Text(context.t.bookmark.groups.merge),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            BookmarkGroupConflictDecision(
              choice: BookmarkGroupConflictChoice.replace,
              applyToRemaining: _applyToRemaining,
            ),
          ),
          child: Text(context.t.bookmark.groups.replace),
        ),
      ],
    );
  }
}
