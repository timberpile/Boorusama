// Package imports:
import 'package:cache_manager/cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../../foundation/display.dart';
import '../../../configs/config/types.dart';
import '../../../configs/manage/providers.dart';
import '../../../downloads/filename/types.dart';
import '../../post/types.dart';
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
    final profileIconUrl = profileIconUrlForAuth(
      ref.read(booruConfigProvider),
      config,
    );
    final modal = UnifiedPostShareSheet(
      post: post,
      auth: config,
      profileIconUrl: profileIconUrl,
      viewer: configViewer,
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
