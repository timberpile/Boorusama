import 'package:flutter/widgets.dart';

import '../types/viewer_entry.dart';

/// Presentation can reuse route-local gallery state without putting occurrence
/// identity, authorization or widget state into reusable Group metadata.
class GroupViewerScope extends InheritedWidget {
  const GroupViewerScope({
    required this.entry,
    required super.child,
    this.embedded = true,
    super.key,
  });
  final GroupViewerEntry entry;
  final bool embedded;
  static GroupViewerScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GroupViewerScope>();
  static GroupViewerEntry? maybeEntryOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GroupViewerScope>()?.entry;
  @override
  bool updateShouldNotify(GroupViewerScope oldWidget) =>
      entry != oldWidget.entry || embedded != oldWidget.embedded;
}
