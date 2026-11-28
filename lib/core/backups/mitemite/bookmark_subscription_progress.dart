import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import '../export_import/import/import_flow_page.dart';
import 'bookmark_subscription_import.dart';

class BookmarkSubscriptionProgress extends StatelessWidget {
  const BookmarkSubscriptionProgress({required this.operation, super.key});

  final BookmarkSubscriptionImport operation;

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<BookmarkSubscriptionImportState>(
        valueListenable: operation,
        builder: (context, state, _) => operation.waitingForProjection
            ? Text(context.t.mitemite.refresh_pending)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (state.cancelling)
                    Text(context.t.mitemite.subscription_cancelling)
                  else ...[
                    if (state.groups case (:final checked, :final total)
                        when total > 1) ...[
                      _GroupProgress(checked: checked, total: total),
                      const SizedBox(height: 12),
                    ],
                    ImportProgressIndicator(progress: state.progress),
                  ],
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton(
                      onPressed: state.saving || state.cancelling
                          ? null
                          : operation.cancel,
                      child: Text(context.t.generic.action.cancel),
                    ),
                  ),
                ],
              ),
      );
}

class _GroupProgress extends StatelessWidget {
  const _GroupProgress({required this.checked, required this.total});

  final int checked;
  final int total;

  @override
  Widget build(BuildContext context) {
    final label = context.t.mitemite.subscription_groups_checked(
      checked: checked,
      total: total,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(child: Text(label)),
        const SizedBox(height: 8),
        LinearProgressIndicator(value: checked / total, semanticsLabel: label),
      ],
    );
  }
}
