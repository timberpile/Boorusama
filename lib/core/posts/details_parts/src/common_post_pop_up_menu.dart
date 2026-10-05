// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../configs/config/types.dart';
import '../../../configs/config/providers.dart';
import '../../../images/providers.dart';
import '../../shares/providers.dart';
import '../../post/types.dart';
import 'common_post_buttons.dart';

class CommonPostPopupMenu extends ConsumerWidget {
  const CommonPostPopupMenu({
    required this.post,
    required this.onStartSlideshow,
    required this.onLoadOriginal,
    required this.config,
    required this.configViewer,
    super.key,
    this.copy = true,
  });

  final Post post;
  final VoidCallback onStartSlideshow;
  final VoidCallback? onLoadOriginal;
  final BooruConfigAuth? config;
  final BooruConfigViewer? configViewer;
  final bool copy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CommonPostButtonsBuilder(
      post: post,
      onStartSlideshow: onStartSlideshow,
      onLoadOriginal: onLoadOriginal,
      config: config,
      configViewer: configViewer,
      copy: copy,
      builder: (context, buttons) {
        return KurumiPopupMenuButton(
          items: [
            if (copy && config != null && configViewer != null)
              KurumiPopupMenuItem(
                title: Text(context.t.post.action.share),
                onTap: () => ref
                    .read(shareProvider)
                    .sharePost(
                      post,
                      config!,
                      context: context,
                      configViewer: configViewer!,
                      download: ref.readConfigDownload,
                      filenameBuilder: null,
                      imageCacheManager: ref.read(
                        defaultImageCacheManagerProvider,
                      ),
                    ),
              ),
            for (final button in buttons)
              KurumiPopupMenuItem(
                title: Text(button.title),
                onTap: () => button.onTap?.call(),
              ),
          ],
        );
      },
    );
  }
}
