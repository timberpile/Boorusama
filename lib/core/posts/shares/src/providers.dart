import '../../../bookmarks/src/providers/bookmark_hydration_provider.dart';
import '../../../boorus/booru/types.dart';
import '../../../content/content_access.dart';
import '../../../content/content_access_provider.dart';
import '../../../content/groups/group_source_provider.dart';
import '../../../navigation/destination_activity.dart';
import '../../details/src/providers/viewer_source_access_provider.dart';
import '../../details/src/types/viewer_entry.dart';
import '../../details/src/widgets/group_viewer_scope.dart';
import '../../links/boorusama_group_link.dart';
import '../../links/link_share_message.dart';
import 'share_action_adapter.dart';
import 'share_group_target.dart';

// Package imports:
import 'package:cache_manager/cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../../foundation/display.dart';
import '../../../configs/config/types.dart';
import '../../../configs/manage/providers.dart';
import '../../../content/content_media_access.dart';
import '../../../settings/providers.dart';
import '../../../downloads/filename/types.dart';
import '../../post/types.dart';
import '../../links/boorusama_post_link.dart';
import 'unified_post_share_sheet.dart';

final shareProvider = Provider.autoDispose((ref) => ShareService(ref));

String? profileIconUrlForAuth(
  Iterable<BooruConfig> profiles,
  BooruConfigAuth auth,
) {
  for (final profile in profiles) {
    if (profile.auth == auth) return profile.profileIcon?.url;
  }
  return null;
}

/// Resolve the source profile, not an unrelated active mixed-viewer profile.
String? postShareProfileName(
  Iterable<BooruConfig> profiles,
  Post post,
  BooruConfigAuth auth,
) {
  final matches =
      BoorusamaPostLink.fromPost(
        post,
        auth: auth,
      )?.matchingProfiles(profiles) ??
      const <BooruConfig>[];
  if (matches.isEmpty) return null;

  // A source hint may distinguish accounts on the same site, but it is never
  // included in the shared document.
  final hinted = matches
      .where((profile) => profile.id == post.origin.profileIdHint)
      .firstOrNull;
  final owner =
      hinted ??
      matches.where((profile) => profile.auth == auth).firstOrNull ??
      matches.singleOrNull;
  return owner?.name;
}

class ShareService {
  ShareService(this.ref);

  final Ref ref;

  Future<void> sharePost(
    Post requestedPost,
    BooruConfigAuth config, {
    required BuildContext context,
    required BooruConfigViewer configViewer,
    required BooruConfigDownload download,
    required DownloadFilenameGenerator? filenameBuilder,
    required ImageCacheManager imageCacheManager,
  }) async {
    var post = requestedPost;
    final caller = ProviderScope.containerOf(context, listen: false);
    final accessKey =
        config.anonymousReadScope?.key ??
        caller.read(currentContentAccessKeyProvider);
    final group = GroupViewerScope.maybeEntryOf(context);
    final candidate = group == null ? null : _groupTarget(caller, group);
    final groupTarget = candidate?.access.key == accessKey ? candidate : null;
    if (post.requiresDetailLookup && accessKey != null) {
      final source = caller.read(contentAccessContextProvider(accessKey));
      final reader = source?.config;
      if (reader != null && reader.auth == config) {
        final resolved = await ref
            .read(bookmarkRecoveryServiceProvider)
            .resolveListedPost(post, reader);
        if (!context.mounted ||
            !NavigationActivity.of(context) ||
            GroupViewerScope.maybeEntryOf(context) != group ||
            caller
                    .read(contentAccessContextProvider(accessKey))
                    ?.hasSameAuthorization(source!) !=
                true)
          return;
        post = resolved ?? post;
      }
    }
    final requireAccess =
        config.anonymousReadScope != null ||
        caller.read(contentAccessRequiredProvider);
    final public = config.anonymousReadScope != null;
    final profiles = public
        ? const <BooruConfig>[]
        : ref
              .read(booruConfigProvider)
              .where(
                (profile) =>
                    accessKey?.profileId == null ||
                    profile.id == accessKey!.profileId,
              )
              .toList();
    final profileIconUrl = public
        ? null
        : profileIconUrlForAuth(profiles, config);
    final profileName = postShareProfileName(profiles, post, config);
    final modal = UnifiedPostShareSheet(
      post: post,
      auth: config,
      profileIconUrl: profileIconUrl,
      profileName: profileName,
      viewer: configViewer,
      postQuality: ref.read(postQualityProvider(config)),
      imageCacheManager: imageCacheManager,
      accessKey: accessKey,
      requireAccess: requireAccess,
      group: groupTarget,
    );
    await _show(context, modal);
  }

  Future<void> shareGroup(
    GroupViewerEntry entry, {
    required BuildContext context,
    required ImageCacheManager imageCacheManager,
    ShareActionAdapter? adapter,
  }) async {
    final caller = ProviderScope.containerOf(context, listen: false);
    final group = _groupTarget(caller, entry);
    final config = group?.access.config;
    if (group == null || config == null) return;
    await _show(
      context,
      UnifiedPostShareSheet(
        post: null,
        auth: config.auth,
        viewer: config.viewer,
        imageCacheManager: imageCacheManager,
        accessKey: group.access.key,
        requireAccess: true,
        shareAdapter: adapter,
        group: group,
      ),
    );
  }

  ShareGroupTarget? _groupTarget(
    ProviderContainer caller,
    GroupViewerEntry group,
  ) {
    final binding = group.source;
    if (binding == null) return null;
    final access = caller.read(viewerSourceAccessProvider(binding));
    if (access == null || !access.accepts(group.contentReference)) return null;
    try {
      final reference = group.contentReference;
      final link = BoorusamaGroupLink.fromReference(reference);
      final provider = groupDetailsProvider(
        GroupMetadataKey(reference: reference, access: access.key),
      );
      final details = caller.exists(provider)
          ? caller.read(provider).asData?.value
          : null;
      final stored = group.storedDetails;
      final storedDetails =
          reference.engine == BooruType.pixiv &&
              stored?.summary.reference == reference
          ? stored
          : null;
      return ShareGroupTarget(
        link: link,
        access: access,
        groupName:
            details?.summary.title ??
            storedDetails?.summary.title ??
            group.summary.title,
        author:
            [
                  ...?details?.creators,
                  ...?storedDetails?.creators,
                ]
                .map((creator) => linkShareAuthor(creator.displayName))
                .nonNulls
                .firstOrNull,
      );
    } on FormatException {
      return null;
    }
  }

  Future<void> _show(BuildContext context, UnifiedPostShareSheet modal) async {
    if (!context.mounted) return;
    const routeSettings = RouteSettings(name: 'post_share');

    await (Screen.of(context).size == ScreenSize.small
        ? Kurumi.showModalBottomSheet(
            context: context,
            routeSettings: routeSettings,
            includeAppChromeInsets: false,
            isScrollControlled: true,
            useSafeArea: true,
            builder: (context) => Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: modal,
            ),
          )
        : showDialog(
            context: context,
            routeSettings: routeSettings,
            builder: (context) => KurumiDialog(
              padding: EdgeInsets.zero,
              child: modal,
            ),
          ));
  }
}
