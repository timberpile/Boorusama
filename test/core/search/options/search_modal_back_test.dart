import 'package:boorusama/core/search/options/search_modal_back_handler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

void main() {
  testWidgets('system Back closes the root sheet before the nested editor', (
    tester,
  ) async {
    var editorOpen = true;
    var sheetCompleted = false;
    String? result;
    final router = GoRouter(
      routes: [
        ShellRoute(
          builder: (context, state, child) => Scaffold(body: child),
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => StatefulBuilder(
                builder: (context, setState) => KurumiBackHandler(
                  enabled: editorOpen,
                  onBack: () => setState(() => editorOpen = false),
                  child: TextButton(
                    child: const Text('Open option'),
                    onPressed: () async {
                      result = await showModalBottomSheet<String>(
                        context: context,
                        useRootNavigator: true,
                        builder: (_) => const SearchModalBackHandler(
                          child: SizedBox(height: 120, child: Text('Option')),
                        ),
                      );
                      sheetCompleted = true;
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('Open option'));
    await tester.pumpAndSettle();
    expect(find.text('Option'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Option'), findsNothing);
    expect(sheetCompleted, isTrue);
    expect(result, isNull);
    expect(editorOpen, isTrue);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(editorOpen, isFalse);
    expect(tester.takeException(), isNull);
  });
}
