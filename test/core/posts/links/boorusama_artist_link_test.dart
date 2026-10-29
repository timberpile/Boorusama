import 'dart:convert';

import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/posts/links/boorusama_artist_link.dart';
import 'package:boorusama/core/posts/links/boorusama_link_file.dart';
import 'package:flutter_test/flutter_test.dart';

String link({String name = 'artist_(name)', String site = 'https://danbooru.test/', String engine = 'danbooru'}) => Uri(
  scheme: 'boorusama', host: 'artist', path: '/open',
  queryParameters: {'v': '1', 'engine': engine, 'site': site, 'name': name},
).toString();

BooruConfig profile(String id, String url, {BooruType type = BooruType.danbooru}) => BooruConfig.fromJson({
  ...BooruConfig.empty.toJson(), 'id': id, 'name': id,
  'booruId': type.id, 'booruIdHint': type.id, 'url': url,
  'login': 'private-user', 'apiKey': 'private-key',
});

void main() {
  test('round trips a Unicode artist in the existing document envelope', () {
    final artist = BoorusamaArtistLink.parse(link(name: '絵師_(sample)'));
    final document = BoorusamaLinkFile.fromUri(artist.uri.toString());
    expect(document.fileName, 'boorusama-artist.bslink');
    expect(BoorusamaLinkFile.decode(document.encode()).uri, artist.uri);
    expect(BoorusamaArtistLink.parse(document.uri.toString()), artist);
    expect(jsonDecode(utf8.decode(document.encode()))['version'], 1);
  });

  test('sharing includes only a site and artist identity, never account fields', () {
    final source = profile('00000000-0000-4000-8000-000000000001', 'https://danbooru.test/');
    final artist = BoorusamaArtistLink.fromArtist(auth: source.auth, artistName: 'cat')!;
    expect(artist.uri.queryParameters.keys.toSet(), {'v', 'engine', 'site', 'name'});
    expect(artist.uri.toString(), isNot(contains('private')));
  });

  for (final invalid in [
    link(name: ''), link(name: 'cat dog'), link(name: 'cat\n'),
    link(engine: 'pixiv'), link(site: 'javascript:alert(1)'),
    link(site: 'https://user:secret@danbooru.test/'),
    link(site: 'https://danbooru.test/?api_key=secret'),
    link(site: 'https://danbooru.test/#fragment'),
    '${link()}&name=other', '${link()}&token=secret', '${link()}#fragment',
    link().replaceFirst('v=1', 'v=2'), link().replaceFirst('/open', '/other'),
    '${link()}%',
  ]) {
    test('rejects malformed or unsupported artist URI ${invalid.hashCode}', () {
      expect(BoorusamaArtistLink.tryParse(invalid), isNull);
      expect(() => BoorusamaLinkFile.fromUri(invalid), throwsFormatException);
    });
  }

  test('matches only the exact engine and normalized site including path and port', () {
    final artist = BoorusamaArtistLink.parse(link(site: 'https://danbooru.test/sub/'));
    final profiles = [
      profile('00000000-0000-4000-8000-000000000001', 'https://danbooru.test/sub/'),
      profile('00000000-0000-4000-8000-000000000002', 'https://danbooru.test/other/'),
      profile('00000000-0000-4000-8000-000000000003', 'https://danbooru.test:8443/sub/'),
      profile('00000000-0000-4000-8000-000000000004', 'https://other.test/sub/'),
      profile('00000000-0000-4000-8000-000000000005', 'https://danbooru.test/sub/', type: BooruType.pixiv),
    ];
    expect(artist.matchingProfiles(profiles), [profiles.first]);
  });

  test('existing search documents retain their type and filename', () {
    final search = Uri(scheme: 'boorusama', host: 'search', path: '/open', queryParameters: {
      'v': '1', 'engine': 'danbooru', 'site': 'https://danbooru.test/', 'mode': 'raw', 'q': 'cat',
    });
    final file = BoorusamaLinkFile.fromUri(search.toString());
    final canonical = search.replace(queryParameters: {
      ...search.queryParameters,
      'site': 'https://danbooru.test',
    });
    expect(file.fileName, 'boorusama-search.bslink');
    expect(file.uri, canonical);
    expect(BoorusamaLinkFile.decode(file.encode()).uri, canonical);
  });
}
