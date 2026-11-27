import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import '../../blacklists/providers.dart';
import '../../config_widgets/website_logo.dart';
import '../../configs/config/types.dart';
import '../../configs/manage/providers.dart';
import '../../images/booru_image.dart';
import '../details/routes.dart';
import '../details/src/types/viewer_entry.dart';
import '../post/providers.dart';
import '../post/types.dart';
import 'lookup_selector.dart';
import 'providers.dart';
import 'types.dart';

enum CrossProfileResultStatus {
  idle,
  loading,
  success,
  noMatch,
  unsupported,
  permissionRequired,
  missingHash,
  incomplete,
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
    this.coverageIssue,
    this.hasMore,
    this.scores = const {},
  });

  final BooruConfig profile;
  final CrossProfileResultStatus status;
  final List<Post> posts;
  final bool complete;
  final PostLookupMatchKind? matchKind;
  final PixivLookupCoverageIssue? coverageIssue;
  final bool? hasMore;
  final Map<int, double> scores;
  bool get canLoadMore => hasMore ?? !complete;
}

Future<void> openCrossProfileResults(
  WidgetRef ref,
  Iterable<CrossProfileResult> rows,
  BooruConfig selectedProfile,
  Post selectedPost, {
  bool Function(CrossProfileResult)? canOpen,
}) async {
  final profiles = ref.read(booruConfigProvider);
  final filters = {
    for (final row in rows)
      if (row.posts.isNotEmpty && profiles.contains(row.profile))
        row.profile: blacklistTagsProvider(row.profile.filter),
  };
  final subscriptions = [
    for (final provider in filters.values.toSet())
      ref.listenManual(provider, (_, _) {}),
  ];
  try {
    await Future.wait([
      for (final provider in filters.values.toSet())
        ref
            .read(provider.future)
            .timeout(const Duration(seconds: 10))
            .then<void>(
              (_) {},
              onError: (Object _, StackTrace _) {},
            ),
    ]);
    if (!ref.context.mounted ||
        ModalRoute.of(ref.context)?.isCurrent == false) {
      return;
    }
    final currentProfiles = ref.read(booruConfigProvider);
    final entries = <PostViewerEntry>[];
    final seen = <(String, String)>{};
    var initialIndex = -1;
    for (final row in rows) {
      final profile = row.profile;
      final provider = filters[profile];
      if (provider == null ||
          !currentProfiles.contains(profile) ||
          canOpen?.call(row) == false) {
        continue;
      }
      final state = ref.read(provider);
      final tags = state.isLoading ? null : state.asData?.value;
      if (tags == null) continue;
      for (final post in row.posts) {
        final key = (profile.id, post.sitePostId ?? post.id.toString());
        if (post.origin != postOriginFromConfig(profile) ||
            !isExactLookupPostVisible(post, profile, tags) ||
            !seen.add(key)) {
          continue;
        }
        if (profile == selectedProfile &&
            key.$2 == (selectedPost.sitePostId ?? selectedPost.id.toString())) {
          initialIndex = entries.length;
        }
        entries.add(
          PostViewerEntry(
            post: post,
            occurrenceId: key,
            source: ViewerSourceBinding(profile),
          ),
        );
      }
    }
    if (initialIndex < 0) return;
    goToPostDetailsPageCore(
      ref: ref,
      posts: [for (final entry in entries) entry.post],
      entries: entries,
      initialIndex: initialIndex,
      initialThumbnailUrl: selectedPost.thumbnailImageUrl,
      hero: false,
      config: selectedProfile,
    );
  } finally {
    for (final subscription in subscriptions) {
      subscription.close();
    }
  }
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
        Column(
          key: const ValueKey('unsupported-profiles'),
          children: [
            for (final result in results.where(
              (r) => r.status == CrossProfileResultStatus.unsupported,
            ))
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: _ProfileIcon(profile: result.profile),
                title: Text(result.profile.name),
                dense: true,
              ),
          ],
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
    this.showMethod = false,
    super.key,
  });
  final bool showMethod;
  final CrossProfileResult result;
  final VoidCallback onSelect;
  final ValueChanged<Post> onOpen;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final t = context.t.post.cross_profile;
    final coverageMessage = switch (result.coverageIssue) {
      PixivLookupCoverageIssue.authentication => t.pixiv_auth_required,
      PixivLookupCoverageIssue.restricted => t.originals_restricted,
      PixivLookupCoverageIssue.ugoira => t.ugoira_hash_unavailable,
      PixivLookupCoverageIssue.originalsUnavailable => t.originals_incomplete,
      null => null,
    };
    final message = switch (result.status) {
      CrossProfileResultStatus.idle => t.select_profile,
      CrossProfileResultStatus.loading => t.loading,
      CrossProfileResultStatus.noMatch => t.no_match,
      CrossProfileResultStatus.unsupported => t.unsupported,
      CrossProfileResultStatus.permissionRequired => t.iqdb_permission_required,
      CrossProfileResultStatus.missingHash => t.missing_hash,
      CrossProfileResultStatus.error => t.failed,
      CrossProfileResultStatus.incomplete =>
        coverageMessage ?? t.originals_incomplete,
      CrossProfileResultStatus.success => null,
    };
    final kindLabel = switch (result.matchKind) {
      PostLookupMatchKind.exactFile => t.exact_file,
      PostLookupMatchKind.pixivSource => t.pixiv_match,
      PostLookupMatchKind.sourceUrl => t.source_match,
      PostLookupMatchKind.similarImage => t.similar_image,
      null => null,
    };
    final canSelect =
        result.status != CrossProfileResultStatus.loading &&
        result.status != CrossProfileResultStatus.unsupported &&
        result.status != CrossProfileResultStatus.permissionRequired;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            key: ValueKey('profile-${result.profile.id}'),
            leading: _ProfileIcon(profile: result.profile),
            title: Text(
              showMethod && result.matchKind != null
                  ? lookupMethodLabel(context, result.matchKind!)
                  : result.profile.name,
            ),
            subtitle: message == null ? null : Text(message),
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
          if (coverageMessage != null &&
              result.status != CrossProfileResultStatus.incomplete)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(coverageMessage),
            ),
          if (!showMethod && kindLabel != null && result.posts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                kindLabel,
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
          if (result.posts.isNotEmpty)
            GridView.builder(
              shrinkWrap: true,
              primary: false,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: result.posts.length,
              itemBuilder: (context, index) {
                final post = result.posts[index];
                final id = '#${post.sitePostId ?? post.id}';
                final rawScore = result.scores[post.id];
                final score = rawScore == null
                    ? null
                    : t.similarity_score(score: rawScore.toStringAsFixed(1));
                final label = score == null ? id : '$id · $score';
                final image = BooruImage(
                  config: result.profile.auth,
                  imageUrl: post.thumbnailImageUrl,
                  fit: BoxFit.cover,
                );
                return Semantics(
                  button: true,
                  label: label,
                  child: Tooltip(
                    message: label,
                    excludeFromSemantics: true,
                    child: InkWell(
                      key: ValueKey('match-${result.profile.id}-${post.id}'),
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => onOpen(post),
                      child: score == null
                          ? image
                          : Stack(
                              fit: StackFit.expand,
                              children: [
                                image,
                                Align(
                                  alignment: Alignment.bottomCenter,
                                  child: ColoredBox(
                                    color: Colors.black87,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      child: Text(
                                        score,
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                );
              },
            ),
          if (result.canLoadMore &&
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

class _ProfileIcon extends StatelessWidget {
  const _ProfileIcon({required this.profile});

  final BooruConfig profile;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 24,
    child: ConfigAwareWebsiteLogo.fromConfig(
      profile.auth,
      width: 24,
      height: 24,
      customIconUrl: profile.profileIcon?.url,
    ),
  );
}
