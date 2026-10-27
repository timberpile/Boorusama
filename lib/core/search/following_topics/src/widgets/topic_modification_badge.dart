import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

/// An overlay keeps the action's size and hit target unchanged.
class TopicModificationBadge extends StatelessWidget {
  const TopicModificationBadge({
    required this.modified,
    required this.child,
    super.key,
  });
  final bool modified;
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      child,
      if (modified)
        Positioned(
          top: -3,
          left: -3,
          child: IgnorePointer(
            child: Tooltip(
              message: context.t.following_topics.original_modified,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.surface,
                    width: 2,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: Icon(
                    Icons.edit,
                    size: 12,
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
            ),
          ),
        ),
    ],
  );
}
