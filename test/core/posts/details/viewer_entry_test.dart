import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/content/types.dart';
import 'package:boorusama/core/posts/details/src/types/viewer_entry.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../bookmarks/pool_bookmark_test_utils.dart';

void main() {
  final profile = BooruConfig.fromJson({
    ...BooruConfig.empty.toJson(),
    'id': poolProfile,
    'url': 'https://danbooru.donmai.us',
    'booruId': 0,
    'booruIdHint': 0,
    'login': 'original',
  });
  final source = ViewerSourceBinding(profile);
  ContentReference groupReference(int id) =>
      const ContentReferenceCodec().parse(
        engine: BooruType.danbooru,
        site: Uri.parse(profile.url),
        kind: ContentKind.group,
        sourceKey: 'pool:$id',
      );
  GroupViewerEntry group(String occurrence, {int id = 10}) => GroupViewerEntry(
    summary: ContentGroupSummary(
      reference: groupReference(id),
      title: 'Pool',
      memberCount: 20,
      displayCategory: 'series',
    ),
    occurrenceId: occurrence,
    source: source,
  );
  PostViewerEntry post(String occurrence, int id) => PostViewerEntry(
    post: testPoolPost(id).post,
    occurrenceId: occurrence,
    source: source,
  );

  test(
    'display indices map explicitly across Posts, Series and Collections',
    () {
      final sequence = ViewerEntrySequence([
        post('a', 1),
        group('b'),
        post('c', 2),
        group('d', id: 20),
        post('e', 3),
      ]);
      expect(sequence.entries.map((e) => e.occurrenceId), [
        'a',
        'b',
        'c',
        'd',
        'e',
      ]);
      expect(List.generate(5, sequence.postIndex), [0, null, 1, null, 2]);
      expect(List.generate(5, sequence.postAt).map((p) => p?.id), [
        1,
        null,
        2,
        null,
        3,
      ]);
      expect(sequence.postAt(-1), isNull);
      expect(sequence.postAt(5), isNull);
    },
  );

  test('identical content has distinct navigation occurrences', () {
    final first = group('first');
    final second = group('second');
    expect(first.contentIdentity, second.contentIdentity);
    final sequence = ViewerEntrySequence([first, second]);
    expect(sequence.entries, [first, second]);
    expect(sequence.posts, isEmpty);
  });

  test(
    'source removals and reordering cannot substitute established pages',
    () {
      final a = post('a', 1);
      final b = group('b');
      final sequence = ViewerEntrySequence([b, a]);
      sequence.append([a, post('c', 3)]);
      expect(sequence.entries.map((e) => e.occurrenceId), ['b', 'a', 'c']);
      expect(sequence.entries.first, same(b));
    },
  );

  test('removed profile never borrows another account on the same host', () {
    final other = BooruConfig.fromJson({...profile.toJson(), 'id': poolGroupB});
    expect(source.resolve([other]), isNull);
    expect(source.resolve([other, profile]), profile);
  });

  test('changed credentials, account or visibility invalidate the source', () {
    for (final change in [
      {'login': 'replacement'},
      {'apiKey': 'replacement'},
      {'url': 'https://other.example'},
      {'ratingFilter': profile.ratingFilter.index == 0 ? 1 : 0},
    ]) {
      final changed = BooruConfig.fromJson({...profile.toJson(), ...change});
      expect(source.resolve([changed]), isNull, reason: change.keys.single);
    }
  });
}
