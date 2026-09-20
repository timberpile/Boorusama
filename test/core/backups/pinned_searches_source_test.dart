import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:boorusama/core/backups/preparation/preparation_pipeline.dart';
import 'package:boorusama/core/backups/preparation/version_checking.dart';
import 'package:boorusama/core/backups/types/backup_data_source.dart';
import 'package:boorusama/core/backups/sources/booru_configs_source.dart';
import 'package:boorusama/core/backups/sources/pinned_search_backup_data.dart';
import 'package:boorusama/core/backups/sources/pinned_searches_source.dart';
import 'package:boorusama/core/backups/sources/providers.dart';
import 'package:boorusama/core/backups/transfer/import/import_data_notifier.dart';
import 'package:boorusama/core/backups/transfer/import/transfer_data_dialog.dart';
import 'package:boorusama/core/backups/types.dart';
import 'package:boorusama/core/backups/widgets/backup_restore_tile.dart';
import 'package:boorusama/core/backups/zip/bulk_backup_service.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/src/data/booru_config_repository_hive.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/errors/types.dart';
import 'package:boorusama/core/posts/post/providers.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/search/subscriptions/providers.dart';
import 'package:boorusama/core/search/subscriptions/src/data/providers.dart';
import 'package:boorusama/core/search/subscriptions/src/data/hive/search_subscription_repository_hive.dart';
import 'package:boorusama/core/search/subscriptions/src/refresh/chronological_search_scanner.dart';
import 'package:boorusama/core/search/subscriptions/src/refresh/search_refresh_query_adapter.dart';
import 'package:boorusama/core/search/subscriptions/src/services/search_refresh_service.dart';
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
import 'package:foundation/foundation.dart';
import 'package:hive_ce/hive.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:shelf/shelf.dart' as shelf;

import '../search/subscriptions/subscription_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final action in ['cancel', 'dismiss', 'accept', 'change profiles']) {
    testWidgets('standalone unmatched imports $action before writing', (
      tester,
    ) async {
      final harness = _Harness();
      addTearDown(harness.container.dispose);
      await harness.profiles.addAll([_profile]);
      final beforePins = await harness.repository.getAll();
      final beforeFeeds = await harness.repository.getFeeds();
      final beforeOrg = await harness.repository.getOrganization();
      final context = await _pumpReboot(tester, harness);
      Object? error;
      final pending = harness
          .source
          .resultExecutor!(
            _data(includeMissing: true, missingFeed: true),
            context,
          )
          .then<void>(
            (_) {},
            onError: (Object e) {
              error = e;
            },
          );
      await tester.pumpAndSettle();
      expect(find.text('Skip unmatched records?'), findsOneWidget);
      expect(
        find.text(
          '2 pinned searches or feeds have no matching profile and will be skipped. Continue importing?',
        ),
        findsOneWidget,
      );
      expect(await harness.repository.getAll(), beforePins);
      if (action == 'change profiles') await harness.profiles.clear();
      if (action == 'dismiss') {
        Navigator.of(context).pop();
      } else {
        await tester.tap(
          find.text(action == 'cancel' ? 'Cancel' : 'Skip and import'),
        );
      }
      await tester.pumpAndSettle();
      await pending;
      if (action == 'accept') {
        expect(error, isNull);
        expect((await harness.repository.getAll()).map((p) => p.id), [_id]);
      } else {
        expect(error, isA<ImportCancelledException>());
        expect(await harness.repository.getAll(), beforePins);
        expect(await harness.repository.getFeeds(), beforeFeeds);
        expect(await harness.repository.getOrganization(), beforeOrg);
      }
    });
  }

  test(
    'headless unmatched imports cancel before changing organization',
    () async {
      final harness = _Harness();
      addTearDown(harness.container.dispose);
      await harness.profiles.addAll([_profile]);
      final before = await harness.repository.getOrganization();
      await expectLater(
        harness.source.resultExecutor!(_data(includeMissing: true), null),
        throwsA(isA<ImportCancelledException>()),
      );
      expect(await harness.repository.getAll(), isEmpty);
      expect(await harness.repository.getFeeds(), isEmpty);
      expect(await harness.repository.getOrganization(), before);
    },
  );

  test('headless ZIP preflight cancels before replacing profiles', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final harness = _Harness();
    addTearDown(harness.container.dispose);
    harness.container.read(allBackupSourcesProvider);
    await harness.profiles.addAll([_replacement(id: 8)]);
    final profiles = await harness.profiles.getAll();
    final directory = Directory.systemTemp.createTempSync('preflight-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final file = _writeBackupZip(
      directory,
      harness,
      includePins: true,
      pinData: _data(includeMissing: true),
    );
    await expectLater(
      harness.container
          .read(bulkBackupServiceProvider)
          .importFromZip(file.path, null),
      throwsA(isA<ImportCancelledException>()),
    );
    expect(await harness.profiles.getAll(), profiles);
    expect(await harness.repository.getAll(), isEmpty);
  });

  for (final selectedProfiles in [false, true]) {
    test(
      'ZIP ${selectedProfiles ? 'aborts for invalid selected profiles' : 'uses current profiles when profiles are deselected'}',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.linux;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        final harness = _Harness();
        addTearDown(harness.container.dispose);
        await harness.profiles.addAll([_profile]);
        final before = await harness.profiles.getAll();
        final directory = Directory.systemTemp.createTempSync('preflight-');
        addTearDown(() => directory.deleteSync(recursive: true));
        final file = _writeBackupZip(
          directory,
          harness,
          includePins: true,
          backupProfiles: [],
        );
        final importing = harness.container
            .read(bulkBackupServiceProvider)
            .importFromZip(
              file.path,
              null,
              onlySourceIds: [
                if (selectedProfiles) 'profiles',
                'pinned_searches',
              ],
            );
        if (selectedProfiles) {
          await expectLater(importing, throwsStateError);
          expect(await harness.repository.getAll(), isEmpty);
        } else {
          final result = await importing;
          expect(result.imported, ['pinned_searches']);
          expect((await harness.repository.getAll()).single.profileId, 4);
        }
        expect(await harness.profiles.getAll(), before);
      },
    );
  }

  for (final action in ['cancel', 'accept']) {
    testWidgets(
      'ZIP $action checks projected profiles before any source writes',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.linux;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        final harness = (await tester.runAsync(() async {
          final harness = _Harness();
          await harness.profiles.addAll([
            _replacement(id: 8, url: 'https://old.test'),
          ]);
          await harness.repository.restoreForProfile(8, [_runtimePin(8)]);
          await harness.container.read(searchSubscriptionsProvider.future);
          return harness;
        }))!;
        addTearDown(harness.container.dispose);
        var otherWrites = 0;
        harness.container
            .read(backupRegistryProvider)
            .register(
              _OtherBackupSource(() {
                otherWrites++;
              }),
            );
        final context = await _pumpReboot(tester, harness);
        final directory = Directory.systemTemp.createTempSync('preflight-');
        addTearDown(() => directory.deleteSync(recursive: true));
        final file = _writeBackupZip(
          directory,
          harness,
          includePins: true,
          includeOther: true,
          pinData: _data(includeMissing: true),
        );
        await tester.runAsync(() async {
          final beforeProfiles = await harness.profiles.getAll();
          final beforePins = await harness.repository.getAll();
          final beforeOrg = await harness.repository.getOrganization();
          Object? error;
          final pending = harness.container
              .read(bulkBackupServiceProvider)
              .importFromZip(file.path, context)
              .then<void>(
                (_) {},
                onError: (Object e) {
                  error = e;
                },
              );
          for (
            var i = 0;
            i < 100 && find.text('Skip unmatched records?').evaluate().isEmpty;
            i++
          ) {
            await Future<void>.delayed(const Duration(milliseconds: 10));
            _renderPendingFrame(tester);
          }
          expect(find.text('Skip unmatched records?'), findsOneWidget);
          expect(
            find.text(
              '1 pinned searches or feeds have no matching profile and will be skipped. Continue importing?',
            ),
            findsOneWidget,
          );
          expect(otherWrites, 0);
          expect(await harness.profiles.getAll(), beforeProfiles);
          expect(await harness.repository.getAll(), beforePins);
          Navigator.of(context).pop(action == 'accept');
          await pending;
          if (action == 'cancel') {
            expect(error, isA<ImportCancelledException>());
            expect(otherWrites, 0);
            expect(await harness.profiles.getAll(), beforeProfiles);
            expect(await harness.repository.getAll(), beforePins);
            expect(await harness.repository.getOrganization(), beforeOrg);
          } else {
            expect(error, isNull);
            expect(otherWrites, 1);
            expect((await harness.profiles.getAll()).map((p) => p.id), [4]);
            expect((await harness.repository.getAll()).single.profileId, 4);
          }
        });
        await tester.pump();
        debugDefaultTargetPlatformOverride = null;
      },
    );
  }

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
      {
        'kind': 'organization',
        'homeSearchIds': [_id],
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
      expect(result?.skippedProfileCount, 0);
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
      expect(repeated?.skippedProfileCount, 0);
    },
  );

  test(
    'exports credential-free identity and maps different local credentials',
    () async {
      final exporter = _Harness();
      final importer = _Harness();
      addTearDown(exporter.container.dispose);
      addTearDown(importer.container.dispose);
      await exporter.profiles.addAll([
        _replacement(
          url:
              'https://private-user:private-password@EXAMPLE.test:8443/Posts/'
              '?api_key=private-token#private-fragment',
        ),
      ]);
      await exporter.repository.restoreForProfile(4, [_runtimePin(4)]);
      await importer.profiles.addAll([
        _replacement(
          id: 8,
          url:
              'https://local-user:local-password@example.test:8443/Posts'
              '?other_key=local-token#local-fragment',
        ),
      ]);

      final data = await exporter.source.dataGetter();
      expect(
        data.records.single.profile.url,
        'https://example.test:8443/Posts',
      );
      final response = await exporter.source.capabilities.server.export(
        shelf.Request('GET', Uri.parse('https://device.test/pinned_searches')),
      );
      final text = await response.readAsString();
      expect(text, isNot(contains('private-')));
      final parsed = importer.source.handler.parse(
        importer.source.converter.decode(data: text),
      );
      final result = await importer.source.resultExecutor!(parsed, null);
      expect(result?.pinnedSearchCount, 1);
      expect(result?.skippedProfileCount, 0);
      expect((await importer.repository.getAll()).single.profileId, 8);
    },
  );

  final slashCases = [
    (description: 'root', url: 'https://EXAMPLE.test////'),
    (description: 'base path', url: 'https://EXAMPLE.test/Posts////'),
  ];
  for (final c in slashCases) {
    test(
      'exported pins restore to the same profile with repeated ${c.description} slashes',
      () async {
        final harness = _Harness();
        addTearDown(harness.container.dispose);
        await harness.profiles.addAll([_replacement(url: c.url)]);
        await harness.repository.restoreForProfile(4, [_runtimePin(4)]);
        final response = await harness.source.capabilities.server.export(
          shelf.Request(
            'GET',
            Uri.parse('https://device.test/pinned_searches'),
          ),
        );
        final parsed = harness.source.handler.parse(
          harness.source.converter.decode(data: await response.readAsString()),
        );
        await harness.repository.delete(_id);

        final result = await harness.source.resultExecutor!(parsed, null);

        expect(result?.pinnedSearchCount, 1);
        expect(result?.skippedProfileCount, 0);
        expect((await harness.repository.getAll()).single.profileId, 4);
      },
    );
  }

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
      expect(harness.source.lastImportResult?.skippedProfileCount, 0);
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
    (
      description: 'preserves pin history when only profile credentials change',
      replacement: _replacement(
        url:
            'https://new-user:new-password@example.test/'
            '?api_key=new-key#new-fragment',
      ),
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

  final staleRefreshCases = [
    (description: 'success', fails: false),
    (description: 'failure', fails: true),
  ];
  for (final c in staleRefreshCases) {
    test(
      'discards an old refresh ${c.description} after profile replacement restores the same UUID',
      () async {
        final harness = _Harness();
        addTearDown(harness.container.dispose);
        await harness.profiles.addAll([_profile]);
        final oldPin = await harness.repository.create(
          id: _id,
          profileId: 4,
          query: 'cat',
          name: null,
          createdAt: DateTime.utc(2026),
        );
        final fetched = Completer<void>();
        final release = Completer<void>();
        var calls = 0;
        var posts = TestSearchPostRepository((_, _, _) async {
          calls++;
          fetched.complete();
          await release.future;
          return c.fails
              ? Either.left(
                  AppError(
                    type: AppErrorType.cannotReachServer,
                    message: 'offline',
                  ),
                )
              : Either.of(
                  PostResult(
                    posts: [TestSearchPost(42, DateTime.utc(2026, 9))],
                    total: 1,
                  ),
                );
        });
        final refresh = SearchRefreshService(
          repository: harness.repository,
          resolvePostRepository: (_) => posts,
          resolveQueryAdapter: (_) => const DefaultSearchRefreshQueryAdapter(),
          scanner: ChronologicalSearchScanner(),
        );
        final pending = refresh.refresh(oldPin, _profile);
        await fetched.future;
        final profilesSource =
            harness.container.read(booruConfigsBackupSourceProvider)
                as BooruConfigsBackupSource;
        final replacement = _replacement(url: 'https://replacement.test');
        await profilesSource.executor([replacement], null);
        expect(await harness.repository.getById(_id), isNull);
        final data = PinnedSearchBackupData(
          records: [
            PinnedSearchBackupRecord(
              id: _id,
              name: null,
              query: 'cat',
              position: 0,
              profile: PinnedSearchProfileReference(
                id: 4,
                booruType: 'danbooru',
                url: replacement.url,
                name: replacement.name,
              ),
            ),
          ],
        );
        final result = await harness.source.resultExecutor!(data, null);
        expect(result?.pinnedSearchCount, 1);
        final restored = (await harness.repository.getById(_id))!;
        expect(restored.createdAt, isNot(oldPin.createdAt));
        expect(restored.previews, isEmpty);
        expect(restored.recentPostIdentities, isEmpty);
        expect(restored.unreadCount, 0);
        expect(restored.lastSuccessfulCheckAt, isNull);
        expect(restored.lastAttemptAt, isNull);
        expect(restored.lastErrorKind, isNull);
        expect(calls, 1);

        release.complete();
        expect(await pending, const SearchRefreshDiscarded());
        expect(await harness.repository.getById(_id), restored);

        posts = TestSearchPostRepository((_, _, _) async {
          calls++;
          return Either.of(
            PostResult(
              posts: [TestSearchPost(77, DateTime.utc(2026, 9))],
              total: 1,
            ),
          );
        });
        expect(
          await refresh.refresh(restored, replacement),
          isA<SearchRefreshSucceeded>(),
        );
        final refreshed = (await harness.repository.getById(_id))!;
        expect(refreshed.previews.map((post) => post.postId), [77]);
        expect(refreshed.unreadCount, 0);
        expect(refreshed.lastSuccessfulCheckAt, isNotNull);
        expect(refreshed.lastErrorKind, isNull);
        expect(calls, 2);
      },
    );
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
    'restores both profiles with their pins feeds and shared order when replacement fails',
    () async {
      final harness = _Harness();
      addTearDown(harness.container.dispose);
      await harness.profiles.addAll([_profile, _replacement(id: 5)]);
      final oldProfiles = await harness.profiles.getAll();
      await harness.repository.restoreForProfile(4, [_runtimePin(4)]);
      final other = await harness.repository.create(
        profileId: 5,
        query: 'dog',
        name: 'Dogs',
      );
      final homePins = <SearchSubscription>[];
      for (final profileId in [4, 5]) {
        homePins.add(
          await harness.repository.create(
            profileId: profileId,
            query: 'bird',
            name: 'Birds',
          ),
        );
        await harness.repository.saveFeed(
          profileId: profileId,
          name: 'Following',
          queries: ['fish'],
        );
      }
      final organization = SearchOrganization(
        folders: [
          SharedSearchFolder(
            id: 'shared',
            name: 'Animals',
            searchIds: [other.id, _id],
          ),
        ],
        homeSearchIds: [homePins[1].id, homePins[0].id],
      );
      await harness.repository.replaceOrganization(organization);
      final oldPins = await harness.repository.getAll();
      final oldFeeds = await harness.repository.getFeeds();
      (harness.profiles.box as _ProfileBox).failNextWrite = true;
      final source =
          harness.container.read(booruConfigsBackupSourceProvider)
              as BooruConfigsBackupSource;

      await expectLater(
        source.executor([_replacement(id: 8)], null),
        throwsStateError,
      );

      expect(await harness.profiles.getAll(), oldProfiles);
      expect(await harness.repository.getAll(), unorderedEquals(oldPins));
      expect(await harness.repository.getFeeds(), unorderedEquals(oldFeeds));
      expect(await harness.repository.getOrganization(), organization);
      expect(
        (await harness.container.read(
          searchSubscriptionsProvider.future,
        )).subscriptions,
        unorderedEquals(oldPins),
      );
    },
  );

  testWidgets(
    'shows the definition count and explains skipped profile imports',
    (tester) async {
      final harness = _Harness();
      addTearDown(harness.container.dispose);
      await harness.profiles.addAll([_profile]);
      await harness.source.resultExecutor!(_data(), null);
      const result = BackupOperationResult(
        bookmarkCount: 0,
        pinnedSearchCount: 1,
        skippedProfileCount: 1,
      );
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
      expect(tile.importSuccessMessageBuilder!(result), contains('Skipped 1'));
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

  for (final action in ['matched', 'cancel', 'accept', 'late cancel']) {
    testWidgets(
      'server restore $action preflights before exposing the profile restart',
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
                    payload: harness.source.handler.encode(
                      _data(includeMissing: action != 'matched'),
                    ),
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
        if (action == 'late cancel') {
          harness.container
              .read(backupRegistryProvider)
              .register(
                _OtherBackupSource(
                  () => throw const ImportCancelledException(),
                  id: 'pinned_searches',
                  priority: 100000,
                ),
              );
        }
        final notifier =
            harness.container.read(importDataProvider(url).notifier)
              ..deselectAllTasks()
              ..toggleTask('profiles')
              ..toggleTask('pinned_searches');

        await tester.runAsync(() async {
          final pending = HttpOverrides.runWithHttpOverrides(
            () => notifier.startImport(context),
            _LocalHttpOverrides(),
          );
          if (action == 'cancel' || action == 'accept') {
            await _waitForWarning(tester);
            expect(await harness.profiles.getAll(), isEmpty);
            expect(await harness.repository.getAll(), isEmpty);
            Navigator.of(context).pop(action == 'accept');
          }
          await pending;
        });
        await tester.pump();
        final state = harness.container.read(importDataProvider(url));
        if (action == 'cancel') {
          expect(state.step, ImportStep.selection);
          expect(await harness.profiles.getAll(), isEmpty);
          expect(await tester.runAsync(harness.repository.getAll), isEmpty);
          expect(state.reloadPayload, isNull);
          return;
        }
        if (action == 'late cancel') {
          expect(state.step, ImportStep.done);
          expect(state.reloadPayload?.configs.map((profile) => profile.id), [
            4,
          ]);
          expect(
            state.tasks
                .firstWhere((task) => task.id == 'profiles')
                .importStatus,
            isA<ImportDone>(),
          );
          expect(
            state.tasks
                .firstWhere((task) => task.id == 'pinned_searches')
                .importStatus,
            isNot(isA<ImportDone>()),
          );
          expect(await tester.runAsync(harness.repository.getAll), isEmpty);
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: harness.container,
              child: BooruLocalization(
                child: MaterialApp(
                  builder: (context, child) => KurumiTheme(
                    data: KurumiThemeData.fromMaterial(Theme.of(context)),
                    child: child!,
                  ),
                  home: Scaffold(body: ImportingStep(url: url)),
                ),
              ),
            ),
          );
          expect(find.text('Restart App'), findsOneWidget);
          return;
        }
        expect(
          state.tasks
              .where((task) => task.status == SelectStatus.selected)
              .map((task) => task.importStatus),
          everyElement(isA<ImportDone>()),
        );
        final pins = await tester.runAsync(harness.repository.getAll);
        expect(pins!.map((pin) => pin.id), [_id]);
        expect(state.reloadPayload?.configs.map((config) => config.id), [4]);
        expect(context.mounted, isTrue);
      },
    );
  }

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

Future<void> _waitForWarning(WidgetTester tester) async {
  for (var i = 0; i < 100; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    _renderPendingFrame(tester);
    if (find.text('Skip unmatched records?').evaluate().isNotEmpty) return;
  }
  fail('Missing profile warning did not appear');
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
  PinnedSearchBackupData? pinData,
  List<BooruConfig>? backupProfiles,
  bool includeOther = false,
}) {
  final source =
      harness.container.read(booruConfigsBackupSourceProvider)
          as BooruConfigsBackupSource;
  final entries = {
    if (includeOther) 'other.json': '{}',
    'manifest.json': jsonEncode({
      'version': 1,
      'exportDate': '2026-09-14T12:00:00Z',
      'sourceFiles': {
        if (includeOther) 'other': 'other.json',
        if (includePins) 'pinned_searches': 'pins.json',
        'profiles': 'profiles.json',
      },
    }),
    'profiles.json': source.converter.encode(
      payload: (backupProfiles ?? [_profile]).map((p) => p.toJson()).toList(),
    ),
    if (includePins)
      'pins.json': harness.source.converter.encode(
        payload: harness.source.handler.encode(pinData ?? _data()),
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

PinnedSearchBackupData _data({
  bool includeMissing = false,
  bool missingFeed = false,
}) => PinnedSearchBackupData(
  feeds: [
    if (missingFeed)
      const PinnedSearchFeedBackupRecord(
        id: '550e8400-e29b-41d4-a716-446655440099',
        name: 'Missing feed',
        position: 0,
        queries: ['cat'],
        profile: PinnedSearchProfileReference(
          id: 5,
          booruType: 'gelbooru',
          url: 'https://missing.test',
          name: 'Missing',
        ),
      ),
  ],
  records: [
    const PinnedSearchBackupRecord(
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
    if (includeMissing)
      const PinnedSearchBackupRecord(
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

class _OtherBackupSource implements BackupDataSource {
  _OtherBackupSource(this.onWrite, {this.id = 'other', this.priority = 0});
  final void Function() onWrite;
  @override
  final String id;
  @override
  String get displayName => 'Other';
  @override
  final int priority;
  ImportPreparation _prepare() => ImportPreparation(
    versionCheck: const VersionCheckInfo(
      result: VersionCheckResult.compatible,
      currentVersion: null,
      importVersion: null,
    ),
    executeImport: () async {
      onWrite();
    },
  );
  @override
  late final capabilities = BackupCapabilities(
    server: ServerCapability(
      export: (_) => throw UnimplementedError(),
      prepareImport: (_, _) async => _prepare(),
    ),
    file: FileCapability(
      export: (_, {options}) async => null,
      prepareImport: (_, _) async => _prepare(),
    ),
  );
  @override
  Widget buildTile(BuildContext context) => const SizedBox();
}
