import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import '../../../core/blacklists/providers.dart';
import '../../../core/bookmarks/src/types/content_group_bookmark.dart';
import '../../../core/bookmarks/src/types/stored_group_snapshot.dart';
import '../../../core/bookmarks/src/widgets/bookmark_group_picker.dart';
import '../../../core/bookmarks/src/widgets/scoped_bookmark_button.dart';
import '../../../core/bookmarks/src/widgets/selected_content_groups_bookmark_button.dart';
import '../../../core/boorus/booru/types.dart';
import '../../../core/configs/config/types.dart';
import '../../../core/content/capabilities.dart';
import '../../../core/content/content_access_provider.dart';
import '../../../core/content/groups/group_visibility.dart';
import '../../../core/content/types.dart';
import '../../../core/http/client/coordination.dart';
import '../../../core/posts/details/src/widgets/group_media_timeline.dart';
import '../../../core/posts/details/src/widgets/group_viewer_scope.dart';
import '../../../core/posts/pools/group_summary_card.dart';
import '../../../core/posts/pools/pool_grid_item.dart';
import '../../../core/posts/rating/types.dart';
import '../availability.dart';
import '../client_provider.dart';
import '../favorites/control.dart';
import '../posts/data.dart';
import '../tags/providers.dart';
import 'mapper.dart';
import 'source.dart';

BooruGroupCapability createNhentaiGroupCapability(Ref _) =>
    BooruGroupCapability(
      engine: BooruType.nhentai,
      keyCodec: const BooruContentKeyCodec(BooruType.nhentai),
      createSource: (ref, access) {
        if (!ref.read(nhentaiAvailableProvider)) {
          throw StateError('Gallery source unavailable');
        }
        final config = access.config!;
        final client = ref.read(nhentaiClientProvider(config.auth));
        return NhentaiGallerySource(
          access: access,
          mediaPolicy: () =>
              ref.read(nhentaiMediaPolicyProvider(config.auth).future),
          fetchGallery: (id) async {
            final request = ApiRequestContext.current();
            final result = await client.getGallery(
              id,
              cancelToken: request.cancelToken,
            );
            final blacklist = switch (access.key.profileId) {
              final profileId? =>
                ref
                    .read(contentEffectiveBlacklistProvider(profileId))
                    .requireValue,
              null => {
                for (final tag
                    in ref.read(globalBlacklistedTagsProvider).requireValue)
                  if (tag.isActive) tag.name,
              },
            };
            if ((result.blacklisted ?? false) ||
                !(request.canAdmit?.call() ?? true) ||
                !groupAllowsRating(config, Rating.unknown) ||
                !groupTagsPassBlacklist(
                  nhentaiGroupTags(result),
                  blacklist,
                  rating: Rating.unknown,
                  sourceId: id,
                  sourceUrl: 'https://nhentai.net/g/$id/',
                )) {
              throw StateError('Gallery unavailable under current policy');
            }
            unawaited(
              ref
                  .read(nhentaiTagCacheProvider(config.auth))
                  .remember(result.tags)
                  .onError((_, _) {}),
            );
            return result;
          },
        );
      },
      presentation: const NhentaiGroupPresentation(),
    );

class NhentaiGroupPresentation
    implements
        BooruGroupPresentation,
        BooruMediaGroupFavoritePresentation,
        BooruScopedGroupBookmarkPresentation,
        BooruGroupKindPresentation,
        BooruGroupSelectionPresentation {
  const NhentaiGroupPresentation();

  @override
  bool supports(ContentGroupSummary summary) =>
      summary.reference.engine == BooruType.nhentai &&
      summary.reference.sourceKey.startsWith('gallery:');

  @override
  GroupLayout layoutFor(ContentGroupSummary summary) => GroupLayout.mediaPager;

  @override
  String memberLabel(BuildContext context, ContentGroupSummary summary) =>
      context.t.content_viewer.pages;

  @override
  String kindLabel(BuildContext context, ContentGroupSummary summary) =>
      context.t.content_viewer.gallery;

  @override
  Widget buildCard(BuildContext context, ContentGroupSummary summary) =>
      GroupSummaryCard(summary: summary, kind: PoolGridItemKind.collection);

  @override
  Widget buildDetails(BuildContext context, ContentGroupDetails details) =>
      switch (GroupViewerScope.maybeEntryOf(context)) {
        final entry? => GroupMediaTimeline(
          entry: entry,
          favorite: (state) => switch (state.access) {
            final access? when !state.failed && state.details != null =>
              NhentaiFavoriteControl(
                access: access,
                galleryId: nhentaiIdFromReference(details.summary.reference),
              ),
            _ => null,
          },
        ),
        _ => const SizedBox.shrink(),
      };

  @override
  Widget buildFavoriteActions(
    ContentAccessContext access,
    ContentGroupSummary summary, {
    required bool detailsVerified,
    required bool Function() isCurrent,
    required FavoriteActionRowBuilder builder,
  }) => Builder(
    builder: (context) => detailsVerified
        ? NhentaiFavoriteControl(
            access: access,
            galleryId: nhentaiIdFromReference(summary.reference),
            isOwnerCurrent: isCurrent,
            builder: builder,
          )
        : builder(context, const []),
  );

  @override
  List<Widget> buildSelectionActions(
    BuildContext context,
    List<GroupBookmarkPresentationData> groups,
  ) => [
    SelectedContentGroupsBookmarkButton(
      groups: groups,
      supports: (data) =>
          supports(data.summary) && data.access.key.profileId != null,
      request: (_, data) =>
          nhentaiBookmarkRequest(data, wholeGroup: true)!
              as ContentGroupBookmarkPickerRequest,
    ),
  ];

  @override
  Widget buildScopedBookmarkButton(
    BuildContext context,
    GroupBookmarkPresentationData data, {
    required bool wholeGroup,
  }) {
    // Picker ownership follows Gallery identity and authorization while
    // Details fill in. Capture the actual snapshot only when the picker opens.
    final owner = wholeGroup
        ? nhentaiBookmarkRequest(
            GroupBookmarkPresentationData(
              access: data.access,
              summary: ContentGroupSummary(reference: data.summary.reference),
            ),
            wholeGroup: true,
            observedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
          )
        : nhentaiBookmarkRequest(data, wholeGroup: false);
    return ScopedBookmarkButton(
      request: owner,
      requestBuilder: owner == null || !wholeGroup
          ? null
          : () => nhentaiBookmarkRequest(data, wholeGroup: true)!,
      scope: wholeGroup
          ? BookmarkTargetScope.group
          : BookmarkTargetScope.member,
      label: wholeGroup
          ? context.t.content_viewer.bookmark_gallery
          : context.t.content_viewer.bookmark_page,
    );
  }
}

BookmarkPickerRequest? nhentaiBookmarkRequest(
  GroupBookmarkPresentationData data, {
  required bool wholeGroup,
  DateTime? observedAt,
}) {
  final access = data.access;
  final config = access.config;
  final reference = data.summary.reference;
  if (config == null ||
      access.key.profileId == null ||
      !const NhentaiGroupPresentation().supports(data.summary) ||
      !access.accepts(reference) ||
      (data.details != null && data.details!.summary.reference != reference)) {
    return null;
  }
  if (!wholeGroup) {
    final post = data.page;
    final facts = post?.booruData;
    if (post == null ||
        facts is! NhentaiPostData ||
        reference.sourceKey != 'gallery:${facts.galleryId}' ||
        post.origin.booruType != access.key.engine ||
        post.origin.sourceHost != access.key.siteNamespace ||
        post.origin.profileIdHint != access.key.profileId) {
      return null;
    }
    return PostBookmarkPickerRequest(
      config: config.auth,
      source: config,
      access: access.key,
      post: post,
    );
  }
  final at = observedAt ?? DateTime.now().toUtc();
  final tags = data.details?.tags ?? data.summary.previewTags;
  return ContentGroupBookmarkPickerRequest(
    source: config,
    access: access.key,
    draft: ContentGroupBookmark(
      id: 0,
      snapshot: StoredGroupSnapshot(
        summary: data.summary,
        details: data.details,
        index: tags == null
            ? null
            : GroupBookmarkIndex(
                tags: {for (final tag in tags.values) ?tag.name},
                basis: GroupTagIndexBasis.sourceGroup,
                coverage: tags.coverage,
              ),
      ),
      createdAt: at,
      observedAt: at,
      sourceProfileHint: access.key.profileId,
    ),
  );
}
