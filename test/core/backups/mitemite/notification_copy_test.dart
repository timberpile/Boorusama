import 'package:boorusama/core/backups/mitemite/notification_copy.dart';
import 'package:boorusama/core/backups/mitemite/notification_intent.dart';
import 'package:boorusama/core/backups/mitemite/notification_outbox.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';

void main() {
  const publisher = '11111111-2222-4333-8444-555555555555';
  const source = '22222222-2222-4333-8444-555555555555';
  final fingerprint = 'a' * 64;
  final translations = Translations();
  SyncNotice notice(SyncNoticeKind kind, int count) => SyncNotice(
    kind: kind,
    bucket: switch (kind) {
      SyncNoticeKind.device => 'device:$publisher/$fingerprint',
      SyncNoticeKind.offers => 'offers:$publisher/$fingerprint',
      SyncNoticeKind.followingOffers =>
        'followingOffers:$publisher/$fingerprint',
      SyncNoticeKind.posts => 'posts',
      SyncNoticeKind.topics => 'topics',
    },
    batch: 1,
    generation: 1,
    items: [
      for (var i = 0; i < count; i++)
        SyncNoticeItem(
          publisher: publisher,
          fingerprint: fingerprint,
          at: DateTime.utc(2026),
          sourceKind: kind == SyncNoticeKind.device
              ? null
              : kind == SyncNoticeKind.topics ||
                    kind == SyncNoticeKind.followingOffers
              ? 'following_topics'
              : 'bookmarks',
          source: kind == SyncNoticeKind.device
              ? null
              : kind == SyncNoticeKind.posts || kind == SyncNoticeKind.topics
              ? source
              : '22222222-2222-4333-8444-${i.toString().padLeft(12, '0')}',
          member: kind == SyncNoticeKind.posts || kind == SyncNoticeKind.topics
              ? 'member:$i'
              : null,
        ),
    ],
  );

  for (final count in [1, 12]) {
    test(
      'five private category messages and validated destinations at count $count',
      () {
        final messages = <String>{};
        for (final kind in SyncNoticeKind.values) {
          final value = notice(kind, kind == SyncNoticeKind.device ? 1 : count);
          final copy = syncNotificationCopy(translations, value);
          messages.add(copy.title);
          expect('${copy.title} ${copy.body}', isNot(contains(publisher)));
          expect('${copy.title} ${copy.body}', isNot(contains(source)));
          final intent = syncNotificationIntent(value);
          expect(SyncNotificationIntent.tryParse(intent.payload), intent);
          expect(intent.destination, switch (kind) {
            SyncNoticeKind.device => SyncNotificationDestination.devices,
            SyncNoticeKind.posts => SyncNotificationDestination.bookmarks,
            SyncNoticeKind.topics => SyncNotificationDestination.following,
            SyncNoticeKind.offers || SyncNoticeKind.followingOffers =>
              SyncNotificationDestination.subscriptions,
          });
          if (kind == SyncNoticeKind.topics)
            expect(copy.title, '$count new ${count == 1 ? 'topic' : 'topics'}');
          if (kind == SyncNoticeKind.posts)
            expect(copy, (
              title: 'Mite mite!',
              body: 'New bookmarks are available! 👀',
            ));
          if (kind == SyncNoticeKind.device)
            expect(copy, (
              title: 'Someone new showed up!',
              body: 'A new device wants to join the fun! 👋',
            ));
        }
        expect(messages, hasLength(5));
      },
    );
  }

  test('tap queue preserves blocked cold/warm intents and consumes each exact event once', () {
    final queue = SyncNotificationTapQueue();
    final posts = syncNotificationIntent(notice(SyncNoticeKind.posts, 1));
    final offers = syncNotificationIntent(
      notice(SyncNoticeKind.followingOffers, 1),
    );
    expect(queue.add(posts), isTrue);
    expect(queue.add(SyncNotificationIntent.tryParse(posts.payload)!), isFalse);
    expect(queue.first, posts); // No navigation acceptance yet.
    expect(queue.add(offers), isTrue);
    queue.accepted(posts);
    expect(queue.first, offers);
    expect(queue.add(posts), isFalse);
    queue.accepted(offers);
    expect(queue.isEmpty, isTrue);
  });

  test(
    'unknown and malformed payloads cannot request arbitrary navigation',
    () {
      for (final payload in [
        null,
        'download',
        'mitemite:v3:bookmarks',
        '${SyncNotificationIntent.payloadPrefix}invalid',
        '${SyncNotificationIntent.payloadPrefix}${'a' * 100000}',
      ]) {
        expect(SyncNotificationIntent.tryParse(payload), isNull);
      }
      expect(
        SyncNotificationIntent.tryParse('mitemite:bookmarks')!.destination,
        SyncNotificationDestination.bookmarks,
      );
      expect(
        SyncNotificationIntent.tryParse('mitemite:receive')!.destination,
        SyncNotificationDestination.subscriptions,
      );
      expect(
        SyncNotificationIntent.tryParse(
          const SyncNotificationIntent(
            destination: SyncNotificationDestination.devices,
            publisher: publisher,
          ).payload,
        ),
        isNull,
      );
    },
  );
}
