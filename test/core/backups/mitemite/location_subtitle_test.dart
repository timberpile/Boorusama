import 'package:boorusama/core/backups/auto/repo_android.dart';
import 'package:boorusama/core/backups/mitemite/location_subtitle.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

void main() {
  const primary =
      'content://com.android.externalstorage.documents/tree/primary%3ADocuments%2FMiteMite';
  const removable =
      'content://com.android.externalstorage.documents/tree/ABCD-1234%3ADocuments%2FMiteMite';
  const cloud = 'content://example.provider/tree/opaque%3A123';
  final calls = <MethodCall>[];
  String? displayName;
  bool revoked = false;

  setUp(() {
    calls.clear();
    displayName = 'Cloud sync folder';
    revoked = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          AutoBackupRepositoryAndroid.channel,
          (call) async {
            calls.add(call);
            if (revoked)
              throw PlatformException(code: 'backup_folder_access_required');
            return displayName;
          },
        );
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AutoBackupRepositoryAndroid.channel, null),
  );
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final entry in [
    (primary, 'Documents/MiteMite'),
    (removable, 'ABCD-1234/Documents/MiteMite'),
    (cloud, 'Cloud sync folder'),
    ('/home/test/My Sync', '/home/test/My Sync'),
  ]) {
    testWidgets(
      'Storage Location displays ${entry.$2} without changing its opaque input',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: BooruLocalization(
              child: MaterialApp(
                home: Scaffold(
                  body: MiteMiteLocationSubtitle(
                    location: entry.$1,
                    lastUpdated: null,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(entry.$2), findsOneWidget);
        if (entry.$1.startsWith('content:')) {
          expect(find.text(entry.$1), findsNothing);
          expect(calls.single.method, 'directoryDisplayName');
          expect((calls.single.arguments as Map)['location'], entry.$1);
        } else {
          expect(calls, isEmpty);
        }
        expect(
          calls.where((call) => call.method == 'prepare'),
          isEmpty,
          reason: 'Display never creates a backup directory',
        );
      },
    );
  }

  for (final location in [primary, cloud, 'content://invalid/tree/']) {
    testWidgets(
      'invalid or revoked $location hides raw URI and recovers after an update',
      (tester) async {
        final input = ValueNotifier<(String?, DateTime?)>((location, null));
        addTearDown(input.dispose);
        revoked = true;
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          ProviderScope(
            child: BooruLocalization(
              child: MaterialApp(
                home: MediaQuery(
                  data: const MediaQueryData(textScaler: TextScaler.linear(2)),
                  child: Scaffold(
                    body: ValueListenableBuilder(
                      valueListenable: input,
                      builder: (_, value, _) => MiteMiteLocationSubtitle(
                        location: value.$1,
                        lastUpdated: value.$2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(location), findsNothing);
        expect(
          find.text(
            'Storage location unavailable. Choose it again to restore access.',
          ),
          findsOneWidget,
        );
        revoked = false;
        input.value = (cloud, DateTime.utc(2026));
        await tester.pumpAndSettle();
        expect(find.text('Cloud sync folder'), findsOneWidget);
        displayName = 'Renamed folder';
        input.value = (cloud, DateTime.utc(2026, 2));
        await tester.pumpAndSettle();
        expect(find.text('Renamed folder'), findsOneWidget);
        input.value = (null, null);
        await tester.pumpAndSettle();
        expect(
          find.text('Choose a shared directory to enable MiteMite.'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  test(
    'opaque provider without a display name never falls back to URI',
    () async {
      for (final value in [null, '', ' ', cloud]) {
        displayName = value;
        expect(
          await AutoBackupRepositoryAndroid.directoryDisplayPath(
            cloud,
            verifyAccess: true,
          ),
          isNull,
        );
      }
    },
  );
}
