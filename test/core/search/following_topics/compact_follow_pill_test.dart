import 'package:boorusama/core/search/following_topics/src/widgets/topic_follow_control.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    bool compact = true,
    int count = 0,
    bool busy = false,
    bool modified = false,
    double scale = 1,
    VoidCallback? onPressed,
  }) async {
    await tester.pumpWidget(
      BooruLocalization(
        child: MaterialApp(
          builder: (context, child) =>
              // ignore: deprecated_member_use
              MaterialUiCompatibilityBridge(
                child: KurumiTheme(
                  data: KurumiThemeData.fromMaterial(Theme.of(context)),
                  child: MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      textScaler: TextScaler.linear(scale),
                    ),
                    child: child!,
                  ),
                ),
              ),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 160,
                child: TopicFollowPill(
                  compact: compact,
                  count: count,
                  busy: busy,
                  modified: modified,
                  onPressed: onPressed,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    // Do not settle an indeterminate progress indicator.
    await tester.pump();
  }

  testWidgets('compact fill keeps a tappable 48 pixel target', (tester) async {
    var pressed = 0;
    await pump(tester, onPressed: () => pressed++);
    final finder = find.byType(FilledButton);
    final button = tester.widget<FilledButton>(finder);
    expect(button.style!.minimumSize!.resolve({}), const Size(48, 36));
    expect(button.style!.tapTargetSize, MaterialTapTargetSize.padded);
    final rect = tester.getRect(finder);
    expect(rect.width, greaterThanOrEqualTo(48));
    expect(rect.height, greaterThanOrEqualTo(48));
    await tester.tapAt(Offset(rect.center.dx, rect.top + 1));
    expect(pressed, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('state changes do not change compact target height', (
    tester,
  ) async {
    double? height;
    for (final state in [
      (count: 0, busy: false, modified: false),
      (count: 3, busy: false, modified: false),
      (count: 3, busy: true, modified: false),
      (count: 3, busy: false, modified: true),
    ]) {
      await pump(
        tester,
        count: state.count,
        busy: state.busy,
        modified: state.modified,
        onPressed: () {},
      );
      final current = tester.getSize(find.byType(FilledButton)).height;
      height ??= current;
      expect(current, height);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('large text in a narrow toolbar remains usable', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pump(tester, count: 12, modified: true, scale: 2, onPressed: () {});
    expect(find.byType(FilledButton).hitTestable(), findsOneWidget);
    expect(
      tester.getSize(find.byType(FilledButton)).height,
      greaterThanOrEqualTo(48),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('non-compact styling is unchanged', (tester) async {
    await pump(tester, compact: false, onPressed: () {});
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.style!.minimumSize!.resolve({}), const Size(64, 48));
    expect(
      button.style!.padding!.resolve({}),
      const EdgeInsets.symmetric(horizontal: 16),
    );
  });
}
