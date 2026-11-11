import 'package:boorusama/core/posts/details_pageview/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final initialHide in [false, true]) {
    for (final visible in [false, true]) {
      testWidgets(
        'zoom preserves chosen UI and system bars, initialHide=$initialHide visible=$visible',
        (tester) async {
          final systemCalls = <MethodCall>[];
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            (call) async {
              if (call.method == 'SystemChrome.setEnabledSystemUIMode') {
                systemCalls.add(call);
              }
              return null;
            },
          );
          addTearDown(
            () => tester.binding.defaultBinaryMessenger
                .setMockMethodCallHandler(SystemChannels.platform, null),
          );
          final controller = PostDetailsPageViewController(
            initialPage: 0,
            totalPage: 2,
            checkIfLargeScreen: () => false,
            initialHideOverlay: initialHide,
            disableAnimation: true,
          );
          addTearDown(controller.dispose);
          if (visible) {
            controller.showAllUI();
          } else {
            controller.hideAllUI();
          }
          await tester.pump();
          systemCalls.clear();
          controller.synchronizeZoom(true);
          await tester.pump();
          expect(controller.overlay.value, visible);
          expect(controller.bottomSheet.value, visible);
          expect(systemCalls, isEmpty);
          controller.toggleOverlay();
          await tester.pump();
          expect(controller.overlay.value, !visible);
          expect(controller.bottomSheet.value, !visible);
          systemCalls.clear();
          controller.synchronizeZoom(false);
          await tester.pump();
          expect(controller.overlay.value, !visible);
          expect(controller.bottomSheet.value, !visible);
          expect(controller.swipe.value, isTrue);
          expect(systemCalls, isEmpty);
        },
      );
    }
  }
}
