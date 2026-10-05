import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/posts/shares/src/providers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../profile_uuid_utils.dart';

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
}
