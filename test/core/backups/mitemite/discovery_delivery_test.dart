import 'dart:async';

import 'package:boorusama/core/backups/mitemite/discovery_delivery.dart';
import 'package:boorusama/core/backups/mitemite/notification_intent.dart';
import 'package:boorusama/core/backups/mitemite/local_events.dart';
import 'package:boorusama/core/cache/misc_data_store.dart';
import 'package:boorusama/core/downloads/background/notification.dart';
import 'package:boorusama/foundation/data_mutation_coordinator.dart';
import 'package:boorusama/foundation/platform.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  AndroidFlutterLocalNotificationsPlugin.registerWith();
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  final calls = <MethodCall>[];
  late SyncLocalEvents events;
  late _Store preferences;
  late DownloadNotifications native;
  var granted = true;
  var initialized = true;
  var channelBlocked = false;
  Object? launch;
  final active = <Map<String, dynamic>>[];
  var failSummary = false;
  Completer<void>? summaryDismissed;
  Iterable<MethodCall> getEventShows() => calls.where(
    (call) =>
        call.method == 'show' &&
        !((call.arguments as Map)['platformSpecifics']['tag'] as String)
            .startsWith('mitemite.summary.'),
  );
  final device = SyncDiscovery(
    '11111111-2222-4333-8444-555555555555',
    'a' * 64,
  );
  final other = SyncDiscovery('22222222-2222-4333-8444-555555555555', 'b' * 64);
  late FlutterLocalNotificationsPlatform previousPlatform;

  setUp(() async {
    previousPlatform = FlutterLocalNotificationsPlatform.instance;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    preferences = _Store();
    events = SyncLocalEvents(
      preferences: preferences,
      mutations: DataMutationCoordinator(),
      now: () => DateTime.utc(2026),
    );
    calls.clear();
    granted = true;
    initialized = true;
    channelBlocked = false;
    launch = null;
    active.clear();
    failSummary = false;
    summaryDismissed = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'getActiveNotifications') return List.of(active);
          if (call.method == 'cancel') {
            final args = call.arguments as Map;
            active.removeWhere(
              (notice) =>
                  notice['id'] == args['id'] && notice['tag'] == args['tag'],
            );
            if (args['id'] == 0x14400000 &&
                !(summaryDismissed?.isCompleted ?? true)) {
              summaryDismissed!.complete();
            }
          }
          if (call.method == 'show') {
            final args = call.arguments as Map;
            final android = args['platformSpecifics'] as Map;
            if (failSummary &&
                (android['tag'] as String).startsWith('mitemite.summary.')) {
              throw PlatformException(code: 'summary_failed');
            }
            active.removeWhere(
              (notice) =>
                  notice['id'] == args['id'] && notice['tag'] == android['tag'],
            );
            active.add({
              'id': args['id'],
              'tag': android['tag'],
              'groupKey': android['groupKey'],
              'title': args['title'],
              'body': args['body'],
              'payload': args['payload'],
            });
          }
          return switch (call.method) {
            'initialize' => initialized,
            'areNotificationsEnabled' ||
            'requestNotificationsPermission' => granted,
            'getNotificationAppLaunchDetails' => launch,
            'getNotificationChannels' => [
              {
                'id': 'mitemite.discovery.v1',
                'name': 'MiteMite',
                'importance': channelBlocked ? 0 : 3,
                'showBadge': true,
                'bypassDnd': false,
                'playSound': true,
                'enableLights': false,
                'enableVibration': true,
                'ledColor': 0,
                'audioAttributesUsage': 5,
              },
            ],
            _ => null,
          };
        });
    native = DownloadNotifications.uninitialized(platform: AppPlatform.android);
    await events.discover([device], DateTime.utc(2026));
  });

  tearDown(() {
    native.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    FlutterLocalNotificationsPlatform.instance = previousPlatform;
    debugDefaultTargetPlatformOverride = null;
  });

  Future<void> show(SyncDiscovery value) =>
      native.showDeviceDiscoveryNotification(
        id: syncDiscoveryNotificationId(value),
        key: value.key,
        title: 'MiteMite',
        body: 'New device detected. Review its identity before trusting it.',
        channelName: 'MiteMite Devices',
        channelDescription: 'New devices in the shared directory.',
      );

  Future<void> deliver(
    SyncDiscoveryDelivery delivery, {
    bool enabled = true,
    bool Function()? current,
    Future<void> Function(SyncDiscovery)? send,
    Future<void> Function(Set<String>)? acknowledge,
  }) => delivery.deliver(
    events: events,
    enabled: enabled,
    current: current ?? () => true,
    requestPermission: native.requestDeviceNotificationPermission,
    show: send ?? show,
    acknowledge: acknowledge ?? events.acknowledgeDiscoveries,
  );

  test('native channel is private, generic and delivered once across polls/restart', () async {
    final delivery = SyncDiscoveryDelivery();
    await Future.wait([deliver(delivery), deliver(delivery)]);
    await events.discover([device], DateTime.utc(2026, 2));
    events = SyncLocalEvents(
      preferences: preferences,
      mutations: DataMutationCoordinator(),
      now: () => DateTime.utc(2026),
    );
    await deliver(SyncDiscoveryDelivery());
    final shows = getEventShows().toList();
    expect(shows, hasLength(1));
    final args = shows.single.arguments as Map;
    expect(args['title'], 'MiteMite');
    expect(
      SyncNotificationIntent.tryParse(args['payload'] as String)!.destination,
      SyncNotificationDestination.devices,
    );
    expect(args['body'], isNot(contains(device.publisher)));
    final android = args['platformSpecifics'] as Map;
    expect(android['channelId'], 'mitemite.discovery.v1');
    expect(android['tag'], 'mitemite.discovery.${device.key}');
    expect(android['onlyAlertOnce'], isTrue);
    expect(
      android['groupKey'],
      'mitemite.mitemite.v2.devices',
    );
    expect(android['setAsGroupSummary'], isFalse);
    expect(android['visibility'], NotificationVisibility.private.index);
    expect(events.pendingDiscoveries, isEmpty);
    expect(events.history.single.kind, SyncEventKind.discovered);
  });

  test(
    'device alerts share a silent summary with the Devices destination',
    () async {
      await events.discover([other], DateTime.utc(2026));
      await deliver(SyncDiscoveryDelivery());
      final shows = getEventShows().toList();
      expect(shows, hasLength(2));
      for (final show in shows) {
        final args = show.arguments as Map;
        final android = args['platformSpecifics'] as Map;
        expect(
          SyncNotificationIntent.tryParse(args['payload'] as String)!
              .destination,
          SyncNotificationDestination.devices,
        );
        expect(android['setAsGroupSummary'], isFalse);
        expect(android['groupKey'], 'mitemite.mitemite.v2.devices');
        expect(
          android['groupAlertBehavior'],
          GroupAlertBehavior.children.index,
        );
      }
      final summaries = calls.where(
        (call) =>
            call.method == 'show' &&
            (call.arguments as Map)['platformSpecifics']['tag'] ==
                'mitemite.summary.v2.devices',
      );
      expect(summaries, hasLength(2));
      final summary = summaries.last.arguments as Map;
      expect(summaries.map((call) => (call.arguments as Map)['id']).toSet(), {
        0x14400003,
      });
      expect(
        SyncNotificationIntent.tryParse(summary['payload'] as String)!
            .destination,
        SyncNotificationDestination.devices,
      );
      final android = summary['platformSpecifics'] as Map;
      expect(android['setAsGroupSummary'], isTrue);
      expect(android['groupKey'], 'mitemite.mitemite.v2.devices');
      expect(android['silent'], isTrue);
      expect(android['playSound'], isFalse);
      expect(android['enableVibration'], isFalse);
      expect(android['visibility'], NotificationVisibility.private.index);
      expect(
        active,
        hasLength(3),
        reason: 'Two actual events and one silent group container',
      );
    },
  );

  test('mixed categories produce destination-specific summaries and preserve private download notifications', () async {
    for (final destination in SyncNotificationDestination.values) {
      final tag = switch (destination) {
        SyncNotificationDestination.bookmarks => 'mitemite.posts.v1',
        SyncNotificationDestination.following => 'mitemite.topics.v1',
        SyncNotificationDestination.subscriptions => 'mitemite.offers.fixture',
        SyncNotificationDestination.devices => 'mitemite.discovery.fixture',
      };
      await native.showMiteMiteNotification(
        id: 100 + destination.index,
        tag: tag,
        title: destination.name,
        body: 'Generic content',
        channelName: 'MiteMite',
        channelDescription: 'Updates',
        intent: SyncNotificationIntent(destination: destination),
      );
    }
    final summaries = active
        .where(
          (notice) =>
              (notice['tag'] as String).startsWith('mitemite.summary.v2.'),
        )
        .toList();
    expect(summaries, hasLength(4));
    for (final summary in summaries) {
      final destination = SyncNotificationIntent.tryParse(
        summary['payload'] as String,
      )!.destination;
      expect(
        summary['groupKey'],
        'mitemite.mitemite.v2.${destination.name}',
      );
      final children = active.where(
        (notice) =>
            notice['groupKey'] == summary['groupKey'] &&
            notice['id'] != summary['id'],
      );
      expect(children, isNotEmpty);
      expect(
        children.every(
          (notice) =>
              SyncNotificationIntent.tryParse(notice['payload'] as String)!
                  .destination ==
              destination,
        ),
        isTrue,
      );
    }
  });

  test('regroups an already displayed legacy event silently and leaves downloads alone', () async {
    active.addAll([
      {
        'id': 8,
        'tag': 'mitemite.posts.v1',
        'groupKey': 'old',
        'title': '1 New Posts',
        'body': 'Groups: 1',
      },
      {
        'id': 9,
        'tag': 'download',
        'groupKey': null,
        'title': 'download',
        'body': 'private filename',
      },
    ]);
    await deliver(SyncDiscoveryDelivery());
    final migrated =
        getEventShows()
                .singleWhere((call) => (call.arguments as Map)['id'] == 8)
                .arguments
            as Map;
    expect(
      SyncNotificationIntent.tryParse(migrated['payload'] as String)!
          .destination,
      SyncNotificationDestination.bookmarks,
    );
    expect(migrated['platformSpecifics']['silent'], isTrue);
    expect(
      migrated['platformSpecifics']['groupKey'],
      'mitemite.mitemite.v2.bookmarks',
    );
    expect(
      getEventShows().where((call) => (call.arguments as Map)['id'] == 9),
      isEmpty,
    );
    final summary = calls
        .lastWhere((call) => call.method == 'show')
        .arguments
        .toString();
    expect(summary, isNot(contains('private filename')));
  });

  test('a failed group summary retains intent and replaces the same child on retry', () async {
    failSummary = true;
    final delivery = SyncDiscoveryDelivery();
    await deliver(delivery);
    expect(events.pendingDiscoveries, hasLength(1));
    final first = getEventShows().single.arguments as Map;
    failSummary = false;
    await deliver(delivery);
    expect(events.pendingDiscoveries, isEmpty);
    final retried = getEventShows().last.arguments as Map;
    expect(retried['id'], first['id']);
    expect(
      retried['platformSpecifics']['tag'],
      first['platformSpecifics']['tag'],
    );
    expect(retried['platformSpecifics']['onlyAlertOnce'], isTrue);
    expect(active, hasLength(2));
  });

  test('permission denial and disabled preference retain discovery without replacement UI', () async {
    granted = false;
    await deliver(SyncDiscoveryDelivery());
    expect(
      calls.where((call) => call.method == 'requestNotificationsPermission'),
      hasLength(1),
    );
    expect(getEventShows(), isEmpty);
    expect(events.pendingDiscoveries, hasLength(1));
    expect(events.history, hasLength(1));
    await events.discover([other], DateTime.utc(2026));
    calls.clear();
    await deliver(SyncDiscoveryDelivery(), enabled: false);
    expect(
      calls,
      isEmpty,
      reason: 'Disabled notifications do not request OS permission',
    );
    expect(events.history, hasLength(2));
    expect(events.pendingDiscoveries, hasLength(2));
    await deliver(SyncDiscoveryDelivery());
    expect(
      calls.where((call) => call.method == 'requestNotificationsPermission'),
      isEmpty,
      reason:
          'Permission denial survives process restart without another prompt',
    );
    granted = true;
    await deliver(SyncDiscoveryDelivery());
    expect(getEventShows(), hasLength(2));
    expect(events.pendingDiscoveries, isEmpty);
  });

  test('blocked Android channel retains pending intent and reuses the same channel after enabling', () async {
    channelBlocked = true;
    final delivery = SyncDiscoveryDelivery();
    await deliver(delivery);
    expect(getEventShows(), isEmpty);
    expect(events.pendingDiscoveries, hasLength(1));
    channelBlocked = false;
    await deliver(delivery);
    expect(getEventShows(), hasLength(1));
    expect(events.pendingDiscoveries, isEmpty);
    expect(
      calls
          .where((call) => call.method == 'createNotificationChannel')
          .every(
            (call) => (call.arguments as Map)['id'] == 'mitemite.discovery.v1',
          ),
      isTrue,
    );
  });

  test('a failed receipt retries persistence without another alert and preserves later events', () async {
    final delivery = SyncDiscoveryDelivery();
    await deliver(
      delivery,
      acknowledge: (_) async => throw StateError('disk unavailable'),
    );
    expect(events.pendingDiscoveries, hasLength(1));
    await events.discover([other], DateTime.utc(2026));
    await deliver(delivery);
    expect(getEventShows(), hasLength(2));
    expect(events.pendingDiscoveries, isEmpty);
    expect(
      syncDiscoveryNotificationId(device),
      syncDiscoveryNotificationId(
        SyncDiscovery(device.publisher, device.fingerprint),
      ),
    );
  });

  test(
    'one failed native alert does not starve a different publisher',
    () async {
      await events.discover([other], DateTime.utc(2026));
      await deliver(
        SyncDiscoveryDelivery(),
        send: (value) async {
          if (value.key == device.key) throw StateError('native failure');
          await show(value);
        },
      );
      expect(events.pendingDiscoveries.single.key, device.key);
      expect(getEventShows(), hasLength(1));
    },
  );

  test(
    'foreground loss during permission request retains receipts for resume',
    () async {
      var current = true;
      final permission = Completer<bool>();
      final pending = SyncDiscoveryDelivery().deliver(
        events: events,
        enabled: true,
        current: () => current,
        requestPermission: ({requestIfDenied = true}) => permission.future,
        show: show,
        acknowledge: events.acknowledgeDiscoveries,
      );
      await Future<void>(() {});
      current = false;
      permission.complete(true);
      await pending;
      expect(events.pendingDiscoveries, hasLength(1));
      expect(getEventShows(), isEmpty);
    },
  );

  test('a new fingerprint has its own receipt while unrelated history is preserved', () async {
    final delivery = SyncDiscoveryDelivery();
    await events.record(
      SyncEvent(kind: SyncEventKind.published, at: DateTime.utc(2026)),
    );
    await deliver(delivery);
    final rotated = SyncDiscovery(device.publisher, 'c' * 64);
    await events.discover([device, rotated], DateTime.utc(2026));
    await deliver(delivery);
    final shows = getEventShows().toList();
    expect(shows, hasLength(2));
    expect(
      (shows[0].arguments as Map)['platformSpecifics']['tag'],
      isNot((shows[1].arguments as Map)['platformSpecifics']['tag']),
    );
    expect(
      events.history.where((event) => event.kind == SyncEventKind.published),
      hasLength(1),
    );
    expect(events.pendingDiscoveries, isEmpty);
  });

  test(
    'native initialization failure retains the pending receipt for retry',
    () async {
      initialized = false;
      final delivery = SyncDiscoveryDelivery();
      await expectLater(deliver(delivery), throwsStateError);
      expect(events.pendingDiscoveries, hasLength(1));
      expect(getEventShows(), isEmpty);
      initialized = true;
      channelBlocked = false;
      await deliver(delivery);
      expect(events.pendingDiscoveries, isEmpty);
      expect(getEventShows(), hasLength(1));
    },
  );

  for (final cold in [false, true]) {
    test(
      '${cold ? 'cold' : 'warm'} summary tap dismisses only its compatible destination without acknowledging domain intent',
      () async {
        active.addAll([
          {'id': null, 'tag': 'mitemite.summary.v1'},
          {'id': 8, 'tag': 'mitemite.posts.v1'},
          {'id': 9, 'tag': 'mitemite.discovery.fixture'},
          {'id': 0x14400000, 'tag': 'mitemite.summary.v1'},
          {'id': 10, 'tag': 'download'},
        ]);
        final response = {
          'notificationId': 0x14400000,
          'notificationResponseType': 0,
          'payload': 'mitemite:bookmarks',
        };
        summaryDismissed = Completer<void>();
        if (cold) {
          launch = {
            'notificationLaunchedApp': true,
            'notificationResponse': response,
          };
          await native.initialize();
          expect(native.launchPayload, 'mitemite:bookmarks');
        } else {
          await native.initialize();
          final tapped = native.tapStream.first;
          await TestDefaultBinaryMessengerBinding
              .instance
              .defaultBinaryMessenger
              .handlePlatformMessage(
                channel.name,
                const StandardMethodCodec().encodeMethodCall(
                  MethodCall('didReceiveNotificationResponse', response),
                ),
                (_) {},
              );
          expect(await tapped, 'mitemite:bookmarks');
        }
        await summaryDismissed!.future;
        expect(
          calls
              .where((call) => call.method == 'cancel')
              .map((call) => (call.arguments as Map)['id']),
          [8, 0x14400000],
        );
        expect(active, hasLength(3));
        expect(active.last['tag'], 'download');
        expect(events.pendingDiscoveries.single.key, device.key);
        expect(events.history.single.kind, SyncEventKind.discovered);
      },
    );
  }

  test('native taps retain the shared download callback and capture cold launch once', () async {
    launch = {
      'notificationLaunchedApp': true,
      'notificationResponse': {
        'notificationId': 7,
        'notificationResponseType': 0,
        'payload': 'mitemite:receive',
      },
    };
    await native.initialize();
    expect(native.launchPayload, 'mitemite:receive');
    native.consumeLaunchPayload('unrelated');
    expect(native.launchPayload, 'mitemite:receive');
    native.consumeLaunchPayload('mitemite:receive');
    expect(native.launchPayload, isNull);
    final received = <String>[];
    final subscription = native.tapStream.listen(received.add);
    addTearDown(subscription.cancel);
    for (final payload in [
      'native:complete',
      'mitemite:receive',
      'bulk:fixture',
    ]) {
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            channel.name,
            const StandardMethodCodec().encodeMethodCall(
              MethodCall('didReceiveNotificationResponse', {
                'notificationId': 1,
                'notificationResponseType': 0,
                'payload': payload,
              }),
            ),
            (_) {},
          );
    }
    await Future<void>(() {});
    expect(received, [
      'native:complete',
      'mitemite:receive',
      'bulk:fixture',
    ]);
    expect(calls.where((call) => call.method == 'initialize'), hasLength(1));
  });
}

class _Store implements MiscDataStore {
  final values = <String, String>{};
  @override
  String? get(String key) => values[key];
  @override
  Future<void> put(String key, String value) async {
    values[key] = value;
  }
}
