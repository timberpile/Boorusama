import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../foundation/filesystem.dart';
import '../../../foundation/platform.dart';
import '../shares/src/share_action_adapter.dart';
import '../shares/src/share_platform_capabilities.dart';
import 'boorusama_artist_link.dart';
import 'boorusama_link_file.dart';
import 'boorusama_link_file_share.dart';
import 'link_file_labels.dart';

final artistLinkShareAdapterProvider = Provider<ShareActionAdapter>(
  (ref) => ShareActionAdapter(SharePlus.instance.share),
);

class ArtistLinkShareButton extends ConsumerStatefulWidget {
  const ArtistLinkShareButton({
    required this.link,
    required this.profileName,
    super.key,
  });
  final BoorusamaArtistLink? link;
  final String profileName;
  @override
  ConsumerState<ArtistLinkShareButton> createState() =>
      _ArtistLinkShareButtonState();
}

class _ArtistLinkShareButtonState extends ConsumerState<ArtistLinkShareButton> {
  var _sharing = false;

  Future<void> _share() async {
    final link = widget.link;
    final profileName = widget.profileName;
    if (link == null || _sharing) return;
    setState(() => _sharing = true);
    try {
      final box = context.findRenderObject();
      final origin = box is RenderBox && box.hasSize
          ? box.localToGlobal(Offset.zero) & box.size
          : null;
      final result =
          await BoorusamaLinkFileShare(
            fs: ref.read(appFileSystemProvider),
            adapter: ref.read(artistLinkShareAdapterProvider),
          ).share(
            BoorusamaLinkFile.fromArtist(link, profileName: profileName),
            sharePositionOrigin: origin,
            beforeHandoff: () {
              if (!mounted ||
                  widget.link != link ||
                  widget.profileName != profileName)
                throw const FormatException('Artist share changed');
            },
          );
      if (mounted &&
          result != ShareActionOutcome.success &&
          result != ShareActionOutcome.dismissed) {
        Kurumi.showErrorToast(context, context.t.post.action.operation_failed);
      }
    } on Exception {
      if (mounted)
        Kurumi.showErrorToast(context, context.t.post.action.operation_failed);
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
