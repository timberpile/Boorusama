import 'package:i18n/i18n.dart';

import 'notification_outbox.dart';

({String title, String body}) syncNotificationCopy(
  Translations translations,
  SyncNotice notice,
) {
  final t = translations.mitemite;
  return switch (notice.kind) {
    SyncNoticeKind.device => (title: t.new_device_title, body: t.new_device),
    SyncNoticeKind.offers => (
      title: t.new_collections_title,
      body: t.new_collections_description,
    ),
    SyncNoticeKind.followingOffers => (
      title: t.new_following_collections_title,
      body: t.new_following_collections_description,
    ),
    SyncNoticeKind.topics => (
      title: t.new_topics_title(n: notice.postCount),
      body: t.new_topics_description,
    ),
    SyncNoticeKind.posts => (
      title: t.new_posts_title,
      body: t.new_posts_description,
    ),
  };
}
