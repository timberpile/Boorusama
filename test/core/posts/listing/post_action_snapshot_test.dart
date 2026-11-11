import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/posts/listing/src/types/post_action_snapshot.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fakes/test_post.dart';

void main() {
  test('repeated content produces one bulk target', () {
    final profile = _profile(
      '00000000-0000-4000-8000-000000000001',
      BooruType.danbooru,
      'https://a.example',
    );
    final first = _post(
      42,
      BooruType.danbooru,
      profile.url,
      hint: profile.id,
      tags: {'first'},
    );
    final second = _post(
      42,
      BooruType.danbooru,
      profile.url,
      hint: profile.id,
      tags: {'second'},
    );
    expect(PostActionSnapshot.uniquePosts([first, second]), [same(first)]);
    final snapshot = PostActionSnapshot([first, second], [profile]);
    expect(snapshot.posts, [same(first)]);
    expect(snapshot.targets, hasLength(1));
    expect(snapshot.targets.single.config, profile);
    expect(snapshot.isSingle, isTrue);
    expect(snapshot.accountsMatch([profile]), isTrue);
    expect(snapshot.accountsMatch([]), isFalse);
  });

  test('same numeric ID across engines and sites remains distinct', () {
    final a = _post(42, BooruType.danbooru, 'https://a.example');
    final b = _post(42, BooruType.szurubooru, 'https://a.example');
    final c = _post(42, BooruType.danbooru, 'https://b.example');
    final snapshot = PostActionSnapshot([a, b, c], []);
    expect(snapshot.posts, [same(a), same(b), same(c)]);
    expect(snapshot.targets, hasLength(3));
    expect(snapshot.targets.every((target) => target.config == null), isTrue);
  });

  test('unknown content identities are retained individually', () {
    final a = TestPost(id: 0);
    final b = TestPost(id: 0);
    final snapshot = PostActionSnapshot([a, b], []);
    expect(snapshot.posts, [same(a), same(b)]);
    expect(snapshot.targets, hasLength(2));
    expect(snapshot.canBookmark, isFalse);
    expect(snapshot.allResolved, isFalse);
  });

  test(
    'same content with different hints keeps first actor deterministically',
    () {
      final firstProfile = _profile(
        '00000000-0000-4000-8000-000000000001',
        BooruType.danbooru,
        'https://a.example',
      );
      final secondProfile = _profile(
        '00000000-0000-4000-8000-000000000002',
        BooruType.danbooru,
        'https://a.example',
      );
      final first = _post(
        42,
        BooruType.danbooru,
        firstProfile.url,
        hint: firstProfile.id,
      );
      final second = _post(
        42,
        BooruType.danbooru,
        secondProfile.url,
        hint: secondProfile.id,
      );
      final snapshot = PostActionSnapshot(
        [first, second],
        [firstProfile, secondProfile],
      );
      expect(snapshot.posts, [same(first)]);
      expect(snapshot.targets.single.config, firstProfile);
      expect(snapshot.accountsMatch([secondProfile]), isFalse);
      final reversed = PostActionSnapshot(
        [second, first],
        [firstProfile, secondProfile],
      );
      expect(reversed.posts, [same(second)]);
      expect(reversed.targets.single.config, secondProfile);
    },
  );
}

BooruConfig _profile(String id, BooruType type, String url) =>
    BooruConfig.fromJson({
      ...BooruConfig.empty.toJson(),
      'id': id,
      'url': url,
      'booruId': type.id,
      'booruIdHint': type.id,
    });
Post _post(
  int id,
  BooruType type,
  String site, {
  String? hint,
  Set<String> tags = const {},
}) => TestPost(
  id: id,
  tags: tags,
  origin: PostOrigin.fromSource(
    booruType: type,
    booruId: type.id,
    source: site,
    profileIdHint: hint,
  ),
);
