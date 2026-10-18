// Package imports:
import 'package:foundation/foundation.dart';
import 'package:uuid/uuid.dart';

// Project imports:
import 'package:boorusama/core/blacklists/types.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/bookmarks/types.dart';
import 'package:boorusama/core/cache/misc_data_store.dart';
import 'package:boorusama/core/cache/persistent_cache_store.dart';
import 'package:boorusama/core/configs/config/src/data/booru_config_converter.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/debug/types.dart';
import 'package:boorusama/core/developer_options/src/developer_options_repository.dart';
import 'package:boorusama/core/developer_options/types.dart';
import 'package:boorusama/core/downloads/downloader/types.dart';
import 'package:boorusama/core/groups/folder_tree.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/search/histories/src/types/search_history.dart';
import 'package:boorusama/core/search/histories/src/types/search_history_repository.dart';
import 'package:boorusama/core/search/histories/src/types/search_history_repository_factory.dart';
import 'package:boorusama/core/search/selected_tags/types.dart';
import 'package:boorusama/core/settings/src/types/settings_repository.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:boorusama/core/tags/favorites/types.dart';

final class MemoryBookmarkRepository implements BookmarkRepository {
  final _bookmarks = <Bookmark>[];
  var _nextId = 0;
  BooruPostDataCodec? Function(BooruType type)? postDataCodec;

  List<Bookmark> get bookmarks => List.of(_bookmarks);

  @override
  Future<Bookmark> addBookmark(
    int booruId,
    Post post, {
    required ImageUrlResolver Function(int? booruId) imageUrlResolver,
    required PostLinkGenerator Function(int? booruId) postLinkGenerator,
  }) async {
    final now = DateTime.now();
    final bookmark = Bookmark.fromSnapshot(
      id: _nextId++,
      createdAt: now,
      updatedAt: now,
      snapshot: const StoredPostCodec().encode(
        post,
        dataCodec: postDataCodec?.call(post.origin.booruType),
      ),
      post: post,
      postId: post.id,
      sourceUrl: postLinkGenerator(booruId).getLink(post),
    );
    _bookmarks.add(bookmark);
    return bookmark;
  }

  @override
  Future<List<Bookmark>> addBookmarks(
    int booruId,
    Iterable<Post> posts, {
    required ImageUrlResolver Function(int? booruId) imageUrlResolver,
    required PostLinkGenerator Function(int? booruId) postLinkGenerator,
  }) => Future.wait(
    posts.map(
      (post) => addBookmark(
        booruId,
        post,
        imageUrlResolver: imageUrlResolver,
        postLinkGenerator: postLinkGenerator,
      ),
    ),
  );

  @override
  Future<List<Bookmark>> addBookmarkWithBookmarks(
    List<Bookmark> bookmarks,
  ) async {
    _bookmarks.addAll(bookmarks);
    return List.unmodifiable(bookmarks);
  }

  @override
  Future<void> removeBookmark(Bookmark favorite) async {
    _bookmarks.removeWhere((bookmark) => bookmark.id == favorite.id);
  }

  @override
  Future<void> removeBookmarks(Iterable<Bookmark> favorites) async {
    final ids = favorites.map((favorite) => favorite.id).toSet();
    _bookmarks.removeWhere((bookmark) => ids.contains(bookmark.id));
  }

  @override
  Future<void> updateBookmark(Bookmark favorite) async {
    final index = _bookmarks.indexWhere(
      (bookmark) => bookmark.id == favorite.id,
    );
    if (index != -1) _bookmarks[index] = favorite;
  }

  @override
  BookmarksOrError getAllBookmarks({
    required ImageUrlResolver Function(int? booruId) imageUrlResolver,
  }) => TaskEither.right(List.of(_bookmarks));
}

final class MemoryBookmarkRepositoryFactory
    implements BookmarkRepositoryFactory {
  const MemoryBookmarkRepositoryFactory(this.repository);

  final BookmarkRepository repository;

  @override
  Future<BookmarkRepository> create({
    BooruPostDataCodec? Function(BooruType)? postDataCodec,
  }) async {
    if (repository case final MemoryBookmarkRepository memoryRepository) {
      memoryRepository.postDataCodec = postDataCodec;
    }
    return repository;
  }

  @override
  Future<void> dispose(BookmarkRepository repository) async {}
}

final class MemoryBookmarkGroupRepository
    implements BookmarkGroupRepository, BookmarkFolderRepository {
  MemoryBookmarkGroupRepository({Uuid uuid = const Uuid()}) : _uuid = uuid;

  final Uuid _uuid;
  final _groups = <String, BookmarkGroup>{};
  var _folders = <CollectionFolder>[];

  @override
  Future<List<BookmarkGroup>> getGroups() async =>
      _groups.values.toList()..sort(
        (a, b) => a.position != b.position
            ? a.position.compareTo(b.position)
            : a.id.compareTo(b.id),
      );

  @override
  Future<BookmarkGroup?> getGroup(String id) async => _groups[id];

  @override
  Future<BookmarkGroup> createGroup(String name, {String? id}) async {
    final groupId = id ?? _uuid.v4().toLowerCase();
    if (_groups.containsKey(groupId)) {
      throw StateError('Bookmark group $groupId already exists.');
    }
    final group = BookmarkGroup(
      id: groupId,
      name: groupId == defaultBookmarkGroupId ? 'Default' : name.trim(),
      bookmarkIds: const {},
      position: _groups.length,
    );
    _groups[groupId] = group;
    return group;
  }

  @override
  Future<BookmarkGroup> duplicateGroup(String id, {String? name}) async {
    final source = _require(id);
    final duplicate = await createGroup(name ?? source.name);
    return _write(
      duplicate.copyWith(
        bookmarkIds: source.bookmarkIds,
        folderId: source.folderId,
      ),
    );
  }

  @override
  Future<BookmarkGroup> renameGroup(String id, String name) async {
    final group = _require(id);
    if (group.isDefault) throw StateError('Default cannot be renamed.');
    return _write(group.copyWith(name: name.trim()));
  }

  @override
  Future<BookmarkGroup> replaceMemberships(
    String id,
    Set<int> bookmarkIds,
  ) async => _write(_require(id).copyWith(bookmarkIds: bookmarkIds));

  @override
  Future<BookmarkGroup> addBookmarks(String id, Set<int> bookmarkIds) async {
    final group = _require(id);
    return _write(
      group.copyWith(bookmarkIds: {...group.bookmarkIds, ...bookmarkIds}),
    );
  }

  @override
  Future<BookmarkGroup> removeBookmarks(String id, Set<int> bookmarkIds) async {
    final group = _require(id);
    return _write(
      group.copyWith(bookmarkIds: group.bookmarkIds.difference(bookmarkIds)),
    );
  }

  @override
  Future<void> removeBookmarkFromAllGroups(int bookmarkId) async {
    for (final group in await getGroups()) {
      if (group.bookmarkIds.contains(bookmarkId)) {
        await removeBookmarks(group.id, {bookmarkId});
      }
    }
  }

  @override
  Future<BookmarkGroupDeletionPreview> previewDeleteGroup(String id) async {
    final group = _require(id);
    final otherBookmarkIds = _groups.values
        .where((other) => other.id != id)
        .expand((other) => other.bookmarkIds)
        .toSet();
    return BookmarkGroupDeletionPreview(
      group: group,
      orphanBookmarkIds: group.bookmarkIds.difference(otherBookmarkIds),
    );
  }

  @override
  Future<BookmarkGroupDeletionPreview> deleteGroup(String id) async {
    final preview = await previewDeleteGroup(id);
    if (preview.group.isDefault) throw StateError('Default cannot be deleted.');
    _groups.remove(id);
    return preview;
  }

  @override
  Future<bool> repair({required Set<int> validBookmarkIds}) async {
    var changed = false;
    for (final group in await getGroups()) {
      final repaired = group.bookmarkIds.intersection(validBookmarkIds);
      if (repaired.length != group.bookmarkIds.length) {
        await replaceMemberships(group.id, repaired);
        changed = true;
      }
    }
    return changed;
  }

  @override
  Future<List<CollectionFolder>> readFolders() async => List.of(_folders);

  @override
  Future<void> writeOrganization(
    List<CollectionFolder> folders,
    List<BookmarkGroup> groups,
  ) async {
    FolderTree(folders).validatePlacements([
      for (final group in groups)
        FolderPlacement(
          itemId: group.id,
          folderId: group.folderId,
          position: group.position,
        ),
    ]);
    _folders = List.of(folders);
    _groups
      ..clear()
      ..addEntries(groups.map((group) => MapEntry(group.id, group)));
  }

  BookmarkGroup _require(String id) =>
      _groups[id] ?? (throw StateError('Bookmark group $id does not exist.'));

  BookmarkGroup _write(BookmarkGroup group) {
    _groups[group.id] = group;
    return group;
  }
}

final class MemoryBookmarkGroupRepositoryFactory
    implements BookmarkGroupRepositoryFactory {
  MemoryBookmarkGroupRepositoryFactory([
    MemoryBookmarkGroupRepository? repository,
  ]) : repository = repository ?? MemoryBookmarkGroupRepository();

  final MemoryBookmarkGroupRepository repository;

  @override
  Future<BookmarkGroupRepository> create() async => repository;

  @override
  Future<void> dispose(BookmarkGroupRepository repository) async {}
}

final class MemoryGlobalBlacklistedTagRepositoryFactory
    implements GlobalBlacklistedTagRepositoryFactory {
  const MemoryGlobalBlacklistedTagRepositoryFactory(this.repository);

  final GlobalBlacklistedTagRepository repository;

  @override
  Future<GlobalBlacklistedTagRepository> create() async => repository;

  @override
  Future<void> dispose(GlobalBlacklistedTagRepository repository) async {}
}

final class MemoryFavoriteTagRepositoryFactory
    implements FavoriteTagRepositoryFactory {
  const MemoryFavoriteTagRepositoryFactory(this.repository);

  final FavoriteTagRepository repository;

  @override
  Future<FavoriteTagRepository> create() async => repository;

  @override
  Future<void> dispose(FavoriteTagRepository repository) async {}
}

final class MemorySearchHistoryRepositoryFactory
    implements SearchHistoryRepositoryFactory {
  const MemorySearchHistoryRepositoryFactory(this.repository);

  final SearchHistoryRepository repository;

  @override
  Future<SearchHistoryRepository> create() async => repository;

  @override
  Future<void> dispose(SearchHistoryRepository repository) async {}
}

final class MemoryDownloadServiceFactory implements DownloadServiceFactory {
  const MemoryDownloadServiceFactory(this.service);

  final DownloadService service;

  @override
  DownloadService create(DownloadServiceDependencies dependencies) => service;

  @override
  Future<void> dispose(DownloadService service) async {}
}

final class MemorySettingsRepository implements SettingsRepository {
  MemorySettingsRepository([this._settings = Settings.defaultSettings]);

  Settings _settings;
  final savedSettings = <Settings>[];

  Settings get settings => _settings;

  @override
  Future<bool> save(Settings setting) async {
    _settings = setting;
    savedSettings.add(setting);
    return true;
  }

  @override
  SettingsOrError load() => TaskEither.right(_settings);
}

final class MemoryGlobalBlacklistedTagRepository
    implements GlobalBlacklistedTagRepository {
  final _tags = <BlacklistedTag>[];
  var _nextId = 0;

  @override
  Future<BlacklistedTag?> addTag(String tag) async {
    if (_tags.any((item) => item.name == tag)) return null;

    final now = DateTime.now();
    final result = BlacklistedTag(
      id: _nextId++,
      name: tag,
      isActive: true,
      createdDate: now,
      updatedDate: now,
    );
    _tags.add(result);
    return result;
  }

  @override
  Future<List<BlacklistedTag>> addTags(List<BlacklistedTag> tags) async =>
      _tags..addAll(tags);

  @override
  Future<List<BlacklistedTag>> getBlacklist() async => List.unmodifiable(_tags);

  @override
  Future<void> replaceAll(List<BlacklistedTag> tags) async {
    _tags
      ..clear()
      ..addAll(tags);
  }

  @override
  Future<void> removeTag(int tagId) async {
    _tags.removeWhere((tag) => tag.id == tagId);
  }

  @override
  Future<BlacklistedTag> updateTag(int tagId, String newTag) async {
    final index = _tags.indexWhere((tag) => tag.id == tagId);
    if (index == -1) {
      throw StateError('Blacklist tag not found: $tagId');
    }

    final updated = _tags[index].copyWith(
      name: newTag,
      updatedDate: DateTime.now(),
    );
    _tags[index] = updated;
    return updated;
  }
}

final class MemoryFavoriteTagRepository implements FavoriteTagRepository {
  final _tags = <FavoriteTag>[];

  List<FavoriteTag> get tags => List.of(_tags);

  @override
  Future<List<FavoriteTag>> get(String name) async =>
      _tags.where((tag) => tag.name == name).toList();

  @override
  Future<List<FavoriteTag>> getAll() async => List.of(_tags);

  @override
  Future<void> replaceAll(List<FavoriteTag> tags) async {
    _tags
      ..clear()
      ..addAll(tags);
  }

  @override
  Future<FavoriteTag?> getFirst(String name) async =>
      _tags.cast<FavoriteTag?>().firstWhere(
        (tag) => tag?.name == name,
        orElse: () => null,
      );

  @override
  Future<FavoriteTag?> deleteFirst(String name) async {
    final index = _tags.indexWhere((tag) => tag.name == name);
    if (index == -1) return null;

    return _tags.removeAt(index);
  }

  @override
  Future<FavoriteTag> create({
    required String name,
    List<String>? labels,
    QueryType? queryType,
  }) async {
    final now = DateTime.now();
    final tag = FavoriteTag(
      name: name,
      createdAt: now,
      updatedAt: now,
      labels: labels,
      queryType: queryType,
    );
    _tags.add(tag);
    return tag;
  }

  @override
  Future<FavoriteTag?> restore(FavoriteTag tag) async {
    if (_tags.any((item) => item.name == tag.name)) return null;

    _tags.add(tag);
    return tag;
  }

  @override
  Future<List<FavoriteTag>> createFrom(List<FavoriteTag> tags) async {
    _tags.addAll(tags);
    return List.unmodifiable(tags);
  }

  @override
  Future<FavoriteTag?> updateFirst(String name, FavoriteTag tag) async {
    final index = _tags.indexWhere((item) => item.name == name);
    if (index == -1) return null;

    _tags[index] = tag;
    return tag;
  }
}

final class MemorySearchHistoryRepository implements SearchHistoryRepository {
  final _histories = <SearchHistory>[];

  List<SearchHistory> get historiesForTest => List.unmodifiable(_histories);

  @override
  Future<List<SearchHistory>> getHistories() async =>
      List.unmodifiable(_histories);

  @override
  Future<List<SearchHistory>> addHistory(
    String query, {
    required QueryType queryType,
    required String booruTypeName,
    required String siteUrl,
  }) async {
    final history = SearchHistory.now(
      query,
      queryType,
      booruTypeName: booruTypeName,
      siteUrl: siteUrl,
    );
    _histories
      ..removeWhere((item) => item.query == query)
      ..insert(0, history);
    return List.unmodifiable(_histories);
  }

  @override
  Future<List<SearchHistory>> removeHistory(SearchHistory history) async {
    _histories.remove(history);
    return List.unmodifiable(_histories);
  }

  @override
  Future<bool> clearAll() async {
    _histories.clear();
    return true;
  }
}

final class MemoryDownloadService implements DownloadService {
  final requests = <DownloadOptions>[];

  @override
  Future<DownloadResult> download(DownloadOptions options) async {
    requests.add(options);
    return DownloadEnqueued(
      DownloadTaskInfo(
        path: options.path ?? '',
        id: options.filename,
      ),
    );
  }

  @override
  Future<bool> cancelAll(String group) async => false;

  @override
  Future<void> pauseAll(String group) async {}

  @override
  Future<void> resumeAll(String group) async {}
}

final class MemoryDeveloperOptionsRepository
    implements DeveloperOptionsRepository {
  MemoryDeveloperOptionsRepository([
    this._options = DeveloperOptions.defaults,
  ]);

  DeveloperOptions _options;

  @override
  Future<DeveloperOptions> load() async => _options;

  @override
  Future<void> save(DeveloperOptions options) async {
    _options = options;
  }
}

final class MemoryBooruConfigRepository implements BooruConfigRepository {
  MemoryBooruConfigRepository({Iterable<BooruConfig> configs = const []}) {
    seed(configs);
  }

  final _configs = <BooruConfig>[];

  List<BooruConfig> get configs => List.unmodifiable(_configs);

  /// Replaces the contents while retaining the IDs assigned by the caller.
  void seed(Iterable<BooruConfig> configs) {
    _configs
      ..clear()
      ..addAll(configs);
  }

  @override
  Future<BooruConfig?> add(BooruConfigData data) async {
    final config = data.toBooruConfig(id: createProfileId());
    if (config != null) {
      _configs.add(config);
    }
    return config;
  }

  @override
  Future<List<BooruConfig>> addAll(List<BooruConfig> configs) async {
    for (final config in configs) {
      final index = _configs.indexWhere((item) => item.id == config.id);
      if (index == -1) {
        _configs.add(config);
      } else {
        _configs[index] = config;
      }
    }
    return List.unmodifiable(configs);
  }

  @override
  Future<void> clear() async => _configs.clear();

  @override
  Future<List<BooruConfig>> getAll() async => List.unmodifiable(_configs);

  @override
  Future<void> remove(BooruConfig config) async {
    _configs.removeWhere((value) => value.id == config.id);
  }

  @override
  Future<BooruConfig?> update(String id, BooruConfigData data) async {
    final index = _configs.indexWhere((config) => config.id == id);
    if (index == -1) return null;

    final config = data.toBooruConfig(id: id);
    if (config != null) _configs[index] = config;
    return config;
  }
}

final class MemoryLogOptionsRepository implements LogOptionsRepository {
  LogOptions _options = LogOptions.defaults;

  @override
  Future<LogOptions> load() async => _options;

  @override
  Future<void> save(LogOptions options) async {
    _options = options;
  }
}

final class MemoryMiscDataStore implements MiscDataStore {
  final _values = <String, String>{};

  @override
  String? get(String key) => _values[key];

  @override
  Future<void> put(String key, String value) async {
    _values[key] = value;
  }
}

final class MemoryPersistentCacheStore implements PersistentCacheStore {
  MemoryPersistentCacheStore({this.suppressChangelog = false});

  final bool suppressChangelog;
  final _values = <String, String>{};

  @override
  Iterable<String> get keys => _values.keys;

  @override
  int get length => _values.length;

  @override
  String? get(String key) {
    if (suppressChangelog &&
        key.startsWith('changelog_') &&
        key.endsWith('_seen')) {
      return '';
    }

    return _values[key];
  }

  @override
  Future<void> put(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<void> clear() async => _values.clear();
}
