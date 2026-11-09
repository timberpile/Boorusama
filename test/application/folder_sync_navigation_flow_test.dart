import 'dart:async';
import 'dart:typed_data';

import 'package:boorusama/core/backups/folder_sync/pages.dart';
import 'package:boorusama/core/backups/folder_sync/protocol.dart';
import 'package:boorusama/core/backups/folder_sync/providers.dart';
import 'package:boorusama/core/backups/folder_sync/service.dart';
import 'package:boorusama/core/backups/folder_sync/widgets.dart';
import 'package:boorusama/core/bookmarks/src/widgets/bookmark_group_name_dialog.dart';
import 'package:boorusama/core/navigation/app_navigation_shell.dart';
import 'package:boorusama/core/navigation/destination_id.dart';
import 'package:boorusama/core/navigation/navigation_controller.dart';
import 'package:boorusama/core/settings/src/pages/backup_and_restore_page.dart';
import 'package:boorusama/core/settings/src/pages/settings_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import 'support/headless_app_harness.dart';

void main() {
  for (final leaf in ['publish', 'receive', 'activity']) {
    testWidgets('one platform Back removes only Folder Sync $leaf', (
      tester,
    ) async {
      final harness = await _mount(tester);
      await _openLeaf(tester, harness, leaf);
      await tester.binding.handlePopRoute();
      await harness.settle(tester);
      _expectSync(tester);
      await tester.binding.handlePopRoute();
      await harness.settle(tester);
      expect(find.byType(FolderSyncPage), findsNothing);
      expect(find.byType(BackupAndRestorePage), findsOneWidget);
      await tester.binding.handlePopRoute();
      await harness.settle(tester);
      expect(find.byType(BackupAndRestorePage), findsNothing);
      expect(find.byType(SettingsPage), findsOneWidget);
      expect(find.text('Export and Import'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final received in [false, true]) {
    testWidgets(
      'collection sync entry retains Settings underlay (received=$received)',
      (tester) async {
        final harness = await _mount(tester, subscription: received);
        await _openExportImport(tester, harness);
        final context = tester.element(find.byType(BackupAndRestorePage));
        unawaited(
          openFolderSyncForCollection(
            context,
            kind: 'following_topics',
            localId: 'topic',
          ),
        );
        final page = find.byType(
          received ? FolderSyncReceivePage : FolderSyncPage,
        );
        for (var turn = 0; turn < 100 && page.evaluate().isEmpty; turn++) {
          await tester.pump();
          await tester.runAsync(() => Future<void>(() {}));
        }
        await harness.settle(tester);
        expect(page, findsOneWidget);
        await tester.binding.handlePopRoute();
        await harness.settle(tester);
        expect(page, findsNothing);
        expect(find.byType(BackupAndRestorePage), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('appbar and platform Back retain the same Folder Sync parent', (
    tester,
  ) async {
    final harness = await _mount(tester);
    await _openLeaf(tester, harness, 'publish');
    await tester.tap(find.byTooltip('Back').last);
    await harness.settle(tester);
    _expectSync(tester);
    await _tapLeaf(tester, harness, 'publish');
    await tester.binding.handlePopRoute();
    await harness.settle(tester);
    _expectSync(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'keyboard dismissal and dialog Back preserve the Sync page stack',
    (tester) async {
      final harness = await _mount(tester, phone: TestPhone.portrait);
      await _openLeaf(tester, harness, 'publish');
      unawaited(
        showBookmarkGroupNameDialog(
          tester.element(find.byType(FolderSyncPublishPage)),
          title: 'Local name',
        ),
      );
      await harness.settle(tester);
      expect(find.byType(BookmarkGroupNameDialog), findsOneWidget);
      expect(harness.keyboard.isShown, isTrue);
      // Android consumes Back to hide its IME before dispatching a route pop.
      tester.testTextInput.hide();
      await harness.settle(tester);
      expect(harness.keyboard.isShown, isFalse);
      expect(find.byType(BookmarkGroupNameDialog), findsOneWidget);
      await tester.binding.handlePopRoute();
      await harness.settle(tester);
      expect(find.byType(BookmarkGroupNameDialog), findsNothing);
      expect(find.byType(FolderSyncPublishPage), findsOneWidget);
      await tester.binding.handlePopRoute();
      await harness.settle(tester);
      _expectSync(tester);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'subscription popup Back removes only the popup before its Sync page',
    (tester) async {
      final harness = await _mount(tester, subscription: true);
      await _openLeaf(tester, harness, 'publish');
      final context = tester.element(find.byType(FolderSyncPublishPage));
      final container = ProviderScope.containerOf(context);
      final service = container.read(folderSyncServiceProvider);
      unawaited(
        showFolderSyncSubscriptionActions(context, service, 'publisher/topic'),
      );
      await harness.settle(tester);
      expect(find.text(context.t.folder_sync.unsubscribe), findsOneWidget);
      await tester.binding.handlePopRoute();
      await harness.settle(tester);
      expect(find.text(context.t.folder_sync.unsubscribe), findsNothing);
      expect(find.byType(FolderSyncPublishPage), findsOneWidget);
      expect(
        (service.snapshot['subscriptions'] as Map).containsKey(
          'publisher/topic',
        ),
        isTrue,
      );
      await tester.binding.handlePopRoute();
      await harness.settle(tester);
      _expectSync(tester);
      expect(tester.takeException(), isNull);
    },
  );
}

void _expectSync(WidgetTester tester) {
  expect(find.byType(FolderSyncPage), findsOneWidget);
  expect(find.byType(FolderSyncPublishPage), findsNothing);
  expect(find.byType(FolderSyncReceivePage), findsNothing);
  expect(find.byType(FolderSyncActivityPage), findsNothing);
  expect(
    find.text(
      tester.element(find.byType(FolderSyncPage)).t.folder_sync.sync_now,
    ),
    findsOneWidget,
  );
}

Future<HeadlessAppHarness> _mount(
  WidgetTester tester, {
  TestPhone? phone,
  bool subscription = false,
}) async {
  final service = (await tester.runAsync(() async {
    final metadata = _Metadata();
    FolderSyncService create() => FolderSyncService(
      metadata: metadata,
      port: _Port(),
      storageFor: (_) =>
          throw StateError('Back navigation must not access shared storage'),
    );
    final initial = create();
    await initial.initialize();
    if (!subscription) return initial;
    await initial.dispose();
    metadata.value['subscriptions'] = {
      'publisher/topic': {
        'kind': 'following_topics',
        'localId': 'topic',
        'subscribed': true,
      },
    };
    final restored = create();
    await restored.initialize();
    return restored;
  }))!;
  addTearDown(() async {
    var disposed = false;
    Object? failure;
    unawaited(
      service.dispose().then<void>(
        (_) => disposed = true,
        onError: (Object error) {
          failure = error;
          disposed = true;
        },
      ),
    );
    for (var turn = 0; turn < 100 && !disposed; turn++) {
      await tester.pump();
      await tester.runAsync(() => Future<void>(() {}));
    }
    expect(failure, isNull);
    expect(
      disposed,
      isTrue,
      reason: 'Sync service teardown must finish its actual work',
    );
  });
  final harness = await HeadlessAppHarness.mount(
    tester,
    viewportSize: kMobileViewport,
    phone: phone,
    additionalOverrides: [folderSyncServiceProvider.overrideWithValue(service)],
  );
  await harness.settle(tester);
  final container = ProviderScope.containerOf(
    tester.element(find.byType(AppNavigationShell)),
  );
  await container
      .read(navigationControllerProvider.notifier)
      .selectDestination(
        const DestinationId.app(AppDestination.settings),
      );
  await harness.settle(tester);
  expect(find.byType(SettingsPage), findsOneWidget);
  return harness;
}

Future<void> _openExportImport(
  WidgetTester tester,
  HeadlessAppHarness harness,
) async {
  final category = find.text('Export and Import');
  await tester.ensureVisible(category);
  await tester.tap(category);
  await harness.settle(tester);
  expect(find.byType(BackupAndRestorePage), findsOneWidget);
}

Future<void> _openLeaf(
  WidgetTester tester,
  HeadlessAppHarness harness,
  String leaf,
) async {
  await _openExportImport(tester, harness);
  final strings = tester
      .element(find.byType(BackupAndRestorePage))
      .t
      .folder_sync;
  final tile = find.widgetWithText(ListTile, strings.title);
  await tester.ensureVisible(tile);
  await tester.tap(tile);
  await harness.settle(tester);
  final syncContainer = ProviderScope.containerOf(
    tester.element(find.byType(FolderSyncPage)),
  );
  for (
    var turn = 0;
    turn < 100 && !syncContainer.read(folderSyncStateProvider).hasValue;
    turn++
  ) {
    await tester.pump();
    await tester.runAsync(() => Future<void>(() {}));
  }
  expect(
    syncContainer.read(folderSyncStateProvider).hasValue,
    isTrue,
    reason: 'The actual sync-state initialization must complete before navigation assertions',
  );
  await harness.settle(tester);
  _expectSync(tester);
  await _tapLeaf(tester, harness, leaf);
}

Future<void> _tapLeaf(
  WidgetTester tester,
  HeadlessAppHarness harness,
  String leaf,
) async {
  final strings = tester.element(find.byType(FolderSyncPage)).t.folder_sync;
  final label = switch (leaf) {
    'publish' => strings.publish,
    'receive' => strings.receive,
    _ => strings.activity,
  };
  final tile = find.widgetWithText(ListTile, label);
  await tester.ensureVisible(tile);
  await tester.tap(tile);
  await harness.settle(tester);
  expect(
    find.byType(switch (leaf) {
      'publish' => FolderSyncPublishPage,
      'receive' => FolderSyncReceivePage,
      _ => FolderSyncActivityPage,
    }),
    findsOneWidget,
  );
}

class _Metadata implements FolderSyncMetadataStore {
  Map<String, dynamic> value = {};
  @override
  Future<Map<String, dynamic>> load() async => value;
  @override
  Future<void> save(Map<String, dynamic> data) async {
    value = data;
  }
}

class _Port implements SyncCollectionPort {
  @override
  Future<List<SyncSourceCollection>> sources() async => const [];
  @override
  Future<SyncCapturedCollection> capture(SyncSourceCollection source) =>
      throw UnimplementedError();
  @override
  Future<SyncAppliedCollection?> inspect(String kind, String localId) =>
      throw UnimplementedError();
  @override
  Future<SyncAppliedCollection> apply({
    required SyncRevision revision,
    required Uint8List bytes,
    required String localId,
    required String name,
    String? parentId,
  }) => throw UnimplementedError();
}
