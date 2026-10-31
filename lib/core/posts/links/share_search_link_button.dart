// ignore_for_file: avoid_catching_errors
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../foundation/filesystem.dart';
import '../../../foundation/platform.dart';
import '../shares/src/share_action_adapter.dart';
import '../shares/src/share_platform_capabilities.dart';
import 'boorusama_link_file.dart';
import 'boorusama_link_file_share.dart';
import 'boorusama_search_link.dart';
import 'link_file_labels.dart';

final searchLinkShareAdapterProvider = Provider<ShareActionAdapter>(
  (ref) => ShareActionAdapter(SharePlus.instance.share),
);

/// A single file-only action, shared by all engines' search result headers.
class SearchLinkShareMenu extends ConsumerStatefulWidget {
  const SearchLinkShareMenu({
    required this.link,
    this.profileName,
    this.shareAdapter,
    super.key,
  });

  final BoorusamaSearchLink? link;
  final String? profileName;
  final ShareActionAdapter? shareAdapter;

  @override
  ConsumerState<SearchLinkShareMenu> createState() =>
      _SearchLinkShareMenuState();
}

class _SearchLinkShareMenuState extends ConsumerState<SearchLinkShareMenu> {
  var _sharing = false;

  Future<void> _share() async {
    final link = widget.link;
    if (link == null || _sharing) return;
    setState(() => _sharing = true);
    try {
      await shareSearchLinkFile(
        context,
        link: link,
        fs: ref.read(appFileSystemProvider),
        profileName: widget.profileName,
        shareAdapter:
            widget.shareAdapter ?? ref.read(searchLinkShareAdapterProvider),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled =
        widget.link != null &&
        !_sharing &&
        SharePlatformCapabilities.forPlatform(currentAppPlatform())
            .canShareMedia;
    return IconButton(
      tooltip: context.linkFileLabel,
      icon: const Icon(Icons.share),
      onPressed: enabled ? _share : null,
    );
  }
}

/// Send a standalone .bslink, not raw URI text or mixed image attachments.
Future<void> shareSearchLinkFile(
  BuildContext context, {
  required BoorusamaSearchLink link,
  required AppFileSystem fs,
  required ShareActionAdapter shareAdapter,
  String? profileName,
}) async {
  try {
    final box = context.findRenderObject();
    final origin = box is RenderBox && box.hasSize
        ? box.localToGlobal(Offset.zero) & box.size
        : null;
    final outcome = await BoorusamaLinkFileShare(fs: fs, adapter: shareAdapter)
        .share(
          BoorusamaLinkFile.fromUri(link.uri.toString()),
          text: context.searchLinkFileMessage(
            link,
            profileName: profileName ?? link.site.host,
          ),
          sharePositionOrigin: origin,
          beforeHandoff: () {
            if (!context.mounted) {
              throw const FormatException('Search share was closed');
            }
          },
        );
    if (context.mounted &&
        outcome != ShareActionOutcome.success &&
        outcome != ShareActionOutcome.dismissed) {
      Kurumi.showErrorToast(context, context.t.search.app_link.share_failed);
    }
  } on Exception {
    if (context.mounted) {
      Kurumi.showErrorToast(context, context.t.search.app_link.share_failed);
    }
  } on UnimplementedError {
    if (context.mounted) {
      Kurumi.showErrorToast(context, context.t.search.app_link.share_failed);
    }
  }
}
