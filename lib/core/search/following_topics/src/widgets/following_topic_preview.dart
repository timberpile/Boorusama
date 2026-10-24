import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import '../../../../boorus/engine/providers.dart';
import '../../../../configs/config/types.dart';
import '../../../../configs/manage/providers.dart';
import '../../../../images/booru_image.dart';
import '../providers/untracked_topic_preview_provider.dart';
import '../providers/following_topic_selectors.dart';
import '../refresh/search_refresh_query_adapter.dart';
import '../types/following_topic.dart';
import '../types/search_refresh.dart';

/// Preview errors are presentation state; they never update the Topic's
/// tracking error, checkpoint, last-success timestamp, or unread counters.
class FollowingTopicPreview extends ConsumerWidget {
  const FollowingTopicPreview({
    required this.topic,
    required this.auth,
    this.fallback,
    super.key,
  });

  final FollowingTopic topic;
  final BooruConfigAuth auth;
  final Widget? fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Feed members supply their own snapshot-backed, cache-only preview.
    // Preserve that surface without starting a separate search or image load.
    if (fallback case final preview?) return preview;
    final owner = ref
        .watch(booruConfigProvider)
        .where(
          (profile) => profile.id == topic.profileId && profile.auth == auth,
        )
        .firstOrNull;
    final adapter = owner == null
        ? null
        : ref
              .watch(booruRepoProvider(owner.auth))
              ?.searchRefreshQueryAdapter(owner.auth);
    final untracked =
        owner != null &&
        (topic.lastErrorKind == SearchRefreshErrorKind.unsupported ||
            !ref.watch(followingTopicTrackingSupportedProvider(owner.auth)) ||
            !supportsSearchRefreshQuery(adapter, topic.query));
    final stored = topic.previews
        .map((preview) => preview.thumbnailUrl)
        .toList();
    if (!untracked) return fallback ?? _images(stored);

    final previews = ref.watch(
      untrackedTopicPreviewProvider((
        config: owner,
        query: topic.query,
        structure: topic.queryStructure,
        revision: topic.runtimeRevision,
        attemptedAt: topic.lastAttemptAt,
      )),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        previews.when(
          data: _images,
          loading: () => _images(stored),
          error: (_, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _images(stored),
              // Separate from the existing unsupported-tracking notice.
              Row(
                children: [
                  const Icon(Icons.broken_image_outlined, size: 16),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      context.t.following_topics.preview_error,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // A locally followed Topic need not have attempted tracking yet.
        // Do not duplicate the card's persisted unsupported notice.
        if (topic.lastErrorKind != SearchRefreshErrorKind.unsupported)
          Text(
            context.t.following_topics.error_unsupported,
            style: Theme.of(context).textTheme.bodySmall,
          ),
      ],
    );
  }

  Widget _images(List<String> urls) {
    if (urls.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 3, bottom: 4),
      child: Row(
        children: [
          for (final url in urls.take(4))
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(1),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: BooruImage(
                    imageUrl: url,
                    config: auth,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          for (var i = urls.length; i < 4; i++) const Spacer(),
        ],
      ),
    );
  }
}
