import 'package:boorusama/core/backups/auto/failure.dart';
import 'package:boorusama/core/backups/auto/providers.dart';
import 'package:boorusama/core/backups/auto/widgets.dart';
import 'package:boorusama/core/backups/zip/providers.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/src/types/settings.dart';
import 'package:boorusama/foundation/platform.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:i18n/src/gen/strings.g.dart' show TranslationProvider;
import 'package:material_ui/material_ui.dart';

void main() {
  test('retains known stages without exception messages or arbitrary details', () {
    final failure = AutoBackupFailure.fromError(PlatformException(
      code: 'backup_storage_failed',
      message: 'content://private/document',
      details: {
        'stage': 'verify_backup_document',
        'causeType': '/private/path',
      },
    ));
    expect(failure.stage, 'verify_backup_document');
    expect(failure.requiresFolderAccess, isFalse);
    expect(failure.diagnostic, isNot(contains('private')));
  });

  test('unrecognized native fields and non-native errors remain generic', () {
    for (final error in [
      PlatformException(
        code: '/private/path',
        details: {'stage': 'content://private/document'},
      ),
      StateError('/private/path'),
    ]) {
      final failure = AutoBackupFailure.fromError(error);
      expect(failure.stage, isNull);
      expect(failure.diagnostic, 'backup_failed');
      expect(failure.requiresFolderAccess, isFalse);
    }
  });

  for (final accessRequired in [false, true]) {
    testWidgets('shows the correct retained diagnostic, access=$accessRequired', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final container = ProviderContainer(overrides: [
        appPlatformProvider.overrideWithValue(AppPlatform.android),
        settingsNotifierProvider.overrideWith(
          () => SettingsNotifier(Settings.defaultSettings),
        ),
        autoBackupDefaultDirectoryPathProvider.overrideWith((ref) => null),
      ]);
      addTearDown(container.dispose);
      final stage = accessRequired
          ? 'check_persisted_permission'
          : 'verify_backup_document';
      container.read(autoBackupFailureProvider.notifier).report(
        PlatformException(
          code: accessRequired
              ? 'backup_folder_access_required'
              : 'backup_storage_failed',
          message: '/private/path',
          details: {'stage': stage},
        ),
      );
      container.invalidate(backupProvider);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: TranslationProvider(
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(2),
              ),
              child: child!,
            ),
            home: const Scaffold(
              body: SingleChildScrollView(child: AutoBackupSection()),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.textContaining(stage), findsOneWidget);
      expect(find.textContaining('/private/path'), findsNothing);
      expect(
        find.textContaining(Translations().settings.auto_backup.folder_access_error),
        accessRequired ? findsOneWidget : findsNothing,
      );
      expect(tester.takeException(), isNull);
      container.read(autoBackupFailureProvider.notifier).clear();
      await tester.pump();
      expect(find.textContaining(stage), findsNothing);
    });
  }
}
