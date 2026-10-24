// Package imports:
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

/// Non-blocking status for the intentionally limited Pixiv integration.
/// Keep it informational: it must not gate existing profiles or authentication.
class PixivExperimentalNotice extends StatelessWidget {
  const PixivExperimentalNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Kurumi.themeOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.t.pixiv.experimental.label,
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          context.t.pixiv.experimental.description,
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}
