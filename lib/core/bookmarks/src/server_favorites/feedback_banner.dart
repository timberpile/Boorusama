import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import 'controller.dart';
import 'presentation.dart';
import 'target_settings.dart';

/// Separate from remote-action toasts, so remote success cannot hide a failed
/// optional local projection (or encourage retrying the server mutation).
class ServerFavoriteFeedbackBanner extends ConsumerWidget {
  const ServerFavoriteFeedbackBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedback = ref.watch(serverFavoriteFeedbackProvider);
    if (feedback == null ||
        feedback.problem == ServerFavoriteProblem.unsupported) {
      return const SizedBox.shrink();
    }
    return Material(
      color: Theme.of(context).colorScheme.errorContainer,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .4,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Flexible(
                  child: SingleChildScrollView(
                    child: Text(
                      context.t.bookmark.server_favorites.projection_failed
                          .replaceAll(
                            '{reason}',
                            serverFavoriteProblemText(
                              context,
                              feedback.problem,
                            ),
                          ),
                    ),
                  ),
                ),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton(
                    onPressed: () => ref
                        .read(serverFavoriteFeedbackProvider.notifier)
                        .clear(),
                    child: Text(
                      MaterialLocalizations.of(context).closeButtonLabel,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
