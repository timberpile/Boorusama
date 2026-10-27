import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import '../../config_widgets/website_logo.dart';
import '../../configs/config/types.dart';
import '../../images/booru_image.dart';
import '../post/types.dart';
import 'types.dart';

enum CrossProfileResultStatus {
  idle,
  loading,
  success,
  noMatch,
  unsupported,
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
  });

  final BooruConfig profile;
  final CrossProfileResultStatus status;
  final List<Post> posts;
  final bool complete;
  final PostLookupMatchKind? matchKind;
  final PixivLookupCoverageIssue? coverageIssue;
  final bool? hasMore;
  bool get canLoadMore => hasMore ?? !complete;
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
    super.key,
  });
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
            leading: _ProfileIcon(profile: result.profile),
            title: Text(result.profile.name),
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
          if (kindLabel != null && result.posts.isNotEmpty)
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
                final label = '#${post.sitePostId ?? post.id}';
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
                      child: BooruImage(
                        config: result.profile.auth,
                        imageUrl: post.thumbnailImageUrl,
                        fit: BoxFit.cover,
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
