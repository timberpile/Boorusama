// Project imports:
import '../../../post/types.dart';

enum PostLookupMatchKind { exactFile, pixivSource, sourceUrl }

enum PixivLookupCoverageIssue {
  authentication,
  restricted,
  originalsUnavailable,
  ugoira,
}

sealed class PostLookupResult {
  const PostLookupResult();
}

/// One validated, visibility-filtered page from the selected profile.
final class PostLookupPage extends PostLookupResult {
  PostLookupPage({
    required this.targetOrigin,
    required List<Post> posts,
    required this.page,
    required this.hasMore,
    required this.hasFilteredMatches,
    this.matchKind = PostLookupMatchKind.exactFile,
    this.coverageIssue,
  }) : posts = List.unmodifiable(posts);

  final PostLookupMatchKind matchKind;
  final PostOrigin targetOrigin;
  final List<Post> posts;
  final int page;
  final bool hasMore;
  final PixivLookupCoverageIssue? coverageIssue;

  /// Distinguishes known local filtering from an ordinary empty result without
  /// retaining the hidden posts or exposing their metadata to the picker.
  final bool hasFilteredMatches;

  /// A single item on an incomplete or later page is not a unique result.
  bool get canOpenDirectly =>
      page == 1 && posts.length == 1 && !hasMore && coverageIssue == null;
}

enum PostLookupUnavailableReason {
  unsupported,
  missingHash,
  invalidTarget,
}

final class PostLookupUnavailable extends PostLookupResult {
  const PostLookupUnavailable(this.reason);

  final PostLookupUnavailableReason reason;
}

/// The response cannot establish an exact match in the selected profile.
/// Treat this as a lookup failure, not as evidence that the post does not exist.
final class PostLookupInvalidResponse extends PostLookupResult {
  const PostLookupInvalidResponse();
}

final class PostLookupFailed extends PostLookupResult {
  const PostLookupFailed(this.error);

  /// Preserve typed repository errors for safe, localized presentation. Never
  /// display or log the raw object: transport errors can contain credentials.
  final Object error;
}

final class PostLookupCancelled extends PostLookupResult {
  const PostLookupCancelled();
}

/// Discards late completions after dismissal or a different target selection.
/// This does not abort the underlying repository's HTTP request.
final class PostLookupCancellation {
  var _isCancelled = false;

  bool get isCancelled => _isCancelled;

  void cancel() => _isCancelled = true;
}
