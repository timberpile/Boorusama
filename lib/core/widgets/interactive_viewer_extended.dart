// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../settings/providers.dart';

class InteractiveViewerExtended extends ConsumerWidget {
  const InteractiveViewerExtended({
    required this.child,
    super.key,
    this.onTap,
    this.onDoubleTap,
    this.onLongPress,
    this.controller,
    this.onTransformationChanged,
    this.enable = true,
    this.contentSize,
    this.panEnabled = true,
    this.scaleEnabled = true,
    this.constrainPanToContent = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final void Function(TapDownDetails?)? onDoubleTap;
  final VoidCallback? onLongPress;
  final void Function(KurumiTransformationDetails details)?
  onTransformationChanged;
  final TransformationController? controller;
  final bool enable;
  final Size? contentSize;
  final bool panEnabled;
  final bool scaleEnabled;
  final bool constrainPanToContent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enableHapticFeedback = ref.watch(
      hapticFeedbackLevelProvider.select((value) => value.isReducedOrAbove),
    );

    return KurumiInteractiveViewer(
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      onLongPress: onLongPress,
      controller: controller,
      onTransformationChanged: onTransformationChanged,
      enable: enable,
      contentSize: contentSize,
      enableHapticFeedback: enableHapticFeedback,
      panEnabled: panEnabled,
      scaleEnabled: scaleEnabled,
      constrainPanToContent: constrainPanToContent,
      child: child,
    );
  }
}
