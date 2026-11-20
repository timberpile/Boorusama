// Dart imports:
import 'dart:async';

// Package imports:
import 'package:background_downloader/background_downloader.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Project imports:
import '../../../foundation/platform.dart';
import '../../backups/mitemite/notification_intent.dart';
import '../../backups/mitemite/protocol.dart';

class DownloadNotifications {
  static const _miteMiteSummaryId = 0x14400000;
  static const _miteMiteSummaryTag = 'mitemite.summary.v1';
  DownloadNotifications.uninitialized({required this.platform})
    : _flutterLocalNotificationsPlugin = null,
      _tapController = StreamController<String>.broadcast();

  final AppPlatform platform;
  FlutterLocalNotificationsPlugin? _flutterLocalNotificationsPlugin;
  final StreamController<String> _tapController;
  var _isInitialized = false;
  Future<void>? _initialization;
  final _activeBulkNotifications = <String>{};
  String? _launchPayload;

  Stream<String> get tapStream => _tapController.stream;
  String? get launchPayload => _launchPayload;
  void consumeLaunchPayload(String payload) {
    if (_launchPayload == payload) _launchPayload = null;
  }

  // flutter_local_notifications has one platform tap handler. Reuse this
  // application-owned instance instead of replacing the downloads callback.
  Future<void> initialize() => _ensureInitialized();

  Future<void> _ensureInitialized() async {
    if (_isInitialized || platform == AppPlatform.windows) return;

    final pending = _initialization;
    if (pending != null) {
      await pending;
      return;
    }

    final initialization = _initialize();
    _initialization = initialization;
    try {
      await initialization;
    } finally {
      _initialization = null;
    }
  }

  Future<void> _initialize() async {
    final plugin = FlutterLocalNotificationsPlugin();
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
      macOS: DarwinInitializationSettings(),
      linux: LinuxInitializationSettings(
        defaultActionName: 'Open notification',
      ),
    );
    final initialized = await plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        if (_isMiteMiteSummary(response.id, response.payload)) {
          unawaited(
            _dismissMiteMiteGroup(
              plugin,
              SyncNotificationIntent.tryParse(response.payload)!.destination,
            ),
          );
        }
        if (!_tapController.isClosed) {
          _tapController.add(response.payload ?? response.id.toString());
        }
      },
    );
    if (initialized == false) {
      throw StateError('Native notification initialization failed');
    }
    _flutterLocalNotificationsPlugin = plugin;
    if (platform == AppPlatform.android) {
      final launch = await plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) {
        _launchPayload = launch?.notificationResponse?.payload;
        if (_isMiteMiteSummary(
          launch?.notificationResponse?.id,
          _launchPayload,
        )) {
          await _dismissMiteMiteGroup(
            plugin,
            SyncNotificationIntent.tryParse(_launchPayload)!.destination,
          );
        }
      }
    }
    _isInitialized = true;
  }

  static bool _isMiteMiteEvent(ActiveNotification notice) =>
      notice.id != null &&
      (notice.tag?.startsWith('mitemite.discovery.') == true ||
          notice.tag?.startsWith('mitemite.offers.') == true ||
          notice.tag?.startsWith('mitemite.following_offers.') == true ||
          notice.tag == 'mitemite.topics.v1' ||
          notice.tag == 'mitemite.posts.v1');

  static int _summaryId(SyncNotificationDestination destination) =>
      _miteMiteSummaryId + destination.index;
  static String _summaryTag(SyncNotificationDestination destination) =>
      'mitemite.summary.v2.${destination.name}';
  static bool _isMiteMiteSummary(int? id, String? payload) {
    final intent = SyncNotificationIntent.tryParse(payload);
    return intent != null && id == _summaryId(intent.destination);
  }

  static SyncNotificationIntent? _activeIntent(ActiveNotification notice) {
    if (!_isMiteMiteEvent(notice)) return null;
    if (notice.payload?.startsWith(SyncNotificationIntent.payloadPrefix) ??
        false) {
      return SyncNotificationIntent.tryParse(notice.payload);
    }
    final destination = notice.tag!.startsWith('mitemite.discovery.')
        ? SyncNotificationDestination.devices
        : notice.tag!.startsWith('mitemite.offers.') ||
              notice.tag!.startsWith('mitemite.following_offers.')
        ? SyncNotificationDestination.subscriptions
        : notice.tag == 'mitemite.topics.v1'
        ? SyncNotificationDestination.following
        : SyncNotificationDestination.bookmarks;
    return SyncNotificationIntent(destination: destination);
  }

  // Opening the group dismisses its currently displayed notices, never domain
  // intent/read state. Leaving children behind would recreate Android's launcher
  // summary after our summary auto-cancels. Downloads are independent.
  Future<void> _dismissMiteMiteGroup(
    FlutterLocalNotificationsPlugin plugin,
    SyncNotificationDestination destination,
  ) async {
    try {
      for (final notice in await plugin.getActiveNotifications()) {
        if (notice.id != null &&
            (_activeIntent(notice)?.destination == destination ||
                notice.tag == _summaryTag(destination) ||
                notice.tag == _miteMiteSummaryTag)) {
          await plugin.cancel(id: notice.id!, tag: notice.tag);
        }
      }
    } catch (_) {
      // Dismissal is best effort and must not prevent Home navigation/startup.
    }
  }

  Future<bool> requestDeviceNotificationPermission({
    bool requestIfDenied = true,
  }) async {
    if (platform != AppPlatform.android) return false;
    await _ensureInitialized();
    final android = _flutterLocalNotificationsPlugin
        ?.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (await android?.areNotificationsEnabled() ?? false) return true;
    if (!requestIfDenied) return false;
    return await android?.requestNotificationsPermission() ?? false;
  }

  Future<bool> showMiteMiteNotification({
    required int id,
    required String tag,
    required String title,
    required String body,
    required String channelName,
    required String channelDescription,
    SyncNotificationIntent intent = const SyncNotificationIntent(
      destination: SyncNotificationDestination.bookmarks,
    ),
  }) async {
    if (platform != AppPlatform.android) return false;
    await _ensureInitialized();
    final plugin = _flutterLocalNotificationsPlugin!;
    final android = plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (!(await android?.areNotificationsEnabled() ?? false)) return false;
    // Reuse the existing channel, including the user's blocked-channel choice.
    const channelId = 'mitemite.discovery.v1';
    await android?.createNotificationChannel(
      AndroidNotificationChannel(
        channelId,
        channelName,
        description: channelDescription,
      ),
    );
    final channels = await android?.getNotificationChannels();
    if (channels?.any(
          (channel) =>
              channel.id == channelId && channel.importance == Importance.none,
        ) ??
        false)
      return false;
    String group(SyncNotificationDestination destination) =>
        'mitemite.mitemite.v2.${destination.name}';
    final active = await plugin.getActiveNotifications();
    Future<void> child({
      required int noticeId,
      required String noticeTag,
      required String? noticeTitle,
      required String? noticeBody,
      required SyncNotificationIntent target,
      bool regrouping = false,
    }) => plugin.show(
      id: noticeId,
      title: noticeTitle,
      body: noticeBody,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDescription,
          tag: noticeTag,
          groupKey: group(target.destination),
          groupAlertBehavior: GroupAlertBehavior.children,
          silent: regrouping,
          onlyAlertOnce: true,
          visibility: NotificationVisibility.private,
          category: AndroidNotificationCategory.status,
        ),
      ),
      payload: target.payload,
    );
    final grouped = <SyncNotificationDestination, Map<String, String>>{};
    for (final notice in active) {
      if (notice.tag == _miteMiteSummaryTag) {
        await plugin.cancel(id: notice.id!, tag: notice.tag);
      }
      final target = _activeIntent(notice);
      if (target == null) continue;
      if (notice.groupKey != group(target.destination)) {
        await child(
          noticeId: notice.id!,
          noticeTag: notice.tag!,
          noticeTitle: notice.title,
          noticeBody: notice.body,
          target: target,
          regrouping: true,
        );
      }
      grouped.putIfAbsent(
            target.destination,
            () => {},
          )['${notice.tag}/${notice.id}'] =
          '${notice.title ?? channelName}: ${notice.body ?? ''}';
    }
    await child(
      noticeId: id,
      noticeTag: tag,
      noticeTitle: title,
      noticeBody: body,
      target: intent,
    );
    grouped.putIfAbsent(intent.destination, () => {})['$tag/$id'] =
        '$title: $body';
    // Every summary contains only children with the same explicit destination.
    // Summary taps cannot consume another category's displayed notices.
    for (final entry in grouped.entries) {
      final summary = SyncNotificationIntent(
        destination: entry.key,
        event: syncDigest(syncJsonBytes(entry.value)),
      );
      await plugin.show(
        id: _summaryId(entry.key),
        title: channelName,
        body: channelDescription,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            channelName,
            channelDescription: channelDescription,
            tag: _summaryTag(entry.key),
            groupKey: group(entry.key),
            setAsGroupSummary: true,
            groupAlertBehavior: GroupAlertBehavior.children,
            silent: true,
            playSound: false,
            enableVibration: false,
            onlyAlertOnce: true,
            visibility: NotificationVisibility.private,
            category: AndroidNotificationCategory.status,
            styleInformation: InboxStyleInformation(
              entry.value.values.toList(),
            ),
          ),
        ),
        payload: summary.payload,
      );
    }
    return true;
  }

  Future<void> showDeviceDiscoveryNotification({
    required int id,
    required String key,
    required String title,
    required String body,
    required String channelName,
    required String channelDescription,
  }) async {
    if (!await showMiteMiteNotification(
      id: id,
      tag: 'mitemite.discovery.$key',
      intent: const SyncNotificationIntent(
        destination: SyncNotificationDestination.devices,
      ),
      title: title,
      body: body,
      channelName: channelName,
      channelDescription: channelDescription,
    ))
      throw StateError('Native MiteMite notification is blocked');
  }

  void configureNativeDownloads({required bool enabled}) {
    FileDownloader().configureNotificationForGroup(
      FileDownloader.defaultGroup,
      running: enabled
          ? const TaskNotification('{filename}', '{progress}')
          : null,
      complete: enabled
          ? const TaskNotification('{filename}', 'completed')
          : null,
      error: enabled ? const TaskNotification('{filename}', 'failed') : null,
      progressBar: enabled,
    );
  }

  void registerNativeTapCallback() {
    FileDownloader().registerCallbacks(
      taskNotificationTapCallback: (task, type) {
        if (!_tapController.isClosed) _tapController.add('native:${type.name}');
      },
    );
  }

  Future<void> showDownloadCompleteNotification(
    String filename, {
    String? customMessage,
    bool fromCache = false,
  }) async {
    if (platform == AppPlatform.windows) return;

    await _ensureInitialized();

    final title = fromCache
        ? 'Download complete (disk cached)'
        : 'Download complete';
    final body =
        customMessage ??
        (fromCache
            ? '$filename saved instantly from cache'
            : '$filename ready in Downloads');

    const platformChannelSpecifics = NotificationDetails(
      android: AndroidNotificationDetails(
        'downloads',
        'Downloads',
        channelDescription: 'Download notifications',
        category: AndroidNotificationCategory.status,
      ),
      iOS: DarwinNotificationDetails(
        presentSound: false,
      ),
    );

    await _flutterLocalNotificationsPlugin?.show(
      id: 'complete_${filename.hashCode}'.hashCode,
      title: title,
      body: body,
      notificationDetails: platformChannelSpecifics,
      payload: 'native:complete',
    );
  }

  Future<void> showDownloadErrorNotification(
    String filename, {
    String? error,
  }) async {
    if (platform == AppPlatform.windows) return;

    await _ensureInitialized();

    const title = 'Download failed';
    final body = error ?? "Couldn't save $filename";

    const platformChannelSpecifics = NotificationDetails(
      android: AndroidNotificationDetails(
        'downloads',
        'Downloads',
        channelDescription: 'Download notifications',
        category: AndroidNotificationCategory.error,
        importance: Importance.high,
      ),
      iOS: DarwinNotificationDetails(
        presentSound: false,
      ),
    );

    await _flutterLocalNotificationsPlugin?.show(
      id: 'error_${filename.hashCode}'.hashCode,
      title: title,
      body: body,
      notificationDetails: platformChannelSpecifics,
      payload: 'native:error',
    );
  }

  Future<void> showBulkPreparing(
    String sessionId,
    String title,
    String body,
  ) async {
    if (platform == AppPlatform.windows) return;
    await _ensureInitialized();

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'download_$sessionId',
        'Download Progress',
        channelDescription: 'Shows download progress for bulk downloads',
        playSound: false,
        enableVibration: false,
        category: AndroidNotificationCategory.progress,
        showProgress: true,
        indeterminate: true,
        ongoing: true,
        autoCancel: false,
      ),
      iOS: const DarwinNotificationDetails(presentSound: false),
    );

    await _flutterLocalNotificationsPlugin?.show(
      id: sessionId.hashCode,
      title: title,
      body: body,
      notificationDetails: details,
      payload: 'bulk:$sessionId',
    );
    _activeBulkNotifications.add(sessionId);
  }

  Future<void> showBulkProgress(
    String sessionId,
    String title, {
    required int completed,
    required int total,
  }) async {
    if (platform == AppPlatform.windows) return;
    await _ensureInitialized();

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'download_$sessionId',
        'Download Progress',
        channelDescription: 'Shows download progress for bulk downloads',
        playSound: false,
        enableVibration: false,
        category: AndroidNotificationCategory.progress,
        showProgress: true,
        maxProgress: total,
        progress: completed,
        ongoing: true,
        autoCancel: false,
      ),
      iOS: const DarwinNotificationDetails(presentSound: false),
    );

    await _flutterLocalNotificationsPlugin?.show(
      id: sessionId.hashCode,
      title: title,
      body: '$completed/$total files',
      notificationDetails: details,
      payload: 'bulk:$sessionId',
    );
    _activeBulkNotifications.add(sessionId);
  }

  Future<void> showBulkComplete(
    String sessionId,
    String title, {
    required int total,
  }) async {
    if (platform == AppPlatform.windows) return;
    await _ensureInitialized();

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'download',
        'Download',
        category: AndroidNotificationCategory.status,
      ),
      iOS: DarwinNotificationDetails(presentSound: false),
    );

    await _flutterLocalNotificationsPlugin?.show(
      id: sessionId.hashCode,
      title: title,
      body: 'Downloaded $total files',
      notificationDetails: details,
      payload: 'bulk:$sessionId',
    );
    _activeBulkNotifications.remove(sessionId);
  }

  Future<void> cancelBulk(String sessionId) async {
    if (platform == AppPlatform.windows) return;
    await _ensureInitialized();
    await _flutterLocalNotificationsPlugin?.cancel(id: sessionId.hashCode);
    _activeBulkNotifications.remove(sessionId);
  }

  Future<void> cancelAllBulk() async {
    for (final sessionId in _activeBulkNotifications.toList()) {
      await cancelBulk(sessionId);
    }
  }

  void dispose() {
    unawaited(_tapController.close());
  }
}
