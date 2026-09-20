import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:boorusama/core/backups/sources/booru_configs_source.dart';
import 'package:boorusama/core/backups/sources/pinned_search_backup_data.dart';
import 'package:boorusama/core/backups/sources/pinned_searches_source.dart';
import 'package:boorusama/core/backups/sources/providers.dart';
import 'package:boorusama/core/backups/transfer/import/import_data_notifier.dart';
import 'package:boorusama/core/backups/types.dart';
import 'package:boorusama/core/backups/widgets/backup_restore_tile.dart';
import 'package:boorusama/core/backups/zip/bulk_backup_service.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/src/data/booru_config_repository_hive.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/posts/post/providers.dart';
import 'package:boorusama/core/search/subscriptions/providers.dart';
import 'package:boorusama/core/search/subscriptions/src/data/providers.dart';
import 'package:boorusama/core/search/subscriptions/src/data/hive/search_subscription_repository_hive.dart';
import 'package:boorusama/core/search/subscriptions/types.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:boorusama/core/widgets/reboot.dart';
import 'package:boorusama/foundation/filesystem.dart';
import 'package:boorusama/foundation/info/device_info.dart';
import 'package:boorusama/foundation/info/package_info.dart';
import 'package:boorusama/foundation/loggers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:shelf/shelf.dart' as shelf;

import '../search/subscriptions/subscription_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('registers and watches pinned searches after profiles', () {
    final harness = _Harness();
    addTearDown(harness.container.dispose);
    harness.container.read(allBackupSourcesProvider);
    final registry = harness.container.read(backupRegistryProvider);
    final sources = registry.getAllSources();
    expect(
      sources.map((source) => source.id).toList().sublist(sources.length - 2),
      ['profiles', 'pinned_searches'],
    );
    expect(registry.getSource('pinned_searches'), same(harness.source));
    expect(harness.source.priority, 100000);
    harness.container.invalidate(pinnedSearchesBackupSourceProvider);
    expect(
      harness.container
          .read(backupRegistryProvider)
          .getSource('pinned_searches'),
      same(harness.source),
    );
  });

  test('exports only definitions and portable profile references', () async {
    final harness = _Harness();
    addTearDown(harness.container.dispose);
    await harness.profiles.addAll([_profile]);
    final profile = (await harness.profiles.getAll()).single;
    await harness.repository.restoreForProfile(profile.id, [
      _runtimePin(profile.id),
    ]);

    final response = await harness.source.capabilities.server.export(
      shelf.Request('GET', Uri.parse('https://device.test/pinned_searches')),
    );
    final payload =
        jsonDecode(await response.readAsString()) as Map<String, dynamic>;
    expect(payload['data'], [
      {
        'id': _id,
        'name': 'Cats',
        'query': 'cat  rating:safe',
        'position': 0,
        'profile': {
          'id': profile.id,
          'booruType': 'danbooru',
          'url': 'https://example.test',
          'name': 'Example',
        },
      },
    ]);
    final result = harness.source.exportResultBuilder!(
      await harness.source.dataGetter(),
    );
    expect(result.pinnedSearchCount, 1);
    expect(result.bookmarkCount, 0);
    expect(result.groupCount, 0);
  });

  test(
    'restores against newly installed profiles and publishes clean pins without fetching posts',
    () async {
      final harness = _Harness();
      addTearDown(harness.container.dispose);
      await harness.container.read(searchSubscriptionsProvider.future);
      expect(harness.container.read(booruConfigProvider), isEmpty);

      final profilesSource =
          harness.container.read(booruConfigsBackupSourceProvider)
              as BooruConfigsBackupSource;
      await profilesSource.executor([_profile], null);
      final profile = (await harness.profiles.getAll()).single;
      expect(profile.id, 4);
      final result = await harness.source.resultExecutor!(_data(), null);

      expect(result?.pinnedSearchCount, 1);
      expect(result?.skippedProfileCount, 1);
      expect(result?.alreadyExistedCount, 0);
      final state = await harness.container.read(
        searchSubscriptionsProvider.future,
      );
      expect(state.subscriptions.map((pin) => pin.profileId), [profile.id]);
      final pin = state.subscriptions.single;
      expect(pin.previews, isEmpty);
      expect(pin.recentPostIdentities, isEmpty);
      expect(pin.unreadCount, 0);
      expect(pin.lastAttemptAt, isNull);
      expect(pin.lastSuccessfulCheckAt, isNull);
      expect(pin.lastErrorKind, isNull);
      final repeated = await harness.source.resultExecutor!(_data(), null);
      expect(repeated?.pinnedSearchCount, 0);
      expect(repeated?.alreadyExistedCount, 1);
      expect(repeated?.skippedProfileCount, 1);
    },
  );

  test(
    'file import exposes counts through the shared result interface',
    () async {
      final harness = _Harness();
      addTearDown(harness.container.dispose);
      await harness.profiles.addAll([_profile]);
      final directory = Directory.systemTemp.createTempSync(
        'pinned-source-test-',
      );
      addTearDown(() => directory.deleteSync(recursive: true));
      final file = File('${directory.path}/pins.json')
        ..writeAsStringSync(
          harness.source.converter.encode(
            payload: harness.source.handler.encode(_data()),
          ),
        );
      final prepared = await harness.source.capabilities.file!.prepareImport(
        file.path,
        null,
      );
      expect(await harness.repository.getAll(), isEmpty);
      await prepared.executeImport();
      expect(harness.source.lastImportResult?.pinnedSearchCount, 1);
      expect(harness.source.lastImportResult?.skippedProfileCount, 1);
    },
  );

  final replacementCases = [
    (
      description: 'removes pins when their profile disappears',
      replacement: _replacement(id: 8),
      preservesPins: false,
    ),
    (
      description: 'removes pins when a profile ID changes booru type',
      replacement: _replacement(type: BooruType.gelbooru),
      preservesPins: false,
    ),
    (
      description: 'removes pins when a profile ID changes site',
      replacement: _replacement(url: 'https://other.test'),
      preservesPins: false,
    ),
    (
      description: 'removes pins when a profile ID changes scheme',
      replacement: _replacement(url: 'http://example.test'),
      preservesPins: false,
    ),
    (
      description: 'removes pins when a profile ID changes path',
      replacement: _replacement(url: 'https://example.test/Posts'),
      preservesPins: false,
    ),
    (
      description: 'preserves pin history for an equivalent same-ID profile',
      replacement: _replacement(),
      preservesPins: true,
    ),
  ];
  for (final c in replacementCases) {
    test(c.description, () async {
      final harness = _Harness();
      addTearDown(harness.container.dispose);
      await harness.profiles.addAll([_profile]);
      final pin = _runtimePin(4);
      await harness.repository.restoreForProfile(4, [pin]);
      await harness.container.read(searchSubscriptionsProvider.future);
      final source =
          harness.container.read(booruConfigsBackupSourceProvider)
              as BooruConfigsBackupSource;

      await source.executor([c.replacement], null);

      final expected = c.preservesPins ? [pin] : <SearchSubscription>[];
      expect(await harness.repository.getAll(), expected);
      expect(
        (await harness.container.read(
          searchSubscriptionsProvider.future,
        )).subscriptions,
        expected,
      );
      expect((await harness.profiles.getAll()).map((profile) => profile.id), [
        c.replacement.id,
      ]);
    });
  }

  test('keeps profiles and pins when removing old pins fails', () async {
    final box = _FailingSubscriptionBox();
    final harness = _Harness(subscriptionBox: box);
    addTearDown(harness.container.dispose);
    await harness.profiles.addAll([_profile]);
    final oldProfiles = await harness.profiles.getAll();
    final pin = _runtimePin(4);
    await harness.repository.restoreForProfile(4, [pin]);
    box.failNextDelete = true;
    final source =
        harness.container.read(booruConfigsBackupSourceProvider)
            as BooruConfigsBackupSource;

    await expectLater(
      source.executor([_replacement(id: 8)], null),
      throwsStateError,
    );

    expect(await harness.profiles.getAll(), oldProfiles);
    expect(await harness.repository.getAll(), [pin]);
  });

  test(
    'restores profiles and pin history when writing replacement profiles fails',
    () async {
      final harness = _Harness();
      addTearDown(harness.container.dispose);
      await harness.profiles.addAll([_profile]);
      final oldProfiles = await harness.profiles.getAll();
      final pin = _runtimePin(4);
      await harness.repository.restoreForProfile(4, [pin]);
      (harness.profiles.box as _ProfileBox).failNextWrite = true;
      final source =
          harness.container.read(booruConfigsBackupSourceProvider)
              as BooruConfigsBackupSource;

      await expectLater(
        source.executor([_replacement(id: 8)], null),
        throwsStateError,
      );

      expect(await harness.profiles.getAll(), oldProfiles);
      expect(await harness.repository.getAll(), [pin]);
      expect(
        (await harness.container.read(
          searchSubscriptionsProvider.future,
        )).subscriptions,
        [pin],
      );
    },
  );

  testWidgets(
    'shows the definition count and explains skipped profile imports',
    (tester) async {
      final harness = _Harness();
      addTearDown(harness.container.dispose);
      await harness.profiles.addAll([_profile]);
      final result = await harness.source.resultExecutor!(_data(), null);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: harness.container,
          child: BooruLocalization(
            child: MaterialApp(
              builder: (context, child) => KurumiTheme(
                data: KurumiThemeData.fromMaterial(Theme.of(context)),
                child: child!,
              ),
              home: Scaffold(body: Builder(builder: harness.source.buildTile)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Pinned Searches'), findsOneWidget);
      expect(find.text('1 pinned search'), findsOneWidget);
      final tile = tester.widget<DefaultBackupTile>(
        find.byType(DefaultBackupTile),
      );
      expect(tile.importSuccessMessageBuilder!(result!), contains('Skipped 1'));
      expect(tile.importSuccessMessageBuilder!(result), contains('profile'));
      expect(tile.importSuccessMessageBuilder!(result), contains('Imported 1'));
      expect(
        tile.exportSuccessMessageBuilder!(
          const BackupOperationResult(bookmarkCount: 0, pinnedSearchCount: 3),
        ),
        contains('3 pinned searches'),
      );
    },
  );

  test(
    'legacy manifests omit pins without changing existing missing-source handling',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final harness = _Harness();
      addTearDown(harness.container.dispose);
      final directory = Directory.systemTemp.createTempSync(
        'pinned-legacy-test-',
      );
      addTearDown(() => directory.deleteSync(recursive: true));
      final bytes = utf8.encode(
        jsonEncode({
          'version': 1,
          'exportDate': '2026-09-01T12:00:00Z',
          'sourceFiles': <String, String>{},
        }),
      );
      final archive = Archive()
        ..addFile(ArchiveFile('manifest.json', bytes.length, bytes));
      final file = File('${directory.path}/legacy.zip')
        ..writeAsBytesSync(ZipEncoder().encode(archive));
      final service = harness.container.read(bulkBackupServiceProvider);
      final preview = await service.previewZip(file.path);
      expect(preview.missingSources, isEmpty);
      expect(preview.availableSources, isEmpty);
      final normal = await service.importFromZip(file.path, null);
      expect(normal.failed, isEmpty);
      expect(normal.skipped, isEmpty);
      final requested = await service.importFromZip(
        file.path,
        null,
        onlySourceIds: ['pinned_searches'],
      );
      expect(requested.failed, ['pinned_searches']);
      expect(await harness.repository.getAll(), isEmpty);
    },
  );

  final zipCases = [
    (
      description: 'ZIP restore restarts only after profiles and pins finish',
      includePins: true,
      sources: ['profiles', 'pinned_searches'],
      pinIds: [_id],
    ),
    (
      description: 'legacy profile-only ZIP restores without requiring pins',
      includePins: false,
      sources: ['profiles'],
      pinIds: <String>[],
    ),
  ];
  for (final c in zipCases) {
    testWidgets(c.description, (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final fs = _FrameBeforePinnedRead(tester);
      final harness = (await tester.runAsync(() async {
        final harness = _Harness(fs: fs);
        await harness.container.read(searchSubscriptionsProvider.future);
        return harness;
      }))!;
      addTearDown(harness.container.dispose);
      final snapshotsAtRestart = <Future<List<SearchSubscription>>>[];
      final context = await _pumpReboot(
        tester,
        harness,
        onRestart: () => snapshotsAtRestart.add(harness.repository.getAll()),
      );
      final mountedDuringCleanup = <bool>[];
      fs.onCleanup = () => mountedDuringCleanup.add(context.mounted);
      final directory = Directory.systemTemp.createTempSync(
        'pinned-batch-test-',
      );
      addTearDown(() => directory.deleteSync(recursive: true));
      final file = _writeBackupZip(
        directory,
        harness,
        includePins: c.includePins,
      );

      await tester.runAsync(() async {
        final result = await harness.container
            .read(bulkBackupServiceProvider)
            .importFromZip(file.path, context);
        expect(result.imported, c.sources);
        expect(result.failed, isEmpty);
      });
      await tester.pump();
      expect(snapshotsAtRestart, hasLength(1));
      expect(mountedDuringCleanup, [true]);
      final snapshot = await tester.runAsync(() => snapshotsAtRestart.single);
      expect(snapshot!.map((pin) => pin.id), c.pinIds);
      expect(context.mounted, isFalse);
      debugDefaultTargetPlatformOverride = null;
    });
  }

  testWidgets(
    'server restore finishes pins before exposing the profile restart',
    (tester) async {
      final harness = (await tester.runAsync(() async {
        final harness = _Harness();
        await harness.container.read(searchSubscriptionsProvider.future);
        return harness;
      }))!;
      addTearDown(harness.container.dispose);
      final context = await _pumpReboot(tester, harness);
      final server = await tester.runAsync(
        () => HttpServer.bind(InternetAddress.loopbackIPv4, 0),
      );
      addTearDown(() => server!.close(force: true));
      final profilesSource =
          harness.container.read(booruConfigsBackupSourceProvider)
              as BooruConfigsBackupSource;
      await tester.runAsync(() async {
        server!.listen((request) async {
          if (request.uri.path == '/pinned_searches') {
            _renderPendingFrame(tester);
          }
          final data = request.uri.path == '/profiles'
              ? profilesSource.converter.encode(payload: [_profile.toJson()])
              : harness.source.converter.encode(
                  payload: harness.source.handler.encode(_data()),
                );
          request.response.headers.contentType = ContentType.json;
          request.response.write(data);
          await request.response.close();
        });
      });
      final url = 'http://127.0.0.1:${server!.port}';
      final listener = harness.container.listen(
        importDataProvider(url),
        (_, _) {},
      );
      addTearDown(listener.close);
      final notifier = harness.container.read(importDataProvider(url).notifier)
        ..deselectAllTasks()
        ..toggleTask('profiles')
        ..toggleTask('pinned_searches');

      await tester.runAsync(
        () => HttpOverrides.runWithHttpOverrides(
          () => notifier.startImport(context),
          _LocalHttpOverrides(),
        ),
      );
      await tester.pump();
      final state = harness.container.read(importDataProvider(url));
      expect(
        state.tasks.map((task) => task.importStatus),
        everyElement(isA<ImportDone>()),
      );
      final pins = await tester.runAsync(harness.repository.getAll);
      expect(pins!.map((pin) => pin.id), [_id]);
      expect(state.reloadPayload?.configs.map((config) => config.id), [4]);
      expect(context.mounted, isTrue);
    },
  );

  testWidgets('standalone profile import still restarts after installation', (
    tester,
  ) async {
    final harness = (await tester.runAsync(() async {
      final harness = _Harness();
      await harness.container.read(searchSubscriptionsProvider.future);
      return harness;
    }))!;
    addTearDown(harness.container.dispose);
    final context = await _pumpReboot(tester, harness);
    final directory = Directory.systemTemp.createTempSync(
      'profile-single-test-',
    );
    addTearDown(() => directory.deleteSync(recursive: true));
    final source =
        harness.container.read(booruConfigsBackupSourceProvider)
            as BooruConfigsBackupSource;
    final file = File(
      '${directory.path}/profiles.json',
    )..writeAsStringSync(source.converter.encode(payload: [_profile.toJson()]));
    await tester.runAsync(() async {
      final preparation = await source.capabilities.file!.prepareImport(
        file.path,
        context,
      );
      await preparation.executeImport();
    });
    await tester.pump();
    expect((await harness.profiles.getAll()).map((profile) => profile.id), [4]);
    expect(context.mounted, isFalse);
  });
}

Future<BuildContext> _pumpReboot(
  WidgetTester tester,
  _Harness harness, {
  void Function()? onRestart,
}) async {
  late BuildContext initialContext;
  var builds = 0;
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: harness.container,
      child: BooruLocalization(
        child: Reboot(
          initialData: RebootData(
            config: _profile,
            configs: const [],
            settings: Settings.defaultSettings,
          ),
          builder: (context, data, key) {
            if (builds++ > 0) onRestart?.call();
            return MaterialApp(
              home: Builder(
                builder: (context) {
                  if (builds == 1) initialContext = context;
                  return const SizedBox();
                },
              ),
            );
          },
        ),
      ),
    ),
  );
  return initialContext;
}

File _writeBackupZip(
  Directory directory,
  _Harness harness, {
  required bool includePins,
}) {
  final source =
      harness.container.read(booruConfigsBackupSourceProvider)
          as BooruConfigsBackupSource;
  final entries = {
    'manifest.json': jsonEncode({
      'version': 1,
      'exportDate': '2026-09-14T12:00:00Z',
      'sourceFiles': {
        if (includePins) 'pinned_searches': 'pins.json',
        'profiles': 'profiles.json',
      },
    }),
    'profiles.json': source.converter.encode(payload: [_profile.toJson()]),
    if (includePins)
      'pins.json': harness.source.converter.encode(
        payload: harness.source.handler.encode(_data()),
      ),
  };
  final archive = Archive();
  for (final entry in entries.entries) {
    final bytes = utf8.encode(entry.value);
    archive.addFile(ArchiveFile(entry.key, bytes.length, bytes));
  }
  return File('${directory.path}/backup.zip')
    ..writeAsBytesSync(ZipEncoder().encode(archive));
}

class _FrameBeforePinnedRead extends IoFileSystem {
  _FrameBeforePinnedRead(this.tester);
  final WidgetTester tester;
  void Function()? onCleanup;
  @override
  Future<String> readString(String path) {
    if (path.endsWith('/pins.json')) {
      _renderPendingFrame(tester);
    }
    return super.readString(path);
  }

  @override
  Future<void> deleteDirectory(String path, {bool recursive = false}) async {
    _renderPendingFrame(tester);
    onCleanup?.call();
    await super.deleteDirectory(path, recursive: recursive);
  }
}

class _LocalHttpOverrides extends HttpOverrides {}

void _renderPendingFrame(WidgetTester tester) {
  tester.binding.handleBeginFrame(Duration.zero);
  tester.binding.handleDrawFrame();
}

const _id = '550e8400-e29b-41d4-a716-446655440000';
final _profile = BooruConfig.fromJson({
  ...BooruConfig.empty.toJson(),
  'id': 4,
  'booruId': BooruType.danbooru.id,
  'booruIdHint': BooruType.danbooru.id,
  'url': 'https://EXAMPLE.test/',
  'name': 'Example',
  'apiKey': 'private-key',
  'login': 'private-user',
});

BooruConfig _replacement({
  int id = 4,
  BooruType type = BooruType.danbooru,
  String url = 'https://example.test',
}) => BooruConfig.fromJson({
  ..._profile.toJson(),
  'id': id,
  'booruId': type.id,
  'booruIdHint': type.id,
  'url': url,
  'name': 'Replacement',
});

PinnedSearchBackupData _data() => const PinnedSearchBackupData(
  records: [
    PinnedSearchBackupRecord(
      id: _id,
      name: 'Cats',
      query: 'cat  rating:safe',
      position: 0,
      profile: PinnedSearchProfileReference(
        id: 4,
        booruType: 'danbooru',
        url: 'https://example.test',
        name: 'Example',
      ),
    ),
    PinnedSearchBackupRecord(
      id: '550e8400-e29b-41d4-a716-446655440001',
      name: null,
      query: 'dog',
      position: 0,
      profile: PinnedSearchProfileReference(
        id: 5,
        booruType: 'gelbooru',
        url: 'https://missing.test',
        name: 'Missing',
      ),
    ),
  ],
);

SearchSubscription _runtimePin(int profileId) => SearchSubscription(
  id: _id,
  profileId: profileId,
  query: 'cat  rating:safe',
  name: 'Cats',
  position: 0,
  createdAt: DateTime.utc(2026),
  unreadCount: 7,
  lastAttemptAt: DateTime.utc(2026, 9),
  lastSuccessfulCheckAt: DateTime.utc(2026, 9),
  lastErrorKind: SearchRefreshErrorKind.network,
  previews: [
    SearchPostPreview(
      postId: 42,
      postCreatedAt: DateTime.utc(2026),
      thumbnailUrl: 'https://private.test/42.jpg',
      sampleUrl: null,
      discoveredAt: DateTime.utc(2026),
    ),
  ],
  recentPostIdentities: [
    RecentSearchPostIdentity(postId: 42, postCreatedAt: DateTime.utc(2026)),
  ],
);

class _Harness {
  _Harness({
    AppFileSystem fs = const IoFileSystem(),
    MemorySubscriptionBox? subscriptionBox,
  }) {
    repository = subscriptionBox == null
        ? memorySubscriptionRepository()
        : HiveSearchSubscriptionRepository(box: subscriptionBox);
    container = ProviderContainer(
      overrides: [
        appVersionProvider.overrideWithValue(null),
        appFileSystemProvider.overrideWithValue(fs),
        settingsProvider.overrideWithValue(Settings.defaultSettings),
        deviceInfoProvider.overrideWithValue(DeviceInfo.empty()),
        booruConfigRepoProvider.overrideWithValue(profiles),
        booruConfigProvider.overrideWith(
          () => BooruConfigNotifier(initialConfigs: const []),
        ),
        searchSubscriptionRepositoryProvider.overrideWith(
          () => _RepositoryNotifier(repository),
        ),
        postRepoProvider.overrideWith(
          (ref, config) =>
              throw StateError('Restore must not resolve a post repository'),
        ),
        loggerProvider.overrideWithValue(
          ConsoleLogger(options: const ConsoleLoggerOptions.defaults()),
        ),
      ],
    );
  }
  late final SearchSubscriptionRepository repository;
  final profiles = HiveBooruConfigRepository(box: _ProfileBox());
  late final ProviderContainer container;
  PinnedSearchesBackupSource get source =>
      container.read(pinnedSearchesBackupSourceProvider)
          as PinnedSearchesBackupSource;
}

class _RepositoryNotifier extends SearchSubscriptionRepositoryNotifier {
  _RepositoryNotifier(this.repository);
  final SearchSubscriptionRepository repository;
  @override
  Future<SearchSubscriptionRepository> build() async => repository;
}

class _ProfileBox implements Box<String> {
  final _items = <int, String>{};
  var _nextKey = 20;
  var failNextWrite = false;
  @override
  Iterable<dynamic> get keys => _items.keys;
  @override
  String? get(dynamic key, {String? defaultValue}) =>
      _items[key] ?? defaultValue;

  @override
  Future<void> put(dynamic key, String value) async {
    if (failNextWrite) {
      failNextWrite = false;
      throw StateError('profile write failed');
    }
    _items[key as int] = value;
  }

  @override
  Future<int> add(String value) async {
    final key = _nextKey++;
    _items[key] = value;
    return key;
  }

  @override
  Future<int> clear() async {
    final count = _items.length;
    _items.clear();
    return count;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FailingSubscriptionBox extends MemorySubscriptionBox {
  var failNextDelete = false;
  @override
  Future<void> deleteAll(Iterable<dynamic> keys) async {
    if (failNextDelete) {
      failNextDelete = false;
      throw StateError('pin removal failed');
    }
    await super.deleteAll(keys);
  }
}
