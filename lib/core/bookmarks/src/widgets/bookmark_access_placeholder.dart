import '../providers/bookmark_read_access.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import '../../../blacklists/providers.dart';
import '../../../configs/config/types.dart';
import '../../../content/content_access_provider.dart';
import '../../../posts/post/types.dart';

void retryBookmarkPolicy(
  WidgetRef ref,
  PostOrigin origin, {
  BookmarkReaderRequest? reader,
}) {
  final config = selectBookmarkReadProfile(
    reader ?? BookmarkReaderRequest(origin),
    ref.read(bookmarkReadProfilesProvider),
  );
  if (config != null) {
    ref.invalidate(blacklistedTagsNotifierProvider(config.filter));
    ref.invalidate(blacklistTagsProvider(config.filter));
    ref.invalidate(contentEffectiveBlacklistProvider(config.id));
    ref.invalidate(contentEffectivePolicyProvider(config.id));
  } else {
    ref.invalidate(globalBlacklistedTagsProvider);
  }
}

/// Occupied slots retain geometry while access policy is unresolved or denied.
class BookmarkAccessPlaceholder extends ConsumerWidget {
  const BookmarkAccessPlaceholder({
    required this.origin,
    this.aspectRatio = 1,
    this.reader,
    super.key,
  });
  final PostOrigin origin;
  final BookmarkReaderRequest? reader;
  final double aspectRatio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = selectBookmarkReadProfile(
      reader ?? BookmarkReaderRequest(origin),
      ref.watch(bookmarkReadProfilesProvider),
    );
    final policy = config != null
        ? ref.watch(contentEffectivePolicyProvider(config.id))
        : ref.watch(globalBlacklistedTagsProvider).whenData((_) => "public");
    final loading = policy.isLoading;
    return AspectRatio(
      aspectRatio: aspectRatio.isFinite && aspectRatio > 0 ? aspectRatio : 1,
      child: ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Center(
          child: loading
              ? Semantics(
                  label: context.t.bookmark.loading,
                  child: const SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : IconButton(
                  tooltip: context.t.bookmark.unavailable_temporary,
                  icon: const Icon(Icons.cloud_off_outlined),
                  onPressed: () =>
                      retryBookmarkPolicy(ref, origin, reader: reader),
                ),
        ),
      ),
    );
  }
}
