import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../configs/config/types.dart';
import '../../../../images/booru_image.dart';
import '../../../../posts/listing/providers.dart';
import '../../../../posts/post/types.dart';

class FeedPostThumbnail extends ConsumerWidget {
  const FeedPostThumbnail({
    required this.post,
    required this.config,
    this.fit = BoxFit.cover,
    super.key,
  });

  final Post post;
  final BooruConfigAuth config;
  final BoxFit fit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolver = ref.watch(gridThumbnailUrlGeneratorProvider(config));
    final settings = ref.watch(gridThumbnailSettingsProvider(config));
    final media = resolver.resolve(post, settings: settings);

    return BooruImage(
      imageUrl: media.url,
      placeholderUrl: media.placeholderUrl,
      placeholderAspectRatio: media.placeholderAspectRatio,
      config: config,
      fit: fit,
    );
  }
}
