import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:boorusama/core/backups/folder_sync/pages.dart';
import 'package:boorusama/core/backups/folder_sync/protocol.dart';
import 'package:boorusama/core/backups/folder_sync/providers.dart';
import 'package:boorusama/core/backups/folder_sync/service.dart';
import 'package:boorusama/core/backups/folder_sync/storage.dart';
import 'package:boorusama/core/backups/folder_sync/widgets.dart';
import 'package:boorusama/core/bookmarks/providers.dart';
import 'package:boorusama/core/bookmarks/types.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:oktoast/oktoast.dart';

void main() {
  testWidgets(
    'ordinary sync settings and publication stay usable at 320dp and 2x text',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final service = (await tester.runAsync(() async {
        final service = FolderSyncService(
          metadata: _Metadata(),
          port: _Port(),
          storageFor: (_) => _Storage(),
        );
        await service.initialize();
        return service;
      }))!;
      final container = await _mount(tester, service, const FolderSyncPage());
      try {
        await tester.pumpAndSettle();
        expect(find.text('Choose a shared folder to begin.'), findsOneWidget);
        await tester.scrollUntilVisible(find.text('Sync now'), 120);
        final syncNow = tester.widget<TextButton>(
          find.widgetWithText(TextButton, 'Sync now'),
        );
        expect(syncNow.onPressed, isNull);
        await tester.scrollUntilVisible(
          find.widgetWithText(ListTile, 'Publish'),
          120,
        );
        await tester.tap(find.widgetWithText(ListTile, 'Publish'));
        await tester.pumpAndSettle();
        expect(find.byType(CheckboxListTile), findsOneWidget);
        final committed = service.changes.first;
        await tester.ensureVisible(find.byType(Checkbox));
        await tester.tap(find.byType(Checkbox));
        await _pumpUntilCommitted(tester, committed);
        await tester.pumpAndSettle();
        expect((service.snapshot['rules'] as Map).length, 1);
        expect(find.text('Include current subgroups'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        container.dispose();
        unawaited(service.dispose());
        await tester.pump();
      }
    },
  );
  testWidgets(
    'ancestor numeric badge deduplicates stable additions without marking descendants seen',
    (tester) async {
      const root = '10000000-0000-4000-8000-000000000001';
      const child = '10000000-0000-4000-8000-000000000002';
      const sibling = '10000000-0000-4000-8000-000000000003';
      final metadata = _Metadata();
      final service = (await tester.runAsync(() async {
        final initial = FolderSyncService(
          metadata: metadata,
          port: _Port(),
          storageFor: (_) => _Storage(),
        );
        await initial.initialize();
        await initial.dispose();
        metadata.value['subscriptions'] = {
          'a': {
            'kind': 'bookmarks',
            'localId': child,
            'unseen': ['post:shared'],
            'changed': true,
          },
          'b': {
            'kind': 'bookmarks',
            'localId': sibling,
            'unseen': ['post:shared', 'post:second'],
            'changed': true,
          },
        };
        final service = FolderSyncService(
          metadata: metadata,
          port: _Port(),
          storageFor: (_) => _Storage(),
        );
        await service.initialize();
        return service;
      }))!;
      final library = BookmarkLibraryState(
        bookmarks: const [],
        groups: [
          BookmarkGroup(id: root, name: 'Root', bookmarkIds: {}),
          BookmarkGroup(
            id: child,
            name: 'Child',
            parentGroupId: root,
            bookmarkIds: {},
          ),
          BookmarkGroup(
            id: sibling,
            name: 'Sibling',
            parentGroupId: root,
            bookmarkIds: {},
          ),
        ],
      );
      final container = await _mount(
        tester,
        service,
        const Scaffold(
          body: Column(
            children: [
              CollectionSyncIndicator(
                kind: 'bookmarks',
                localId: root,
                numericOnly: true,
              ),
              CollectionSyncIndicator(
                kind: 'bookmarks',
                localId: child,
                numericOnly: true,
              ),
              CollectionSyncIndicator(
                kind: 'bookmarks',
                localId: sibling,
                numericOnly: true,
              ),
            ],
          ),
        ),
        overrides: [bookmarkProvider.overrideWith(() => _Library(library))],
      );
      try {
        await tester.runAsync(() => container.read(bookmarkProvider.future));
        await tester.pumpAndSettle();
        expect(find.text('+2'), findsNWidgets(2));
        expect(find.text('+1'), findsOneWidget);
        expect(find.text('NEW'), findsNothing);
        expect((service.snapshot['subscriptions'] as Map)['a']['unseen'], [
          'post:shared',
        ]);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        container.dispose();
        unawaited(service.dispose());
        await tester.pump();
      }
    },
  );
}

Future<void> _pumpUntilCommitted(
  WidgetTester tester,
  Future<void> signal,
) async {
  var complete = false;
  Object? failure;
  unawaited(
    signal.then(
      (_) => complete = true,
      onError: (Object error) {
        failure = error;
        complete = true;
      },
    ),
  );
  // The service and the test framework use different asynchronous zones.
  // Yield their event queues until the actual write signal, without sleeping.
  for (var turns = 0; turns < 100 && !complete; turns++) {
    await tester.pump();
    await tester.runAsync(() => Future<void>(() {}));
  }
  expect(failure, isNull);
  expect(
    complete,
    isTrue,
    reason: 'The publication action must finish its durable metadata write',
  );
}

Future<ProviderContainer> _mount(
  WidgetTester tester,
  FolderSyncService service,
  Widget page, {
  List<Override> overrides = const [],
}) async {
  final container = ProviderContainer(
    overrides: [
      folderSyncServiceProvider.overrideWithValue(service),
      ...overrides,
    ],
  );
  await tester.runAsync(() => container.read(folderSyncStateProvider.future));
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: BooruLocalization(
        child: MaterialApp(
          theme: ThemeData(extensions: const [KurumiExtendedColorScheme()]),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(2)),
            child: KurumiTheme(
              data: KurumiThemeData.fromMaterial(Theme.of(context)),
              child: OKToast(child: child!),
            ),
          ),
          home: page,
        ),
      ),
    ),
  );
  return container;
}

class _Metadata implements FolderSyncMetadataStore {
  Map<String, dynamic> value = {};
  @override
  Future<Map<String, dynamic>> load() async => value;
  @override
  Future<void> save(Map<String, dynamic> data) async {
    value = jsonDecode(jsonEncode(data)) as Map<String, dynamic>;
  }
}

class _Port implements SyncCollectionPort {
  @override
  Future<List<SyncSourceCollection>> sources() async => const [
    SyncSourceCollection(
      kind: 'bookmarks',
      id: '10000000-0000-4000-8000-000000000001',
      name: 'A long collection title with an emoji 🐈',
      container: true,
    ),
  ];
  @override
  Future<SyncCapturedCollection> capture(SyncSourceCollection source) =>
      throw UnimplementedError();
  @override
  Future<SyncAppliedCollection?> inspect(String kind, String localId) async =>
      null;
  @override
  Future<SyncAppliedCollection> apply({
    required SyncRevision revision,
    required Uint8List bytes,
    required String localId,
    required String name,
    String? parentId,
  }) => throw UnimplementedError();
}

class _Storage implements FolderSyncStorage {
  @override
  Future<void> deleteOwnedRevision(
    String path, {
    required String owner,
  }) async {}
  @override
  Future<List<String>> list(String path) async => [];
  @override
  Future<Uint8List?> read(
    String path, {
    int maxBytes = folderSyncMaxBytes,
  }) async => null;
  @override
  Future<void> writeImmutable(String path, Uint8List bytes) async {}
}

class _Library extends BookmarkLibraryNotifier {
  _Library(this.library);
  final BookmarkLibraryState library;
  @override
  Future<BookmarkLibraryState> build() async => library;
}
