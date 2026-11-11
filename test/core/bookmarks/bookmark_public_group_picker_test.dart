import 'dart:async';
import 'dart:io';

import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_group_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/unified_bookmark_repository.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/unified_bookmark_group_repository.dart';
import 'package:boorusama/core/bookmarks/src/data/providers.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_picker_actions.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/src/providers/pool_bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/src/services/bookmark_storage_migration.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_picker_request.dart';
import 'package:boorusama/core/bookmarks/src/types/content_group_bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/pool_bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/pool_bookmark_capability.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/content/anonymous_read_scope.dart';
import 'package:boorusama/core/content/anonymous_source_policy.dart';
import 'package:boorusama/core/content/content_access.dart';
import 'package:boorusama/core/content/content_access_provider.dart';
import 'package:boorusama/core/content/content_map.dart';
import 'package:boorusama/core/hive/hive_adapters.dart';
import 'package:boorusama/core/posts/post/src/types/image_url_resolver.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/src/types/settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

import '../../support/fakes/bookmark_test_storage.dart';
import 'pool_bookmark_test_utils.dart';

const _zeroProfileId = '00000000-0000-4000-8000-000000000000';
const _groupId = poolGroupA;

void main() {
  late Directory directory;
  late Box<BookmarkHiveObject> recordsBox;
  late Box<BookmarkGroupHiveObject> legacyGroups;
  late Box<dynamic> legacyOrganization;
  late BookmarkTestStorage storage;
  late BookmarkHiveRepository repository;
  late UnifiedBookmarkGroupRepository groups;
  late ProviderContainer container;
  late AnonymousReadScope scope;
  late ContentAccessContext access;
  late BooruConfig publicConfig;
  late RemoteBookmarkPool remote;
  late CollectionBookmark draft;
  Completer<void>? draftStarted;
  var current = true;
  var draftCalls = 0;
  var networkClientsCreated = 0;

  Future<void> initialize({
    Future<CollectionBookmark> Function()? draftValue,
  }) async {
    directory = await Directory.systemTemp.createTemp('public-group-picker-');
    Hive.init(directory.path);
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(BookmarkHiveObjectAdapter());
    }
    if (!Hive.isAdapterRegistered(5)) {
      Hive.registerAdapter(BookmarkGroupHiveObjectAdapter());
    }
    recordsBox = await Hive.openBox<BookmarkHiveObject>('records');
    legacyGroups = await Hive.openBox<BookmarkGroupHiveObject>('groups');
    legacyOrganization = await Hive.openBox<dynamic>('organization');
    storage = await BookmarkTestStorage.open(recordsBox);
    repository = storage.repository(recordsBox);
    await legacyOrganization.put('version', 1);
    await legacyOrganization.put('poolBookmarks', []);
    final reader = await BookmarkStorageMigration(
      bookmarks: repository,
      legacyGroups: legacyGroups,
      legacyOrganization: legacyOrganization,
      metadata: storage.metadataBox,
    ).open();
    final activeOrganization = contentMap(
      storage.metadataBox.get('activeOrganization'),
    );
    final generation = contentMap(activeOrganization['generation']);
    await Hive.openBox<BookmarkGroupHiveObject>(
      generation['groups']! as String,
    );
    await Hive.openBox<dynamic>(generation['organization']! as String);
    groups = UnifiedBookmarkGroupRepository(
      bookmarks: repository,
      reader: reader,
    );
    await groups.createGroup('Public collection', id: _groupId);

    final site = Uri.parse('https://safebooru.donmai.us');
    final source = const AnonymousSourcePolicy().resolve(
      BooruType.danbooru,
      site,
    )!;
    scope = AnonymousReadScope(
      source: source,
      key: ContentAccessKey(
        engine: source.engine,
        siteNamespace: source.site.host,
        authEpoch: 1,
        policyEpoch: 1,
      ),
      createDio: () {
        networkClientsCreated++;
        throw StateError('Bookmark toggle must not create a network client');
      },
      current: () => current,
    );
    publicConfig = BooruConfig.fromJson({
      ...BooruConfig.defaultConfig(
        booruType: BooruType.danbooru,
        url: site.toString(),
        customDownloadFileNameFormat: null,
      ).toJson(),
      'id': _zeroProfileId,
    }).copyWith(anonymousReadScope: scope);
    access = ContentAccessContext.anonymous(config: publicConfig, scope: scope);
    remote = RemoteBookmarkPool(
      id: 42,
      title: 'Public Pool',
      category: BookmarkedPoolCategory.collection,
      total: 3,
      supportsUploadOrder: false,
    );
    draft =
        testPool(
          id: remote.id,
          groups: const {},
          host: 'safebooru.donmai.us',
          category: BookmarkedPoolCategory.collection,
        ).copyWith(
          sourceSite: () => site,
          origin: PostOrigin.fromSource(
            booruType: BooruType.danbooru,
            booruId: BooruType.danbooru.id,
            source: site.toString(),
            profileIdHint: null,
          ),
        );
    draftCalls = 0;
    networkClientsCreated = 0;
    current = true;
    container = ProviderContainer(
      overrides: [
        ...storage.overrides,
        booruConfigProvider.overrideWith(
          () => BooruConfigNotifier(initialConfigs: const []),
        ),
        bookmarkRepoProvider.overrideWith((ref) async => repository),
        bookmarkGroupRepoProvider.overrideWith((ref) async => groups),
        bookmarkUrlResolverProvider.overrideWith(
          (ref, id) => const DefaultImageUrlResolver(),
        ),
        settingsNotifierProvider.overrideWith(
          () => _SettingsNotifier(Settings.defaultSettings),
        ),
        contentAccessContextProvider(access.key).overrideWithValue(access),
        poolBookmarkDraftProvider.overrideWith((ref, request) {
          draftCalls++;
          if (draftStarted?.isCompleted == false) draftStarted!.complete();
          return draftValue?.call() ?? Future.value(draft);
        }),
      ],
    );
    await container.read(bookmarkProvider.future);
  }

  Future<void> close() async {
    container.dispose();
    scope.dispose();
    await storage.close();
    await recordsBox.close();
    await legacyGroups.close();
    await legacyOrganization.close();
    await Hive.close();
    await directory.delete(recursive: true);
  }

  BookmarkPickerActions actions() => BookmarkPickerActions(
    container: container,
    request: RemotePoolBookmarkPickerRequest(
      config: publicConfig,
      pool: remote,
    ),
    isActive: () => true,
  );

  test(
    'current anonymous Group scope saves a native Group and membership',
    () async {
      await initialize();
      addTearDown(close);

      await actions().toggle(_groupId, onRemoved: (_) {});

      final saved = (await repository.readAll())
          .whereType<ContentGroupBookmark>()
          .single;
      expect(saved.reference.site, Uri.parse('https://safebooru.donmai.us'));
      expect(saved.reference.sourceKey, 'pool:42');
      expect(saved.reference.engine, BooruType.danbooru);
      expect(saved.sourceProfileHint, isNull);
      expect(
        (await groups.getGroup(_groupId))!.bookmarkIds,
        contains(saved.id),
      );
      expect(draftCalls, 1);
      expect(networkClientsCreated, 0);
    },
  );

  test(
    'revocation before the write leaves local Group records unchanged',
    () async {
      await initialize();
      addTearDown(close);
      current = false;

      await expectLater(
        actions().toggle(_groupId, onRemoved: (_) {}),
        throwsStateError,
      );

      expect(
        (await repository.readAll()).whereType<ContentGroupBookmark>(),
        isEmpty,
      );
      expect((await groups.getGroup(_groupId))!.bookmarkIds, isEmpty);
      expect(draftCalls, 0);
      expect(networkClientsCreated, 0);
    },
  );

  test(
    'revocation while draft is pending cannot borrow a same-host profile',
    () async {
      final gate = Completer<CollectionBookmark>();
      final started = Completer<void>();
      draftStarted = started;
      await initialize(draftValue: () => gate.future);
      addTearDown(close);
      final profile = BooruConfig.fromJson({
        ...BooruConfig.defaultConfig(
          booruType: BooruType.danbooru,
          url: publicConfig.url,
          customDownloadFileNameFormat: null,
        ).toJson(),
        'id': poolProfile,
      });
      container.read(booruConfigProvider.notifier).state = [profile];
      final pending = actions().toggle(_groupId, onRemoved: (_) {});
      final settled = pending.then<void>(
        (_) {},
        onError: (Object _, StackTrace _) {},
      );
      await Future.any([started.future, settled]);
      expect(started.isCompleted, isTrue);
      current = false;
      gate.complete(draft);

      await expectLater(pending, throwsStateError);
      expect(
        (await repository.readAll()).whereType<ContentGroupBookmark>(),
        isEmpty,
      );
      expect((await groups.getGroup(_groupId))!.bookmarkIds, isEmpty);
      expect(draftCalls, 1);
      expect(networkClientsCreated, 0);
    },
  );
}

class _SettingsNotifier extends SettingsNotifier {
  _SettingsNotifier(super.initialSettings);
}
