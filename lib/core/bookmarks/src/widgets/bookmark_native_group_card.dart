import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:selection_mode/selection_mode.dart';

import '../../../config_widgets/website_logo.dart';
import '../../../blacklists/providers.dart';
import '../../../configs/config/types.dart';
import '../../../configs/manage/widgets.dart';
import '../../../content/content_access_provider.dart';
import '../../../content/types.dart';
import '../../../content/groups/group_capability.dart';
import '../../../content/groups/group_source_provider.dart';
import '../../../content/groups/group_visibility.dart';
import '../../../images/booru_image.dart';
import '../../../posts/details/src/types/viewer_entry.dart';
import '../../../posts/details/src/providers/viewer_source_access_provider.dart';
import '../../../posts/rating/types.dart';
import '../../../posts/pools/pool_grid_item.dart';
import '../../../selection/selection_input.dart';
import '../../../settings/providers.dart';
import '../providers/bookmark_provider.dart';
import '../types/content_group_bookmark.dart';
import '../types/bookmark_record_fields.dart';
import 'bookmark_access_placeholder.dart';
import 'bookmark_group_picker.dart';

GroupViewerEntry nativeGroupViewerEntryForBookmark(
  WidgetRef ref,
  ContentGroupBookmark bookmark, {
  required Object occurrenceId,
}) => GroupViewerEntry(
  summary: bookmark.summary,
  storedDetails: bookmark.snapshot.details,
  occurrenceId: occurrenceId,
  source: bindViewerOrigin(
    ref,
    nativeBookmarkGroupOrigin(bookmark),
    bookmarkId: bookmark.id,
  ),
);

/// Saved native Group membership editing uses the same frozen local record
/// picker as other saved entries. It cannot implicitly save any member Pages.
class BookmarkNativeGroupCard extends ConsumerWidget {
  const BookmarkNativeGroupCard({
    required this.bookmark,
    required this.index,
    required this.onOpen,
    this.groupId,
    super.key,
  });
  final ContentGroupBookmark bookmark;
  final int index;
  final VoidCallback onOpen;
  final String? groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = SelectionMode.of(context);
    final access = ref.watch(
      contentAccessForReferenceProvider(
        ContentAccessRequest(
          reference: bookmark.reference,
          profileIdHint: bookmark.sourceProfileHint,
        ),
      ),
    );
    final config = access?.config;
    final presentation = ref
        .watch(booruGroupCapabilityProvider(bookmark.reference.engine))
        ?.presentation;
    final card = PoolGridItem(
      category: presentation is BooruGroupKindPresentation
          ? (presentation as BooruGroupKindPresentation).kindLabel(
              context,
              bookmark.summary,
            )
          : null,
      name: bookmark.summary.title,
      total: bookmark.summary.memberCount,
      sourceIcon: ConfigAwareWebsiteLogo.fromBooruType(
        bookmark.reference.engine,
        bookmark.reference.siteNamespace,
        fit: BoxFit.contain,
      ),
      image: BookmarkNativeGroupCover(bookmark: bookmark),
      onTap: () {
        if (!handleSelectionTap(context, index)) onOpen();
      },
    );
    final content = KurumiContextMenu(
      triggers: !selection.isActive,
      menuItemsBuilder: (_) => [
        KurumiContextMenuTile(
          title: context.t.generic.action.view,
          onTap: onOpen,
        ),
        KurumiContextMenuTile(
          title: context.t.post.action.bookmark,
          onTap: () => showBookmarkPickerDialog(
            context,
            request: SavedBookmarkPickerRequest(
              config: config?.auth ?? BooruConfig.empty.auth,
              record: bookmark,
            ),
          ),
        ),
        if (groupId case final groupId?)
          KurumiContextMenuTile(
            title: context.t.generic.action.remove,
            onTap: () async {
              final notifier = ref.read(bookmarkProvider.notifier);
              try {
                final result = await notifier.removeSavedRecordsFromGroup(
                  [bookmark],
                  groupId,
                );
                if (context.mounted) notifier.showRemovalUndo(context, result);
              } catch (_) {
                if (context.mounted)
                  Kurumi.showErrorToast(
                    context,
                    context.t.bookmark.groups.operation_failed,
                  );
              }
            },
          ),
        KurumiContextMenuTile(
          title: context.t.generic.action.select,
          onTap: () => selection.enable(initialSelected: [index]),
        ),
      ],
      child: GestureDetector(
        onLongPress:
            selection.isActive || ref.watch(postGridLongPressOpensMenuProvider)
            ? null
            : () => selection.enable(initialSelected: [index]),
        child: SelectableBuilder(
          index: index,
          builder: (_, selected) => KurumiSelectableItem(
            item: AspectRatio(aspectRatio: .6, child: card),
            onPreview: onOpen,
            isInSelectionMode: selection.isActive,
            isSelected: selected,
          ),
        ),
      ),
    );
    return config == null
        ? content
        : CurrentBooruConfigScope(
            config: config,
            accessKey: access!.key,
            requireAccess: true,
            bookmarkId: bookmark.id,
            child: content,
          );
  }
}

/// The same retained cover/policy/cache path serves native cards and local
/// mosaics. A known cached sample may replace a missing thumbnail; no original
/// or member manifest is requested just to fill a small tile.
class BookmarkNativeGroupCover extends ConsumerWidget {
  const BookmarkNativeGroupCover({
    required this.bookmark,
    this.onFailed,
    super.key,
  });
  final ContentGroupBookmark bookmark;
  final VoidCallback? onFailed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final origin = nativeBookmarkGroupOrigin(bookmark);
    final access = ref.watch(
      contentAccessForReferenceProvider(
        ContentAccessRequest(
          reference: bookmark.reference,
          profileIdHint: bookmark.sourceProfileHint,
        ),
      ),
    );
    final config = access?.config;
    final cover = bookmark.summary.cover;
    if (config == null) return BookmarkAccessPlaceholder(origin: origin);
    if (cover == null) return _NativeCoverFailure(onFailed: onFailed);
    final blacklist = ref.watch(blacklistTagsProvider(config.filter));
    if (!blacklist.hasValue || blacklist.isLoading) {
      return BookmarkAccessPlaceholder(origin: origin);
    }
    final visibility = cover.visibility;
    final rating = Rating.parse(visibility?.rating);
    final allowed =
        !blacklist.hasError &&
        groupAllowsRating(config, rating) &&
        !(visibility?.deleted ?? false) &&
        !(visibility?.banned ?? false) &&
        groupTagsPassBlacklist(
          visibility == null
              ? bookmark.snapshot.details?.tags ?? bookmark.summary.previewTags
              : GroupTags(
                  values: [
                    for (final name in visibility.tags) GroupTag(name: name),
                  ],
                  coverage: visibility.tagCoverage,
                ),
          blacklist.requireValue,
          rating: rating,
          sourceUrl: bookmark.reference.site.toString(),
        );
    if (!allowed) return _NativeCoverFailure(onFailed: onFailed);
    final selectedUrl = cover.thumbnail.toString();
    return CurrentBooruConfigScope(
      config: config,
      accessKey: access!.key,
      requireAccess: true,
      bookmarkId: bookmark.id,
      child: BooruImage(
        imageUrl: selectedUrl,
        config: config.auth,
        fit: BoxFit.cover,
        forceCover: true,
        errorWidget: onFailed == null
            ? null
            : _NativeCoverFailure(
                onFailed: () {
                  onFailed?.call();
                },
              ),
      ),
    );
  }
}

class _NativeCoverFailure extends StatefulWidget {
  const _NativeCoverFailure({this.onFailed});
  final VoidCallback? onFailed;
  @override
  State<_NativeCoverFailure> createState() => _NativeCoverFailureState();
}

class _NativeCoverFailureState extends State<_NativeCoverFailure> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onFailed?.call();
    });
  }

  @override
  Widget build(BuildContext context) =>
      const Center(child: Icon(Icons.photo_library_outlined));
}
