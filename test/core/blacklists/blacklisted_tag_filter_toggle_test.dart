import 'package:boorusama/core/blacklists/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';

void main() {
  setUpAll(() => ensureI18nInitialized('en-US'));

  Future<void> pumpEditor(WidgetTester tester) async {
    await tester.pumpWidget(
      BooruLocalization(
        child: MaterialApp(
          builder: (context, child) => KurumiTheme(
            data: KurumiThemeData.fromMaterial(Theme.of(context)),
            child: child!,
          ),
          home: BlacklistedTagsViewScaffold(
            title: 'Blacklist',
            tags: const ['cat', 'dog'],
            limitation: const SizedBox.shrink(),
            actions: const [],
            onAddTag: (_) {},
            onEditTap: (_, _) {},
            onRemoveTag: (_) {},
          ),
        ),
      ),
    );
  }

  testWidgets('hides filter controls when the editor opens', (tester) async {
    await pumpEditor(tester);

    expect(find.byType(TextField), findsNothing);
    expect(find.text('cat'), findsOneWidget);
  });

  testWidgets('shows and hides filter controls from the top bar', (
    tester,
  ) async {
    await pumpEditor(tester);

    await tester.tap(find.byTooltip('Show filters'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);

    await tester.tap(find.byTooltip('Hide filters'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('preserves the active filter while controls are collapsed', (
    tester,
  ) async {
    await pumpEditor(tester);
    await tester.tap(find.byTooltip('Show filters'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'ca');
    await tester.pumpAndSettle();
    expect(find.text('cat'), findsOneWidget);
    expect(find.text('dog'), findsNothing);

    await tester.tap(find.byTooltip('Hide filters'));
    await tester.pumpAndSettle();
    expect(find.text('cat'), findsOneWidget);
    expect(find.text('dog'), findsNothing);

    await tester.tap(find.byTooltip('Show filters'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('ca'), findsOneWidget);
    expect(find.text('dog'), findsNothing);
  });

  testWidgets('announces whether the filter controls are expanded', (
    tester,
  ) async {
    await pumpEditor(tester);
    final semantics = tester.ensureSemantics();

    expect(
      tester.getSemantics(find.bySemanticsLabel('Show filters')),
      matchesSemantics(
        hasTapAction: true,
        isButton: true,
        hasToggledState: true,
        label: 'Show filters',
      ),
    );

    await tester.tap(find.byTooltip('Show filters'));
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(find.bySemanticsLabel('Hide filters')),
      matchesSemantics(
        hasTapAction: true,
        isButton: true,
        hasToggledState: true,
        label: 'Hide filters',
        isToggled: true,
      ),
    );
    semantics.dispose();
  });
}
