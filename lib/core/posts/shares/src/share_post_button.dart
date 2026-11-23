// Package imports:
import 'package:cache_manager/cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

// Project imports:
import '../../../configs/config/types.dart';
import '../../../downloads/filename/providers.dart';
import '../../../downloads/filename/types.dart';
import '../../../images/providers.dart';
import '../../post/types.dart';
import 'providers.dart';

class SharePostButton extends ConsumerWidget {
  const SharePostButton({
    required this.post,
    required this.auth,
    required this.configViewer,
    required this.download,
    this.filenameBuilder,
    this.imageCacheManager,
    super.key,
  });

  final Post post;
  final BooruConfigAuth auth;
  final BooruConfigViewer configViewer;
  final BooruConfigDownload download;
  final DownloadFilenameGenerator? filenameBuilder;
  final ImageCacheManager? imageCacheManager;

  VoidCallback action(BuildContext context, WidgetRef ref) => () {
    if (!context.mounted) return;
    ref
        .read(shareProvider)
        .sharePost(
          post,
          auth,
          context: context,
          configViewer: configViewer,
          download: download,
          filenameBuilder:
              filenameBuilder ??
              ref.read(downloadFilenameBuilderProvider(auth)),
          imageCacheManager:
              imageCacheManager ?? ref.read(defaultImageCacheManagerProvider),
        );
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) => IconButton(
    tooltip: context.t.post.action.share,
    splashRadius: 16,
    onPressed: action(context, ref),
    icon: const Icon(Symbols.share),
  );
}
