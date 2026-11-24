import 'dart:async';
import 'dart:io';

import 'package:boorusama/boorus/pixiv/configs/extra_data.dart';
import 'package:boorusama/boorus/pixiv/posts/post_codec.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_group_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_group_repository_hive.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/repository.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/unified_bookmark_group_repository.dart';
import 'package:boorusama/core/bookmarks/src/services/bookmark_storage_migration.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_group_repository.dart';

import '../../../support/fakes/bookmark_test_storage.dart';

import 'package:boorusama/core/bookmarks/src/data/providers.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/server_favorites.dart';
import 'package:boorusama/core/cache/misc_data_store.dart';
import 'package:boorusama/core/hive/hive_adapters.dart';
import 'package:boorusama/core/settings/src/types/settings.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/posts/post/providers.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';

import '../../search/following_topics/topic_test_utils.dart';

BooruConfig pixivFavoriteTestProfile({
  String? token = 'fixture-token',
  String? userId = '42',
}) => BooruConfig.fromJson({
  ...BooruConfig.empty.toJson(),
  'id': '00000000-0000-4000-8000-000000000042',
  'name': 'Pixiv fixture',
  'booruId': BooruType.pixiv.id,
  'booruIdHint': BooruType.pixiv.id,
  'url': 'https://pixiv.net',
  'apiKey': token,
  'passHash': PixivExtraData(userId: userId).toPassHash(),
});

class FavoriteTestStore implements MiscDataStore {
  bool fail = false;
  int writes = 0;
  final values = <String, String>{};
  @override
  String? get(String key) => values[key];
  @override
  Future<void> put(String key, String value) async {
    if (fail) throw StateError('storage unavailable');
    writes++;
    values[key] = value;
  }
}

class FavoriteTestProfiles implements BooruConfigRepository {
  FavoriteTestProfiles(this.profiles);
  List<BooruConfig> profiles;
  @override
  Future<List<BooruConfig>> getAll() async => profiles;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FavoriteTestSource implements ServerFavoriteSource {
  FavoriteTestSource(this.posts);
  List<Post> posts;
  Map<int, List<Post>>? pages;
  int calls = 0;
  Object? error;
  Completer<ServerFavoritePage<Post>>? pending;
  final requested = Completer<void>();
  @override
  Future<ServerFavoritePage<Post>> fetchPage(
    int page, {
    ServerFavoriteCancellation? cancellation,
  }) {
    calls++;
    if (!requested.isCompleted) requested.complete();
    if (error case final failure?) return Future.error(failure);
    if (pages case final paged?) {
      return Future.value(
        ServerFavoritePage(
          paged[page] ?? [],
          hasMore: paged.containsKey(page + 1),
        ),
      );
    }
    return pending?.future ??
        Future.value(ServerFavoritePage(posts, hasMore: false));
  }

  @override
  Future<Post?> getPost(int postId) async =>
      posts.where((p) => p.id == postId).firstOrNull;
}

class _Settings extends SettingsNotifier {
  _Settings() : super(Settings.defaultSettings);
  @override
  Future<bool> updateWith(Settings Function(Settings) selector) async {
    state = selector(state);
    return true;
  }
}

class _Links extends PostLinkGenerator<Post> {
  @override
  String getLink(Post post) =>
      'https://${post.origin.sourceHost}/posts/${post.id}';
}

class FavoriteHarness {
  final store = FavoriteTestStore();
  late final FavoriteTestProfiles profiles;
  late final FavoriteTestSource source;
  final sources = <String, FavoriteTestSource>{};
  late ProviderContainer container;
  late BookmarkHiveRepository bookmarks;
  late BookmarkGroupRepositoryHive groups;
  late final Directory directory;
  late Box<BookmarkHiveObject> bookmarkBox;
  late Box<BookmarkGroupHiveObject> groupBox;
  late Box<dynamic> organizationBox;
  late BookmarkTestStorage bookmarkStorage;
  List<Override> Function(BooruConfig)? _extraOverrides;
  bool _unifiedGroups = false;
  late BooruConfig profile;

  Future<void> open({
    bool sharedAuth = false,
    bool unifiedGroups = false,
    List<BooruConfig> additionalProfiles = const [],
    List<Override> Function(BooruConfig)? extraOverrides,
  }) async {
    profile = BooruConfig.fromJson({
      ...BooruConfig.empty.toJson(),
      'id': '00000000-0000-4000-8000-000000000001',
      'name': 'Account one',
      'booruId': 1,
      'booruIdHint': 1,
      'url': 'https://danbooru.donmai.us',
      'login': 'fixture',
      'apiKey': 'fixture-key',
    });
    profiles = FavoriteTestProfiles([
      profile,
      if (sharedAuth)
        BooruConfig.fromJson({
          ...profile.toJson(),
          'id': '00000000-0000-4000-8000-000000000002',
          'name': 'Account two',
        }),
      ...additionalProfiles,
    ]);
    source = FavoriteTestSource([post(1), post(2)]);
    directory = await Directory.systemTemp.createTemp('server-favorites-');
    Hive.init(directory.path);
    if (!Hive.isAdapterRegistered(4))
      Hive.registerAdapter(BookmarkHiveObjectAdapter());
    if (!Hive.isAdapterRegistered(5))
      Hive.registerAdapter(BookmarkGroupHiveObjectAdapter());
    _extraOverrides = extraOverrides;
    _unifiedGroups = unifiedGroups;
    await _openRepositories();
  }

  Future<void> _openRepositories({bool warmLibrary = true}) async {
    bookmarkBox = await Hive.openBox<BookmarkHiveObject>('favorites-posts');
    groupBox = await Hive.openBox<BookmarkGroupHiveObject>('favorites-groups');
    organizationBox = await Hive.openBox<dynamic>('favorites-organization');
    bookmarkStorage = await BookmarkTestStorage.open(bookmarkBox);
    bookmarks = bookmarkStorage.repository(
      bookmarkBox,
      postDataCodec: (type) =>
          type == BooruType.pixiv ? const PixivPostCodec() : null,
    );
    groups = _unifiedGroups
        ? await BookmarkStorageMigration(
            bookmarks: bookmarks,
            legacyGroups: groupBox,
            legacyOrganization: organizationBox,
            metadata: bookmarkStorage.metadataBox,
          ).open()
        : BookmarkGroupRepositoryHive(
            groupBox,
            organizationBox: organizationBox,
          );
    final BookmarkGroupRepository groupRepository = _unifiedGroups
        ? UnifiedBookmarkGroupRepository(bookmarks: bookmarks, reader: groups)
        : groups;
    container = ProviderContainer(
      overrides: [
        ...bookmarkStorage.overrides,
        ...?_extraOverrides?.call(profile),
        miscDataStoreProvider.overrideWithValue(store),
        booruConfigRepoProvider.overrideWithValue(profiles),
        booruConfigProvider.overrideWith(
          () => BooruConfigNotifier(initialConfigs: profiles.profiles),
        ),
        bookmarkRepoProvider.overrideWith((ref) => bookmarks),
        bookmarkGroupRepoProvider.overrideWith((ref) => groupRepository),
        bookmarkUrlResolverProvider.overrideWith(
          (ref, id) => const DefaultImageUrlResolver(),
        ),
        postLinkGeneratorProvider.overrideWith((ref, auth) => _Links()),
        settingsNotifierProvider.overrideWith(_Settings.new),
        serverFavoriteSourceProvider.overrideWith(
          (ref, config) => sources[config.id] ?? source,
        ),
        serverFavoritePostLoaderProvider.overrideWith(
          (ref, config) => (sources[config.id] ?? source).getPost,
        ),
      ],
    );
    if (warmLibrary) await container.read(bookmarkLibraryProvider.future);
    await container.read(serverFavoriteSettingsProvider.future);
  }

  Post post(int id) => testSearchPost(
    id,
    DateTime.utc(2026),
  ).copyWith(origin: postOriginFromConfig(profile));

  /// Dispose providers and reopen every Hive file, including mixed membership
  /// storage, so preservation checks cannot pass from retained memory state.
  Future<void> restart({bool warmLibrary = true}) async {
    container.dispose();
    if (_unifiedGroups) await groups.close();
    await bookmarkStorage.close();
    await bookmarkBox.close();
    await groupBox.close();
    await organizationBox.close();
    await _openRepositories(warmLibrary: warmLibrary);
  }

  Future<void> close() async {
    container.dispose();
    if (_unifiedGroups) await groups.close();
    await bookmarkStorage.close();
    await bookmarkBox.close();
    await groupBox.close();
    await organizationBox.close();
    await directory.delete(recursive: true);
  }
}
