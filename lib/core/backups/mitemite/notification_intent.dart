import 'dart:convert';

import 'package:equatable/equatable.dart';

import 'notification_outbox.dart';
import 'protocol.dart';

enum SyncNotificationDestination {
  bookmarks,
  following,
  subscriptions,
  devices,
}

/// A native tap carries a bounded destination, never labels or write authority.
final class SyncNotificationIntent extends Equatable {
  const SyncNotificationIntent({
    required this.destination,
    this.publisher,
    this.sourceKind,
    this.event,
  });

  final SyncNotificationDestination destination;
  final String? publisher;
  final String? sourceKind;
  final String? event;

  static const payloadPrefix = 'mitemite:v1:';

  String get payload {
    final body = base64Url.encode(
      utf8.encode(
        canonicalSyncJson({
          'destination': destination.name,
          if (publisher != null) 'publisher': publisher,
          if (sourceKind != null) 'kind': sourceKind,
          if (event != null) 'event': event,
        }),
      ),
    );
    return '$payloadPrefix$body';
  }

  static SyncNotificationIntent? tryParse(String? payload) {
    if (payload == 'mitemite:bookmarks') {
      return const SyncNotificationIntent(
        destination: SyncNotificationDestination.bookmarks,
      );
    }
    if (payload == 'mitemite:receive') {
      return const SyncNotificationIntent(
        destination: SyncNotificationDestination.subscriptions,
      );
    }
    if (payload == null ||
        payload.length > miteMiteMaxMetadataBytes ||
        !payload.startsWith(payloadPrefix))
      return null;
    try {
      final value = jsonDecode(
        utf8.decode(
          base64Url.decode(payload.substring(payloadPrefix.length)),
        ),
      );
      if (value is! Map<String, dynamic> ||
          value.keys.any(
            (key) => !const {
              'destination',
              'publisher',
              'kind',
              'event',
            }.contains(key),
          ))
        return null;
      final destination = SyncNotificationDestination.values.byName(
        syncString(value['destination']),
      );
      final publisher = value['publisher'] == null
          ? null
          : syncUuid(value['publisher']);
      final kind = value['kind'];
      final event = value['event'];
      if (kind != null &&
              (!syncSourceKinds.contains(kind) ||
                  destination != SyncNotificationDestination.subscriptions) ||
          publisher != null &&
              destination != SyncNotificationDestination.subscriptions ||
          event != null && (event is! String || !isSyncDigest(event)))
        return null;
      return SyncNotificationIntent(
        destination: destination,
        publisher: publisher,
        sourceKind: kind as String?,
        event: event as String?,
      );
    } on Object {
      return null;
    }
  }

  @override
  List<Object?> get props => [destination, publisher, sourceKind, event];
}

SyncNotificationIntent syncNotificationIntent(SyncNotice notice) =>
    SyncNotificationIntent(
      destination: switch (notice.kind) {
        SyncNoticeKind.device => SyncNotificationDestination.devices,
        SyncNoticeKind.posts => SyncNotificationDestination.bookmarks,
        SyncNoticeKind.topics => SyncNotificationDestination.following,
        SyncNoticeKind.offers || SyncNoticeKind.followingOffers =>
          SyncNotificationDestination.subscriptions,
      },
      publisher:
          notice.kind == SyncNoticeKind.offers ||
              notice.kind == SyncNoticeKind.followingOffers
          ? notice.items.first.publisher
          : null,
      sourceKind: notice.kind == SyncNoticeKind.offers
          ? 'bookmarks'
          : notice.kind == SyncNoticeKind.followingOffers
          ? 'following_topics'
          : null,
      event: notice.token,
    );

/// A blocked navigator retains exact tap intents, including cold-start ingress.
final class SyncNotificationTapQueue {
  final _pending = <SyncNotificationIntent>[];
  final _handled = <String>{};
  SyncNotificationIntent? get first => _pending.firstOrNull;
  bool get isEmpty => _pending.isEmpty;
  bool add(SyncNotificationIntent intent) {
    if (_pending.contains(intent) ||
        intent.event != null && _handled.contains(intent.payload))
      return false;
    _pending.add(intent);
    return true;
  }

  void accepted(SyncNotificationIntent intent) {
    _pending.remove(intent);
    if (intent.event != null) {
      _handled.add(intent.payload);
      if (_handled.length > 200) _handled.remove(_handled.first);
    }
  }
}
