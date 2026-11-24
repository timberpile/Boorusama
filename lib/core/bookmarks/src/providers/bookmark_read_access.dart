import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../configs/config/types.dart';
import '../../../boorus/engine/providers.dart';
import '../../../content/groups/group_source_provider.dart';
import '../../../configs/manage/providers.dart';
import '../../../content/anonymous_access_provider.dart';
import '../../../content/content_access_provider.dart';
import '../../../content/types.dart';
import '../../../posts/details/src/types/viewer_entry.dart';
import '../../../posts/links/boorusama_post_link.dart';
import '../../../posts/post/types.dart';
import '../../../settings/providers.dart';

/// A saved locator, independent of local/publisher account hints.
final class BookmarkReaderRequest extends Equatable {
  const BookmarkReaderRequest(
    this.origin, {
    this.site,
    this.kind = ContentKind.post,
  });
  factory BookmarkReaderRequest.reference(ContentReference reference) =>
      BookmarkReaderRequest(
        PostOrigin.fromSource(
          booruType: reference.engine,
          booruId: reference.engine.id,
          source: reference.site.toString(),
        ),
        site: reference.site,
        kind: reference.kind,
      );
  final PostOrigin origin;
  final Uri? site;
  final ContentKind kind;
  @override
  List<Object?> get props => [origin.booruType, origin.sourceHost, site, kind];
}

/// Stored order may contain stale or duplicate IDs; neither hides a profile.
List<BooruConfig> bookmarkReadProfiles(
  Iterable<BooruConfig> profiles,
  Iterable<String> order,
) {
  final remaining = {for (final profile in profiles) profile.id: profile};
  return [for (final id in order) ?remaining.remove(id), ...remaining.values];
}

BooruConfig? selectBookmarkReadProfile(
  BookmarkReaderRequest target,
  Iterable<BooruConfig> profiles,
) {
  for (final profile in profiles) {
    if (profile.auth.booruType != target.origin.booruType ||
        normalizePostSourceHost(profile.url) != target.origin.sourceHost) {
      continue;
    }
    try {
      final site = BoorusamaPostLink.parseSourceSite(profile.url);
      if (target.site != null &&
          site != BoorusamaPostLink.parseSourceSite(target.site.toString())) {
        continue;
      }
      return profile;
    } on FormatException {
      continue;
    }
  }
  return null;
}

final bookmarkReadProfilesProvider = Provider<List<BooruConfig>>(
  (ref) {
    final profiles = ref.watch(booruConfigProvider);
    if (profiles.length < 2) return profiles;
    return bookmarkReadProfiles(
      profiles,
      ref.watch(
        settingsProvider.select((value) => value.booruConfigIdOrderList),
      ),
    );
  },
  dependencies: [booruConfigProvider, settingsProvider],
);

/// Selection is lazy: an unavailable/loading first actor never authorizes a
/// second account or an anonymous downgrade. Active viewers capture this actor.
final bookmarkReadAdapterProvider =
    Provider.family<bool, BookmarkReaderRequest>(
      (ref, target) {
        return switch (target.kind) {
          ContentKind.post =>
            ref.watch(booruPostCapabilityProvider(target.origin.booruType)) !=
                null,
          ContentKind.group =>
            ref.watch(booruGroupCapabilityProvider(target.origin.booruType)) !=
                null,
        };
      },
      dependencies: [booruPostCapabilityProvider, booruGroupCapabilityProvider],
    );

final bookmarkReadAccessProvider = Provider.autoDispose
    .family<ContentAccessContext?, BookmarkReaderRequest>(
      (ref, target) {
        final profile = selectBookmarkReadProfile(
          target,
          ref.watch(bookmarkReadProfilesProvider),
        );
        if (profile != null) {
          return ref.watch(contentProfileAccessProvider(profile.id));
        }
        final policy = ref.watch(anonymousSourcePolicyProvider);
        final source = target.site == null
            ? policy.forNamespace(
                target.origin.booruType,
                target.origin.sourceHost,
              )
            : policy.resolve(target.origin.booruType, target.site!);
        if (source == null ||
            !ref.watch(bookmarkReadAdapterProvider(target)) ||
            normalizePostSourceHost(source.site.toString()) !=
                target.origin.sourceHost) {
          return null;
        }
        return ref.watch(anonymousContentAccessProvider(source));
      },
      dependencies: [
        bookmarkReadProfilesProvider,
        contentProfileAccessProvider,
        anonymousSourcePolicyProvider,
        anonymousContentAccessProvider,
        bookmarkReadAdapterProvider,
      ],
    );

ViewerSourceBinding? bookmarkReadBinding(
  WidgetRef ref,
  BookmarkReaderRequest target, {
  int? bookmarkId,
}) {
  final profile = selectBookmarkReadProfile(
    target,
    ref.read(bookmarkReadProfilesProvider),
  );
  if (profile != null) {
    return ViewerSourceBinding(profile, bookmarkId: bookmarkId);
  }
  final policy = ref.read(anonymousSourcePolicyProvider);
  final source = target.site == null
      ? policy.forNamespace(target.origin.booruType, target.origin.sourceHost)
      : policy.resolve(target.origin.booruType, target.site!);
  return source == null ||
          !ref.read(bookmarkReadAdapterProvider(target)) ||
          normalizePostSourceHost(source.site.toString()) !=
              target.origin.sourceHost
      ? null
      : ViewerSourceBinding.publicRead(target.origin, bookmarkId: bookmarkId);
}
