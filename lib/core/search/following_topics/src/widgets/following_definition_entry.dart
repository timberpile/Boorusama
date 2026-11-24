import '../../../../configs/config/types.dart';
import '../providers/following_topic_config_provider.dart';

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/material.dart';

import '../../../../backups/mitemite/providers.dart';
import '../../../../backups/mitemite/actions.dart';
import '../../../../navigation/destination_activity.dart';
import '../../../../backups/mitemite/service.dart';

/// A route acknowledges only definitions captured for its successful entry.
/// Later synchronizations must remain unseen even while this route stays open.
class FollowingDefinitionEntry extends ConsumerStatefulWidget {
  const FollowingDefinitionEntry({
    required this.receipts,
    required this.child,
    this.ready = true,
    super.key,
  });
  final Map<String, String> receipts;
  final Widget child;
  final bool ready;
  @override
  ConsumerState<FollowingDefinitionEntry> createState() =>
      _FollowingDefinitionEntryState();
}

class _FollowingDefinitionEntryState
    extends ConsumerState<FollowingDefinitionEntry> {
  Map<String, String>? _captured;
  late Map<String, BooruConfig?> _capturedConfigs;
  var _scheduled = false;
  var _committed = false;
  var _inFlight = false;
  @override
  Widget build(BuildContext context) {
    if (widget.ready && _captured == null) {
      _captured = Map.unmodifiable(widget.receipts);
      _capturedConfigs = {
        for (final id in _captured!.keys)
          id: ref.read(followingTopicConfigProvider(id)),
      };
    }
    if (_captured?.isEmpty ?? false) return widget.child;
    for (final id in _captured?.keys ?? const <String>[]) {
      ref.watch(followingTopicConfigProvider(id));
    }
    if (widget.ready &&
        !_inFlight &&
        !_scheduled &&
        !_committed &&
        NavigationActivity.of(context)) {
      _scheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scheduled = false;
        if (!mounted ||
            !(ModalRoute.of(context)?.isCurrent ?? true) ||
            !NavigationActivity.of(context)) {
          return;
        }
        unawaited(_acknowledge());
      });
    }
    return widget.child;
  }

  Future<void> _acknowledge() async {
    _inFlight = true;
    try {
      final service = await ref.read(miteMiteServiceProvider.future);
      if (!mounted ||
          !isCurrentSyncService(context, service) ||
          !widget.ready ||
          !(ModalRoute.of(context)?.isCurrent ?? true) ||
          !NavigationActivity.of(context)) {
        return;
      }
      if (WidgetsBinding.instance.lifecycleState != null &&
          WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
        return;
      }
      final eligible = <String, String>{};
      for (final entry in _captured!.entries) {
        final captured = _capturedConfigs[entry.key];
        final current = ref.read(followingTopicConfigProvider(entry.key));
        if (captured != null &&
            current?.auth == captured.auth &&
            (captured.anonymousReadScope?.isCurrent ?? true)) {
          eligible[entry.key] = entry.value;
        }
      }
      await service.acknowledgeFollowingDefinitions(eligible);
      _committed = true;
    } catch (_) {
      // Keep persisted UNSEEN state on failure; another route entry may retry.
    } finally {
      _inFlight = false;
    }
  }
}
