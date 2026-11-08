import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

import '../../../../developer_options/l10n.dart';
import '../../../../developer_options/zoom_study.dart';
import '../../../../settings/providers.dart';
import '../../../post/types.dart';
import 'post_viewer_transformation_scope.dart';

/// Developer-only overlay. Zoom is measured relative to the contain-fit image.
class ZoomStudyOverlay extends ConsumerStatefulWidget {
  const ZoomStudyOverlay({
    required this.post,
    required this.controller,
    this.decodedSize,
    super.key,
  });

  final Post post;
  final TransformationController controller;
  final Size? decodedSize;

  @override
  ConsumerState<ZoomStudyOverlay> createState() => _ZoomStudyOverlayState();
}

class _ZoomStudyOverlayState extends ConsumerState<ZoomStudyOverlay> {
  var _busy = false;

  void _message(String text) {
    if (!mounted) return;
    Kurumi.showSimpleSnackBar(context: context, content: Text(text));
  }

  Future<void> _record() async {
    if (_busy) return;
    final post = widget.post;
    final imageWidth = widget.decodedSize?.width ?? post.width;
    final imageHeight = widget.decodedSize?.height ?? post.height;
    final viewport =
        PostViewerTransformationScope.maybeOf(context)?.viewportSize ??
        MediaQuery.sizeOf(context);
    final scale = widget.controller.value.getMaxScaleOnAxis();
    if (imageWidth <= 0 ||
        imageHeight <= 0 ||
        !imageWidth.isFinite ||
        !imageHeight.isFinite ||
        !viewport.width.isFinite ||
        !viewport.height.isFinite ||
        viewport.width <= 0 ||
        viewport.height <= 0 ||
        !scale.isFinite ||
        scale <= 0) {
      _message(context.t.developerOptions.zoomStudyFailure);
      return;
    }

    final settings = ref.read(imageViewerSettingsProvider);
    final record = <String, Object?>{
      'recorded_at': DateTime.now().toUtc().toIso8601String(),
      'engine': post.origin.booruType.toString(),
      'post_id': post.id,
      'image_width': imageWidth,
      'image_height': imageHeight,
      'image_aspect_ratio': imageWidth / imageHeight,
      'image_dimensions_source': widget.decodedSize == null
          ? 'post_metadata'
          : 'decoded_media',
      'post_metadata_width': post.width,
      'post_metadata_height': post.height,
      'viewport_width': viewport.width,
      'viewport_height': viewport.height,
      'viewport_aspect_ratio': viewport.width / viewport.height,
      'orientation': MediaQuery.orientationOf(context).name,
      'preferred_zoom': scale,
      'double_tap_mode': 'classic',
      'snap_to_fit': settings.snapZoomToFit,
      'snap_tolerance': 0.10,
      'auto_comic': settings.autoAdjustComicStrips,
    };

    setState(() => _busy = true);
    try {
      await ref.read(zoomStudyRecorderProvider).record(record);
      if (!mounted) return;
      _message(context.t.developerOptions.zoomStudyRecorded);
    } catch (_) {
      if (!mounted) return;
      _message(context.t.developerOptions.zoomStudyFailure);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _export() async {
    if (_busy) return;
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      _message(context.t.developerOptions.zoomStudyAndroidOnly);
      return;
    }
    setState(() => _busy = true);
    try {
      final path = await ref.read(zoomStudyRecorderProvider).export();
      if (!mounted) return;
      _message('${context.t.developerOptions.zoomStudyExported}: $path');
    } catch (_) {
      if (!mounted) return;
      _message(context.t.developerOptions.zoomStudyFailure);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = context.t.developerOptions;
    return Material(
      color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.94),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.only(left: 12, right: 4),
        child: ValueListenableBuilder<Matrix4>(
          valueListenable: widget.controller,
          builder: (context, matrix, _) {
            final scale = matrix.getMaxScaleOnAxis();
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  scale.isFinite ? '${scale.toStringAsFixed(2)}×' : '—',
                  style: theme.textTheme.labelLarge,
                ),
                IconButton(
                  icon: const Icon(Icons.bookmark_add_outlined),
                  tooltip: strings.zoomStudyRecord,
                  onPressed: _busy ? null : _record,
                ),
                IconButton(
                  icon: const Icon(Icons.file_download_outlined),
                  tooltip: strings.zoomStudyExport,
                  onPressed: _busy ? null : _export,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
