// Package imports:
import 'package:cache_manager/cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../../foundation/display.dart';
import '../../../configs/config/types.dart';
import '../../../configs/manage/providers.dart';
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
String postShareProfileName(
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
  if (matches.isEmpty) return post.origin.sourceHost;

  // A source hint may distinguish accounts on the same site, but it is never
  // included in the shared document.
  final hinted = matches
      .where((profile) => profile.id == post.origin.profileIdHint)
      .firstOrNull;
  final owner =
      hinted ??
      matches.where((profile) => profile.auth == auth).firstOrNull ??
      matches.first;
  return owner.name;
}

class ShareService {
  ShareService(this.ref);

  final Ref ref;

  void sharePost(
    Post post,
    BooruConfigAuth config, {
    required BuildContext context,
    required BooruConfigViewer configViewer,
    required BooruConfigDownload download,
    required DownloadFilenameGenerator? filenameBuilder,
    required ImageCacheManager imageCacheManager,
  }) {
    final profiles = ref.read(booruConfigProvider);
    final profileIconUrl = profileIconUrlForAuth(profiles, config);
    final profileName = postShareProfileName(profiles, post, config);
    final modal = UnifiedPostShareSheet(
      post: post,
      auth: config,
      profileIconUrl: profileIconUrl,
      profileName: profileName,
      viewer: configViewer,
      postQuality: ref.read(postQualityProvider(config)),
      imageCacheManager: imageCacheManager,
    );

    const routeSettings = RouteSettings(name: 'post_share');

    Screen.of(context).size == ScreenSize.small
        ? Kurumi.showModalBottomSheet(
            context: context,
            routeSettings: routeSettings,
            builder: (context) => modal,
          )
        : showDialog(
            context: context,
            routeSettings: routeSettings,
            builder: (context) => AlertDialog(
              contentPadding: EdgeInsets.zero,
              content: modal,
            ),
          );
  }
}
