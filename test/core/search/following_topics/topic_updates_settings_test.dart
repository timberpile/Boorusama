import 'dart:async';

import 'package:boorusama/core/search/following_topics/src/providers/search_refresh_coordinator.dart';
import 'package:boorusama/core/search/following_topics/src/services/conservative_refresh_policy.dart';

import 'package:boorusama/core/analytics/providers.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/src/pages/accessibility_page.dart';
import 'package:boorusama/core/settings/src/pages/appearance/image_listing_settings_section.dart';
import 'package:boorusama/core/settings/src/pages/appearance/image_viewer_settings_section.dart';
import 'package:boorusama/core/settings/src/pages/topic_updates_page.dart';
import 'package:boorusama/core/settings/src/types/settings.dart';
import 'package:boorusama/core/settings/src/types/settings_repository.dart';
import 'package:boorusama/foundation/loggers.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';

void main() {
  setUpAll(() => ensureI18nInitialized('en-US'));

  testWidgets('rapid scope edits persist both choices in order', (
    tester,
  ) async {
    final repository = _ControlledRepository();
    await tester.pumpWidget(
      BooruLocalization(
        child: ProviderScope(
          overrides: [
            settingsRepoProvider.overrideWithValue(repository),
            settingsNotifierProvider.overrideWith(
              () => SettingsNotifier(Settings.defaultSettings),
            ),
            loggerProvider.overrideWithValue(
              ConsoleLogger(options: const ConsoleLoggerOptions.defaults()),
            ),
            analyticsProvider.overrideWith((ref) => Future.value()),
          ],
          child: const _TestMaterialApp(
            home: TopicUpdatesSettingsPage(),
          ),
        ),
      ),
    );

    KurumiSwitchListTile switchFor(String label) =>
        tester.widget<KurumiSwitchListTile>(
          find.ancestor(
            of: find.text(label),
            matching: find.byType(KurumiSwitchListTile),
          ),
        );
    switchFor('Topics').onChanged!(false);
    switchFor('Enable Automatic Checks').onChanged!(false);
    await _waitForAttempts(tester, repository, 1);
    expect(repository.attempts, hasLength(1));
    repository.releases.first.complete(true);
    await _waitForAttempts(tester, repository, 2);
    repository.releases.last.complete(true);
    await tester.pumpAndSettle();

    expect(repository.stored?.searchRefresh.followingTopicsEnabled, isFalse);
    expect(repository.stored?.searchRefresh.enabled, isFalse);

    final reopened = Settings.fromJson(repository.stored!.toJson());
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      BooruLocalization(
        child: ProviderScope(
          overrides: [
            settingsNotifierProvider.overrideWith(
              () => SettingsNotifier(reopened),
            ),
          ],
          child: const _TestMaterialApp(
            home: TopicUpdatesSettingsPage(),
          ),
        ),
      ),
    );
    expect(switchFor('Topics').value, isFalse);
    expect(switchFor('Enable Automatic Checks').value, isFalse);
  });

  testWidgets(
    'a queued edit from another settings page preserves the refresh choice',
    (
      tester,
    ) async {
      final repository = _ControlledRepository();
      await tester.pumpWidget(
        BooruLocalization(
          child: ProviderScope(
            overrides: [
              settingsRepoProvider.overrideWithValue(repository),
              settingsNotifierProvider.overrideWith(
                () => SettingsNotifier(Settings.defaultSettings),
              ),
              loggerProvider.overrideWithValue(
                ConsoleLogger(options: const ConsoleLoggerOptions.defaults()),
              ),
              analyticsProvider.overrideWith((ref) => Future.value()),
            ],
            child: const _TestMaterialApp(
              home: Column(
                children: [
                  Expanded(child: TopicUpdatesSettingsPage()),
                  Expanded(child: AccessibilityPage()),
                ],
              ),
            ),
          ),
        ),
      );

      final refreshSwitch = tester.widget<KurumiSwitchListTile>(
        find.ancestor(
          of: find.text('Topics'),
          matching: find.byType(KurumiSwitchListTile),
        ),
      );
      refreshSwitch.onChanged!(false);
      await _waitForAttempts(tester, repository, 1);

      final accessibilitySwitch = tester.widget<KurumiSwitchListTile>(
        find
            .descendant(
              of: find.byType(AccessibilityPage),
              matching: find.byType(KurumiSwitchListTile),
            )
            .first,
      );
      accessibilitySwitch.onChanged!(true);
      repository.releases.first.complete(true);
      await _waitForAttempts(tester, repository, 2);
      repository.releases.last.complete(true);
      await tester.pumpAndSettle();

      expect(repository.stored?.searchRefresh.followingTopicsEnabled, isFalse);
      expect(repository.stored?.reduceAnimations, isTrue);
    },
  );

  testWidgets('a thrown settings save shows the visible failure message', (
    tester,
  ) async {
    final repository = _ControlledRepository(throwOnSave: true);
    await tester.pumpWidget(
      BooruLocalization(
        child: ProviderScope(
          overrides: [
            settingsRepoProvider.overrideWithValue(repository),
            settingsNotifierProvider.overrideWith(
              () => SettingsNotifier(Settings.defaultSettings),
            ),
            loggerProvider.overrideWithValue(
              ConsoleLogger(options: const ConsoleLoggerOptions.defaults()),
            ),
          ],
          child: const _TestMaterialApp(
            home: TopicUpdatesSettingsPage(),
          ),
        ),
      ),
    );

    final pinnedSwitch = tester.widget<KurumiSwitchListTile>(
      find.ancestor(
        of: find.text('Topics'),
        matching: find.byType(KurumiSwitchListTile),
      ),
    );
    pinnedSwitch.onChanged!(false);
    await tester.pumpAndSettle();

    expect(find.text('Could not save refresh settings.'), findsOneWidget);
    expect(
      tester
          .widget<KurumiSwitchListTile>(
            find.ancestor(
              of: find.text('Topics'),
              matching: find.byType(KurumiSwitchListTile),
            ),
          )
          .value,
      isTrue,
    );
    expect(repository.stored, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'rapid listing choices preserve both fields in one settings group',
    (
      tester,
    ) async {
      final repository = _ControlledRepository();
      await tester.pumpWidget(
        BooruLocalization(
          child: ProviderScope(
            overrides: [
              settingsRepoProvider.overrideWithValue(repository),
              settingsNotifierProvider.overrideWith(
                () => SettingsNotifier(Settings.defaultSettings),
              ),
              loggerProvider.overrideWithValue(
                ConsoleLogger(options: const ConsoleLoggerOptions.defaults()),
              ),
              analyticsProvider.overrideWith((ref) => Future.value()),
            ],
            child: _TestMaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: Consumer(
                    builder: (context, ref, _) => ImageListingSettingsSection(
                      listing: ref.watch(settingsProvider).listing,
                      onUpdate: (change) => ref
                          .read(settingsNotifierProvider.notifier)
                          .updateWith(
                            (settings) => settings.copyWith(
                              listing: change(settings.listing),
                            ),
                          ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      KurumiSwitchListTile switchFor(String label) =>
          tester.widget<KurumiSwitchListTile>(
            find.ancestor(
              of: find.text(label),
              matching: find.byType(KurumiSwitchListTile),
            ),
          );
      switchFor('Show Scores').onChanged!(true);
      await _waitForAttempts(tester, repository, 1);
      switchFor('Show Posts Configuration Header').onChanged!(false);
      repository.releases.first.complete(true);
      await _waitForAttempts(tester, repository, 2);
      repository.releases.last.complete(true);
      await tester.pumpAndSettle();

      expect(repository.stored?.listing.showScoresInGrid, isTrue);
      expect(repository.stored?.listing.showPostListConfigHeader, isFalse);
    },
  );

  testWidgets(
    'rapid viewer choices preserve both fields in one settings group',
    (
      tester,
    ) async {
      final repository = _ControlledRepository();
      await tester.pumpWidget(
        BooruLocalization(
          child: ProviderScope(
            overrides: [
              settingsRepoProvider.overrideWithValue(repository),
              settingsNotifierProvider.overrideWith(
                () => SettingsNotifier(Settings.defaultSettings),
              ),
              loggerProvider.overrideWithValue(
                ConsoleLogger(options: const ConsoleLoggerOptions.defaults()),
              ),
              analyticsProvider.overrideWith((ref) => Future.value()),
            ],
            child: _TestMaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: Consumer(
                    builder: (context, ref, _) {
                      final section = ImageViewerSettingsSection(
                        viewer: ref.watch(settingsProvider).viewer,
                        onUpdate: (change) => ref
                            .read(settingsNotifierProvider.notifier)
                            .updateWith(
                              (settings) => settings.copyWith(
                                viewer: change(settings.viewer),
                              ),
                            ),
                      );
                      final children =
                          (section.build(context, ref) as Column).children;
                      // Radio cards below these controls emit a ListTile ink
                      // diagnostic when mounted in this focused widget harness.
                      return Column(
                        children: children
                            .whereType<KurumiSwitchListTile>()
                            .take(2)
                            .toList(),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      KurumiSwitchListTile switchFor(String label) =>
          tester.widget<KurumiSwitchListTile>(
            find.ancestor(
              of: find.text(label),
              matching: find.byType(KurumiSwitchListTile),
            ),
          );
      switchFor('Load Original When Zooming').onChanged!(false);
      await _waitForAttempts(tester, repository, 1);
      switchFor('Snap Zoom to Fit').onChanged!(false);
      repository.releases.first.complete(true);
      await _waitForAttempts(tester, repository, 2);
      repository.releases.last.complete(true);
      await tester.pumpAndSettle();

      expect(repository.stored?.viewer.loadOriginalOnZoom, isFalse);
      expect(repository.stored?.viewer.snapZoomToFit, isFalse);
    },
  );

  testWidgets(
    'the page keeps explanations concise and publishes live status',
    (
      tester,
    ) async {
      await tester.pumpWidget(
        BooruLocalization(
          child: ProviderScope(
            overrides: [
              settingsNotifierProvider.overrideWith(
                () => SettingsNotifier(Settings.defaultSettings),
              ),
            ],
            child: const _TestMaterialApp(
              home: TopicUpdatesSettingsPage(),
            ),
          ),
        ),
      );
      expect(
        find.textContaining('Adaptive checks start after 24 hours'),
        findsNothing,
      );
      expect(find.textContaining('Manual refresh'), findsNothing);
      final context = tester.element(
        find.byType(TopicUpdatesSettingsPage),
      );
      final container = ProviderScope.containerOf(context);
      await tester.scrollUntilVisible(
        find.textContaining('Last automatic run:'),
        250,
      );
      container
          .read(searchRefreshStatusProvider.notifier)
          .update(
            SearchRefreshStatus(
              paused: RefreshSkipReason.batterySaver,
              eligible: 3,
            ),
          );
      await tester.pump();
      expect(find.text('Paused: battery saver is active'), findsOneWidget);
      expect(find.text('Topics ready to check: 3'), findsOneWidget);
      container
          .read(searchRefreshStatusProvider.notifier)
          .update(SearchRefreshStatus(running: true));
      await tester.pump();
      expect(find.text('Checking topics…'), findsOneWidget);
    },
  );
}

Future<void> _waitForAttempts(
  WidgetTester tester,
  _ControlledRepository repository,
  int count,
) async {
  for (var i = 0; i < 50 && repository.attempts.length < count; i++) {
    await tester.pump();
  }
  expect(repository.attempts, hasLength(count));
}

class _TestMaterialApp extends StatelessWidget {
  const _TestMaterialApp({required this.home});

  final Widget home;

  @override
  Widget build(BuildContext context) => MaterialApp(
    builder: (context, child) =>
        // ignore: deprecated_member_use
        MaterialUiCompatibilityBridge(child: child!),
    home: home,
  );
}

class _ControlledRepository implements SettingsRepository {
  _ControlledRepository({this.throwOnSave = false});

  final bool throwOnSave;
  final attempts = <Settings>[];
  final releases = <Completer<bool>>[];
  Settings? stored;

  @override
  SettingsOrError load() => throw UnimplementedError();

  @override
  Future<bool> save(Settings settings) async {
    if (throwOnSave) throw StateError('disk unavailable');
    attempts.add(settings);
    final release = Completer<bool>();
    releases.add(release);
    final accepted = await release.future;
    if (accepted) stored = settings;
    return accepted;
  }
}
