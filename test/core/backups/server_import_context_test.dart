// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:boorusama/core/backups/preparation/version_checking.dart';
import 'package:boorusama/core/backups/sources/providers.dart';
import 'package:boorusama/core/backups/transfer/import/import_data_notifier.dart';
import 'package:boorusama/core/backups/types/backup_data_source.dart';
import 'package:boorusama/core/backups/types/backup_registry.dart';
import 'package:boorusama/core/backups/types/types.dart';

void main() {
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
  _TestBackupSource({required this.onPrepareImport});

  final ImportPreparation Function(BuildContext? context) onPrepareImport;

  @override
  String get id => 'test';

  @override
  int get priority => 0;

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
