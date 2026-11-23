import 'package:flutter/widgets.dart';

import '../types/viewer_entry.dart';

/// Presentation can reuse route-local gallery state without putting occurrence
/// identity, authorization or widget state into reusable Group metadata.
class GroupViewerScope extends InheritedWidget {
  const GroupViewerScope({
    required this.entry,
    required super.child,
    this.embedded = true,
    this.passive = false,
    this.onOpenMember,
    super.key,
  });
  final GroupViewerEntry entry;
  final bool embedded;
  final bool passive;
  final ValueChanged<String>? onOpenMember;
  static GroupViewerScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GroupViewerScope>();
  static GroupViewerEntry? maybeEntryOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GroupViewerScope>()?.entry;
  static bool openMember(BuildContext context, Object? selectionKey) {
    final scope = maybeOf(context);
    if (scope?.onOpenMember == null) return false;
    if (selectionKey case (final reference, _, final String memberKey)
        when reference == scope!.entry.contentReference) {
      scope.onOpenMember!(memberKey);
    }
    // A missing occurrence is never substituted with a neighboring Post route.
    return true;
  }

  @override
  bool updateShouldNotify(GroupViewerScope oldWidget) =>
      entry != oldWidget.entry ||
      embedded != oldWidget.embedded ||
      passive != oldWidget.passive ||
      onOpenMember != oldWidget.onOpenMember;
}
