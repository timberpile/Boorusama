// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:boorusama/core/backups/transfer/import/transfer_data_dialog.dart';

// Project imports:
import 'package:boorusama/core/backups/preparation/version_checking.dart';
import 'package:boorusama/core/backups/preparation/preparation_pipeline.dart';
import 'package:boorusama/core/backups/sources/providers.dart';
import 'package:boorusama/core/backups/transfer/import/import_data_notifier.dart';
import 'package:boorusama/core/backups/types/backup_data_source.dart';
import 'package:boorusama/core/backups/types/backup_registry.dart';
import 'package:boorusama/core/backups/types/types.dart';

void main() {
  testWidgets('a completed subset shows Done and omits unselected progress', (
    tester,
  ) async {
    final selected = _TestBackupSource(
      id: 'selected',
      onPrepareImport: (_) => _preparation,
    );
    final unselected = _TestBackupSource(
      id: 'unselected',
      onPrepareImport: (_) => throw StateError('Not selected'),
    );
    final registry = BackupRegistry()
      ..register(selected)
      ..register(unselected);
    final container = ProviderContainer(
      overrides: [
        backupRegistryProvider.overrideWithValue(registry),
        settingsProvider.overrideWithValue(Settings.defaultSettings),
        exportCategoriesProvider.overrideWithValue([
          for (final source in [selected, unselected])
            ExportCategory(
              name: source.id,
              displayName: source.id,
              route: source.id,
              handler: source.capabilities.server.export,
            ),
        ]),
      ],
    );
    addTearDown(container.dispose);
    late BuildContext context;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: BooruLocalization(
          child: MaterialApp(
            builder: (context, child) => KurumiTheme(
              data: KurumiThemeData.fromMaterial(Theme.of(context)),
              child: child!,
            ),
            home: Scaffold(
              body: Builder(
                builder: (value) {
                  context = value;
                  return const ImportingStep(url: 'https://example.com');
                },
              ),
            ),
          ),
        ),
      ),
    );
    final notifier = container.read(
      importDataProvider('https://example.com').notifier,
    )..toggleTask('unselected');
    await notifier.startImport(context);
    await tester.pumpAndSettle();
    expect(find.text('Done'), findsOneWidget);
    expect(find.text('selected'), findsOneWidget);
    expect(find.text('unselected'), findsNothing);
  });

  testWidgets(
    'canceling preparation leaves earlier selected sources unexecuted',
    (tester) async {
      var writes = 0;
      final first = _TestBackupSource(
        onPrepareImport: (_) => ImportPreparation(
          versionCheck: _preparation.versionCheck,
          executeImport: () async {
            writes++;
          },
        ),
      );
      final canceled = _TestBackupSource(
        id: 'cancel',
        priority: 1,
        onPrepareImport: (_) => throw const ImportCancelledException(),
      );
      final registry = BackupRegistry()
        ..register(first)
        ..register(canceled);
      final container = ProviderContainer(
        overrides: [
          backupRegistryProvider.overrideWithValue(registry),
          exportCategoriesProvider.overrideWithValue([
            for (final source in [first, canceled])
              ExportCategory(
                name: source.id,
                displayName: source.displayName,
                route: source.id,
                handler: source.capabilities.server.export,
              ),
          ]),
        ],
      );
      addTearDown(container.dispose);
      final listener = container.listen(
        importDataProvider('https://example.com'),
        (_, _) {},
      );
      addTearDown(listener.close);
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (value) {
              context = value;
              return const SizedBox();
            },
          ),
        ),
      );
      await container
          .read(importDataProvider('https://example.com').notifier)
          .startImport(context);
      expect(writes, 0);
      final state = container.read(importDataProvider('https://example.com'));
      expect(state.step, ImportStep.selection);
      expect(
        state.tasks.map((task) => task.importStatus),
        everyElement(isA<ImportNotStarted>()),
      );
    },
  );

  testWidgets('server imports pass their mounted UI context to the source', (
    tester,
  ) async {
    BuildContext? receivedContext;
    late BuildContext pageContext;
    final source = _TestBackupSource(
      onPrepareImport: (context) {
        receivedContext = context;
        return _preparation;
      },
    );
    final registry = BackupRegistry()..register(source);
    final container = ProviderContainer(
      overrides: [
        backupRegistryProvider.overrideWithValue(registry),
        exportCategoriesProvider.overrideWithValue([
          ExportCategory(
            name: source.id,
            displayName: source.displayName,
            route: source.id,
            handler: source.capabilities.server.export,
          ),
        ]),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      importDataProvider('https://example.com'),
      (_, _) {},
    );
    addTearDown(subscription.close);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              pageContext = context;
              return const SizedBox();
            },
          ),
        ),
      ),
    );

    final importing = container
        .read(importDataProvider('https://example.com').notifier)
        .startImport(pageContext);
    await tester.pump(const Duration(milliseconds: 300));
    await importing;

    expect(receivedContext, same(pageContext));
    expect(receivedContext?.mounted, isTrue);
  });

  testWidgets('device import continues a feed after a pinned search fails', (
    tester,
  ) async {
    var feedWrites = 0;
    final pin = _TestBackupSource(
      id: 'pinned_searches',
      priority: 100000,
      onPrepareImport: (_) => ImportPreparation(
        versionCheck: _preparation.versionCheck,
        executeImport: () async => throw StateError('bad pin import'),
      ),
    );
    final feed = _TestBackupSource(
      id: 'following_feeds',
      priority: 100001,
      onPrepareImport: (_) => ImportPreparation(
        versionCheck: _preparation.versionCheck,
        executeImport: () async => feedWrites++,
      ),
    );
    final container = _containerFor([pin, feed]);
    addTearDown(container.dispose);
    final listener = container.listen(
      importDataProvider('https://example.com'),
      (_, _) {},
    );
    addTearDown(listener.close);
    final context = await _context(tester, container);

    await container
        .read(importDataProvider('https://example.com').notifier)
        .startImport(context);

    final tasks = container
        .read(importDataProvider('https://example.com'))
        .tasks;
    expect(
      tasks.singleWhere((task) => task.id == 'pinned_searches').importStatus,
      isA<ImportError>(),
    );
    expect(
      tasks.singleWhere((task) => task.id == 'following_feeds').importStatus,
      isA<ImportDone>(),
    );
    expect(feedWrites, 1);
  });

  testWidgets(
    'failed profile preparation blocks both dependent device sources only',
    (tester) async {
      var otherWrites = 0;
      final profiles = _TestBackupSource(
        id: 'profiles',
        priority: -1,
        onPrepareImport: (_) => throw StateError('bad profiles'),
      );
      final pin = _TestBackupSource(
        id: 'pinned_searches',
        priority: 100000,
        onPrepareImport: (_) => _preparation,
      );
      final feed = _TestBackupSource(
        id: 'following_feeds',
        priority: 100001,
        onPrepareImport: (_) => _preparation,
      );
      final other = _TestBackupSource(
        id: 'other',
        priority: 100002,
        onPrepareImport: (_) => ImportPreparation(
          versionCheck: _preparation.versionCheck,
          executeImport: () async => otherWrites++,
        ),
      );
      final container = _containerFor([profiles, pin, feed, other]);
      addTearDown(container.dispose);
      final listener = container.listen(
        importDataProvider('https://example.com'),
        (_, _) {},
      );
      addTearDown(listener.close);
      final context = await _context(tester, container);

      await container
          .read(importDataProvider('https://example.com').notifier)
          .startImport(context);

      final tasks = container
          .read(importDataProvider('https://example.com'))
          .tasks;
      for (final id in ['profiles', 'pinned_searches', 'following_feeds']) {
        expect(
          tasks.singleWhere((task) => task.id == id).importStatus,
          isA<ImportError>(),
        );
      }
      expect(
        tasks.singleWhere((task) => task.id == 'other').importStatus,
        isA<ImportDone>(),
      );
      expect(otherWrites, 1);
    },
  );
}

ProviderContainer _containerFor(List<_TestBackupSource> sources) {
  final registry = BackupRegistry();
  sources.forEach(registry.register);
  return ProviderContainer(
    overrides: [
      backupRegistryProvider.overrideWithValue(registry),
      exportCategoriesProvider.overrideWithValue([
        for (final source in sources)
          ExportCategory(
            name: source.id,
            displayName: source.displayName,
            route: source.id,
            handler: source.capabilities.server.export,
          ),
      ]),
    ],
  );
}

Future<BuildContext> _context(
  WidgetTester tester,
  ProviderContainer container,
) async {
  late BuildContext context;
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Builder(
          builder: (value) {
            context = value;
            return const SizedBox();
          },
        ),
      ),
    ),
  );
  return context;
}

const _preparation = ImportPreparation(
  versionCheck: VersionCheckInfo(
    result: VersionCheckResult.compatible,
    currentVersion: null,
    importVersion: null,
  ),
  executeImport: _completeImport,
);

Future<void> _completeImport() async {}

class _TestBackupSource implements BackupDataSource {
  _TestBackupSource({
    required this.onPrepareImport,
    this.id = 'test',
    this.priority = 0,
  });

  final ImportPreparation Function(BuildContext? context) onPrepareImport;

  @override
  final String id;

  @override
  final int priority;

  @override
  String get displayName => 'Test';

  @override
  late final capabilities = BackupCapabilities(
    server: ServerCapability(
      export: (_) => throw UnimplementedError(),
      prepareImport: (_, context) async => onPrepareImport(context),
    ),
  );

  @override
  Widget buildTile(BuildContext context) => const SizedBox();
}
