import 'dart:async';

import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_picker_actions.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/src/services/bookmark_library_service.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_group.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_library_state.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_picker_request.dart';
import 'package:boorusama/core/bookmarks/src/types/content_group_bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/stored_group_snapshot.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/content/types.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pool_bookmark_test_utils.dart';

final _config = BooruConfig.defaultConfig(
  booruType: BooruType.danbooru,
  url: 'https://danbooru.donmai.us',
  customDownloadFileNameFormat: null,
);

void main() {
  late _Library library;
  late _ThrowOnReadConfigs profiles;
  late ProviderContainer container;
  late PostBookmark unaddressablePost;
  late ContentGroupBookmark nativeGroup;

  setUp(() {
    unaddressablePost = testPoolPost(88).copyWith(
      id: 4,
      postId: () => null,
    );
    final reference = const ContentReferenceCodec().parse(
      engine: BooruType.danbooru,
      site: Uri.parse('https://danbooru.donmai.us/install'),
      kind: ContentKind.group,
      sourceKey: 'pool:43',
    );
    nativeGroup = ContentGroupBookmark(
      id: 1,
      snapshot: StoredGroupSnapshot(
        summary: ContentGroupSummary(reference: reference, title: 'Pool 43'),
      ),
      createdAt: DateTime.utc(2020),
      observedAt: DateTime.utc(2025),
    );
    library = _Library(
      records: [unaddressablePost, nativeGroup],
      groups: [
        BookmarkGroup(
          id: poolGroupA,
          name: 'A',
          bookmarkIds: {1, 4},
          addedAt: {
            1: DateTime.utc(2024, 1, 2),
            4: DateTime.utc(2024, 3, 4),
          },
        ),
        BookmarkGroup(
          id: poolGroupB,
          name: 'B',
          bookmarkIds: {1, 4},
          addedAt: {
            1: DateTime.utc(2025, 5, 6),
            4: DateTime.utc(2025, 7, 8),
          },
        ),
      ],
    );
    profiles = _ThrowOnReadConfigs();
    container = ProviderContainer(
      overrides: [
        bookmarkProvider.overrideWith(() => library),
        booruConfigProvider.overrideWith(() => profiles),
      ],
    );
  });

  tearDown(() => container.dispose());

  test(
    'saved Post and native Group toggle by their exact local record IDs',
    () async {
      final state = await container.read(bookmarkProvider.future);
      final post = state.byId[unaddressablePost.id]!;
      final group = state.byId[nativeGroup.id]!;
      final postRequest = SavedBookmarkPickerRequest(
        config: _config.auth,
        record: post,
      );
      final groupRequest = SavedBookmarkPickerRequest(
        config: _config.auth,
        record: group,
      );
      expect(postRequest.source, isNull);
      expect(groupRequest.source, isNull);
      expect(postRequest.savedRecordId, unaddressablePost.id);
      expect(groupRequest.savedRecordId, nativeGroup.id);

      final postActions = BookmarkPickerActions(
        container: container,
        request: postRequest,
        isActive: () => true,
      );
      final groupActions = BookmarkPickerActions(
        container: container,
        request: groupRequest,
        isActive: () => true,
      );
      await postActions.toggle(poolGroupA, onRemoved: (_) {});
      await groupActions.toggle(poolGroupB, onRemoved: (_) {});

      expect(library.toggles, hasLength(2));
      expect(library.toggles[0].record, same(post));
      expect(library.toggles[0].groupId, poolGroupA);
      expect(library.toggles[1].record, same(group));
      expect(library.toggles[1].groupId, poolGroupB);
      expect(profiles.reads, 0);
    },
  );

  test(
    'saved record group creation forwards record, folder and commit order',
    () async {
      final state = await container.read(bookmarkProvider.future);
      final post = state.byId[unaddressablePost.id]!;
      final actions = BookmarkPickerActions(
        container: container,
        request: SavedBookmarkPickerRequest(config: _config.auth, record: post),
        isActive: () => true,
      );
      var beforeCommitCount = 0;

      await actions.createGroup(
        'Saved Post group',
        poolGroupB,
        beforeCommit: () {
          beforeCommitCount++;
          library.events.add('beforeCommit');
        },
      );

      expect(library.creations, hasLength(1));
      expect(library.creations.single.records, hasLength(1));
      expect(identical(library.creations.single.records.single, post), isTrue);
      expect(library.creations.single.folderId, poolGroupB);
      expect(library.events, ['beforeCommit', 'createGroup']);
      expect(beforeCommitCount, 1);
      expect(profiles.reads, 0);
    },
  );

  test('inactive picker ownership prevents saved-record writes', () async {
    final state = await container.read(bookmarkProvider.future);
    final post = state.byId[unaddressablePost.id]!;
    final actions = BookmarkPickerActions(
      container: container,
      request: SavedBookmarkPickerRequest(config: _config.auth, record: post),
      isActive: () => false,
    );

    await expectLater(
      actions.toggle(poolGroupA, onRemoved: (_) {}),
      throwsStateError,
    );
    await expectLater(
      actions.createGroup(
        'Should not exist',
        poolGroupA,
        beforeCommit: () => fail('Inactive picker must not reach commit'),
      ),
      throwsStateError,
    );
    expect(library.toggles, isEmpty);
    expect(library.creations, isEmpty);
    expect(profiles.reads, 0);
  });
}

class _ThrowOnReadConfigs extends BooruConfigNotifier {
  _ThrowOnReadConfigs() : super(initialConfigs: const []);

  var reads = 0;

  @override
  List<BooruConfig> build() {
    reads++;
    throw StateError('Saved picker read profiles');
  }
}

class _Library extends BookmarkLibraryNotifier {
  _Library({required this.records, required this.groups});

  final List<Bookmark> records;
  final List<BookmarkGroup> groups;
  final toggles = <({Bookmark record, String groupId})>[];
  final creations = <({List<Bookmark> records, String? folderId})>[];
  final events = <String>[];
  @override
  FutureOr<BookmarkLibraryState> build() => BookmarkLibraryState(
    bookmarks: records.whereType<PostBookmark>().toList(),
    records: records,
    groups: groups,
  );

  @override
  Future<BookmarkToggleOutcome> toggleSavedBookmarkTarget(
    Bookmark record, {
    required String groupId,
    void Function(BookmarkGroupRemovalResult)? onRemoved,
  }) async {
    toggles.add((record: record, groupId: groupId));
    return BookmarkToggleOutcome.added;
  }

  @override
  Future<({BookmarkGroup group, int addedCount})> createGroupWithSavedRecords(
    String name,
    Iterable<Bookmark> records, {
    String? folderId,
    String? parentGroupId,
  }) async {
    events.add('createGroup');
    final parent = parentGroupId ?? folderId;
    creations.add((records: records.toList(), folderId: parent));
    return (
      group: BookmarkGroup(
        id: poolGroupA,
        name: name,
        bookmarkIds: {},
        parentGroupId: parent,
      ),
      addedCount: creations.last.records.length,
    );
  }
}
