import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import '../../../foundation/platform.dart';
import '../../downloads/background/providers.dart';
import '../../navigation/app_navigation.dart';
import '../../navigation/navigation_controller.dart';
import '../../navigation/navigation_chrome_controller.dart';
import '../../navigation/destination_id.dart';
import 'notification_intent.dart';
import 'page.dart';
import '../../navigation/destination_activity.dart';
import 'notification_delivery.dart';
import 'notification_copy.dart';
import 'notification_outbox.dart';
import 'protocol.dart';
import 'providers.dart';

/// Detection runs during foreground/resume scans. Native notifications never
/// grant trust or promise discovery while the application is terminated.
class MiteMiteNotifications extends ConsumerStatefulWidget {
  const MiteMiteNotifications({required this.child, super.key});
  final Widget child;
  @override
  ConsumerState<MiteMiteNotifications> createState() =>
      _MiteMiteNotificationsState();
}

class _MiteMiteNotificationsState extends ConsumerState<MiteMiteNotifications>
    with WidgetsBindingObserver {
  final _delivery = SyncNotificationDelivery();
  final _tapBlocked = ValueNotifier(false);
  var _scheduled = false;
  final _taps = SyncNotificationTapQueue();
  NavigationController? _navigation;
  final _routeSignals = <ValueNotifier<Route<dynamic>?>>[];
  var _opening = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _navigation = ref.read(navigationControllerProvider.notifier);
    _navigation!.bindingChanges.addListener(_bindingChanged);
    _bindingChanged();
    if (ref.read(miteMiteActivationProvider) &&
        ref.read(appPlatformProvider) == AppPlatform.android) {
      _tapBlocked.value = true;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _navigation?.bindingChanges.removeListener(_bindingChanged);
    for (final signal in _routeSignals) {
      signal.removeListener(_schedule);
    }
    _tapBlocked.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _schedule();
  }

  bool get _foreground =>
      mounted &&
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

  void _bindingChanged() {
    for (final signal in _routeSignals) {
      signal.removeListener(_schedule);
    }
    _routeSignals.clear();
    final binding = _navigation?.binding;
    if (binding != null) {
      for (final id in binding.destinations) {
        _routeSignals.add(binding.observerFor(id)!.topRoute);
      }
      if (binding.rootObserver case final observer?) {
        _routeSignals.add(observer.topRoute);
      }
      for (final signal in _routeSignals) {
        signal.addListener(_schedule);
      }
    }
    _schedule();
  }

  void _acceptTap(SyncNotificationIntent intent) {
    if (!_taps.add(intent)) return;
    _tapBlocked.value = true;
    _schedule();
  }

  Future<void> _openPending() async {
    final intent = _taps.first;
    if (!_foreground || _opening || intent == null) return;
    final navigation = _navigation!;
    if (navigation.binding == null) return;
    _opening = true;
    _tapBlocked.value = true;
    try {
      final accepted = await navigation.openAppRoot(
        switch (intent.destination) {
          SyncNotificationDestination.bookmarks => AppDestination.bookmarks,
          SyncNotificationDestination.following => AppDestination.following,
          SyncNotificationDestination.subscriptions ||
          SyncNotificationDestination.devices => AppDestination.settings,
        },
      );
      if (!mounted || !accepted || !_foreground) return;
      if (intent.destination == SyncNotificationDestination.subscriptions ||
          intent.destination == SyncNotificationDestination.devices) {
        final navigator = ref
            .read(appNavigationProvider)
            .navigatorKey
            .currentState;
        if (navigator == null) return;
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => MiteMitePage(
              section:
                  intent.destination ==
                      SyncNotificationDestination.subscriptions
                  ? 'receive'
                  : 'devices',
              focusPublisher: intent.publisher,
            ),
          ),
        );
        await WidgetsBinding.instance.endOfFrame;
      }
      if (mounted) _taps.accepted(intent);
    } finally {
      _opening = false;
      if (mounted) {
        _tapBlocked.value = false;
        if (_taps.first != null && _taps.first != intent) _schedule();
      }
    }
  }

  void _schedule() {
    if (_scheduled || !mounted) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _scheduled = false;
      if (!mounted ||
          !_foreground ||
          !ref.read(miteMiteActivationProvider) ||
          ref.read(appPlatformProvider) != AppPlatform.android) {
        return;
      }
      final notifications = ref.read(downloadNotificationsProvider);
      try {
        await notifications.initialize();
        if (!mounted || !_foreground) return;
        if (SyncNotificationIntent.tryParse(notifications.launchPayload)
            case final intent?) {
          _acceptTap(intent);
          notifications.consumeLaunchPayload(notifications.launchPayload!);
        }
        if (!_taps.isEmpty) {
          await _openPending();
        } else {
          _tapBlocked.value = false;
        }
        if (!mounted) return;
        final service = ref.read(currentMiteMiteServiceProvider);
        if (service == null ||
            service.busy ||
            service.isReconciling ||
            service.events.pendingNotifications.isEmpty) {
          return;
        }
        final navigation = ref.read(appNavigationProvider);
        final anchor =
            navigation.feedbackKey.currentContext ??
            navigation.navigatorKey.currentContext;
        if (anchor == null || !anchor.mounted) return;
        final t = anchor.t.mitemite;
        await _delivery.deliver(
          events: service.events,
          enabled: () => service.discoveryNotifications,
          current: () =>
              mounted &&
              identical(ref.read(currentMiteMiteServiceProvider), service) &&
              _foreground &&
              ref.read(miteMiteActivationProvider) &&
              !service.busy &&
              !service.isReconciling,
          requestPermission: notifications.requestDeviceNotificationPermission,
          allowed: (notice) =>
              notice.kind == SyncNoticeKind.device ||
              notice.items.every((item) {
                final key = service.gate.approvedKey(item.publisher);
                return key != null && syncDigest(key) == item.fingerprint;
              }),
          show: (notice) {
            final copy = syncNotificationCopy(anchor.t, notice);
            return notifications.showMiteMiteNotification(
              id: syncNoticeId(notice),
              tag: syncNoticeTag(notice),
              title: copy.title,
              body: copy.body,
              intent: syncNotificationIntent(notice),
              channelName: t.title,
              channelDescription: t.notifications_description,
            );
          },
        );
      } catch (_) {
        if (mounted && _taps.isEmpty) _tapBlocked.value = false;
        // Native delivery or receipt failure leaves Activity/Devices available.
        // The next scan retries; a stable (tag, id) replaces a prior OS notice.
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(miteMiteActivationProvider) &&
        ref.watch(appPlatformProvider) == AppPlatform.android) {
      ref.listen(miteMiteChangesProvider, (_, _) => _schedule());
      ref.listen(navigationChromeProvider, (_, _) {
        if (!_taps.isEmpty) _schedule();
      });
      ref.listen(downloadNotificationTapProvider, (_, value) {
        if (SyncNotificationIntent.tryParse(value.valueOrNull)
            case final intent?) {
          _acceptTap(intent);
        }
      });
      _schedule();
    }
    return NavigationIntentScope(blocked: _tapBlocked, child: widget.child);
  }
}
