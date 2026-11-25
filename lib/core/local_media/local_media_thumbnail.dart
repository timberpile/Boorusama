import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

import 'local_media_models.dart';
import 'local_media_providers.dart';
import 'local_media_reference.dart';

class LocalMediaThumbnail extends ConsumerWidget {
  const LocalMediaThumbnail({
    required this.reference,
    this.fit = BoxFit.cover,
    this.animateGif = false,
    super.key,
  });

  final LocalMediaReference reference;
  final BoxFit fit;
  final bool animateGif;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(localMediaPresentationProvider(reference));
    final media = result.valueOrNull;
    final file = media?.file;
    if (file == null) {
      return result.isLoading
          ? const KurumiImagePlaceholder()
          : const LocalMediaUnavailable();
    }
    final format = media!.item.format;
    final thumbnail =
        (format.isVideo || (format == LocalMediaFormat.gif && !animateGif))
        ? ref.watch(localMediaPosterProvider(reference)).valueOrNull
        : file;
    if (thumbnail == null) {
      return Center(
        child: Icon(
          format.isVideo ? Icons.play_circle_outline : Icons.gif_box_outlined,
        ),
      );
    }
    final pixelWidth = (MediaQuery.devicePixelRatioOf(context) * 256)
        .round()
        .clamp(256, 768);
    return Image.file(
      thumbnail,
      width: double.infinity,
      height: double.infinity,
      fit: fit,
      cacheWidth: pixelWidth,
      semanticLabel: context.t.local_media.media_item,
      errorBuilder: (_, _, _) => const LocalMediaUnavailable(),
    );
  }
}

class LocalMediaUnavailable extends StatelessWidget {
  const LocalMediaUnavailable({this.showLabel = false, super.key});

  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final label = context.t.local_media.unavailable;
    return Center(
      child: showLabel
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: Text(label, textAlign: TextAlign.center),
            )
          : Tooltip(
              message: label,
              child: const Icon(Icons.broken_image_outlined),
            ),
    );
  }
}
