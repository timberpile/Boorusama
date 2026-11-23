import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../images/providers.dart';
import '../details/src/providers/viewer_source_access_provider.dart';
import '../details/src/types/viewer_entry.dart';
import '../details/src/widgets/group_viewer_scope.dart';
import '../shares/src/providers.dart';
import '../shares/src/share_action_adapter.dart';

final groupLinkShareAdapterProvider = Provider<ShareActionAdapter>(
  (ref) => ShareActionAdapter(SharePlus.instance.share),
);

/// Opens the same Links panel as member sharing, with a Group-only target.
class GroupLinkShareButton extends ConsumerStatefulWidget {
  const GroupLinkShareButton({this.entry, super.key});

  final GroupViewerEntry? entry;

  @override
  ConsumerState<GroupLinkShareButton> createState() =>
      _GroupLinkShareButtonState();
}

class _GroupLinkShareButtonState extends ConsumerState<GroupLinkShareButton> {
  var _open = false;

  Future<void> _share(GroupViewerEntry entry) async {
    if (_open) return;
    setState(() => _open = true);
    try {
      await ref
          .read(shareProvider)
          .shareGroup(
            entry,
            context: context,
            imageCacheManager: ref.read(defaultImageCacheManagerProvider),
            adapter: ref.read(groupLinkShareAdapterProvider),
          );
    } finally {
      if (mounted) setState(() => _open = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry ?? GroupViewerScope.maybeEntryOf(context);
    final binding = entry?.source;
    final access = binding == null
        ? null
        : ref.watch(viewerSourceAccessProvider(binding));
    return IconButton(
      tooltip: context.t.post.action.share,
      icon: const Icon(Icons.share),
      onPressed:
          !_open &&
              entry != null &&
              access?.accepts(entry.contentReference) == true
          ? () => _share(entry)
          : null,
    );
  }
}
