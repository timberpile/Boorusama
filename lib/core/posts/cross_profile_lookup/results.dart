import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import '../../configs/config/types.dart';
import '../../images/booru_image.dart';
import '../post/types.dart';
import '../post/providers.dart';
import 'types.dart';

enum CrossProfileResultStatus {
  idle,
  loading,
  success,
  noMatch,
  unsupported,
  missingHash,
  error,
}

/// Presentation only: both manually selected and automatically searched profiles
/// can supply rows, without sharing query semantics or request orchestration.
class CrossProfileResult {
  const CrossProfileResult({
    required this.profile,
    required this.status,
    this.posts = const [],
    this.complete = false,
    this.matchKind,
  });

  final BooruConfig profile;
  final CrossProfileResultStatus status;
  final List<Post> posts;
  final bool complete;
  final PostLookupMatchKind? matchKind;
}

class CrossProfileResults extends StatelessWidget {
  const CrossProfileResults({
    required this.reference,
    required this.results,
    required this.onSelect,
    required this.onOpen,
    required this.onMore,
    super.key,
  });

  /// A source-post preview or an artwork reference supplied by the entry point.
  final Widget reference;
  final List<CrossProfileResult> results;
  final void Function(BooruConfig) onSelect;
  final void Function(BooruConfig, Post) onOpen;
  final void Function(BooruConfig) onMore;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      reference,
      const SizedBox(height: 16),
      if (results.isEmpty) Text(context.t.post.cross_profile.no_profiles),
      for (final result in results.where(
        (r) => r.status != CrossProfileResultStatus.unsupported,
      ))
        CrossProfileResultSection(
          result: result,
          onSelect: () => onSelect(result.profile),
          onOpen: (post) => onOpen(result.profile, post),
          onMore: () => onMore(result.profile),
        ),
      if (results.any(
        (r) => r.status == CrossProfileResultStatus.unsupported,
      )) ...[
        const SizedBox(height: 16),
        Text(
          context.t.post.cross_profile.unsupported_profiles,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 4),
        Text(
          results
              .where((r) => r.status == CrossProfileResultStatus.unsupported)
              .map(
                (r) =>
                    '${r.profile.name} (${postOriginFromConfig(r.profile).sourceHost})',
              )
              .join('\n'),
          key: const ValueKey('unsupported-profiles'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ],
  );
}

class CrossProfileResultSection extends StatelessWidget {
  const CrossProfileResultSection({
    required this.result,
    required this.onSelect,
    required this.onOpen,
    required this.onMore,
    super.key,
  });
  final CrossProfileResult result;
  final VoidCallback onSelect;
  final ValueChanged<Post> onOpen;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final t = context.t.post.cross_profile;
    final message = switch (result.status) {
      CrossProfileResultStatus.idle => t.select_profile,
      CrossProfileResultStatus.loading => t.loading,
      CrossProfileResultStatus.noMatch => t.no_match,
      CrossProfileResultStatus.unsupported => t.unsupported,
      CrossProfileResultStatus.missingHash => t.missing_hash,
      CrossProfileResultStatus.error => t.failed,
      CrossProfileResultStatus.success =>
        result.complete
            ? t.result_count(count: result.posts.length)
            : t.results_so_far(count: result.posts.length),
    };
    final kindLabel = switch (result.matchKind) {
      PostLookupMatchKind.exactFile => t.exact_file,
      PostLookupMatchKind.pixivSource => t.pixiv_match,
      PostLookupMatchKind.sourceUrl => t.source_match,
      null => null,
    };
    final canSelect =
        result.status != CrossProfileResultStatus.loading &&
        result.status != CrossProfileResultStatus.unsupported;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            key: ValueKey('profile-${result.profile.id}'),
            title: Text(result.profile.name),
            subtitle: Text(
              '${postOriginFromConfig(result.profile).sourceHost}\n$message',
            ),
            isThreeLine: true,
            trailing: result.status == CrossProfileResultStatus.loading
                ? const SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(),
                  )
                : canSelect
                ? const Icon(Icons.refresh)
                : null,
            onTap: canSelect ? onSelect : null,
          ),
          if (kindLabel != null && result.posts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                kindLabel,
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
          for (final post in result.posts)
            ListTile(
              key: ValueKey('match-${result.profile.id}-${post.id}'),
              leading: SizedBox.square(
                dimension: 56,
                child: BooruImage(
                  config: result.profile.auth,
                  imageUrl: post.thumbnailImageUrl,
                  fit: BoxFit.cover,
                ),
              ),
              title: Text('#${post.sitePostId ?? post.id}'),
              trailing: const Icon(Icons.open_in_new),
              onTap: () => onOpen(post),
            ),
          if (!result.complete &&
              result.status == CrossProfileResultStatus.success)
            Padding(
              padding: const EdgeInsets.all(8),
              child: TextButton(onPressed: onMore, child: Text(t.load_more)),
            ),
        ],
      ),
    );
  }
}
