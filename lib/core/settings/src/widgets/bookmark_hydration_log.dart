import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import '../../../../foundation/clipboard.dart';
import '../../../bookmarks/src/types/bookmark_hydration_log.dart';

class BookmarkHydrationLog extends StatelessWidget {
  const BookmarkHydrationLog({required this.entries, super.key});

  final List<BookmarkHydrationLogEntry> entries;

  @override
  Widget build(BuildContext context) {
    final strings = context.t.bookmark.maintenance;
    final lines = entries.reversed
        .take(BookmarkHydrationLogEntry.maxEntries)
        .map((entry) => _formatEntry(context, entry))
        .toList();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                strings.log_title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.copy),
                label: Text(strings.log_copy),
                onPressed: lines.isEmpty
                    ? null
                    : () async {
                        await AppClipboard.copy(lines.join('\n\n'));
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(strings.log_copied)),
                        );
                      },
              ),
            ],
          ),
          Text(
            strings.log_description.replaceAll(
              '{0}',
              '${BookmarkHydrationLogEntry.maxEntries}',
            ),
          ),
          const SizedBox(height: 12),
          if (lines.isEmpty) Text(strings.log_empty),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(line),
            ),
        ],
      ),
    );
  }

  String _formatEntry(BuildContext context, BookmarkHydrationLogEntry entry) {
    final strings = context.t.bookmark.maintenance;
    final domain = entry.domain.isEmpty
        ? strings.log_unknown_domain
        : entry.domain;
    final identity = entry.postId != null && entry.postId! > 0
        ? strings.log_post.replaceAll('{0}', '${entry.postId}')
        : strings.log_bookmark.replaceAll('{0}', '${entry.bookmarkId}');
    final reason = switch (entry.reason) {
      BookmarkHydrationLogReason.updated => strings.log_updated,
      BookmarkHydrationLogReason.missingProfile => strings.log_missing_profile,
      BookmarkHydrationLogReason.ambiguousProfile =>
        strings.log_ambiguous_profile,
      BookmarkHydrationLogReason.missingPostId => strings.log_missing_post_id,
      BookmarkHydrationLogReason.removedPost => strings.log_removed_post,
      BookmarkHydrationLogReason.unsupportedSnapshot =>
        strings.log_unsupported_snapshot,
      BookmarkHydrationLogReason.requestFailed => switch (entry.failureKind) {
        BookmarkHydrationFailureKind.connection =>
          strings.log_connection_failed,
        BookmarkHydrationFailureKind.timeout => strings.log_timeout,
        BookmarkHydrationFailureKind.handshake => strings.log_handshake_failed,
        BookmarkHydrationFailureKind.certificate =>
          strings.log_certificate_failed,
        BookmarkHydrationFailureKind.invalidResponse =>
          strings.log_invalid_response,
        BookmarkHydrationFailureKind.accessDenied => strings.log_access_denied,
        BookmarkHydrationFailureKind.server => strings.log_server_failed,
        _ => strings.log_request_failed,
      },
      BookmarkHydrationLogReason.saveFailed => strings.log_save_failed,
      BookmarkHydrationLogReason.requestCancelled =>
        strings.log_request_cancelled,
      BookmarkHydrationLogReason.rateLimited =>
        strings.log_rate_limited.replaceAll(
          '{0}',
          entry.retryAt?.toUtc().toIso8601String() ?? '',
        ),
    };
    final status = entry.httpStatusCode == null
        ? ''
        : ' (HTTP ${entry.httpStatusCode})';
    final detail = entry.errorDetail == null || entry.errorDetail!.isEmpty
        ? ''
        : ' — ${entry.errorDetail}';
    return '[${entry.timestamp.toUtc().toIso8601String()}] $domain · $identity\n$reason$status$detail';
  }
}
