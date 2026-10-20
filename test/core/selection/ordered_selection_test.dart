import 'package:flutter/widgets.dart';
import 'package:selection_mode/src/core/selection_item_info.dart';
// ignore_for_file: invalid_use_of_internal_member, implementation_imports
import 'package:flutter_test/flutter_test.dart';
import 'package:selection_mode/selection_mode.dart';

import 'package:boorusama/core/selection/ordered_selection_controller.dart';
import 'package:boorusama/core/selection/collection_selection.dart';
import 'package:boorusama/core/posts/listing/src/types/post_selection_identity.dart';
import 'package:boorusama/core/posts/listing/src/types/post_action_snapshot.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';

import '../../support/fakes/test_post.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  OrderedSelectionController<String> controller() {
    final value = OrderedSelectionController<String>();
    value.initializeOptions(
      const SelectionOptions(behavior: SelectionBehavior.manual, haptics: null),
    );
    value.setEntries(['a', 'b', 'c', 'd', 'e']);
    addTearDown(value.dispose);
    return value;
  }

  test('ranges replace, shrink and reverse from a stable selecting anchor', () {
    final selection = controller();
    selection.click(2);
    selection.click(4, range: true);
    expect(selection.selectedKeys, {'c', 'd', 'e'});
    selection.click(3, range: true);
    expect(selection.selectedKeys, {'c', 'd'});
    selection.click(0, range: true);
    expect(selection.selectedKeys, {'a', 'b', 'c'});
    expect(selection.anchor, 'c');
    selection.click(4, additive: true);
    expect(selection.anchor, 'e');
    selection.click(3, range: true, additive: true);
    expect(selection.selectedKeys, {'a', 'b', 'c', 'd', 'e'});
  });

  test(
    'a missing anchor establishes the target instead of guessing an index',
    () {
      final selection = controller();
      selection.click(3, range: true);
      expect(selection.selectedKeys, {'d'});
      selection.setEntries(['a', 'b', 'c', 'e']);
      selection.click(1, range: true);
      expect(selection.selectedKeys, {'b'});
      expect(selection.anchor, 'b');
    },
  );

  test('unmounted loaded rows remain eligible and selected across reorder and removal', () {
    final selection = controller();
    selection.enable();
    selection.selectAll([0, 1, 2, 3, 4]);
    selection.unregister(4);
    expect(selection.selection, {0, 1, 2, 3, 4});
    selection.setEntries(['e', 'c', 'a']);
    expect(selection.selectedKeys, {'e', 'c', 'a'});
    selection.setEntries([]);
    expect(selection.isActive, isTrue);
    expect(selection.selection, isEmpty);
  });

  test('append preserves a live drag while reorder restores its committed snapshot', () {
    final selection = controller();
    selection.click(0);
    selection.startRangeSelection(2);
    selection.handleDragOver(4);
    selection.setEntries(['a', 'b', 'c', 'd', 'e', 'f']);
    expect(selection.isDragInProgress, isTrue);
    expect(selection.selectedKeys, {'a', 'c', 'd', 'e'});
    selection.setEntries(['f', 'e', 'a', 'c']);
    expect(selection.isDragInProgress, isFalse);
    expect(selection.selectedKeys, {'a'});
  });

  testWidgets(
    'row replacement keeps current geometry and unmount only drops dead bounds',
    (tester) async {
      final selection = controller();
      selection.click(1);
      selection.register(
        SelectionItemInfo(
          index: 1,
          identifier: 'old',
          isSelectable: true,
          positionCallback: () => const Rect.fromLTWH(0, 0, 10, 10),
        ),
      );
      selection.setEntries(['e', 'd', 'c', 'b', 'a']);
      expect(
        selection.positionCallbacks[1]?.call(),
        const Rect.fromLTWH(0, 0, 10, 10),
      );
      var alive = true;
      Rect? replacement() => alive ? const Rect.fromLTWH(20, 20, 10, 10) : null;
      selection.register(
        SelectionItemInfo(
          index: 1,
          identifier: 'new',
          isSelectable: true,
          positionCallback: replacement,
        ),
      );
      selection.unregister(1);
      await tester.pump();
      expect(
        selection.positionCallbacks[1]?.call(),
        const Rect.fromLTWH(20, 20, 10, 10),
      );
      alive = false;
      selection.unregister(1);
      await tester.pump();
      expect(selection.positionCallbacks.containsKey(1), isFalse);
      expect(selection.selectedKeys, {'b'});
    },
  );

  test('scope changes clear the selection, anchor and in-flight drag', () {
    final selection = controller();
    selection.click(2);
    selection.startRangeSelection(1);
    selection.handleDragOver(4);
    selection.setEntries(['a', 'b', 'c', 'd', 'e'], scope: 'new query');
    expect(selection.isActive, isFalse);
    expect(selection.anchor, isNull);
    expect(selection.selection, isEmpty);
    expect(selection.isDragInProgress, isFalse);
  });

  test('folder and topic IDs occupy distinct selectable positions', () {
    final selection = OrderedSelectionController<CollectionSelectionKey>();
    addTearDown(selection.dispose);
    selection.setEntries([
      (CollectionSelectionKind.folder, 'same'),
      (CollectionSelectionKind.topic, 'same'),
    ]);
    selection.enable(initialSelected: [0]);
    expect(selection.selectedKeys, {(CollectionSelectionKind.folder, 'same')});
    selection.click(1, range: true);
    expect(selection.selectedKeys.length, 2);
  });

  test('equal numeric IDs from different origins never alias and missing IDs have row tokens', () {
    final identities = PostSelectionIdentity();
    final first = TestPost(
      id: 7,
      origin: PostOrigin.fromSource(
        booruId: BooruType.danbooru.id,
        booruType: BooruType.danbooru,
        source: 'https://one.test',
      ),
    );
    final second = TestPost(
      id: 7,
      origin: PostOrigin.fromSource(
        booruId: BooruType.danbooru.id,
        booruType: BooruType.danbooru,
        source: 'https://two.test',
      ),
    );
    final unknown = TestPost(id: 0);
    final keys = identities.resolve([first, second, unknown, unknown]);
    expect(keys.toSet().length, 4);
    expect(
      identities
          .resolve([first, second, unknown, unknown, TestPost(id: 0)])
          .take(4),
      keys,
    );
    final replacement = identities.resolve([first, second, TestPost(id: 0)]);
    expect(replacement.take(2), keys.take(2));
    expect(replacement[2], isNot(keys[2]));
  });

  test('engine-specific page keys distinguish equal synthetic numeric IDs', () {
    final origin = PostOrigin.fromSource(
      booruType: BooruType.pixiv,
      booruId: BooruType.pixiv.id,
      source: 'https://pixiv.example',
    );
    final first = TestPost(
      id: 7,
      origin: origin,
      booruData: const _PageData('7:0'),
    );
    final second = TestPost(
      id: 7,
      origin: origin,
      booruData: const _PageData('7:1'),
    );
    final identities = PostSelectionIdentity();
    final before = identities.resolve([first, second]);
    expect(before[0], isNot(before[1]));
    expect(identities.resolve([second, first]), before.reversed);
  });

  test('action snapshots retain their targets and reject changed account resolution', () {
    final profile = BooruConfig.defaultConfig(
      booruType: BooruType.danbooru,
      url: 'https://one.test',
      customDownloadFileNameFormat: null,
    );
    final post = TestPost(
      id: 7,
      origin: PostOrigin.fromSource(
        booruId: BooruType.danbooru.id,
        booruType: profile.auth.booruType,
        source: profile.url,
        profileIdHint: profile.id,
      ),
    );
    final posts = <Post>[post];
    final snapshot = PostActionSnapshot(posts, [profile]);
    posts.clear();
    expect(snapshot.posts, [post]);
    expect(snapshot.commonConfig, profile);
    expect(snapshot.accountsMatch([]), isFalse);
    expect(() => snapshot.posts.clear(), throwsUnsupportedError);
  });
}

class _PageData implements BooruPostData, StableBookmarkPostKeyData {
  const _PageData(this.stableBookmarkPostKey);
  @override
  final String stableBookmarkPostKey;
  @override
  String get typeKey => 'page';
  @override
  int get schemaVersion => 1;
}
