import 'dart:async';
import 'dart:io';

import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_group_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_group_repository_hive.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/repository.dart';
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
  late final ProviderContainer container;
  late final BookmarkHiveRepository bookmarks;
  late final BookmarkGroupRepositoryHive groups;
  late final Directory directory;
  late Box<BookmarkHiveObject> bookmarkBox;
  late Box<BookmarkGroupHiveObject> groupBox;
  late BooruConfig profile;

  Future<void> open({bool sharedAuth = false}) async {
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
    ]);
    source = FavoriteTestSource([post(1), post(2)]);
    directory = await Directory.systemTemp.createTemp('server-favorites-');
    Hive.init(directory.path);
    if (!Hive.isAdapterRegistered(4))
      Hive.registerAdapter(BookmarkHiveObjectAdapter());
    if (!Hive.isAdapterRegistered(5))
      Hive.registerAdapter(BookmarkGroupHiveObjectAdapter());
    bookmarkBox = await Hive.openBox<BookmarkHiveObject>('favorites-posts');
    groupBox = await Hive.openBox<BookmarkGroupHiveObject>('favorites-groups');
    bookmarks = BookmarkHiveRepository(bookmarkBox);
    groups = BookmarkGroupRepositoryHive(
      groupBox,
      organizationBox: MemoryBox<dynamic>(),
    );
    container = ProviderContainer(
      overrides: [
        miscDataStoreProvider.overrideWithValue(store),
        booruConfigRepoProvider.overrideWithValue(profiles),
        booruConfigProvider.overrideWith(
          () => BooruConfigNotifier(initialConfigs: profiles.profiles),
        ),
        bookmarkRepoProvider.overrideWith((ref) => bookmarks),
        bookmarkGroupRepoProvider.overrideWith((ref) => groups),
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
    await container.read(bookmarkLibraryProvider.future);
    await container.read(serverFavoriteSettingsProvider.future);
  }

  Post post(int id) => testSearchPost(
    id,
    DateTime.utc(2026),
  ).copyWith(origin: postOriginFromConfig(profile));

  Future<void> close() async {
    container.dispose();
    await bookmarkBox.close();
    await groupBox.close();
    await directory.delete(recursive: true);
  }
}
