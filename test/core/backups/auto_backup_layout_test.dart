import 'package:boorusama/core/backups/auto/providers.dart';
import 'package:boorusama/core/backups/auto/repo_android.dart';
import 'package:boorusama/core/backups/auto/types.dart';
import 'package:boorusama/core/backups/auto/widgets.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/src/types/settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/src/gen/strings.g.dart' show TranslationProvider;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AutoBackupRepositoryAndroid.channel, (
          call,
        ) async {
          if (call.method == 'directoryDisplayName') return 'Cloud backups';
          throw PlatformException(code: 'unexpected_operation');
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AutoBackupRepositoryAndroid.channel, null);
  });

  for (final scale in [1.0, 2.0]) {
    for (final (location, display) in [
      (null, null),
      ('/storage/emulated/0/Pictures', '/storage/emulated/0/Pictures'),
      (
        'content://com.android.externalstorage.documents/tree/primary%3APictures',
        'Pictures',
      ),
      (
        'content://com.android.externalstorage.documents/tree/primary%3ADocuments%2FMy%20Backup%20Folder%2FNested%20Folder',
        'Documents/My Backup Folder/Nested Folder',
      ),
      (
        'content://com.android.externalstorage.documents/tree/ABCD-1234%3APictures',
        'ABCD-1234/Pictures',
      ),
      ('content://example.documents/tree/opaque%3A123', 'Cloud backups'),
    ]) {
      testWidgets(
        'folder controls fit at 320px and $scale text, location $location',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(320, 1600));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final savedRetention =
              location?.startsWith('content://example.') == true ? 12 : 30;
          final settings = Settings.defaultSettings.copyWith(
            autoBackup: AutoBackupSettings(
              enabled: true,
              maxBackups: savedRetention,
              userSelectedPath: location,
            ),
          );
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                settingsNotifierProvider.overrideWith(
                  () => SettingsNotifier(settings),
                ),
                autoBackupDefaultDirectoryPathProvider.overrideWith(
                  (ref) => null,
                ),
              ],
              child: TranslationProvider(
                child: MaterialApp(
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(scale)),
                    child: child!,
                  ),
                  home: const Scaffold(
                    body: SingleChildScrollView(child: AutoBackupSection()),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          if (location?.startsWith('content:') ?? false) {
            expect(find.text('$savedRetention backups'), findsOneWidget);
            final selector = tester.widget<DropdownButton<int>>(
              find.byType(DropdownButton<int>),
            );
            expect(
              selector.items!.map((item) => item.value),
              containsAll([2, 3, 4, 5, 7, 14, 30, 60, 90]),
            );
            expect(
              selector.items!.map((item) => item.value),
              contains(savedRetention),
            );
          }
          if (display != null) expect(find.text(display), findsOneWidget);
          if (location?.startsWith('content:') ?? false) {
            expect(find.text(location!), findsNothing);
          }
          expect(
            find.textContaining('allow access in the Android system picker'),
            findsOneWidget,
          );
          expect(
            find.text('Backup Now'),
            location?.startsWith('content:') ?? false
                ? findsOneWidget
                : findsNothing,
          );
        },
      );
    }
  }
}
