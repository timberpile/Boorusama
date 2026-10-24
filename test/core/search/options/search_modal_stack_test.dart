import 'package:boorusama/core/search/options/search_modal_back_handler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

void main() {
  testWidgets(
    'Back dismisses a child dialog, then its sheet, then the editor',
    (tester) async {
      var editorOpen = true;
      final router = GoRouter(
        routes: [
          ShellRoute(
            builder: (_, _, child) => Scaffold(body: child),
            routes: [
              GoRoute(
                path: '/',
                builder: (_, _) => StatefulBuilder(
                  builder: (context, setState) => KurumiBackHandler(
                    enabled: editorOpen,
                    onBack: () => setState(() => editorOpen = false),
                    child: TextButton(
                      child: const Text('Open options'),
                      onPressed: () => showModalBottomSheet<void>(
                        context: context,
                        useRootNavigator: true,
                        builder: (context) => SearchModalBackHandler(
                          child: SizedBox(
                            height: 200,
                            child: TextButton(
                              child: const Text('Open calendar'),
                              onPressed: () => showDialog<void>(
                                context: context,
                                builder: (_) => const SearchModalBackHandler(
                                  child: AlertDialog(
                                    content: Text('Calendar draft'),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
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
      await tester.tap(find.text('Open options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open calendar'));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Calendar draft'), findsNothing);
      expect(find.text('Open calendar'), findsOneWidget);
      expect(editorOpen, isTrue);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Open calendar'), findsNothing);
      expect(editorOpen, isTrue);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(editorOpen, isFalse);
      expect(tester.takeException(), isNull);
    },
  );
}
