import 'package:boorusama/core/analytics/providers.dart';
import 'package:boorusama/core/settings/src/data/providers.dart';
import 'package:boorusama/core/settings/src/types/settings_repository.dart';
import 'package:boorusama/foundation/loggers/logger.dart';
import 'package:boorusama/foundation/loggers/providers.dart';
import 'package:boorusama/core/settings/src/pages/viewer_toolbar_layout_page.dart';
import 'package:boorusama/core/settings/src/providers/settings_notifier.dart';
import 'package:boorusama/core/settings/src/types/settings.dart';
import 'package:boorusama/core/settings/src/types/viewer_toolbar_layout.dart';
import 'package:kurumi/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';

class _Store implements SettingsRepository {
  _Store(this.saved);
  Settings saved;
  var fail = false;
  var writes = 0;

  @override
  Future<bool> save(Settings next) async {
    writes++;
    if (fail) return false;
    saved = next;
    return true;
  }

  @override
  SettingsOrError load() => throw UnimplementedError('Not used by these route tests');
}

class _Log implements Logger {
  @override
  String getDebugName() => 'toolbar-test';
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  setUpAll(() => ensureI18nInitialized('en-US'));

  Future<void> open(WidgetTester tester, _Store settings) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        settingsRepoProvider.overrideWithValue(settings),
        settingsNotifierProvider.overrideWith(() => SettingsNotifier(settings.saved)),
        loggerProvider.overrideWithValue(_Log()),
        analyticsProvider.overrideWith((ref) async => null),
      ],
      child: BooruLocalization(child: MaterialApp(
        builder: (context, child) => KurumiTheme(
          data: KurumiThemeData.fromMaterial(Theme.of(context)), child: child!),
        home: Builder(builder: (context) => Scaffold(body: TextButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => const ViewerToolbarLayoutPage())),
          child: const Text('Open editor'),
        ))),
      )),
    ));
    await tester.tap(find.text('Open editor'));
    await tester.pumpAndSettle();
  }

  testWidgets('Back discards the draft without persisting it', (tester) async {
    final settings = _Store(Settings.defaultSettings);
    await open(tester, settings);
    await tester.tap(find.byKey(const Key('edit-toolbar-bookmark')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('toolbar-transfer')));
    await tester.pump();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(settings.writes, 0);
    expect(settings.saved.viewerToolbarLayout, isNull);
  });

  testWidgets('Apply opts in without changing unrelated settings', (tester) async {
    final settings = _Store(Settings.defaultSettings.copyWith(showBookmarkCount: true));
    await open(tester, settings);
    await tester.tap(find.byKey(const Key('toolbar-apply')));
    await tester.pumpAndSettle();
    expect(settings.saved.viewerToolbarLayout, ViewerToolbarLayout.editorDefault());
    expect(settings.saved.showBookmarkCount, isTrue);
    expect(find.byType(ViewerToolbarLayoutPage), findsNothing);
  });

  testWidgets('failed persistence retains the editable draft', (tester) async {
    final settings = _Store(Settings.defaultSettings)..fail = true;
    await open(tester, settings);
    await tester.tap(find.byKey(const Key('toolbar-apply')));
    await tester.pumpAndSettle();
    expect(find.byType(ViewerToolbarLayoutPage), findsOneWidget);
    expect(settings.saved.viewerToolbarLayout, isNull);
    settings.fail = false;
    await tester.tap(find.byKey(const Key('toolbar-apply')));
    await tester.pumpAndSettle();
    expect(settings.saved.viewerToolbarLayout, isNotNull);
  });

  testWidgets('Reset removes the override instead of saving the editor seed', (tester) async {
    final settings = _Store(Settings.defaultSettings.copyWith(
      viewerToolbarLayout: ViewerToolbarLayout.editorDefault));
    await open(tester, settings);
    final reset = find.byKey(const Key('toolbar-reset'));
    await tester.ensureVisible(reset);
    await tester.tap(reset);
    await tester.pumpAndSettle();
    expect(settings.saved.viewerToolbarLayout, isNull);
    expect(find.byType(ViewerToolbarLayoutPage), findsNothing);
  });

  testWidgets('a concurrent layout replacement is not overwritten', (tester) async {
    final settings = _Store(Settings.defaultSettings);
    await open(tester, settings);
    final replacement = ViewerToolbarLayout(toolbar: const []);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ViewerToolbarLayoutPage)),
    );
    await container.read(settingsNotifierProvider.notifier).updateWith(
      (s) => s.copyWith(viewerToolbarLayout: () => replacement),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('toolbar-apply')));
    await tester.pumpAndSettle();
    expect(settings.saved.viewerToolbarLayout, replacement);
    expect(settings.writes, 1);
    expect(find.byType(ViewerToolbarLayoutPage), findsOneWidget);
  });
}
