import 'package:boorusama/core/posts/links/boorusama_post_link.dart';
import 'package:boorusama/core/posts/links/boorusama_search_link.dart';
import 'package:boorusama/core/posts/links/link_share_message.dart';
import 'package:flutter_test/flutter_test.dart';

const _postCaption = 'Post {id} on {profile}';
const _postArtistCaption = 'Post {id} by {artist} on {profile}';
const _searchCaption = "Search '{query}' on {profile}";

BoorusamaPostLink _post(String engine, String key) => BoorusamaPostLink.parse(
  Uri(
    scheme: 'boorusama',
    host: 'post',
    path: '/open',
    queryParameters: {
      'v': '1',
      'engine': engine,
      'site': 'https://site.test',
      'key': key,
    },
  ).toString(),
);

BoorusamaSearchLink _search(String query, {String mode = 'raw'}) =>
    BoorusamaSearchLink.parse(
      Uri(
        scheme: 'boorusama',
        host: 'search',
        path: '/open',
        queryParameters: {
          'v': '1',
          'engine': 'danbooru',
          'site': 'https://site.test',
          'mode': mode,
          'q': query,
        },
      ).toString(),
    );

String _postMessage(
  BoorusamaPostLink link, {
  String profile = 'My Danbooru',
  List<String> artists = const [],
}) => postLinkShareMessage(
  link,
  profileName: profile,
  postTemplate: _postCaption,
  postByArtistTemplate: _postArtistCaption,
  artists: artists,
);

String _searchMessage(
  BoorusamaSearchLink link, {
  String profile = 'My Danbooru',
}) => searchLinkShareMessage(
  link,
  profileName: profile,
  searchTemplate: _searchCaption,
);

void main() {
  test('post caption uses the real ID and profile name without extra text', () {
    expect(_postMessage(_post('danbooru', 'id:42')), 'Post 42 on My Danbooru');
    expect(
      _postMessage(_post('sankaku', 'id:abc123')),
      'Post abc123 on My Danbooru',
    );
    expect(_postMessage(_post('danbooru', 'id:42')).split('\n'), hasLength(1));
  });

  test('Pixiv caption uses artwork ID, never the synthetic page ID', () {
    expect(
      _postMessage(_post('pixiv', 'work-page:12345:2'), profile: 'Pixiv Art'),
      'Post 12345 on Pixiv Art',
    );
  });

  test('one known artist is shown; unknown and duplicate tags are ignored', () {
    expect(
      _postMessage(
        _post('danbooru', 'id:42'),
        artists: [
          'artist_request',
          'bob',
          'alice',
          'alice',
          '',
          'unknown_artist',
        ],
      ),
      'Post 42 by alice on My Danbooru',
    );
    expect(
      _postMessage(
        _post('danbooru', 'id:42'),
        artists: ['unknown_artist', 'artist_request', ''],
      ),
      'Post 42 on My Danbooru',
    );
  });

  test('search caption shows readable query and profile in a single line', () {
    expect(
      _searchMessage(_search('one_piece -rating:safe'), profile: 'Danbooru'),
      "Search 'one_piece -rating:safe' on Danbooru",
    );
    expect(
      _searchMessage(_search('["one_piece","-rating:safe"]', mode: 'tags')),
      "Search 'one_piece -rating:safe' on My Danbooru",
    );
  });

  test('long search caption is shortened but never mutates the document', () {
    final query = List.filled(50, 'one_piece').join(' ');
    final link = _search(query);
    final originalUri = link.uri.toString();
    final message = _searchMessage(link);
    final displayed = message.substring(
      "Search '".length,
      message.lastIndexOf("' on "),
    );
    expect(displayed.runes.length, lessThanOrEqualTo(180));
    expect(displayed, endsWith('…'));
    expect(message.split('\n'), hasLength(1));
    expect(link.query, query);
    expect(link.uri.toString(), originalUri);
  });

  test(
    'external names cannot inject message lines or directional controls',
    () {
      final post = _postMessage(
        _post('danbooru', 'id:42'),
        profile: 'A\nB\u202efake',
        artists: ['art\nist\u2068'],
      );
      expect(post, 'Post 42 by art ist on A Bfake');
      expect(post.split('\n'), hasLength(1));
      final search = _searchMessage(
        _search('cat -dog'),
        profile: 'My\nProfile\u202efake',
      );
      expect(search, "Search 'cat -dog' on My Profilefake");
      expect(search.split('\n'), hasLength(1));
      expect(search, isNot(contains('boorusama://')));
      expect(search, isNot(contains('.bslink')));
    },
  );

  test(
    'localized templates render the same content with translated grammar',
    () {
      expect(
        postLinkShareMessage(
          _post('danbooru', 'id:42'),
          profileName: 'Privat',
          postTemplate: 'Post {id} auf {profile}',
          postByArtistTemplate: 'Post {id} von {artist} auf {profile}',
          artists: ['alice'],
        ),
        'Post 42 von alice auf Privat',
      );
    },
  );
}
