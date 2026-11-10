import 'package:boorusama/boorus/pixiv/configs/extra_data.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/bookmarks/src/server_favorites/settings_provider.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:flutter_test/flutter_test.dart';

BooruConfig actor({
  String token = 'first',
  String? user = '42',
  String id = '00000000-0000-4000-8000-000000000001',
}) => BooruConfig.fromJson({
  ...BooruConfig.empty.toJson(),
  'id': id,
  'booruId': BooruType.pixiv.id,
  'booruIdHint': BooruType.pixiv.id,
  'url': 'https://pixiv.net',
  'apiKey': token,
  'passHash': PixivExtraData(userId: user).toPassHash(),
});

void main() {
  test('known actor tolerates token rotation but not account or profile replacement', () {
    final before = actor();
    expect(serverFavoriteActorMatches(before, actor(token: 'rotated')), isTrue);
    expect(serverFavoriteActorMatches(before, actor(user: '99')), isFalse);
    expect(
      serverFavoriteActorMatches(
        before,
        actor(id: '00000000-0000-4000-8000-000000000002'),
      ),
      isFalse,
    );
  });
  test('unknown identities retain exact credential matching', () {
    expect(
      serverFavoriteActorMatches(actor(user: null), actor(user: null)),
      isTrue,
    );
    expect(
      serverFavoriteActorMatches(
        actor(user: null),
        actor(user: null, token: 'rotated'),
      ),
      isFalse,
    );
    expect(serverFavoriteActorMatches(actor(), actor(user: null)), isFalse);
  });
  test(
    'profile order is irrelevant; removed or changed actors are rejected',
    () {
      final a = actor();
      final b = actor(id: '00000000-0000-4000-8000-000000000002');
      expect(
        serverFavoriteAccountsMatch([a, b], [b, actor(token: 'rotated')]),
        isTrue,
      );
      expect(serverFavoriteAccountsMatch([a, b], [a]), isFalse);
      expect(serverFavoriteAccountsMatch([a], [actor(user: '99')]), isFalse);
    },
  );
}
