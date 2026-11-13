import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../foundation/filesystem.dart';
import '../../../foundation/platform.dart';
import '../../content/content_access_provider.dart';
import '../details/src/providers/viewer_source_access_provider.dart';
import '../details/src/widgets/group_viewer_scope.dart';
import '../shares/src/share_action_adapter.dart';
import '../shares/src/share_platform_capabilities.dart';
import 'boorusama_group_link.dart';
import 'boorusama_link_file.dart';
import 'boorusama_link_file_share.dart';
import 'link_file_labels.dart';

final groupLinkShareAdapterProvider = Provider<ShareActionAdapter>(
  (ref) => ShareActionAdapter(SharePlus.instance.share),
);

/// Shares the source address as the existing single-document link format.
/// Group metadata, account hints, local IDs and cover media are never attached.
class GroupLinkShareButton extends ConsumerStatefulWidget {
  const GroupLinkShareButton({this.builder, super.key});
  final Widget Function(BuildContext, VoidCallback?)? builder;
  @override
  ConsumerState<GroupLinkShareButton> createState() =>
      _GroupLinkShareButtonState();
}

class _GroupLinkShareButtonState extends ConsumerState<GroupLinkShareButton> {
  var _sharing = false;

  Future<void> _share() async {
    final entry = GroupViewerScope.maybeEntryOf(context);
    final binding = entry?.source;
    if (_sharing || entry == null || binding == null) return;
    final access = ref.read(viewerSourceAccessProvider(binding));
    if (access == null) return;
    setState(() => _sharing = true);
    try {
      final box = context.findRenderObject();
      final origin = box is RenderBox && box.hasSize
          ? box.localToGlobal(Offset.zero) & box.size
          : null;
      final link = BoorusamaGroupLink.fromReference(entry.summary.reference);
      final result =
          await BoorusamaLinkFileShare(
            fs: ref.read(appFileSystemProvider),
            adapter: ref.read(groupLinkShareAdapterProvider),
          ).share(
            BoorusamaLinkFile.fromUri(link.uri.toString()),
            sharePositionOrigin: origin,
            beforeHandoff: () {
              if (!mounted ||
                  GroupViewerScope.maybeEntryOf(context)?.summary.reference !=
                      link.reference ||
                  !identical(
                    ref.read(contentAccessContextProvider(access.key)),
                    access,
                  )) {
                throw const FormatException('Group share source changed');
              }
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
    final binding = GroupViewerScope.maybeEntryOf(context)?.source;
    final access = binding == null
        ? null
        : ref.watch(viewerSourceAccessProvider(binding));
    final onShare =
        !_sharing &&
            access != null &&
            SharePlatformCapabilities.forPlatform(currentAppPlatform())
                .canShareMedia
        ? _share
        : null;
    return widget.builder?.call(context, onShare) ??
        IconButton(
          tooltip: context.linkFileLabel,
          icon: const Icon(Icons.share),
          onPressed: onShare,
        );
  }
}
