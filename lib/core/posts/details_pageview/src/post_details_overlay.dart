// Package imports:
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

// Project imports:
import '../../../widgets/widgets.dart';
import 'post_details_page_view_controller.dart';

class PostDetailsOverlay extends StatelessWidget {
  const PostDetailsOverlay({
    required this.controller,
    required this.leftActions,
    required this.actions,
    required this.isLargeScreen,
    required this.overlayCurvedAnimation,
    this.detailsEnabled = true,
    super.key,
  });

  final PostDetailsPageViewController controller;
  final List<Widget> leftActions;
  final List<Widget> actions;
  final bool isLargeScreen;
  final Animation<double>? overlayCurvedAnimation;
  final bool detailsEnabled;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Builder(
        builder: (context) {
          final overlay = ValueListenableBuilder(
            valueListenable: controller.sheetState,
            builder: (_, state, _) => ConditionalParentWidget(
              condition: !state.isExpanded,
              conditionalBuilder: (child) => ValueListenableBuilder(
                valueListenable: controller.freestyleMoving,
                builder: (context, moving, _) => child,
              ),
              child: SafeArea(
                child: _buildOverlayContent(context),
              ),
            ),
          );

          // Non-Post entries intentionally retain Back outside dismissal,
          // even when the ordinary media overlay is hidden.
          if (!detailsEnabled) {
            return ValueListenableBuilder<bool>(
              valueListenable: controller.freestyleMoving,
              builder: (context, dismissing, _) =>
                  dismissing ? const SizedBox.shrink() : overlay,
            );
          }

          return ListenableBuilder(
            listenable: Listenable.merge([
              controller.forceHideOverlay,
              controller.overlay,
              controller.freestyleMoving,
            ]),
            builder: (_, _) {
              // Never reveal Back while the entire Viewer is being dismissed,
              // including on group entries or when UI was initially hidden.
              if (controller.freestyleMoving.value ||
                  controller.forceHideOverlay.value ||
                  (overlayCurvedAnimation == null &&
                      !controller.overlay.value)) {
                return const SizedBox.shrink();
              }
              return ExcludeFocus(
                excluding: !controller.overlay.value,
                child: overlayCurvedAnimation != null
                    ? SlideTransition(
                        position: Tween(
                          begin: const Offset(0, -1),
                          end: Offset.zero,
                        ).animate(overlayCurvedAnimation!),
                        child: overlay,
                      )
                    : overlay,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildOverlayContent(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: OverflowBar(
              children: [
                KurumiCircularIconButton(
                  icon: const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(
                      Symbols.arrow_back_ios,
                    ),
                  ),
                  onPressed: Navigator.of(context).maybePop,
                ),
                const SizedBox(
                  width: 4,
                ),
                ...leftActions,
              ],
            ),
          ),
          Flexible(
            child: OverflowBar(
              children: [
                ...actions,
                const SizedBox(width: 8),
                if (detailsEnabled)
                  ListenableBuilder(
                    listenable: Listenable.merge([
                      controller.presentationProgress,
                      controller.overlay,
                      ?overlayCurvedAnimation,
                    ]),
                    builder: (context, _) {
                      final progress = controller.presentationProgress.value;
                      final opacity =
                          (1 - progress * 2).clamp(0.0, 1.0) *
                          (overlayCurvedAnimation?.value ??
                              (controller.overlay.value ? 1 : 0));
                      return Offstage(
                        offstage: opacity == 0,
                        child: ExcludeFocus(
                          excluding: controller.isExpanded || progress > 0,
                          child: IgnorePointer(
                            ignoring: controller.isExpanded || progress > 0,
                            child: Opacity(
                              opacity: opacity,
                              child: _SheetControlButton(
                                controller: controller,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetControlButton extends StatelessWidget {
  const _SheetControlButton({required this.controller});
  final PostDetailsPageViewController controller;

  @override
  Widget build(BuildContext context) => KurumiCircularIconButton(
    onPressed: controller.expandToSnapPoint,
    icon: const KurumiInfoCircleIcon(),
  );
}
