import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../configs/config/types.dart';

import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import '../../../../bookmarks/src/types/pool_bookmark_capability.dart';
import '../../../../bookmarks/src/types/pool_bookmark.dart';
import '../../../../bookmarks/src/widgets/bookmark_group_picker.dart';
import '../../../../bookmarks/src/widgets/scoped_bookmark_button.dart';
import '../../../../content/groups/group_capability.dart';
import '../../../../content/groups/group_source_provider.dart';
import '../../../../content/types.dart';
import '../../../post/types.dart';
import '../../../related/related_family.dart';
import '../../../related/related_posts_order_value.dart';
import '../providers/group_reading_provider.dart';
import '../providers/viewer_source_access_provider.dart';
import '../types/viewer_entry.dart';

class GroupScopedBookmarkButton extends ConsumerWidget {
  const GroupScopedBookmarkButton({
    required this.entry,
    required this.wholeGroup,
    this.post,
    this.metadata,
    this.cachedMembers = const [],
    super.key,
  });
  final GroupViewerEntry entry;
  final bool wholeGroup;
  final Post? post;
  final GroupBookmarkPresentationData? metadata;
  final List<Post> cachedMembers;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final binding = entry.source;
    final access = binding == null
        ? null
        : ref.watch(viewerSourceAccessProvider(binding));
    final reference = entry.contentReference;
    final reading = ref.watch(groupReadingProvider(entry));
    final presentation = ref
        .watch(booruGroupCapabilityProvider(reference.engine))
        ?.presentation;
    final valid =
        access != null && access.config != null && access.accepts(reference);
    final details = metadata != null
        ? metadata!.details
        : !valid
        ? null
        : ref
              .watch(
                groupDetailsProvider(
                  GroupMetadataKey(reference: reference, access: access.key),
                ),
              )
              .asData
              ?.value;
    if (valid && presentation is BooruScopedGroupBookmarkPresentation) {
      return (presentation! as BooruScopedGroupBookmarkPresentation)
          .buildScopedBookmarkButton(
            context,
            GroupBookmarkPresentationData(
              access: access,
              summary: details?.summary ?? entry.summary,
              details: details,
              page: post,
            ),
            wholeGroup: wholeGroup,
          );
    }
    BookmarkPickerRequest? request;
    if (valid) {
      final config = access.config!;
      if (!wholeGroup) {
        final page = post;
        if (page != null &&
            page.origin.booruType == reference.engine &&
            page.origin.sourceHost == reference.siteNamespace &&
            page.origin.profileIdHint == access.key.profileId) {
          request = PostBookmarkPickerRequest(
            config: config.auth,
            source: config,
            access: access.key,
            post: page,
          );
        }
      } else if (reference.sourceKey.startsWith('related:') &&
          !reading.initializing) {
        request = RelatedBookmarkPickerRequest(
          config: config,
          family: RelatedFamilyReference(
            origin: PostOrigin.fromSource(
              booruType: reference.engine,
              booruId: reference.engine.id,
              source: reference.site.toString(),
            ),
            anchorId: int.parse(
              reference.sourceKey.substring('related:'.length),
            ),
          ),
          visibleOrder: RelatedPostsOrder.values.byName(reading.orderKey!),
          cachedMembers: List.unmodifiable(cachedMembers.take(40)),
        );
      } else if (reference.sourceKey.startsWith('pool:')) {
        final summary = details?.summary ?? entry.summary;
        request = RemotePoolBookmarkPickerRequest(
          config: config,
          pool: RemoteBookmarkPool(
            id: int.parse(reference.sourceKey.substring('pool:'.length)),
            title: summary.title ?? '',
            total: summary.memberCount,
            supportsUploadOrder: true,
            category: switch (summary.displayCategory) {
              'series' => BookmarkedPoolCategory.series,
              'collection' => BookmarkedPoolCategory.collection,
              _ => BookmarkedPoolCategory.unknown,
            },
          ),
        );
      }
    }
    return ScopedBookmarkButton(
      request: request,
      scope: wholeGroup
          ? BookmarkTargetScope.group
          : BookmarkTargetScope.member,
      label: wholeGroup
          ? reference.sourceKey.startsWith('related:')
                ? context.t.bookmark.bookmark_related
                : context.t.content_viewer.bookmark_group
          : context.t.content_viewer.bookmark_post,
      authorized: valid,
    );
  }
}
