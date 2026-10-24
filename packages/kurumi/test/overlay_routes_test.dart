import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/kurumi.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  for (final route in ['app', 'material', 'adaptive', 'bar', 'side', 'root']) {
    testWidgets('$route route observes live insets while remaining open', (
      tester,
    ) async {
      final overlap = ValueNotifier(88.0);
      addTearDown(overlap.dispose);
      MediaQueryData? observed;
      late BuildContext pageContext;
      final navigator = GlobalKey<NavigatorState>();
      Widget content(BuildContext context) {
        observed = MediaQuery.of(context);
        return const SizedBox(height: 120, child: Text('overlay content'));
      }

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => KurumiTheme(
            data: KurumiThemeData.fromMaterial(Theme.of(context)),
            child: MaterialUiCompatibilityBridge(
              child: MediaQuery(
                data: const MediaQueryData(
                  size: Size(320, 640),
                  padding: EdgeInsets.only(bottom: 24),
                  viewPadding: EdgeInsets.only(bottom: 24),
                ),
                child: child!,
              ),
            ),
          ),
          home: ValueListenableBuilder<double>(
            valueListenable: overlap,
            child: Navigator(
              key: navigator,
              onGenerateRoute: (_) => MaterialPageRoute<void>(
                builder: (context) {
                  pageContext = context;
                  return const Scaffold(body: Text('stable page'));
                },
              ),
            ),
            builder: (context, value, child) => KurumiOverlayInsetsScope(
              bottomPadding: value,
              bottomViewPadding: value,
              child: MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  padding: const EdgeInsets.only(bottom: 88),
                  viewPadding: const EdgeInsets.only(bottom: 88),
                ),
                child: child!,
              ),
            ),
          ),
        ),
      );
      switch (route) {
        case 'app':
          Kurumi.showAppModalBottomSheet<void>(
            context: pageContext,
            builder: content,
          );
        case 'material':
          Kurumi.showModalBottomSheet<void>(
            context: pageContext,
            builder: content,
          );
        case 'adaptive':
          Kurumi.showAdaptiveSheet<void>(pageContext, builder: content);
        case 'bar':
          Kurumi.showAppModalBarBottomSheet<void>(
            context: pageContext,
            builder: content,
          );
        case 'side':
          Kurumi.showSideSheetFromRight<void>(
            context: pageContext,
            body: Builder(builder: content),
          );
        case 'root':
          showDialog<void>(
            context: pageContext,
            builder: (context) => Dialog(child: content(context)),
          );
      }
      await tester.pumpAndSettle();
      expect(observed!.padding.bottom, switch (route) {
        'root' => 0,
        'side' => 24,
        _ => 88,
      });
      overlap.value = 24;
      await tester.pumpAndSettle();
      expect(observed!.padding.bottom, route == 'root' ? 0 : 24);
      expect(MediaQuery.paddingOf(pageContext).bottom, 88);
      expect(find.text('overlay content'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
