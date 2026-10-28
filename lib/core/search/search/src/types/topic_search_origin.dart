import 'package:flutter/widgets.dart';

import '../../../../configs/config/types.dart';
import '../../../following_topics/types.dart';

/// Captured on navigation, then changed only by successful explicit Topic actions.
class TopicSearchOrigin {
  const TopicSearchOrigin({required this.topic, required this.profile});

  final FollowingTopic topic;
  final BooruConfig profile;

  bool isModified(
    String profileId,
    String query,
    SearchQueryStructure? structure,
  ) =>
      topic.profileId != profileId ||
      normalizeSearchIdentity(topic.query) != normalizeSearchIdentity(query) ||
      topic.queryStructure != structure;
}

class TopicSearchOriginScope
    extends InheritedNotifier<ValueNotifier<TopicSearchOrigin?>> {
  const TopicSearchOriginScope({
    required ValueNotifier<TopicSearchOrigin?> origin,
    required super.child,
    super.key,
  }) : super(notifier: origin);

  static ValueNotifier<TopicSearchOrigin?>? of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<TopicSearchOriginScope>()
      ?.notifier;
}
