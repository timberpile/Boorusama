import 'package:kurumi/material.dart';

/// Shared timeline control layout. Pages own their controls and fetching state.
class TimelineToolbar extends StatelessWidget {
  const TimelineToolbar({required this.children, this.trailing, super.key});

  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              key: const ValueKey('timeline-toolbar-content'),
              scrollDirection: Axis.horizontal,
              child: Row(mainAxisSize: MainAxisSize.min, children: children),
            ),
          ),
          if (trailing case final action?) ...[
            const SizedBox(width: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              child: action,
            ),
          ],
        ],
      ),
    ),
  );
}
