import 'package:boorusama/core/navigation/destination_activity.dart';
import 'package:boorusama/core/navigation/destination_id.dart';
import 'package:boorusama/core/navigation/destination_profile_scope.dart';
import 'package:boorusama/core/navigation/navigation_chrome_controller.dart';
import 'package:boorusama/core/navigation/navigation_interaction_scopes.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final mode in [
    (autoHide: true, active: true, extent: 100.0),
    (autoHide: false, active: true, extent: 100.0),
    (autoHide: true, active: false, extent: 100.0),
    (autoHide: true, active: true, extent: 0.0),
  ]) {
    final enabled = mode.autoHide && mode.active && mode.extent > 0;
    testWidgets(
      'scroll boundary tracks only user gestures: $mode',
      (tester) async {
        late BuildContext notificationContext;
        final container = ProviderContainer(
          overrides: [
            settingsProvider.overrideWithValue(
              Settings.defaultSettings.copyWith(
                autoHideMainNavigation: mode.autoHide,
              ),
            ),
          ],
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: DestinationScope(
                id: const DestinationId.browse('test'),
                child: NavigationActivity(
                  active: mode.active,
                  child: NavigationBarScrollScope(
                    extent: mode.extent,
                    child: NavigationScrollBoundary(
                      child: Builder(
                        builder: (context) {
                          notificationContext = context;
                          return const SizedBox.expand();
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        FixedScrollMetrics metrics([
          AxisDirection direction = AxisDirection.down,
        ]) => FixedScrollMetrics(
          minScrollExtent: 0,
          maxScrollExtent: 1000,
          pixels: 200,
          viewportDimension: 500,
          axisDirection: direction,
          devicePixelRatio: 1,
        );
        void update(
          double delta, {
          bool direct = false,
          AxisDirection direction = AxisDirection.down,
        }) => ScrollUpdateNotification(
          metrics: metrics(direction),
          context: notificationContext,
          scrollDelta: delta,
          dragDetails: direct
              ? DragUpdateDetails(
                  globalPosition: Offset.zero,
                  delta: Offset(0, -delta),
                )
              : null,
        ).dispatch(notificationContext);
        double hidden() =>
            container.read(navigationChromeProvider).barHiddenFraction;

        update(100);
        expect(hidden(), 0);
        ScrollStartNotification(
          metrics: metrics(),
          context: notificationContext,
          dragDetails: DragStartDetails(),
        ).dispatch(notificationContext);
        update(30, direct: true);
        expect(hidden(), enabled ? 0.3 : 0);
        update(50, direct: true, direction: AxisDirection.right);
        expect(hidden(), enabled ? 0.3 : 0);
        // A fling from the same gesture keeps moving the bar with the content.
        update(30);
        expect(hidden(), enabled ? 0.6 : 0);
        ScrollEndNotification(
          metrics: metrics(),
          context: notificationContext,
        ).dispatch(notificationContext);
        expect(hidden(), enabled ? 1 : 0);
        update(-100);
        expect(hidden(), enabled ? 1 : 0);
        // Reversing a new direct gesture reveals exactly the same travel.
        update(-70, direct: true);
        expect(hidden(), enabled ? closeTo(0.3, 0.000001) : 0);
        ScrollEndNotification(
          metrics: metrics(),
          context: notificationContext,
        ).dispatch(notificationContext);
        expect(hidden(), 0);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
