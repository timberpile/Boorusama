import 'package:boorusama/core/posts/listing/src/widgets/timeline_header_sliver.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kurumi/kurumi.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final pinned in [false, true]) {
    testWidgets('toolbar scroll visibility with pinning $pinned', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) =>
              // ignore: deprecated_member_use
              MaterialUiCompatibilityBridge(
                child: KurumiTheme(
                  data: KurumiThemeData.fromMaterial(Theme.of(context)),
                  child: child!,
                ),
              ),
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                const SliverToBoxAdapter(child: SizedBox(height: 120)),
                TimelineHeaderSliver(
                  keepVisible: pinned,
                  child: const SizedBox(height: 56, child: Text('Toolbar')),
                ),
                SliverList.builder(
                  itemCount: 80,
                  itemBuilder: (_, index) => SizedBox(
                    height: 100,
                    child: Text('Post $index'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(
        find.text('Toolbar').hitTestable(),
        pinned ? findsOneWidget : findsNothing,
      );
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 180));
      await tester.pumpAndSettle();
      expect(find.text('Toolbar').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
