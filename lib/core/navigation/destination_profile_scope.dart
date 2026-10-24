import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import '../configs/manage/providers.dart';
import '../configs/manage/widgets.dart';
import 'destination_id.dart';

class DestinationScope extends InheritedWidget {
  const DestinationScope({
    required this.id,
    required super.child,
    this.active = true,
    super.key,
  });
  final DestinationId id;
  final bool active;
  static DestinationScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DestinationScope>();
  @override
  bool updateShouldNotify(DestinationScope oldWidget) => id != oldWidget.id;
}

/// Lives above the destination Navigator so pushed pages and local overlays
/// receive the same full compatibility scope as the destination root.
class DestinationProfileScope extends ConsumerWidget {
  const DestinationProfileScope({
    required this.profileId,
    required this.child,
    super.key,
  });
  final String profileId;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref
        .watch(booruConfigProvider)
        .where((config) => config.id == profileId)
        .firstOrNull;
    if (config == null) {
      return Scaffold(
        body: Center(child: Text(context.t.booru.invalid_selected_profile)),
      );
    }
    return CurrentBooruConfigScope(config: config, child: child);
  }
}
