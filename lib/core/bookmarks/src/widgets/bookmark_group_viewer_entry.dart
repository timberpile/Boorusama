import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../configs/manage/providers.dart';
import '../../../configs/config/types.dart';
import '../../../content/types.dart';
import '../../../content/anonymous_access_provider.dart';
import '../../../posts/details/src/providers/viewer_source_access_provider.dart';
import '../../../posts/details/src/types/viewer_entry.dart';
import '../../../posts/post/types.dart';
import '../providers/pool_bookmark_provider.dart';
import '../types/pool_bookmark.dart';

/// Native records carry their proven locator. Retained v9 records may use only
/// an explicitly resolved matching profile's URL, never an inferred HTTPS host.
ViewerEntry groupViewerEntryForBookmark(
  WidgetRef ref,
  CollectionBookmark pool, {
  required Object occurrenceId,
}) {
  final reference = bookmarkGroupReference(pool, ref.read(booruConfigProvider));
  if (reference == null) {
    return UnavailableGroupViewerEntry(
      occurrenceId: occurrenceId,
      related: pool.isRelated,
    );
  }
  var binding = bindViewerOrigin(ref, pool.origin, bookmarkId: pool.bookmarkId);
  if (binding?.publicOrigin != null &&
      ref
              .read(anonymousSourcePolicyProvider)
              .resolve(reference.engine, reference.site) ==
          null)
    binding = null;
  return GroupViewerEntry(
    summary: pool.loadedDetails?.summary.reference == reference
        ? pool.loadedDetails!.summary
        : ContentGroupSummary(
            reference: reference,
            title: pool.isRelated ? null : pool.title,
            memberCount: pool.total,
            displayCategory:
                pool.isRelated ||
                    pool.category == BookmarkedPoolCategory.unknown
                ? null
                : pool.category.name,
          ),
    occurrenceId: occurrenceId,
    source: binding,
  );
}

ContentReference? bookmarkGroupReference(
  CollectionBookmark pool,
  List<BooruConfig> profiles,
) {
  final profile = resolvePoolBookmarkProfile(
    pool,
    profiles,
  );
  final site =
      pool.sourceSite ?? (profile == null ? null : Uri.tryParse(profile.url));
  if (site == null ||
      pool.sourceTypeId != pool.origin.booruType.id ||
      normalizePostSourceHost(site.toString()) != pool.origin.sourceHost) {
    return null;
  }
  try {
    return const ContentReferenceCodec().parse(
      engine: pool.origin.booruType,
      site: site,
      kind: ContentKind.group,
      sourceKey: '${pool.isRelated ? 'related' : 'pool'}:${pool.referenceId}',
    );
  } on FormatException {
    return null;
  }
}
