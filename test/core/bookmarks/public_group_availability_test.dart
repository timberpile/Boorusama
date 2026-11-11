import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_profile_availability.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_library_state.dart';
import 'package:boorusama/core/bookmarks/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/content/types.dart';
import 'package:boorusama/core/posts/details/src/types/post_presentation_fallback_reason.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pool_bookmark_test_utils.dart';

void main() {
  test(
    'supported built-in native Pool and Related are visible without profiles',
    () {
      final pool = _record(1, 'https://danbooru.donmai.us', 'pool:10');
      final related = _record(2, 'https://danbooru.donmai.us', 'related:10');
      final library = _library([pool, related]);
      final checked = <ContentReference>[];
      final availability = BookmarkProfileAvailability(
        library,
        [],
        supportsGroup: (reference) {
          checked.add(reference);
          return true;
        },
      );
      expect(library.pools.map((p) => p.sourceSite), [
        Uri.parse('https://danbooru.donmai.us'),
        Uri.parse('https://danbooru.donmai.us'),
      ]);
      expect(availability.collectionIds, {'1', '2'});
      expect(availability.recordIds, {1, 2});
      expect(checked.map((r) => r.sourceKey).toSet(), {
        'pool:10',
        'related:10',
      });
      expect(
        checked.every(
          (r) => r.kind == ContentKind.group && r.engine == BooruType.danbooru,
        ),
        isTrue,
      );
      expect(availability.unavailableReasons, isEmpty);
    },
  );

  test('unsupported public Group reports unavailable engine', () {
    final availability = BookmarkProfileAvailability(
      _library([_record(1, 'https://danbooru.donmai.us', 'pool:10')]),
      [],
      supportsGroup: (_) => false,
    );
    expect(availability.collectionIds, isEmpty);
    expect(
      availability.unavailableReasons[1],
      PostPresentationFallbackReason.unavailableEngine,
    );
  });

  test('custom, private, HTTP and unproven legacy locators are not public', () {
    final native = _library([
      _record(1, 'https://custom.example', 'pool:10'),
      _record(2, 'https://192.168.1.5', 'pool:10'),
      _record(3, 'http://danbooru.donmai.us', 'pool:10'),
    ]);
    final legacy = BookmarkLibraryState(
      bookmarks: [],
      groups: [],
      pools: [testPool()],
    );
    final a = BookmarkProfileAvailability(
      native,
      [],
      supportsGroup: (_) => true,
    );
    final b = BookmarkProfileAvailability(
      legacy,
      [],
      supportsGroup: (_) => true,
    );
    expect(native.pools.map((p) => p.sourceSite?.scheme), [
      'https',
      'https',
      'http',
    ]);
    expect(legacy.pools.single.sourceSite, isNull);
    expect(a.collectionIds, isEmpty);
    expect(b.collectionIds, isEmpty);
    expect(a.unavailableReasons.keys, containsAll([1, 2, 3]));
    expect(b.unavailableReasons, isNotEmpty);
  });

  test('ambiguous matching profiles never fall back to public', () {
    final library = _library([
      _record(1, 'https://danbooru.donmai.us', 'related:10'),
    ]);
    final availability = BookmarkProfileAvailability(library, [
      _profile(poolProfile, 'https://danbooru.donmai.us'),
      _profile(poolGroupB, 'https://danbooru.donmai.us'),
    ], supportsGroup: (_) => true);
    expect(availability.collectionIds, isEmpty);
    expect(
      availability.unavailableReasons[1],
      PostPresentationFallbackReason.ambiguousProfile,
    );
  });

  test('configured custom HTTP profile supplies its proven locator', () {
    final library = _library([
      _record(1, 'http://custom.example:8080/install', 'pool:10'),
    ]);
    final checked = <ContentReference>[];
    final availability = BookmarkProfileAvailability(
      library,
      [
        _profile(poolProfile, 'http://custom.example:8080/install'),
      ],
      supportsGroup: (reference) {
        checked.add(reference);
        return true;
      },
    );
    expect(availability.collectionIds, {'1'});
    expect(
      checked.single.site,
      Uri.parse('http://custom.example:8080/install'),
    );
    expect(checked.single.sourceKey, 'pool:10');
  });

  test('same Group IDs at unrelated installations cannot borrow a profile', () {
    final library = _library([_record(1, 'https://custom.example', 'pool:10')]);
    final availability = BookmarkProfileAvailability(library, [
      _profile(poolProfile, 'https://other.example'),
    ], supportsGroup: (_) => true);
    expect(availability.collectionIds, isEmpty);
    expect(
      availability.unavailableReasons[1],
      PostPresentationFallbackReason.missingProfile,
    );
  });
}

ContentGroupBookmark _record(int id, String site, String key) {
  final reference = const ContentReferenceCodec().parse(
    engine: BooruType.danbooru,
    site: Uri.parse(site),
    kind: ContentKind.group,
    sourceKey: key,
  );
  final snapshot = StoredGroupSnapshot(
    summary: ContentGroupSummary(reference: reference, title: 'Group'),
  );
  final created = DateTime.utc(2020);
  final observed = DateTime.utc(2026);
  return key.startsWith('related:')
      ? RelatedBookmark(
          id: id,
          snapshot: snapshot,
          createdAt: created,
          observedAt: observed,
        )
      : ContentGroupBookmark(
          id: id,
          snapshot: snapshot,
          createdAt: created,
          observedAt: observed,
        );
}

BookmarkLibraryState _library(List<ContentGroupBookmark> records) =>
    BookmarkLibraryState(bookmarks: [], groups: [], records: records);
BooruConfig _profile(String id, String url) => BooruConfig.fromJson({
  ...BooruConfig.empty.toJson(),
  'id': id,
  'url': url,
  'booruId': BooruType.danbooru.id,
  'booruIdHint': BooruType.danbooru.id,
});
