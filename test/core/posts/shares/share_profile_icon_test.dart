import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/shares/src/providers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../profile_uuid_utils.dart';
import '../../../bulk_downloads/common.dart';

void main() {
  test('selects the icon of the matching account on the same Booru', () {
    final first = BooruConfig.fromJson({
      ...BooruConfig.empty.toJson(),
      'id': profileUuid(1),
      'url': 'https://site.test',
      'login': 'first',
      'profileIcon': const {'url': 'https://icons.test/first.png'},
    });
    final second = BooruConfig.fromJson({
      ...BooruConfig.empty.toJson(),
      'id': profileUuid(2),
      'url': 'https://site.test',
      'login': 'second',
      'profileIcon': const {'url': 'https://icons.test/second.png'},
    });

    expect(
      profileIconUrlForAuth([first, second], second.auth),
      'https://icons.test/second.png',
    );
    expect(
      profileIconUrlForAuth([first], second.auth),
      isNull,
    );
  });
  test(
    'source profile name follows post origin rather than active account',
    () {
      BooruConfig profile(int id, String name, String url) =>
          BooruConfig.fromJson({
            ...BooruConfig.defaultConfig(
              booruType: BooruType.danbooru,
              url: url,
              customDownloadFileNameFormat: null,
            ).toJson(),
            'id': profileUuid(id),
            'name': name,
            'login': 'account-$id',
          });

      final first = profile(1, 'Primary', 'https://site.test');
      final second = profile(2, 'Artist Account', 'https://site.test');
      final unrelated = profile(3, 'Different Booru', 'https://other.test');
      final post = dummyPost(id: 42).copyWith(
        origin: PostOrigin.fromSource(
          booruType: BooruType.danbooru,
          booruId: BooruType.danbooru.id,
          source: 'https://site.test',
          profileIdHint: second.id,
        ),
      );

      expect(
        postShareProfileName([first, second, unrelated], post, first.auth),
        'Artist Account',
      );
      expect(
        postShareProfileName([first, unrelated], post, first.auth),
        'Primary',
      );
      expect(postShareProfileName([unrelated], post, first.auth), 'site.test');
    },
  );
}
