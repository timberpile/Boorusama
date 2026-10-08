enum BookmarkHydrationLogReason {
  updated,
  missingProfile,
  ambiguousProfile,
  missingPostId,
  removedPost,
  unsupportedSnapshot,
  requestFailed,
  saveFailed,
  requestCancelled,
  rateLimited,
}

enum BookmarkHydrationFailureKind {
  unknown,
  connection,
  timeout,
  handshake,
  certificate,
  invalidResponse,
  accessDenied,
  server,
}

class BookmarkHydrationLogEntry {
  const BookmarkHydrationLogEntry({
    required this.timestamp,
    required this.domain,
    required this.bookmarkId,
    required this.postId,
    required this.reason,
    this.httpStatusCode,
    this.retryAt,
    this.failureKind,
    this.errorDetail,
  });

  static const maxEntries = 100;

  final DateTime timestamp;
  final String domain;
  final int bookmarkId;
  final int? postId;
  final BookmarkHydrationLogReason reason;
  final int? httpStatusCode;
  final DateTime? retryAt;
  final BookmarkHydrationFailureKind? failureKind;
  final String? errorDetail;
}
